import { DurableObject } from 'cloudflare:workers';
import { advance, createRoom, dispatch, nextAlarm, snapshot, type Room } from './engine.ts';
import { commandSchema, GameError, adultPacks, type Principal, type Command } from './protocol.ts';
import type { Catalogue } from './content.ts';
import { rpcResult } from './rpc.ts';

export class RoomObject extends DurableObject<Env> {
  constructor(ctx:DurableObjectState,env:Env) {
    super(ctx,env);
    this.ctx.storage.sql.exec('CREATE TABLE IF NOT EXISTS room (id INTEGER PRIMARY KEY CHECK (id=1), state TEXT NOT NULL)');
    this.ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping','pong'));
  }
  private read():Room|undefined {
    const row=this.ctx.storage.sql.exec<{state:string}>('SELECT state FROM room WHERE id=1').toArray()[0];
    return row ? JSON.parse(row.state) as Room : undefined;
  }
  private write(room:Room) {
    this.ctx.storage.sql.exec('INSERT INTO room(id,state) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET state=excluded.state',JSON.stringify(room));
  }
  async initialize(id:string,code:string,catalogue:Catalogue,seen:string[]) {
    if(!this.read()) {const room=createRoom(id,code,catalogue,seen);room.emptySince=Date.now();this.write(room);await this.schedule(room,Date.now());}
  }
  async execute(principal:Principal,raw:unknown) { return rpcResult(() => this.apply(principal,raw)); }
  private async apply(principal:Principal,raw:unknown) {
    const command=commandSchema.parse(raw),now=Date.now();
    const room=this.read();if(!room)throw new GameError('expired','Spillet findes ikke.',404);
    // Persist clock transitions even when a late/invalid command is rejected.
    advance(room,now);this.write(room);
    let updated:Room;
    try {updated=dispatch(room,principal,command,now);}
    catch(error) {await this.schedule(room,now);this.broadcast(room,now);throw error;}
    this.write(updated);
    await this.schedule(updated,now);
    this.broadcast(updated,now);
    if(command.action.type==='leave')return {requestID:command.requestID,snapshot:null};
    return {requestID:command.requestID,snapshot:snapshot(updated,principal.id,now)};
  }
  async inspect(principal:Principal) { return rpcResult(() => this.inspectValue(principal)); }
  private async inspectValue(principal:Principal) {
    const room=this.read();if(!room)throw new GameError('expired','Spillet findes ikke.',404);
    advance(room,Date.now());this.write(room);await this.schedule(room,Date.now());
    if(room.phase==='expired')throw new GameError('expired','Spillet er udløbet.',410);
    return snapshot(room,principal.id,Date.now());
  }
  async preview() {
    const r=this.read();if(!r)return null;advance(r,Date.now());this.write(r);
    if(r.phase==='expired')return null;
    return {characters:r.players.map(p=>({name:p.name,character:p.character})),adultRequired:r.settings.drinking || r.settings.packs.some(p=>adultPacks.has(p))};
  }
  async isExpired() {const r=this.read();if(!r)return true;advance(r,Date.now());this.write(r);await this.schedule(r,Date.now());return r.phase==='expired';}
  async questionForReport(principal:Principal) {
    const r=this.read();if(!r || !r.players.some(p => p.id===principal.id))throw new GameError('not_in_room','Du er ikke med.',403);
    return r.round?.question.id ?? null;
  }
  async hostSeen() {const r=this.read();return r ? {hostID:r.hostID,seen:r.seen} : null;}
  async fetch(request:Request) {
    // This handler is reachable only through the authenticated Worker binding.
    const principal=JSON.parse(request.headers.get('X-EnTil-Principal') ?? 'null') as Principal|null;
    if(!principal)return new Response('Unauthorized',{status:401});
    if(request.headers.get('Upgrade')!=='websocket')return new Response('WebSocket required',{status:426});
    const initial=await this.inspectValue(principal);
    const pair=new WebSocketPair(),client=pair[0],server=pair[1];
    for(const old of this.ctx.getWebSockets(principal.id))old.close(1000,'Ny forbindelse');
    this.ctx.acceptWebSocket(server,[principal.id]);server.serializeAttachment(principal);
    await this.apply(principal,this.presence(true));
    server.send(JSON.stringify({type:'snapshot',snapshot:initial}));
    return new Response(null,{status:101,webSocket:client});
  }
  private presence(connected:boolean):Command {return {v:1,requestID:crypto.randomUUID(),matchID:null,roundID:null,action:{type:'presence',connected}};}
  async webSocketMessage(socket:WebSocket,message:string|ArrayBuffer) {
    if(this.env.DISABLED==='true') {socket.close(1013,'Spillet holder en kort pause');return;}
    if(typeof message!=='string' || message.length>4096) {socket.close(1009,'Beskeden er for stor');return;}
    const principal=socket.deserializeAttachment() as Principal;
    try {
      // Ownership is refreshed through HTTP; gameplay commands do not need StoreKit lookups.
      const raw:unknown=JSON.parse(message);
      const command=commandSchema.parse(raw);
      if(['settings','start','rematch','end'].includes(command.action.type))throw new GameError('use_http','Prøv igen via forbindelsen.');
      const ack=await this.apply(principal,command);socket.send(JSON.stringify({type:'ack',...ack}));
    } catch(error) {socket.send(JSON.stringify({type:'error',code:error instanceof GameError ? error.code : 'invalid',message:error instanceof GameError ? error.message : 'Beskeden kunne ikke læses.'}));}
  }
  async webSocketClose(socket:WebSocket) {
    const principal=socket.deserializeAttachment() as Principal;
    if(this.ctx.getWebSockets(principal.id).some(s => s!==socket && s.readyState===WebSocket.OPEN))return;
    const r=this.read();if(!r || r.phase==='expired' || !r.players.some(p => p.id===principal.id))return;
    await this.apply(principal,this.presence(false));
  }
  async webSocketError(socket:WebSocket) {await this.webSocketClose(socket);}
  async alarm() {
    const room=this.read();if(!room)return;
    const now=Date.now();advance(room,now);this.write(room);await this.schedule(room,now);this.broadcast(room,now);
  }
  private async schedule(room:Room,now:number) {
    if(room.phase==='expired') {
      await this.ctx.storage.deleteAlarm();
      await this.env.DB.prepare('DELETE FROM rooms WHERE room_id=?').bind(room.id).run();
      await this.ctx.storage.deleteAll();
      return;
    }
    let at=nextAlarm(room,now);
    // Reveal stages need synchronized snapshots even if no player sends a command.
    if(room.phase==='reveal') {
      const stages=[1800,3800,5800,7800].map(ms => room.round!.revealAt!+ms).filter(t => t>now);
      if(stages.length)at=Math.min(at ?? Infinity,...stages);
    }
    if(at!==undefined)await this.ctx.storage.setAlarm(at);else await this.ctx.storage.deleteAlarm();
  }
  private broadcast(room:Room,now:number) {
    for(const socket of this.ctx.getWebSockets()) {
      const p=socket.deserializeAttachment() as Principal;
      if(!room.players.some(x => x.id===p.id)) {socket.close(1000,'Du er ikke længere med');continue;}
      try {socket.send(JSON.stringify({type:'snapshot',snapshot:snapshot(room,p.id,now)}));}catch {socket.close(1011,'Forbind igen');}
    }
  }
}
