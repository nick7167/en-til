import { z } from 'zod';
import { GameError, normalizeCode, packIDs, type Principal, type PackID, commandSchema } from './protocol.ts';
import { validateCatalogue } from './content.ts';
import { unwrap } from './rpc.ts';
import draft from '../../content/catalogue.draft.json';
export { RoomObject } from './room-object.ts';

const json=(value:unknown,status=200) => Response.json(value,{status,headers:{'Cache-Control':'no-store'}});
async function body(request:Request) {
  const reader=request.body?.getReader();if(!reader)throw new GameError('invalid','Der mangler en besked.',400);
  let size=0;const chunks:Uint8Array[]=[];
  while(true){const part=await reader.read();if(part.done)break;size+=part.value.byteLength;if(size>16_384){await reader.cancel();throw new GameError('too_large','Beskeden er for stor.',413);}chunks.push(part.value);}
  const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
  return JSON.parse(new TextDecoder().decode(bytes)) as unknown;
}
async function hash(value:string){return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))),x => x.toString(16).padStart(2,'0')).join('');}
async function authenticate(request:Request,env:Env):Promise<Principal> {
  const bearer=request.headers.get('Authorization');if(!bearer?.startsWith('Bearer ') || bearer.length>200)throw new GameError('unauthorized','Forbindelsen skal oprettes igen.',401);
  const row=await env.DB.prepare('SELECT id FROM sessions WHERE token_hash=?').bind(await hash(bearer.slice(7))).first<{id:string}>();
  if(!row)throw new GameError('unauthorized','Forbindelsen skal oprettes igen.',401);
  const records=await env.DB.prepare('SELECT p.product_id FROM purchases p JOIN ownership o ON o.transaction_id=p.transaction_id AND o.environment=p.environment WHERE o.session_id=? AND p.environment=? AND p.revoked=0').bind(row.id,env.ENVIRONMENT==='production'?'Production':'Sandbox').all<{product_id:string}>();
  const owned=new Set<PackID>();
  for(const record of records.results){const key=record.product_id.split('.').at(-1);if(key==='launch-bundle')for(const p of packIDs.filter(p => p!=='free'))owned.add(p);else if(packIDs.includes(key as PackID))owned.add(key as PackID);}
  return {id:row.id,owned:[...owned]};
}
async function metric(env:Env,event:string){await env.DB.prepare('INSERT INTO metrics(day,event,count) VALUES(?,?,1) ON CONFLICT(day,event) DO UPDATE SET count=count+1').bind(new Date().toISOString().slice(0,10),event).run();}
export default {
  async fetch(request:Request,env:Env,ctx:ExecutionContext):Promise<Response> {
    try {
      const url=new URL(request.url),path=url.pathname;
      if(path==='/health')return json({ok:true,version:1});
      if(env.DISABLED==='true')throw new GameError('disabled','Spillet holder en kort pause. Prøv igen senere.',503);
      if(!['GET','POST'].includes(request.method))return new Response(null,{status:405});
      const ip=request.headers.get('CF-Connecting-IP') ?? 'local';
      const group=path==='/v1/sessions'?'session':path==='/v1/rooms'?'create':path==='/v1/lookup'?'lookup':path.endsWith('/reports')?'report':'request';
      if(group!=='request' && !(await env.ENTRY_LIMIT.limit({key:`${group}:${ip}`})).success)throw new GameError('rate_limited','Lidt for mange forsøg. Prøv igen om et øjeblik.',429);
      if(path==='/v1/sessions' && request.method==='POST') {
        const id=crypto.randomUUID(),token=crypto.randomUUID()+'.'+crypto.randomUUID();
        await env.DB.prepare('INSERT INTO sessions(id,token_hash,created_at) VALUES(?,?,?)').bind(id,await hash(token),Date.now()).run();return json({v:1,id,token},201);
      }
      if(path==='/v1/apple/notifications' && request.method==='POST') {
        const {signedPayload}=z.object({signedPayload:z.string().max(14000)}).parse(await body(request));
        const {receiveAppleNotification}=await import('./purchases.ts');
        await receiveAppleNotification(env,signedPayload);return json({received:true});
      }
      const principal=await authenticate(request,env);
      if(path==='/v1/ownership')return json({owned:principal.owned});
      if(path==='/v1/purchases' && request.method==='POST') {
        const {jws}=z.object({jws:z.string().max(14000)}).parse(await body(request));
        const {verifyPurchase}=await import('./purchases.ts');
        await verifyPurchase(env,principal,jws);ctx.waitUntil(metric(env,'purchase_verified'));return json({verified:true});
      }
      if(path==='/v1/lookup' && request.method==='POST') {
        const {code}=z.object({code:z.string().max(20)}).parse(await body(request));
        const normalized=normalizeCode(code);
        if(!/^[A-Z0-9]{4}$/.test(normalized))throw new GameError('code_invalid','Spilkoden har fire bogstaver eller tal.',400);
        const row=await env.DB.prepare('SELECT room_id FROM rooms WHERE code=?').bind(normalized).first<{room_id:string}>();
        if(!row || await env.ROOMS.getByName(row.room_id).isExpired())throw new GameError('not_found','Vi kunne ikke finde et spil med den kode.',404);
        const preview=await env.ROOMS.getByName(row.room_id).preview();
        if(!preview)throw new GameError('not_found','Vi kunne ikke finde et spil med den kode.',404);
        return json({roomID:row.room_id,code:normalized,...preview});
      }
      if(path==='/v1/rooms' && request.method==='POST') {
        const command=commandSchema.parse(await body(request));if(command.action.type!=='join')throw new GameError('invalid','Vælg navn og figur først.',400);
        const existing=await env.DB.prepare('SELECT room_id,code FROM rooms WHERE creator=? AND request_id=?').bind(principal.id,command.requestID).first<{room_id:string;code:string}>();
        let roomID=existing?.room_id,code=existing?.code;
        if(!roomID) {
          roomID=crypto.randomUUID();
          const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
          for(let attempt=0;attempt<12;attempt++) {
            code=Array.from(crypto.getRandomValues(new Uint8Array(4)),x => alphabet[x%alphabet.length]).join('');
            const result=await env.DB.prepare('INSERT OR IGNORE INTO rooms(code,room_id,creator,request_id,created_at) VALUES(?,?,?,?,?)').bind(code,roomID,principal.id,command.requestID,Date.now()).run();
            if(result.meta.changes)break;
            const retry=await env.DB.prepare('SELECT room_id,code FROM rooms WHERE creator=? AND request_id=?').bind(principal.id,command.requestID).first<{room_id:string;code:string}>();
            if(retry){roomID=retry.room_id;code=retry.code;break;}
            if(attempt===11)throw new GameError('capacity','Der er travlt. Prøv igen om lidt.',503);
          }
        }
        const stored=await env.DB.prepare('SELECT payload FROM catalogue_versions WHERE active=1').first<{payload:string}>();
        if(!stored && env.ENVIRONMENT!=='development')throw new GameError('content_unavailable','Spørgsmålene er ikke klar endnu.',503);
        const catalogue=validateCatalogue(stored?JSON.parse(stored.payload):draft,env.ENVIRONMENT!=='development');
        const seen=await env.DB.prepare('SELECT question_id FROM seen_questions WHERE session_id=?').bind(principal.id).all<{question_id:string}>();
        const stub=env.ROOMS.getByName(roomID);
        await stub.initialize(roomID,code!,catalogue,seen.results.map(x => x.question_id));
        const ack=unwrap(await stub.execute(principal,command));ctx.waitUntil(metric(env,'room_created'));return json(ack,201);
      }
      const route=/^\/v1\/rooms\/([a-f0-9-]{36})(?:\/(commands|socket|reports))?$/.exec(path);
      if(route) {
        const stub=env.ROOMS.getByName(route[1]!);
        if(route[2]==='socket') {
          const headers=new Headers();headers.set('Upgrade','websocket');headers.set('X-EnTil-Principal',JSON.stringify(principal));
          return stub.fetch(new Request('https://internal/socket',{headers}));
        }
        if(route[2]==='commands' && request.method==='POST') {
          const command=commandSchema.parse(await body(request));const result=unwrap(await stub.execute(principal,command));
          const history=await stub.hostSeen();
          if(history?.hostID && history.seen.length)ctx.waitUntil(env.DB.batch(history.seen.map(id => env.DB.prepare('INSERT OR IGNORE INTO seen_questions(session_id,question_id) VALUES(?,?)').bind(history.hostID,id))));
          if(command.action.type==='join')ctx.waitUntil(metric(env,'room_joined'));
          return json(result);
        }
        if(route[2]==='reports' && request.method==='POST') {
          const report=z.object({id:z.string().uuid(),reason:z.enum(['wrong','unclear','inappropriate','other']),note:z.string().max(500).optional()}).parse(await body(request));
          const questionID=await stub.questionForReport(principal);if(!questionID)throw new GameError('phase','Der er ikke et spørgsmål at rapportere.');
          await env.DB.prepare('INSERT OR IGNORE INTO reports(id,session_id,room_id,question_id,reason,note,created_at) VALUES(?,?,?,?,?,?,?)').bind(report.id,principal.id,route[1],questionID,report.reason,report.note ?? null,Date.now()).run();return json({received:true});
        }
        if(!route[2] && request.method==='GET')return json(unwrap(await stub.inspect(principal)));
      }
      return json({code:'not_found',message:'Siden findes ikke.'},404);
    } catch(error) {
      if(error instanceof GameError)return json({code:error.code,message:error.message},error.status);
      if(error instanceof z.ZodError || error instanceof SyntaxError)return json({code:'invalid',message:'Beskeden kunne ikke læses. Prøv igen.'},400);
      // Do not log bodies, tokens, player names, or personal responses.
      ctx.waitUntil(metric(env,'technical_failure'));
      return json({code:'unavailable',message:'Noget gik galt. Prøv igen om et øjeblik.'},503);
    }
  },
} satisfies ExportedHandler<Env>;
