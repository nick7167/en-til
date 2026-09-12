import {mkdirSync,writeFileSync} from 'node:fs';
import {createRoom,dispatch,advance,snapshot,type Room} from '../backend/src/engine.ts';
import {validateCatalogue} from '../backend/src/content.ts';
import type {Command} from '../backend/src/protocol.ts';
import draft from '../content/catalogue.draft.json';
const directory='ios/EnTil/Resources/Fixtures';mkdirSync(directory,{recursive:true});
let now=1000;
let count=0;
const names=['Nicklas','Freja','Noah','Alma','Sofie','William','Ida','Oscar'];
function send(r:Room,i:number,action:Command['action']){return dispatch(r,{id:`p${i}`,owned:['isbryderen']},{v:1,requestID:crypto.randomUUID(),matchID:r.matchID,roundID:r.round?.id ?? null,action},now);}
function save(name:string,r:Room,me='p0'){writeFileSync(`${directory}/${name}.json`,JSON.stringify(snapshot(r,me,now),null,2)+'\n');count++;}
function lobby(personal=false){
  const c=validateCatalogue(draft);
  // Deterministic reference composition; draft content approval is unchanged.
  c.questions=c.questions.filter(q=>q.id===(personal?'free-p001':'free-f001')).map(q=>personal?{...q,pack:'isbryderen',prompt:'Har du nogensinde sunget med på en sang uden at kende teksten?'}:q);
  let r=createRoom('00000000-0000-4000-a000-000000000001','K7MX',c);
  for(let i=0;i<4;i++)r=send(r,i,{type:'join',name:names[i]!,character:i,adult:true,drinking:false});
  for(let i=1;i<4;i++)r=send(r,i,{type:'ready',value:true});
  return r;
}
function start(r:Room){for(let i=1;i<4;i++)r=send(r,i,{type:'ready',value:true});return send(r,0,{type:'start'});}
let r=lobby();save('lobby',r);save('guest-lobby',r,'p1');r=start(r);
// Reference snapshots depict an established race; engine scoring remains unchanged.
r.players.forEach((player,index)=>{player.score=[5,7,5,5][index]!;});
r.round!.number=4;save('answer',r);
r=send(r,0,{type:'answer',value:3});save('backing',r);r=send(r,0,{type:'back',playerID:'p1'});save('waiting',r);
for(let i=1;i<4;i++){r=send(r,i,{type:'answer',value:r.round!.question.correct!});r=send(r,i,{type:'back',playerID:`p${(i+1)%4}`});}
now+=4000;save('reveal',r);now+=4000;advance(r,now);save('board',r);
let paused=send(r,2,{type:'leave'});paused=send(paused,3,{type:'leave'});save('paused',paused);
r.phase='finale';r.winners=['p1'];r.players.forEach((player,index)=>{player.score=[18,20,17,15][index]!;});save('finale',r);
let away=start(lobby());away=send(away,1,{type:'leave'});save('away',away,'p1');away=send(away,4,{type:'join',name:'Sofie',character:4,adult:true,drinking:false});save('late',away,'p4');
let p=lobby(true);p=send(p,0,{type:'settings',settings:{...p.settings,packs:['isbryderen']}});p=start(p);save('private',p);
p=send(p,0,{type:'private',value:'no'});save('private-waiting',p);
for(let i=1;i<4;i++)p=send(p,i,{type:'private',value:i%2?'yes':'no'});save('guess',p);
for(let i=0;i<4;i++){p=send(p,i,{type:'answer',value:[2,2,3,1][i]!});p=send(p,i,{type:'back',playerID:`p${[1,0,1,2][i]}`});}
now+=4000;save('personal-reveal',p);
let full=lobby();for(let i=4;i<8;i++)full=send(full,i,{type:'join',name:names[i]!,character:i,adult:true,drinking:false});
for(let i=1;i<8;i++)full=send(full,i,{type:'ready',value:true});save('eight-lobby',full);
full=send(full,0,{type:'start'});full=send(full,0,{type:'answer',value:3});save('eight-backing',full);
console.log(`${count} public server snapshots generated for hosted native screenshot tests.`);
