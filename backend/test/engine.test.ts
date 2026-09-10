import { test } from 'node:test';
import assert from 'node:assert/strict';
import { advance, createRoom, dispatch, snapshot, nextAlarm, type Room } from '../src/engine.ts';
import { commandSchema, type Command, defaults, type PackID } from '../src/protocol.ts';
import { validateCatalogue, type Catalogue } from '../src/content.ts';
import draft from '../../content/catalogue.draft.json';
const catalogue=validateCatalogue(draft);
const facts:Catalogue={version:'test',questions:catalogue.questions.filter(q => q.kind==='factual')};
const personal:Catalogue={version:'test',questions:[...facts.questions,{...catalogue.questions.find(q => q.kind==='personal')!,pack:'isbryderen'}]};
const owned:PackID[]=['isbryderen','danmark','film-tv','efter-midnat'];
function cmd(r:Room,action:Command['action']):Command {return {v:1,requestID:crypto.randomUUID(),matchID:r.matchID,roundID:r.round?.id ?? null,action};}
function send(r:Room,id:string,action:Command['action'],now=1000){return dispatch(r,{id,owned},cmd(r,action),now);}
function lobby(count=3,pool=facts){let r=createRoom('room','K7MX',pool);for(let i=0;i<count;i++)r=send(r,`p${i}`,{type:'join',name:i<2?'Nicklas':`Ven ${i}`,character:i,adult:true,drinking:true},i);return r;}
function start(r=lobby()){for(const p of r.players.slice(1))r=send(r,p.id,{type:'ready',value:true});return send(r,'p0',{type:'start'});}
function complete(r:Room,values:number[],now=2000){for(const [i,p] of r.round!.participants.entries()){r=send(r,p,{type:'answer',value:values[i]!},now);r=send(r,p,{type:'back',playerID:r.round!.participants[(i+1)%values.length]!},now);}return r;}

