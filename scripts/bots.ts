import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import WebSocket from 'ws';
import type {snapshot} from '../backend/src/engine.ts';
import {normalizeCode, type Command} from '../backend/src/protocol.ts';

type Snapshot = ReturnType<typeof snapshot>;
type Action = Command['action'];

function choose(room:Snapshot, index:number):Action|undefined {
  const me=room.players.find(p=>p.id===room.me);
  if(!me || me.away || me.late || room.adultRequired)return;
  if((room.phase==='lobby' || room.phase==='board') && !me.ready)return {type:'ready',value:true};
  const round=room.round;
  if(!round)return;
  if(room.phase==='private' && !round.privateLocked)return {type:'private',value:index%2 ? 'no' : 'yes'};
  if(room.phase!=='answer')return;
  if(!round.answerLocked) {
    const count=round.kind==='personal' ? (round.responseCount ?? 0)+1 : round.options.length;
    if(count>0)return {type:'answer',value:(round.number+index)%count};
  } else if(!round.backLocked) {
    const others=room.players.filter(p=>p.id!==room.me && !p.away && !p.late);
    const target=others[index%others.length];
    if(target)return {type:'back',playerID:target.id};
  }
}

async function selfTest() {
  const {createRoom,dispatch,snapshot,advance}=await import('../backend/src/engine.ts');
  const {default:catalogue}=await import('../content/catalogue.draft.json');
  const {validateCatalogue}=await import('../backend/src/content.ts');
  let room=createRoom(randomUUID(),'TEST',validateCatalogue(catalogue,false),[]);
  const guests=Array.from({length:3},()=>({id:randomUUID(),owned:[]}));
  let now=Date.now();
  const send=(index:number,action:Action)=>{room=dispatch(room,guests[index]!,{v:1,requestID:randomUUID(),matchID:room.matchID,roundID:room.round?.id ?? null,action},now);};
  guests.forEach((_,i)=>send(i,{type:'join',name:`Bot ${i}`,character:i,adult:true,drinking:false}));
  send(0,{type:'settings',settings:{...room.settings,finish:5,timed:false}});
  guests.forEach((g,i)=>send(i,choose(snapshot(room,g.id,now),i)!));
  send(0,{type:'start'});
  const phases=new Set<string>();
  for(let step=0;step<1000 && room.phase!=='finale';step++) {
    phases.add(room.phase);
    guests.forEach((g,i)=>{const action=choose(snapshot(room,g.id,now),i);if(action)send(i,action);});
    now+=1000;advance(room,now);
  }
  assert.equal(room.phase,'finale');
  for(const phase of ['private','answer','reveal','board','countdown'])assert.ok(phases.has(phase),phase);
  const view=snapshot(room,guests[0]!.id,now);
  assert.equal(choose(view,0),undefined);
  assert.equal(choose({...view,phase:'board',adultRequired:true},0),undefined);
  assert.equal(choose({...view,phase:'board',players:view.players.map(p=>({...p,away:true,ready:false}))},0),undefined);
  console.log('PASS: bots complete a match through private/answer/backing/reveal/board/finale; inactive players stay idle.');
}

