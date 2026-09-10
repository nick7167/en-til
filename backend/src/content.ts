import { z } from 'zod';
import { packIDs, type PackID } from './protocol.ts';
export const questionSchema = z.object({
  id:z.string().regex(/^[a-z0-9-]+$/), pack:z.enum(packIDs), kind:z.enum(['factual','personal']),
  format:z.enum(['comparison','before-after','true-false','over-under','trivia','personal']),
  prompt:z.string().min(8).max(240), options:z.array(z.string().min(1).max(90)).min(2).max(4).optional(),
  correct:z.number().int().min(0).max(3).optional(),
  source:z.string().url().optional(), fact:z.string().max(500).optional(),
  review:z.enum(['draft','approved']), reviewedBy:z.string().optional(), reviewedAt:z.string().optional(),
}).superRefine((q, ctx) => {
  if (q.kind === 'factual' && (!q.options || q.correct === undefined || q.correct >= q.options.length || !q.source || !q.fact)) ctx.addIssue({code:'custom',message:'Factual question needs valid choices, answer, fact and source'});
  if (q.kind === 'personal' && (q.options || q.correct !== undefined || q.format !== 'personal')) ctx.addIssue({code:'custom',message:'Personal questions cannot contain public answers'});
  if (q.review === 'approved' && (!q.reviewedBy || !q.reviewedAt)) ctx.addIssue({code:'custom',message:'Human review attribution required'});
});
export type Question = z.infer<typeof questionSchema>;
export interface Catalogue { version:string; questions:Question[] }
export function validateCatalogue(input:unknown, release = false): Catalogue {
  const value = z.object({version:z.string().min(1),questions:z.array(questionSchema).min(1)}).parse(input);
  if (new Set(value.questions.map(q => q.id)).size !== value.questions.length) throw new Error('Duplicate question IDs');
  if (release) {
    for (const pack of packIDs) {
      const count = value.questions.filter(q => q.pack === pack && q.review === 'approved').length;
      if (count < (pack === 'free' ? 150 : 100)) throw new Error(`Insufficient reviewed content: ${pack}`);
    }
    if (value.questions.some(q => q.review !== 'approved')) throw new Error('Drafts cannot be published');
    if (!value.questions.some(q => q.pack === 'free' && q.kind === 'personal')) throw new Error('Free mix needs personal questions');
  }
  return value;
}
/** Deterministic seed supplied by the authoritative room, never client-selected. */
export function chooseQuestion(pool:Question[], packs:PackID[], seen:string[], seed:number, lastKind?:Question['kind']): Question {
  const selected = pool.filter(q => packs.includes(q.pack));
  if (!selected.length) throw new Error('No questions available');
  // Alternate kinds where possible. Within each kind, exhaust unseen questions first.
  const preferred = lastKind ? selected.filter(q => q.kind !== lastKind) : selected;
  const candidates = preferred.length ? preferred : selected;
  const unseen = candidates.filter(q => !seen.includes(q.id));
  const available = unseen.length ? unseen : candidates;
  return structuredClone(available[(seed >>> 0) % available.length]!);
}
