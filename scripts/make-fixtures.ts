import {mkdirSync,writeFileSync} from 'node:fs';
import {createRoom,dispatch,advance,snapshot,type Room} from '../backend/src/engine.ts';
import {validateCatalogue} from '../backend/src/content.ts';
import type {Command} from '../backend/src/protocol.ts';
import draft from '../content/catalogue.draft.json';
const directory='ios/EnTil/Resources/Fixtures';mkdirSync(directory,{recursive:true});
let now=1000;
const names=['Nicklas','Freja','Noah','Alma','Sofie','William','Ida','Oscar'];
function send(r:Room,i:number,action:Command['action']){return dispatch(r,{id:`p${i}`,owned:['isbryderen']},{v:1,requestID:crypto.randomUUID(),matchID:r.matchID,roundID:r.round?.id ?? null,action},now);}
function save(name:string,r:Room,me='p0'){writeFileSync(`${directory}/${name}.json`,JSON.stringify(snapshot(r,me,now),null,2)+'\n');}
function lobby(personal=false){const c=validateCatalogue(draft);c.questions=c.questions.filter(q=>personal || q.kind==='factual');let r=createRoom('00000000-0000-4000-a000-000000000001','K7MX',c);for(let i=0;i<4;i++)r=send(r,i,{type:'join',name:names[i]!,character:i,adult:true,drinking:false});return r;}
function start(r:Room){for(let i=1;i<4;i++)r=send(r,i,{type:'ready',value:true});return send(r,0,{type:'start'});}
let r=lobby();save('lobby',r);r=start(r);save('answer',r);r=send(r,0,{type:'answer',value:0});save('backing',r);r=send(r,0,{type:'back',playerID:'p1'});save('waiting',r);
for(let i=1;i<4;i++){r=send(r,i,{type:'answer',value:r.round!.question.correct!});r=send(r,i,{type:'back',playerID:`p${(i+1)%4}`});}
now+=4000;save('reveal',r);now+=4000;advance(r,now);save('board',r);
r.phase='finale';r.winners=['p1'];save('finale',r);
let away=start(lobby());away=send(away,1,{type:'leave'});save('away',away,'p1');away=send(away,4,{type:'join',name:'Sofie',character:4,adult:true,drinking:false});save('late',away,'p4');
let p=lobby(true);p.catalogue.questions=p.catalogue.questions.map(q => q.kind==='personal'?{...q,pack:'isbryderen'}:q);p=send(p,0,{type:'settings',settings:{...p.settings,packs:['isbryderen']}});p=start(p);save('private',p);for(let i=0;i<4;i++)p=send(p,i,{type:'private',value:i%2?'yes':'no'});save('guess',p);
console.log('11 public server snapshots generated for hosted native screenshot tests.');
