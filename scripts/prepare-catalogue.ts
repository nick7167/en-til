import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {validateCatalogue} from '../backend/src/content.ts';
const file=process.argv[2];
if(!file)throw new Error('Usage: pnpm exec tsx scripts/prepare-catalogue.ts content/reviewed-version.json');
const catalogue=validateCatalogue(JSON.parse(readFileSync(file,'utf8')),true);
const quote=(text:string)=>"'"+text.replaceAll("'","''")+"'";
// Produces a reviewable LOCAL SQL artifact. Running it against D1 is a separate authorized action.
const sql=`BEGIN TRANSACTION;\nUPDATE catalogue_versions SET active=0 WHERE active=1;\nINSERT INTO catalogue_versions(version,payload,reviewed_at,active) VALUES(${quote(catalogue.version)},${quote(JSON.stringify(catalogue))},${Date.now()},1);\nCOMMIT;\n`;
mkdirSync('build/content',{recursive:true});writeFileSync('build/content/reviewed-catalogue.sql',sql);console.log('Prepared build/content/reviewed-catalogue.sql; nothing published.');