test('all four independent scoring combinations and no recursive backing',()=>{
  let r=start(lobby(4));const correct=r.round!.question.correct!,wrong=(correct+1)%r.round!.question.options!.length;
  r=complete(r,[correct,correct,wrong,wrong]);assert.deepEqual(r.round!.results!.map(x => x.points),[2,1,0,1]);
});
test('idempotent retries remain idempotent after serialization/restart',()=>{
  let r=start();const c=cmd(r,{type:'answer',value:0});r=dispatch(r,{id:'p0',owned},c,2000);
  const restored=JSON.parse(JSON.stringify(r)) as Room;
  assert.deepEqual(dispatch(restored,{id:'p0',owned},c,2001).round,r.round);
  assert.throws(()=>send(r,'p0',{type:'answer',value:1},2001),/låst/);
});
test('question answer, future pool, private state and intermediate status never leak',()=>{
  let r=start();r=send(r,'p0',{type:'answer',value:0});
  const s=snapshot(r,'p1',2000);assert.equal(s.round!.correct,null);assert.equal(s.round!.results.length,0);
  assert.equal(s.players.find(p => p.id==='p0')!.complete,false);
  const json=JSON.stringify(s);assert.ok(!json.includes('privateResponses'));assert.ok(!json.includes('catalogue'));assert.ok(!json.includes('review'));assert.equal(snapshot(r,'p0',2000).round!.ownAnswer,null);
});
test('backing starts individually and timeout equality closes answer',()=>{
  let r=start();r=send(r,'p0',{type:'answer',value:0},2000);
  assert.equal(r.round!.turns.p0!.backingDeadline,12000);
  assert.throws(()=>send(r,'p1',{type:'answer',value:0},21000),/låst/);
  advance(r,21000);assert.equal(r.round!.turns.p1!.backingDeadline,31000);
  r=send(r,'p1',{type:'back',playerID:'p0'},22000);assert.equal(r.round!.turns.p1!.answer,undefined);
  advance(r,31000);assert.equal(r.phase,'reveal');assert.equal(r.round!.results!.find(x => x.playerID==='p1')!.sips,null);
});
test('unconfirmed answer/backing values are absent at timeout',()=>{const r=start();advance(r,31000);for(const x of r.round!.results!){assert.equal(x.answer,null);assert.equal(x.back,null);assert.equal(x.points,0);}});
test('stale round IDs and self backing rejected',()=>{let r=start();const c=cmd(r,{type:'answer',value:0});c.roundID='old';assert.throws(()=>dispatch(r,{id:'p0',owned},c,2000),/videre/);r=send(r,'p0',{type:'answer',value:0});assert.throws(()=>send(r,'p0',{type:'back',playerID:'p0'}),/anden/);});
test('overshoot preserved, joint furthest winners selected after complete scoring',()=>{let r=start(lobby(4));r.settings.finish=5;for(const p of r.players)p.score=4;const c=r.round!.question.correct!;r=complete(r,[c,c,c,c]);assert.deepEqual(r.players.map(p => p.score),[6,6,6,6]);assert.equal(r.winners.length,4);advance(r,9800);assert.equal(r.phase,'finale');});
test('furthest wins when several cross',()=>{let r=start();r.settings.finish=5;r.players[0]!.score=4;r.players[1]!.score=5;const c=r.round!.question.correct!;r=complete(r,[c,c,c]);assert.deepEqual(r.winners,['p1']);});
test('personal closest ties, own response included, private data deleted before guesses',()=>{
  let r=lobby(4,personal);r=send(r,'p0',{type:'settings',settings:{...defaults,packs:['isbryderen']}});r=start(r);
  for(let i=0;i<4;i++)r=send(r,`p${i}`,{type:'private',value:i<2?'yes':'no'},2000);
  assert.equal(r.phase,'answer');assert.equal(r.round!.yesCount,2);assert.deepEqual(r.round!.privateResponses,{});
  assert.equal(snapshot(r,'p0',2000).round!.correct,null);r=complete(r,[1,3,0,4],3000);
  assert.deepEqual(r.round!.results!.map(x=>x.own),[1,1,0,0]);
});
test('private skip still scores and is not attributed; fallback works personal-only',()=>{
  let r=lobby(4,personal);r=send(r,'p0',{type:'settings',settings:{...defaults,packs:['isbryderen']}});r=start(r);
  for(let i=0;i<4;i++)r=send(r,`p${i}`,{type:'private',value:i===0?'skip':'yes'},2000);
  assert.equal(r.round!.responseCount,3);r=complete(r,[3,3,3,3],3000);assert.equal(r.round!.results![0]!.points,2);
  let f=lobby(3,personal);f=send(f,'p0',{type:'settings',settings:{...defaults,packs:['isbryderen']}});f=start(f);
  for(let i=0;i<3;i++)f=send(f,`p${i}`,{type:'private',value:i===0?'skip':'yes'},2000);
  assert.equal(f.phase,'answer');assert.equal(f.round!.question.pack,'free');assert.equal(f.round!.question.kind,'factual');assert.equal(f.round!.yesCount,undefined);assert.ok(f.fallbackNotice);
});
test('eight seats include away and late arrivals; characters unique; names stable',()=>{
  let r=lobby(8);assert.equal(r.players[1]!.name,'Nicklas den anden');r=send(r,'p1',{type:'leave'});
  assert.throws(()=>send(r,'new',{type:'join',name:'Ny',character:10,adult:true,drinking:false}),/fuldt/);
  assert.throws(()=>send(r,'p0',{type:'identity',name:'Vært',character:2}),/allerede/);
  let s=start();s=send(s,'late',{type:'join',name:'Sen',character:8,adult:true,drinking:false});assert.equal(s.players.at(-1)!.late,true);assert.equal(s.round!.participants.length,3);
});
test('host transfer after 30 seconds and deliberate departure immediately',()=>{
  let r=start();r=send(r,'p0',{type:'presence',connected:false},2000);advance(r,31999);assert.equal(r.hostID,'p0');advance(r,32000);assert.equal(r.hostID,'p1');
  let s=start();s=send(s,'p0',{type:'leave'},2000);assert.equal(s.hostID,'p1');
});
test('all-disconnected room expires, connected one does not',()=>{let r=start();for(let i=0;i<3;i++)r=send(r,`p${i}`,{type:'presence',connected:false},2000);advance(r,1801999);assert.notEqual(r.phase,'expired');advance(r,1802000);assert.equal(r.phase,'expired');assert.equal(r.players.length,0);});
test('readiness can reverse until countdown; countdown lasts three seconds',()=>{
  let r=start();r=complete(r,[0,0,0]);advance(r,9800);
  r=send(r,'p0',{type:'ready',value:true},9900);r=send(r,'p0',{type:'ready',value:false},9901);assert.equal(r.players[0]!.ready,false);
  for(let i=0;i<3;i++)r=send(r,`p${i}`,{type:'ready',value:true},10000);
  assert.equal(r.phase,'countdown');assert.equal(nextAlarm(r,10000),13000);assert.throws(()=>send(r,'p0',{type:'ready',value:false},11000),/pause/);advance(r,13000);assert.equal(r.phase,'answer');assert.equal(r.round!.number,2);
});
test('host sitting out preserves confirmed choices; return at boundary',()=>{
  let r=start(lobby(4));r=send(r,'p1',{type:'answer',value:0});r=send(r,'p0',{type:'away',playerID:'p1'});assert.equal(r.round!.turns.p1!.answer,0);assert.ok(r.round!.turns.p1!.backClosed);
  r=send(r,'p1',{type:'return'});assert.equal(r.players[1]!.away,true);advance(r,31000);advance(r,38800);assert.equal(r.players[1]!.away,false);
});
test('two completely missed timed rounds mark away and pause',()=>{
  let r=start();advance(r,31000);advance(r,38800);for(let i=0;i<3;i++)r=send(r,`p${i}`,{type:'ready',value:true},39000);advance(r,42000);advance(r,72000);advance(r,79800);assert.ok(r.players.every(p=>p.away));assert.equal(r.phase,'board');
});
test('untimed round does not expire or count missed automatically',()=>{let r=lobby();r=send(r,'p0',{type:'settings',settings:{...defaults,timed:false}});r=start(r);advance(r,999999);assert.equal(r.phase,'answer');assert.equal(r.players[0]!.missed,0);assert.equal(nextAlarm(r,999999),undefined);});
test('drinking excludes incomplete and opted-out turns; no readiness penalty',()=>{let r=lobby();r=send(r,'p0',{type:'settings',settings:{...defaults,drinking:true}});r=send(r,'p1',{type:'drinking',value:false});r=start(r);r=complete(r,[0,0,0]);assert.equal(r.round!.results![1]!.sips,null);assert.equal(r.round!.results![0]!.sips,2-r.round!.results![0]!.points);});
test('adult setting changes reset readiness and require each adult confirmation',()=>{let r=lobby();r.players[1]!.adult=false;r=send(r,'p1',{type:'ready',value:true});r=send(r,'p0',{type:'settings',settings:{...defaults,drinking:true}});assert.equal(r.players[1]!.ready,false);assert.ok(snapshot(r,'p1',1000).adultRequired);assert.throws(()=>send(r,'p1',{type:'ready',value:true}),/18/);});
test('host transfer retains current pack; rematch intersects new host ownership',()=>{let r=lobby(4,personal);r=send(r,'p0',{type:'settings',settings:{...defaults,packs:['isbryderen']}});r=start(r);r=send(r,'p0',{type:'leave'});assert.deepEqual(r.settings.packs,['isbryderen']);r=dispatch(r,{id:'p1',owned:[]},cmd(r,{type:'end'}),2000);assert.deepEqual(r.settings.packs,['free']);assert.equal(r.matchID,null);});
test('settings bounds are enforced by protocol',()=>{const r=lobby();for(const finish of [4,51])assert.equal(commandSchema.safeParse(cmd(r,{type:'settings',settings:{...defaults,finish}})).success,false);});
test('draft catalogue cannot pass release gate',()=>{assert.throws(()=>validateCatalogue(draft,true),/reviewed/);});
test('100 rooms / 800 simulated players complete independent matches',()=>{for(let i=0;i<100;i++){let r=start(lobby(8));r.settings.finish=5;let now=2000;while(r.phase!=='finale'){r=complete(r,Array(8).fill(r.round!.question.correct!),now);advance(r,now+7800);if(r.phase==='finale')break;for(let p=0;p<8;p++)r=send(r,`p${p}`,{type:'ready',value:true},now+8000);advance(r,now+11000);now+=12000;}assert.equal(r.winners.length,8);assert.equal(r.round!.number,3);}});
test('personal fallback still resolves when departures leave fewer than three active',()=>{
  let r=lobby(3,personal);r=send(r,'p0',{type:'settings',settings:{...defaults,packs:['isbryderen']}});r=start(r);
  r=send(r,'p0',{type:'private',value:'yes'},2000);r=send(r,'p1',{type:'leave'},2000);r=send(r,'p2',{type:'leave'},2000);
  assert.equal(r.phase,'answer');assert.equal(r.round!.question.kind,'factual');r=send(r,'p0',{type:'answer',value:0},3000);assert.equal(r.phase,'reveal');advance(r,10800);assert.equal(r.phase,'board');
});
test('inactive targets cannot be newly backed, prior confirmed backing survives',()=>{
  let r=start(lobby(4));r=send(r,'p0',{type:'answer',value:0},2000);r=send(r,'p0',{type:'back',playerID:'p1'},2000);
  r=send(r,'p1',{type:'answer',value:r.round!.question.correct!},2000);r=send(r,'p0',{type:'away',playerID:'p1'},2000);
  r=send(r,'p2',{type:'answer',value:0},2000);assert.throws(()=>send(r,'p2',{type:'back',playerID:'p1'},2000),/aktiv/);advance(r,31000);assert.equal(r.round!.results![0]!.backing,1);
});
test('adult-required snapshots contain no adult question even when client ignores age UI',()=>{
  let r=start();r.settings.drinking=true;r.players[1]!.adult=false;
  const s=snapshot(r,'p1',2000);assert.equal(s.adultRequired,true);assert.equal(s.round,null);
});
test('unjoined initialized rooms expire too',()=>{const r=createRoom('id','ABCD',facts);advance(r,1000);advance(r,1801000);assert.equal(r.phase,'expired');});
test('deliberate host departure transfers as soon as an eligible connection returns',()=>{
  let r=start();r=send(r,'p1',{type:'presence',connected:false},2000);r=send(r,'p2',{type:'presence',connected:false},2000);r=send(r,'p0',{type:'leave'},2000);r=send(r,'p1',{type:'presence',connected:true},3000);assert.equal(r.hostID,'p1');
});
