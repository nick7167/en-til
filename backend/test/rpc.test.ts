import {test} from 'node:test';
import assert from 'node:assert/strict';
import {rpcResult,unwrap} from '../src/rpc.ts';
import {GameError} from '../src/protocol.ts';
test('game errors survive JSON/RPC serialization with Danish message and status',async()=>{
  const wire=JSON.parse(JSON.stringify(await rpcResult(async()=>{throw new GameError('character_taken','Den figur er allerede valgt.');})));
  assert.throws(()=>unwrap(wire),(e:unknown)=>e instanceof GameError && e.code==='character_taken' && e.status===409 && e.message==='Den figur er allerede valgt.');
});
