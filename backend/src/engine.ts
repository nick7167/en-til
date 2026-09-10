import { defaults, adultPacks, requireGame, type Command, type Settings, type Principal, type PackID } from './protocol.ts';
import { chooseQuestion, type Catalogue, type Question } from './content.ts';

export interface Player {
  id:string; name:string; character:number; joined:number; connected:boolean; disconnectedAt?:number;
  departed?:boolean; away:boolean; late:boolean; returnRequested:boolean; ready:boolean; adult:boolean; drinking:boolean;
  score:number; missed:number; owned:PackID[];
}
export interface Turn { answer?:number; back?:string; answerClosed:boolean; backClosed:boolean; backingDeadline?:number; privateClosed:boolean; submitted:boolean }
export interface Result { playerID:string; answer:number|null; back:string|null; own:number; backing:number; points:number; score:number; sips:number|null }
export interface Round {
  id:string; number:number; question:Question; participants:string[]; turns:Record<string,Turn>;
  privateResponses:Record<string,'yes'|'no'>; responseCount?:number; yesCount?:number;
  startedAt:number; answerDeadline?:number; revealAt?:number; results?:Result[];
}
export interface Room {
  v:1; id:string; code:string; hostID:string; settings:Settings; players:Player[];
  phase:'lobby'|'private'|'answer'|'reveal'|'board'|'countdown'|'finale'|'expired';
  matchID:string|null; round:Round|null; catalogue:Catalogue; seen:string[]; seed:number;
  countdownAt?:number; emptySince?:number; winners:string[]; receipts:string[];
  reactions:{playerID:string; value:string; at:number}[]; fallbackNotice:boolean;
}
export function createRoom(id:string, code:string, catalogue:Catalogue, seen:string[] = []):Room {
  return {v:1,id,code,hostID:'',settings:structuredClone(defaults),players:[],phase:'lobby',matchID:null,round:null,catalogue:structuredClone(catalogue),seen,seed:0,winners:[],receipts:[],reactions:[],fallbackNotice:false};
}
const active = (r:Room) => r.players.filter(p => !p.away && !p.late);
const requiresAdult = (s:Settings) => s.drinking || s.packs.some(p => adultPacks.has(p));
function assertAdult(r:Room,p:Player) { requireGame(!requiresAdult(r.settings) || p.adult,'adult_required','Du skal bekræfte, at du er fyldt 18 år.'); }
function host(r:Room,id:string) { requireGame(r.hostID === id,'host_only','Kun værten kan gøre det.'); }
function player(r:Room,id:string) { const p = r.players.find(p => p.id === id); requireGame(p,'not_in_room','Du er ikke med i dette spil.'); return p; }
function uniqueName(r:Room,name:string,id:string) {
  const names = new Set(r.players.filter(p => p.id !== id).map(p => p.name.toLocaleLowerCase('da')));
  if (!names.has(name.toLocaleLowerCase('da'))) return name;
  for (const suffix of ['den anden','igen','den ekstra','på ny','nummer fem','nummer seks','nummer syv','nummer otte']) {
    const candidate = `${name} ${suffix}`;
    if (!names.has(candidate.toLocaleLowerCase('da'))) return candidate;
  }
  return `${name} ${r.players.length + 1}`;
}
function transferHost(r:Room,now:number,force = false) {
  const current = r.players.find(p => p.id === r.hostID);
  if (!force && current && !current.departed && (current.connected || now - (current.disconnectedAt ?? now) < 30_000)) return;
  const next = active(r).filter(p => p.connected).sort((a,b) => a.joined-b.joined)[0];
  if (next) r.hostID = next.id;
}
function boundary(r:Room) {
  for (const p of r.players) if (p.returnRequested && !p.late && p.connected) { p.away=false; p.returnRequested=false; p.missed=0; }
}
function beginRound(r:Room,now:number,forced?:Question) {
  boundary(r);
  requireGame(forced || active(r).length >= 3,'too_few','I skal være mindst 3 aktive spillere.');
  const previous = r.round;
  r.seed=crypto.getRandomValues(new Uint32Array(1))[0]!;
  const q = forced ?? chooseQuestion(r.catalogue.questions,r.settings.packs,r.seen,r.seed,previous?.question.kind);
  if (!r.seen.includes(q.id)) r.seen.push(q.id);
  const participants = forced && previous ? previous.participants : active(r).map(p => p.id);
  const number = (previous?.number ?? 0) + (forced ? 0 : 1);
  r.round = {id:`${r.matchID}:${number}:${crypto.randomUUID()}`,number,question:q,participants,turns:Object.fromEntries(participants.map(id => [id,{answerClosed:false,backClosed:false,privateClosed:false,submitted:false}])),privateResponses:{},startedAt:now};
  for (const id of participants) if (player(r,id).away) {
    const t=r.round.turns[id]!; t.privateClosed=true;t.answerClosed=true;t.backClosed=true;
  }
  r.phase = q.kind === 'personal' ? 'private' : 'answer';
  if (r.settings.timed) r.round.answerDeadline = now + r.settings.answerSeconds*1000;
  r.countdownAt=undefined;
  for (const p of r.players) p.ready=false;
}
function closeAnswer(r:Room,t:Turn,at:number) {
  if (t.answerClosed) return;
  t.answerClosed=true;
  if (r.settings.timed) t.backingDeadline=at+r.settings.backingSeconds*1000;
}
function finishPrivate(r:Room,now:number) {
  const round=r.round!;
  const responses=Object.values(round.privateResponses);
  round.privateResponses={};
  if (responses.length < 3) {
    const free=r.catalogue.questions.filter(q => q.pack === 'free' && q.kind === 'factual');
    requireGame(free.length,'no_fallback','Der mangler et gratis reservespørgsmål.');
    r.seed++;
    r.fallbackNotice=true;
    beginRound(r,now,chooseQuestion(free,['free'],r.seen,r.seed));
    return;
  }
  round.responseCount=responses.length; round.yesCount=responses.filter(x => x==='yes').length;
  r.phase='answer';
  round.startedAt=now;
  round.answerDeadline=r.settings.timed ? now+r.settings.answerSeconds*1000 : undefined;
}
function scoreRound(r:Room,now:number) {
  const round=r.round!;
  if (round.results) return;
  const guesses=Object.values(round.turns).flatMap(t => t.answer === undefined ? [] : [t.answer]);
  const closest=guesses.length ? Math.min(...guesses.map(a => Math.abs(a-(round.yesCount ?? 0)))) : Infinity;
  const correct = (id:string) => {
    const answer=round.turns[id]?.answer;
    return answer !== undefined && (round.question.kind==='personal' ? Math.abs(answer-round.yesCount!)===closest : answer===round.question.correct);
  };
  round.results=round.participants.map(id => {
    const p=player(r,id),t=round.turns[id]!;
    const own=Number(correct(id)),backing=Number(t.back !== undefined && correct(t.back));
    const points=own+backing;
    p.score+=points;
    if (r.settings.timed) p.missed=t.submitted ? 0 : p.missed+1;
    if (p.missed>=2) p.away=true;
    return {playerID:id,answer:t.answer ?? null,back:t.back ?? null,own,backing,points,score:p.score,sips:r.settings.drinking && p.drinking && t.answer!==undefined && t.back!==undefined ? 2-points : null};
  });
  round.privateResponses={};
  round.revealAt=now; r.phase='reveal';
  const max=Math.max(...r.players.map(p => p.score));
  r.winners=max>=r.settings.finish ? r.players.filter(p => p.score===max).map(p => p.id) : [];
}
/** Clock transitions run before commands; equality at a deadline is already expired. */
export function advance(r:Room,now:number) {
  if (r.phase==='expired') return;
  if (r.players.every(p => !p.connected)) {
    r.emptySince ??= now;
    if (now-r.emptySince>=1_800_000) { r.phase='expired'; r.round=null; r.players=[]; return; }
  } else r.emptySince=undefined;
  transferHost(r,now);
  if (r.phase==='countdown' && now >= (r.countdownAt ?? Infinity)) {
    boundary(r);
    if (active(r).length>=3) beginRound(r,r.countdownAt!);
    else {r.phase='board';r.countdownAt=undefined;}
  }
  const round=r.round;
  if (!round) return;
  if (r.phase==='private') {
    if (round.answerDeadline!==undefined && now>=round.answerDeadline) for (const t of Object.values(round.turns)) t.privateClosed=true;
    if (Object.values(round.turns).every(t => t.privateClosed)) finishPrivate(r,now);
  }
  if (r.phase==='answer') {
    const current=r.round!;
    for (const t of Object.values(current.turns)) {
      if (current.answerDeadline!==undefined && now>=current.answerDeadline) closeAnswer(r,t,current.answerDeadline);
      if (t.backingDeadline!==undefined && now>=t.backingDeadline) t.backClosed=true;
    }
    for(const [id,t] of Object.entries(current.turns)) {
      if(t.answerClosed && !current.participants.some(other => other!==id && !player(r,other).away)) t.backClosed=true;
    }
    if (Object.values(current.turns).every(t => t.answerClosed && t.backClosed)) scoreRound(r,now);
  }
  if (r.phase==='reveal' && now>=r.round!.revealAt!+7800) {
    r.phase=r.winners.length ? 'finale' : 'board'; boundary(r);
  }
}
function toLobby(r:Room) {
  r.phase='lobby';r.matchID=null;r.round=null;r.winners=[];r.countdownAt=undefined;
  for (const p of r.players) {p.late=false;p.ready=false;p.score=0;p.missed=0;if(p.connected)p.away=false;}
  const owner=player(r,r.hostID);
  r.settings.packs=r.settings.packs.filter(p => p==='free' || owner.owned.includes(p));
  if (!r.settings.packs.length) r.settings.packs=['free'];
}
export function dispatch(source:Room,principal:Principal,command:Command,now:number):Room {
  const r=structuredClone(source); advance(r,now);
  requireGame(r.phase!=='expired','expired','Spillet er udløbet. Opret et nyt spil.');
  const receipt=`${principal.id}:${command.requestID}`;
  if (r.receipts.includes(receipt)) return r;
  const a=command.action;
  // Join/presence/leave/return/adult/preferences are installation-level operations.
  if (!['join','presence','leave','return','adult','drinking'].includes(a.type)) {
    requireGame(command.matchID===r.matchID && command.roundID===(r.round?.id ?? null),'stale','Spillet er gået videre. Prøv igen.');
  }
  if (a.type==='join') {
    let p=r.players.find(p => p.id===principal.id);
    if (p) {p.connected=true;p.disconnectedAt=undefined;p.owned=principal.owned;}
    else {
      requireGame(r.players.length<8,'full','Spillet er fuldt. Der kan være 8 spillere.');
      requireGame(!r.players.some(p => p.character===a.character),'character_taken','Den figur er allerede valgt.');
      requireGame(!requiresAdult(r.settings) || a.adult,'adult_required','Du skal bekræfte, at du er fyldt 18 år.');
      p={id:principal.id,name:uniqueName(r,a.name,principal.id),character:a.character,joined:now,connected:true,away:false,late:r.phase!=='lobby',returnRequested:false,ready:false,adult:a.adult,drinking:a.drinking,score:0,missed:0,owned:principal.owned};
      r.players.push(p);if(!r.hostID)r.hostID=p.id;
    }
  } else {
    const p=player(r,principal.id);p.owned=principal.owned;
    switch(a.type) {
      case 'identity':
        requireGame(r.phase==='lobby','phase','Du kan ændre profil i lobbyen.');
        requireGame(!r.players.some(x => x.id!==p.id && x.character===a.character),'character_taken','Den figur er allerede valgt.');
        p.name=uniqueName(r,a.name,p.id);p.character=a.character;p.ready=false;break;
      case 'settings':
        host(r,p.id);requireGame(r.phase==='lobby','phase','Indstillinger ændres i lobbyen.');
        requireGame(a.settings.packs.every(pack => pack==='free' || p.owned.includes(pack)),'not_owned','Værten skal eje de valgte pakker.');
        requireGame(!requiresAdult(a.settings) || p.adult,'adult_required','Bekræft først, at du er fyldt 18 år.');
        r.settings=a.settings;for(const x of r.players)x.ready=false;break;
      case 'adult':p.adult=true;break;
      case 'drinking':requireGame(!a.value || p.adult,'adult_required','Bekræft først, at du er fyldt 18 år.');p.drinking=a.value;break;
      case 'ready':
        requireGame(r.phase==='lobby' || r.phase==='board','phase','Vent til næste pause.');
        requireGame(!p.away && !p.late,'inactive','Du sidder over.');assertAdult(r,p);p.ready=a.value;
        if(r.phase==='board' && active(r).length>=3 && active(r).every(x => x.ready)) {r.phase='countdown';r.countdownAt=now+3000;}
        break;
      case 'start':
        host(r,p.id);requireGame(r.phase==='lobby','phase','Spillet er allerede startet.');
        requireGame(active(r).length>=3 && active(r).every(x => x.id===r.hostID || x.ready),'not_ready','Vent, til alle er klar.');
        for(const x of active(r))assertAdult(r,x);
        requireGame(r.settings.packs.every(pack => pack==='free' || p.owned.includes(pack)),'not_owned','Vælg pakker, som værten ejer.');
        r.matchID=crypto.randomUUID();r.fallbackNotice=false;beginRound(r,now);break;
      case 'end':host(r,p.id);toLobby(r);break;
      case 'rematch':host(r,p.id);requireGame(r.phase==='finale','phase','Kampen er ikke slut.');toLobby(r);break;
      case 'remove':{
        host(r,p.id);requireGame(r.phase==='lobby' && a.playerID!==p.id,'phase','Spillere fjernes i lobbyen.');
        player(r,a.playerID);r.players=r.players.filter(x => x.id!==a.playerID);break;}
      case 'presence':p.connected=a.connected;p.disconnectedAt=a.connected ? undefined : now;break;
      case 'leave':
        p.connected=false;p.disconnectedAt=now;p.departed=true;p.away=true;p.ready=false;closePlayer(r,p.id,now);transferHost(r,now,true);break;
      case 'away':{
        host(r,p.id);const target=player(r,a.playerID);target.away=true;target.ready=false;closePlayer(r,target.id,now);break;}
      case 'return':
        p.connected=true;p.disconnectedAt=undefined;p.departed=false;p.returnRequested=true;
        if(r.phase==='lobby' || r.phase==='board')boundary(r);break;
      case 'private':{
        assertAdult(r,p);const t=turn(r,p,'private');requireGame(!t.privateClosed,'locked','Dit valg er låst.');
        t.privateClosed=true;t.submitted=true;if(a.value!=='skip')r.round!.privateResponses[p.id]=a.value;break;}
      case 'answer':{
        assertAdult(r,p);const t=turn(r,p,'answer');requireGame(!t.answerClosed,'locked','Dit svar er låst.');
        const max=r.round!.question.kind==='personal' ? r.round!.responseCount! : r.round!.question.options!.length-1;
        requireGame(a.value<=max,'answer_invalid','Vælg et af svarene.');t.answer=a.value;t.submitted=true;closeAnswer(r,t,now);break;}
      case 'back':{
        assertAdult(r,p);const t=turn(r,p,'answer');requireGame(t.answerClosed && !t.backClosed,'locked','Du kan ikke satse lige nu.');
        requireGame(a.playerID!==p.id && r.round!.participants.includes(a.playerID) && !player(r,a.playerID).away,'back_invalid','Vælg en anden aktiv spiller.');
        t.back=a.playerID;t.backClosed=true;t.submitted=true;break;}
      case 'reaction':
        requireGame(r.phase==='board' || r.phase==='finale','phase','Reaktioner kommer efter afsløringen.');
        r.reactions=r.reactions.filter(x => now-x.at<4000);
        requireGame(!r.reactions.some(x => x.playerID===p.id && now-x.at<2000) && r.reactions.length<4,'rate_limited','Giv lige de andre plads.');
        r.reactions.push({playerID:p.id,value:a.value,at:now});break;
    }
  }
  r.receipts.push(receipt);r.receipts=r.receipts.slice(-2048);
  advance(r,now);return r;
}
function turn(r:Room,p:Player,phase:Room['phase']) {
  requireGame(r.phase===phase && !p.away && !p.late,'phase','Du kan ikke vælge lige nu.');
  const t=r.round?.turns[p.id];requireGame(t,'inactive','Du sidder over denne runde.');return t;
}
function closePlayer(r:Room,id:string,now:number) {
  const t=r.round?.turns[id];if(!t)return;
  t.privateClosed=true;closeAnswer(r,t,now);t.backClosed=true;
}
export function nextAlarm(r:Room,now:number):number|undefined {
  if(r.phase==='expired')return;
  const times:number[]=[];
  if(r.emptySince!==undefined)times.push(r.emptySince+1_800_000);
  const h=r.players.find(p => p.id===r.hostID);
  if(h && !h.connected && h.disconnectedAt!==undefined && h.disconnectedAt+30_000>now)times.push(h.disconnectedAt+30_000);
  if(r.phase==='countdown' && r.countdownAt)times.push(r.countdownAt);
  if(r.phase==='reveal')times.push(r.round!.revealAt!+7800);
  if(r.phase==='private' || r.phase==='answer') {
    if(r.round?.answerDeadline && r.round.answerDeadline>now)times.push(r.round.answerDeadline);
    for(const t of Object.values(r.round?.turns ?? {})) if(!t.backClosed && t.backingDeadline)times.push(t.backingDeadline);
  }
  return times.length ? Math.max(now+1,Math.min(...times)) : undefined;
}
/** The only public serializer. Never spread private room/question/player state here. */
export function snapshot(r:Room,id:string,now:number) {
  const me=player(r,id);
  const adultBlocked=requiresAdult(r.settings) && !me.adult;
  const round=adultBlocked ? null : r.round,t=round?.turns[id];
  const revealed=['reveal','board','countdown','finale'].includes(r.phase);
  const elapsed=round?.revealAt===undefined ? 0 : now-round.revealAt;
  const stage=r.phase!=='reveal' ? 4 : elapsed<1800 ? 0 : elapsed<3800 ? 1 : elapsed<5800 ? 2 : 3;
  return {
    v:1,roomID:r.id,code:r.code,hostID:r.hostID,me:id,serverTime:now,phase:r.phase,matchID:r.matchID,settings:r.settings,
    adultRequired:requiresAdult(r.settings) && !me.adult,contentVersion:r.catalogue.version,
    players:r.players.map(p => ({id:p.id,name:p.name,character:p.character,connected:p.connected,away:p.away,late:p.late,ready:p.ready,score: revealed && stage<3 ? p.score-(round?.results?.find(x => x.playerID===p.id)?.points ?? 0) : p.score,complete:r.phase==='private' ? false : !!round?.turns[p.id]?.backClosed && !!round?.turns[p.id]?.answerClosed})),
    round:round ? {
      id:round.id,number:round.number,questionID:round.question.id,kind:round.question.kind,pack:round.question.pack,prompt:round.question.prompt,
      options:round.question.options ?? [],responseCount:round.responseCount ?? null,
      deadline:r.phase==='private' ? round.answerDeadline ?? null : t?.answerClosed ? t.backingDeadline ?? null : round.answerDeadline ?? null,
      privateLocked:r.phase==='private' ? t?.privateClosed ?? false : false,
      answerLocked:t?.answerClosed ?? false,backLocked:t?.backClosed ?? false,
      // Own yes/no is deliberately never echoed; own answer disappears during backing.
      ownAnswer:t?.backClosed ? t.answer ?? null : null,
      correct:revealed ? (round.question.kind==='personal' ? round.yesCount : round.question.correct) ?? null : null,
      fact:revealed ? round.question.fact ?? null : null,source:revealed ? round.question.source ?? null : null,
      revealAt:round.revealAt ?? null,revealStage:stage,
      results:revealed && stage>=1 ? (round.results ?? []).map(x => stage>=2 ? x : {...x,own:0,backing:0,points:0,score:x.score-x.points,sips:null}) : [],
    } : null,
    countdownAt:r.countdownAt ?? null,winners:revealed && stage>=3 ? r.winners : [],
    reactions:r.reactions.filter(x => now-x.at<4000),fallbackNotice:r.fallbackNotice,
  };
}
