import { ZodError } from 'zod';
import { GameError } from './protocol.ts';
export type RPCResult<T> = {ok:true;value:T} | {ok:false;error:{code:string;message:string;status:number}};
/** Custom Error properties are not preserved across Durable Object RPC boundaries. */
export async function rpcResult<T>(operation:()=>Promise<T>):Promise<RPCResult<T>> {
  try {return {ok:true,value:await operation()};}
  catch(error) {
    if(error instanceof GameError)return {ok:false,error:{code:error.code,message:error.message,status:error.status}};
    if(error instanceof ZodError)return {ok:false,error:{code:'invalid',message:'Beskeden kunne ikke læses.',status:400}};
    throw error;
  }
}
export function unwrap<T>(result:RPCResult<T>):T {
  if(!result.ok)throw new GameError(result.error.code,result.error.message,result.error.status);
  return result.value;
}
