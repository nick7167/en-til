import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
const base=process.env.ENTIL_TEST_URL ?? 'http://127.0.0.1:8787';
if(!['127.0.0.1','localhost'].includes(new URL(base).hostname))throw new Error('This test creates rooms; use a local service only.');
interface Guest {id:string;token:string}
async function call(path:string,guest?:Guest,body?:unknown,expected=200){const r=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(guest?{Authorization:`Bearer ${guest.token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)});const data=await r.json() as any;assert.equal(r.status,expected,JSON.stringify(data));return data;}
const guests:Guest[]=[];
for(let i=0;i<8;i++)guests.push(await call('/v1/sessions',undefined,{},201));
const host=guests[0]!;
let room:any;
function command(action:unknown){return {v:1,requestID:randomUUID(),matchID:room?.matchID ?? null,roundID:room?.round?.id ?? null,action};}
const create=command({type:'join',name:'Nicklas',character:0,adult:true,drinking:false});
room=(await call('/v1/rooms',host,create,201)).snapshot;
const id=room.roomID;
assert.equal((await call('/v1/rooms',host,create,201)).snapshot.roomID,id);
assert.equal((await call('/v1/lookup',guests[1],{code:room.code.toLowerCase()})).roomID,id);
const path=`/v1/rooms/${id}`;
await call(`${path}/commands`,guests[1],command({type:'join',name:'Nicklas',character:0,adult:true,drinking:false}),409);
for(let i=1;i<8;i++)room=(await call(`${path}/commands`,guests[i],command({type:'join',name:'Nicklas',character:i,adult:true,drinking:false}))).snapshot;
const ninth=await call('/v1/sessions',undefined,{},201);
await call(`${path}/commands`,ninth,command({type:'join',name:'Sen',character:9,adult:true,drinking:false}),409);
await call(path,ninth,undefined,409);
await call(path,undefined,undefined,401);
room=(await call(`${path}/commands`,host,command({type:'settings',settings:{finish:5,timed:false,answerSeconds:20,backingSeconds:10,drinking:false,packs:['free']}}))).snapshot;
for(let i=1;i<8;i++)room=(await call(`${path}/commands`,guests[i],command({type:'ready',value:true}))).snapshot;
room=(await call(`${path}/commands`,host,command({type:'start'}))).snapshot;
if(room.phase==='private')for(let i=0;i<8;i++)room=(await call(`${path}/commands`,guests[i],command({type:'private',value:i%2?'yes':'no'}))).snapshot;
assert.equal(room.phase,'answer');assert.equal(room.round.correct,null);
const first=command({type:'answer',value:0});
room=(await call(`${path}/commands`,host,first)).snapshot;
assert.equal(room.round.answerLocked,true);
await call(`${path}/commands`,host,first);
await call(`${path}/commands`,host,command({type:'answer',value:1}),409);
await call(`${path}/commands`,host,command({type:'back',playerID:host.id}),409);
for(let i=0;i<8;i++){
  if(i>0)room=(await call(`${path}/commands`,guests[i],command({type:'answer',value:0}))).snapshot;
  room=(await call(`${path}/commands`,guests[i],command({type:'back',playerID:guests[(i+1)%8]!.id}))).snapshot;
}
assert.equal(room.phase,'reveal');assert.notEqual(room.round.correct,null);
const seen=await call(path,host);assert.equal(seen.round.id,room.round.id);
console.log('PASS: real local HTTP sessions, create retries, normalized lookup, 8-player admission, authorization, ready/start, privacy, duplicate/invalid inputs, full round and restored snapshot.');
