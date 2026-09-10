import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import WebSocket from 'ws';
const base='http://127.0.0.1:8787';
interface Guest{id:string;token:string}
async function call(path:string,g?:Guest,body?:unknown){const response=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json','CF-Connecting-IP':'192.0.2.61',...(g?{Authorization:`Bearer ${g.token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)});const data=await response.json() as any;assert.ok(response.ok,JSON.stringify(data));return data;}
let room:any;
function command(action:unknown){return {v:1,requestID:randomUUID(),matchID:room?.matchID ?? null,roundID:room?.round?.id ?? null,action};}
const host:Guest=await call('/v1/sessions',undefined,{});
room=(await call('/v1/rooms',host,command({type:'join',name:'Vært',character:0,adult:false,drinking:false}))).snapshot;
function connect(){return new WebSocket(base.replace('http','ws')+`/v1/rooms/${room.roomID}/socket`,{headers:{Authorization:`Bearer ${host.token}`}});}
const socket=connect();
const next=(s:WebSocket,predicate:(m:any)=>boolean)=>new Promise<any>((resolve,reject)=>{const timeout=setTimeout(()=>{cleanup();reject(new Error('WebSocket message timed out'));},6000);const listener=(data:WebSocket.RawData)=>{let m:any;try{m=JSON.parse(data.toString());}catch{return;}if(predicate(m)){cleanup();resolve(m);}};const error=(e:Error)=>{cleanup();reject(e);};function cleanup(){clearTimeout(timeout);s.off('message',listener);s.off('error',error);}s.on('message',listener);s.on('error',error);});
const first=await next(socket,m=>m.type==='snapshot');assert.equal(first.snapshot.roomID,room.roomID);
const c=command({type:'identity',name:'Nyt navn',character:2});const ackPromise=next(socket,m=>m.type==='ack' && m.requestID===c.requestID);socket.send(JSON.stringify(c));const ack=await ackPromise;assert.equal(ack.snapshot.players[0].name,'Nyt navn');
socket.close();await new Promise(resolve=>socket.once('close',resolve));
const restored=connect();const state=await next(restored,m=>m.type==='snapshot');assert.equal(state.snapshot.players[0].name,'Nyt navn');assert.equal(state.snapshot.players.length,1);
restored.close();console.log('PASS: authenticated WebSocket upgrade, private snapshot, acknowledgement, disconnect/reconnect, same seat and state.');
