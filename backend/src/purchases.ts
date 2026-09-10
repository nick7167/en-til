import { AppStoreServerAPIClient, Environment, SignedDataVerifier, Type, VerificationException } from '@apple/app-store-server-library';
import { GameError, packIDs, type Principal } from './protocol.ts';

export async function verifyPurchase(env:Env,principal:Principal,jws:string) {
  const {APPLE_PRIVATE_KEY:key,APPLE_KEY_ID:keyID,APPLE_ISSUER_ID:issuer,APPLE_BUNDLE_ID:bundle,APPLE_ROOT_CERTIFICATES:roots}=env;
  if(!key || !keyID || !issuer || !bundle || !roots)throw new GameError('verification_pending','Købet bliver kontrolleret. Vi prøver igen automatisk.',503);
  const environment=env.ENVIRONMENT==='production'?Environment.PRODUCTION:Environment.SANDBOX;
  const appID=env.APPLE_APP_ID ? Number(env.APPLE_APP_ID) : undefined;
  if(environment===Environment.PRODUCTION && !appID)throw new GameError('verification_pending','Købet bliver kontrolleret.',503);
  const rootBuffers=(JSON.parse(roots) as string[]).map(x => Buffer.from(x,'base64'));
  const verifier=new SignedDataVerifier(rootBuffers,true,environment,bundle,appID);
  let original;
  try {original=await verifier.verifyAndDecodeTransaction(jws);}catch(error){if(error instanceof VerificationException)throw new GameError('purchase_invalid','Købet kunne ikke bekræftes.',400);throw error;}
  if(!original.transactionId)throw new GameError('purchase_invalid','Købet kunne ikke bekræftes.',400);
  const api=new AppStoreServerAPIClient(key,keyID,issuer,bundle,environment);
  // Refresh directly with Apple, so replaying an old valid JWS cannot undo a refund.
  const current=await api.getTransactionInfo(original.transactionId);
  if(!current.signedTransactionInfo)throw new GameError('verification_pending','Vi venter på bekræftelse fra Apple.',503);
  const transaction=await verifier.verifyAndDecodeTransaction(current.signedTransactionInfo);
  const validProducts=[...packIDs.filter(p => p!=='free'),'launch-bundle'].map(p => `${bundle}.${p}`);
  if(transaction.transactionId!==original.transactionId || transaction.productId!==original.productId || !transaction.productId || !validProducts.includes(transaction.productId) || transaction.bundleId!==bundle || transaction.environment!==environment || transaction.type!==Type.NON_CONSUMABLE || !transaction.purchaseDate || transaction.purchaseDate>Date.now()+60_000)throw new GameError('purchase_invalid','Det køb hører ikke til dette spil.',400);
  const revoked=Number(transaction.revocationDate!==undefined);
  await env.DB.batch([
    env.DB.prepare('INSERT INTO purchases(transaction_id,environment,product_id,revoked,verified_at,signed_at) VALUES(?,?,?,?,?,?) ON CONFLICT(transaction_id,environment) DO UPDATE SET revoked=excluded.revoked,verified_at=excluded.verified_at,signed_at=excluded.signed_at WHERE excluded.signed_at>=purchases.signed_at').bind(transaction.transactionId,environment,transaction.productId,revoked,Date.now(),transaction.signedDate ?? 0),
    env.DB.prepare('INSERT OR IGNORE INTO ownership(session_id,transaction_id,environment) VALUES(?,?,?)').bind(principal.id,transaction.transactionId,environment),
  ]);
  if(revoked)throw new GameError('purchase_revoked','Købet er tilbagebetalt og giver ikke længere adgang.',403);
}

/** Signed Apple notifications update every installation restored from the transaction. */
export async function receiveAppleNotification(env:Env,payload:string) {
  if(!env.APPLE_BUNDLE_ID || !env.APPLE_ROOT_CERTIFICATES)throw new GameError('verification_pending','Verifikation er ikke konfigureret.',503);
  const environment=env.ENVIRONMENT==='production'?Environment.PRODUCTION:Environment.SANDBOX;
  const verifier=new SignedDataVerifier((JSON.parse(env.APPLE_ROOT_CERTIFICATES) as string[]).map(x=>Buffer.from(x,'base64')),true,environment,env.APPLE_BUNDLE_ID,env.APPLE_APP_ID?Number(env.APPLE_APP_ID):undefined);
  let notification;
  try {notification=await verifier.verifyAndDecodeNotification(payload);}catch(error){if(error instanceof VerificationException)throw new GameError('purchase_invalid','Ugyldig bekræftelse.',400);throw error;}
  if(!notification.notificationUUID)throw new GameError('purchase_invalid','Ugyldig bekræftelse.',400);
  if(await env.DB.prepare('SELECT id FROM apple_notifications WHERE id=?').bind(notification.notificationUUID).first())return;
  const signed=notification.data?.signedTransactionInfo;
  if(!signed) {await env.DB.prepare('INSERT OR IGNORE INTO apple_notifications(id,received_at) VALUES(?,?)').bind(notification.notificationUUID,Date.now()).run();return;}
  const transaction=await verifier.verifyAndDecodeTransaction(signed);
  if(!transaction.transactionId || transaction.bundleId!==env.APPLE_BUNDLE_ID || transaction.environment!==environment || transaction.type!==Type.NON_CONSUMABLE)throw new GameError('purchase_invalid','Ugyldig bekræftelse.',400);
  await env.DB.batch([
    env.DB.prepare('UPDATE purchases SET revoked=?,verified_at=?,signed_at=? WHERE transaction_id=? AND environment=? AND signed_at<=?').bind(Number(transaction.revocationDate!==undefined),Date.now(),transaction.signedDate ?? 0,transaction.transactionId,environment,transaction.signedDate ?? 0),
    env.DB.prepare('INSERT OR IGNORE INTO apple_notifications(id,received_at) VALUES(?,?)').bind(notification.notificationUUID,Date.now()),
  ]);
}
