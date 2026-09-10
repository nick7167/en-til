import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import WebSocket from 'ws';
import {writeFileSync,mkdirSync} from 'node:fs';
const base='http://127.0.0.1:8787';
const roomCount=Number(process.env.ENTIL_LOAD_ROOMS ?? 100);
interface Guest{id:string;token:string}
const durations:number[]=[];
const sockets:WebSocket[]=[];
async function call(path:string,ip:string,g?:Guest,body?:unknown){const start=performance.now();const r=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json','CF-Connecting-IP':ip,...(g?{Authorization:`Bearer ${g.token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)});const value=await r.json() as any;durations.push(performance.now()-start);assert.ok(r.ok,JSON.stringify(value));return value;}
const start=performance.now();
async function run(index:number){
  const ip=`198.51.${Math.floor(index/250)}.${index%250+1}`;
  const guests:Guest[]=[];let room:any;
  const command=(action:unknown)=>({v:1,requestID:randomUUID(),matchID:room?.matchID ?? null,roundID:room?.round?.id ?? null,action});
  for(let i=0;i<8;i++)guests.push(await call('/v1/sessions',ip,undefined,{}));
  room=(await call('/v1/rooms',ip,guests[0],command({type:'join',name:'Vært',character:0,adult:true,drinking:false}))).snapshot;
  const path=`/v1/rooms/${room.roomID}`;
  for(let i=1;i<8;i++)room=(await call(path+'/commands',ip,guests[i],command({type:'join',name:`Ven ${i}`,character:i,adult:true,drinking:false}))).snapshot;
  for(const guest of guests){
    const socket=new WebSocket(base.replace('http','ws')+path+'/socket',{headers:{Authorization:`Bearer ${guest.token}`}});
    sockets.push(socket);
    await new Promise<void>((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('Connect timeout')),10000);socket.once('message',()=>{clearTimeout(timeout);resolve();});socket.once('error',reject);});
  }
  room=(await call(path+'/commands',ip,guests[0],command({type:'settings',settings:{finish:5,timed:false,answerSeconds:20,backingSeconds:10,drinking:false,packs:['free']}}))).snapshot;
  for(let i=1;i<8;i++)room=(await call(path+'/commands',ip,guests[i],command({type:'ready',value:true}))).snapshot;
  room=(await call(path+'/commands',ip,guests[0],command({type:'start'}))).snapshot;
  if(room.phase==='private')for(let i=0;i<8;i++)room=(await call(path+'/commands',ip,guests[i],command({type:'private',value:i%2?'yes':'no'}))).snapshot;
  for(let i=0;i<8;i++){
    room=(await call(path+'/commands',ip,guests[i],command({type:'answer',value:0}))).snapshot;
    room=(await call(path+'/commands',ip,guests[i],command({type:'back',playerID:guests[(i+1)%8]!.id}))).snapshot;
  }
  assert.equal(room.phase,'reveal');
}
try{
  // Bounded setup; completed rooms keep every WebSocket open until all rooms exist.
  let next=0;
  await Promise.all(Array.from({length:10},async()=>{while(next<roomCount)await run(next++);}));
  assert.equal(sockets.filter(s=>s.readyState===WebSocket.OPEN).length,roomCount*8);
  durations.sort((a,b)=>a-b);
  const report={date:new Date().toISOString(),scope:'local Miniflare; not Cloudflare production capacity or cost',rooms:roomCount,simultaneousSockets:sockets.length,httpRequests:durations.length,elapsedSeconds:(performance.now()-start)/1000,p50Milliseconds:durations[Math.floor(durations.length*.5)],p95Milliseconds:durations[Math.floor(durations.length*.95)],p99Milliseconds:durations[Math.floor(durations.length*.99)]};
  mkdirSync('build',{recursive:true});writeFileSync('build/local-load.json',JSON.stringify(report,null,2));console.log(report);
}finally{for(const s of sockets)s.close();}
