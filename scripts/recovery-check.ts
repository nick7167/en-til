import {spawn, type ChildProcess} from 'node:child_process';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
const config='backend/wrangler.jsonc',persist='build/recovery-state',port='8791';
const base=`http://127.0.0.1:${port}`;
async function run(args:string[]){await new Promise<void>((resolve,reject)=>{const p=spawn('pnpm',args,{stdio:'pipe'});let errors='';p.stderr?.on('data',x=>errors+=x);p.once('exit',code=>code===0?resolve():reject(new Error(errors)));});}
let server:ChildProcess|undefined;
async function start(){
  server=spawn('pnpm',['exec','wrangler','dev','--config',config,'--port',port,'--persist-to',persist],{detached:true,stdio:'ignore'});
  for(let i=0;i<120;i++){try{const r=await fetch(base+'/health');if(r.ok)return;}catch{}await new Promise(r=>setTimeout(r,250));}
  throw new Error('Recovery test server did not start');
}
async function stop(){if(server?.pid){const p=server;const stopped=new Promise<void>(resolve=>p.once('exit',()=>resolve()));process.kill(-server.pid,'SIGTERM');await stopped;server=undefined;}}
interface Guest{id:string;token:string}
async function call(path:string,g?:Guest,body?:unknown){const r=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(g?{Authorization:`Bearer ${g.token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)});const data=await r.json() as any;assert.ok(r.ok,JSON.stringify(data));return data;}
try{
  await run(['exec','wrangler','d1','migrations','apply','en-til-local','--local','--config',config,'--persist-to',persist]);await start();
  const guests:Guest[]=[];for(let i=0;i<3;i++)guests.push(await call('/v1/sessions',undefined,{}));let room:any;
  const command=(action:unknown)=>({v:1,requestID:randomUUID(),matchID:room?.matchID ?? null,roundID:room?.round?.id ?? null,action});
  room=(await call('/v1/rooms',guests[0],command({type:'join',name:'Vært',character:0,adult:true,drinking:false}))).snapshot;
  const path=`/v1/rooms/${room.roomID}`;
  for(let i=1;i<3;i++)room=(await call(path+'/commands',guests[i],command({type:'join',name:`Ven ${i}`,character:i,adult:true,drinking:false}))).snapshot;
  for(let i=1;i<3;i++)room=(await call(path+'/commands',guests[i],command({type:'ready',value:true}))).snapshot;
  room=(await call(path+'/commands',guests[0],command({type:'start'}))).snapshot;
  if(room.phase==='private')for(let i=0;i<3;i++)room=(await call(path+'/commands',guests[i],command({type:'private',value:'yes'}))).snapshot;
  let finalCommand;
  for(let i=0;i<3;i++){
    room=(await call(path+'/commands',guests[i],command({type:'answer',value:0}))).snapshot;
    finalCommand=command({type:'back',playerID:guests[(i+1)%3]!.id});room=(await call(path+'/commands',guests[i],finalCommand)).snapshot;
  }
  assert.equal(room.phase,'reveal');const roundID=room.round.id;
  await stop();await start();
  const replay=(await call(path+'/commands',guests[2],finalCommand)).snapshot;
  assert.equal(replay.round.id,roundID);
  await new Promise(r=>setTimeout(r,8000));
  const settled=await call(path,guests[0]);assert.equal(settled.phase,'board');
  const scores=settled.players.map((p:any)=>p.score);
  await stop();await start();
  const restored=await call(path,guests[0]);assert.deepEqual(restored.players.map((p:any)=>p.score),scores);assert.equal(restored.round.id,roundID);assert.equal(restored.round.results.length,3);
  console.log('PASS: two actual local Worker process restarts, persisted guest authentication/room/round/results, retried scoring command and alarm recovery without duplicate points.');
}finally{await stop();}
