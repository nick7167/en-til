import { z } from 'zod';

export const packIDs = ['free', 'danmark', 'film-tv', 'isbryderen', 'lidt-for-aerlig', 'efter-midnat', 'uden-filter'] as const;
export type PackID = typeof packIDs[number];
export const adultPacks = new Set<PackID>(['lidt-for-aerlig', 'efter-midnat', 'uden-filter']);
export const settingsSchema = z.object({
  finish: z.number().int().min(5).max(50), timed: z.boolean(),
  answerSeconds: z.number().int().min(10).max(60).multipleOf(5),
  backingSeconds: z.number().int().min(5).max(30).multipleOf(5),
  drinking: z.boolean(), packs: z.array(z.enum(packIDs)).min(1).max(7).refine(x => new Set(x).size === x.length),
}).strict();
export type Settings = z.infer<typeof settingsSchema>;
export const defaults: Settings = { finish: 20, timed: true, answerSeconds: 20, backingSeconds: 10, drinking: false, packs: ['free'] };
const identity = { name: z.string().trim().min(1).max(24).refine(x => !/[\p{Cc}\p{Cf}]/u.test(x)), character: z.number().int().min(0).max(11) };
export const commandSchema = z.object({
  v: z.literal(1), requestID: z.string().uuid(), matchID: z.string().nullable(), roundID: z.string().nullable(),
  action: z.discriminatedUnion('type', [
    z.object({type:z.literal('join'), ...identity, adult:z.boolean(), drinking:z.boolean()}),
    z.object({type:z.literal('identity'), ...identity}),
    z.object({type:z.literal('settings'), settings:settingsSchema}),
    z.object({type:z.literal('ready'), value:z.boolean()}),
    z.object({type:z.literal('adult'), value:z.literal(true)}),
    z.object({type:z.literal('drinking'), value:z.boolean()}),
    z.object({type:z.literal('start')}), z.object({type:z.literal('rematch')}),
    z.object({type:z.literal('end')}), z.object({type:z.literal('leave')}),
    z.object({type:z.literal('return')}), z.object({type:z.literal('presence'), connected:z.boolean()}),
    z.object({type:z.literal('away'), playerID:z.string()}), z.object({type:z.literal('remove'), playerID:z.string()}),
    z.object({type:z.literal('private'), value:z.enum(['yes','no','skip'])}),
    z.object({type:z.literal('answer'), value:z.number().int().min(0).max(8)}),
    z.object({type:z.literal('back'), playerID:z.string()}),
    z.object({type:z.literal('reaction'), value:z.enum(['applause','laughter','surprise','side-eye'])}),
  ]),
}).strict();
export type Command = z.infer<typeof commandSchema>;
export interface Principal { id: string; owned: PackID[] }
export class GameError extends Error {
  constructor(public code: string, message: string, public status = 409) { super(message); }
}
export function requireGame(value: unknown, code: string, message: string): asserts value {
  if (!value) throw new GameError(code, message);
}
export function normalizeCode(code: string) { return code.trim().toUpperCase(); }