async function run() {
  const code=normalizeCode(process.argv[2] ?? ''),count=Number(process.argv[3] ?? 2);
  const base=process.env.ENTIL_TEST_URL ?? 'http://127.0.0.1:8787';
  const url=new URL(base);
  if(!['localhost','127.0.0.1'].includes(url.hostname) && !(process.env.ENTIL_ALLOW_REMOTE_BETA==='1' && url.origin==='https://en-til-beta.nicklas-andreasen2000.workers.dev'))throw new Error('Bots require localhost or explicit beta opt-in.');
  assert.match(code,/^[A-Z0-9]{4}$/,'Usage: pnpm exec tsx scripts/bots.ts ROOM_CODE [1–7 bots]');
  assert.ok(Number.isInteger(count) && count>=1 && count<=7,'Choose 1–7 bots.');
  const bots:{socket?:WebSocket;room?:Snapshot;token:string;timer?:NodeJS.Timeout;pending?:string;stopped:boolean}[]=[];
  let stopping=false;
  const shutdown=()=>{
    stopping=true;
    for(const bot of bots) {
      bot.stopped=true;clearTimeout(bot.timer);
      if(bot.socket?.readyState===WebSocket.OPEN)bot.socket.send(JSON.stringify({v:1,requestID:randomUUID(),matchID:null,roundID:null,action:{type:'leave'}}));
      bot.socket?.close();
    }
    setTimeout(()=>{for(const bot of bots)bot.socket?.terminate();},1000).unref();
  };
  process.once('SIGINT',shutdown);process.once('SIGTERM',shutdown);
  // Test companions are session-scoped: stop after one hour, never run as a permanent service.
  setTimeout(shutdown,60*60*1000).unref();
  setInterval(()=>{if(!stopping)for(const bot of bots)if(bot.socket?.readyState===WebSocket.OPEN)bot.socket.send('ping');},15000).unref();
  async function call(path:string,token:string|undefined,body:unknown) {
    const response=await fetch(base+path,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
    const value=await response.json() as any;
    if(!response.ok)throw new Error(`${response.status}: ${value.code ?? 'request_failed'} ${value.message ?? ''}`);
    return value;
  }
  try {
    for(let index=0;index<count;index++) {
      const guest=await call('/v1/sessions',undefined,{});
      const preview=await call('/v1/lookup',guest.token,{code});
      assert.ok(preview.characters.length+count-index<=8,'Not enough free seats for these bots.');
      const character=Array.from({length:12},(_,i)=>i).find(i=>!preview.characters.some((p:{character:number})=>p.character===i))!;
      const joined=await call(`/v1/rooms/${preview.roomID}/commands`,guest.token,{v:1,requestID:randomUUID(),matchID:null,roundID:null,action:{type:'join',name:`Testbot ${index+1}`,character,adult:true,drinking:false}});
      const bot:typeof bots[number]={token:guest.token,room:joined.snapshot,stopped:false};bots.push(bot);
      let lastPhase='',retries=0;
      const schedule=()=>{
        if(stopping || bot.stopped || bot.pending || bot.timer || !bot.room)return;
        if(!choose(bot.room,index))return;
        bot.timer=setTimeout(()=>{
          bot.timer=undefined;
          if(!bot.room || bot.socket?.readyState!==WebSocket.OPEN)return;
          const action=choose(bot.room,index);if(!action)return;
          bot.pending=randomUUID();
          bot.socket.send(JSON.stringify({v:1,requestID:bot.pending,matchID:bot.room.matchID,roundID:bot.room.round?.id ?? null,action}));
        },1200+index*500);
      };
      const connect=()=>{
        if(stopping || bot.stopped)return;
        const socket=new WebSocket(base.replace(/^http/,'ws')+`/v1/rooms/${preview.roomID}/socket`,{headers:{Authorization:`Bearer ${bot.token}`},handshakeTimeout:15000});bot.socket=socket;
        socket.on('message',raw=>{
          if(raw.toString()==='pong')return;
          const message=JSON.parse(raw.toString());
          if(message.type==='error') {
            bot.pending=undefined;console.error(`Testbot ${index+1}: ${message.code}`);
            if(['stale','phase','locked'].includes(message.code))schedule();
            return;
          }
          if(message.type==='ack' && message.requestID===bot.pending)bot.pending=undefined;
          if(message.snapshot) {
            bot.room=message.snapshot;retries=0;
            const phase=`${bot.room!.phase} / round ${bot.room!.round?.number ?? 0}`;
            if(phase!==lastPhase){console.log(`Testbot ${index+1}: ${phase}`);lastPhase=phase;}
          }
          schedule();
        });
        socket.on('error',()=>console.error(`Testbot ${index+1}: connection interrupted`));
        socket.on('close',(status)=>{
          clearTimeout(bot.timer);bot.timer=undefined;bot.pending=undefined;
          if(stopping || bot.stopped || status===1000)return;
          if(++retries<=3)bot.timer=setTimeout(()=>{bot.timer=undefined;connect();},3000);
          else {bot.stopped=true;console.error(`Testbot ${index+1}: stopped after repeated disconnects`);}
        });
      };
      connect();
      console.log(`Testbot ${index+1} joined ${code}. Synthetic choices only; no answers logged.`);
    }
    console.log('Bots will ready up and play. The human host starts/rematches. Ctrl-C stops bots; automatic stop in one hour.');
  } catch(error) {shutdown();throw error;}
}

if(process.argv[2]==='--self-test')await selfTest();else await run();
