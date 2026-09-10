import { readFileSync } from 'node:fs';
import { validateCatalogue } from '../backend/src/content.ts';
const release=process.argv.includes('--release');
const c=validateCatalogue(JSON.parse(readFileSync('content/catalogue.draft.json','utf8')),release);
console.log(`${c.questions.length} structurally valid questions; ${c.questions.filter(q => q.review==='approved').length} human-approved. ${release?'Release gate passed.':'Drafts are for local testing only.'}`);
