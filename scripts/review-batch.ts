import {writeFileSync} from 'node:fs';
import draft from '../content/catalogue.draft.json';
const lines=['# Spørgsmålsreview — batch 001','', '20 udviklingsudkast. Ingen er godkendt. Gennemgå naturligt dansk, sjov/variation, faktakilde og tone. Denne første tekniske testpulje er bevidst rumfartspræget; den repræsenterer ikke variationen i de 150 gratis lanceringsspørgsmål.',''];
for(const [i,q] of draft.questions.entries()){
  lines.push(`## ${i+1}. ${q.id}`,q.prompt,'');
  if(q.options){lines.push(q.options.map((answer,index)=>`${String.fromCharCode(65+index)}. ${answer}${index===q.correct?' **(rigtigt)**':''}`).join('\n'),'');}
  if(q.source)lines.push(`Kilde: ${q.source}`,`Kontrolnote: ${q.fact}`,'');
  lines.push('Review: afventer Nicklas.','');
}
writeFileSync('content/review/batch-001.md',lines.join('\n'));
