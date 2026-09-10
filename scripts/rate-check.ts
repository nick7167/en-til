import assert from 'node:assert/strict';
const base='http://127.0.0.1:8787';
const ip='203.0.113.244';
let rejected=0;
for(let i=0;i<35;i++){
  const response=await fetch(base+'/v1/sessions',{method:'POST',headers:{'CF-Connecting-IP':ip,'Content-Type':'application/json'},body:'{}'});
  if(response.status===429)rejected++;
  else assert.equal(response.status,201);
}
assert.ok(rejected>=5);console.log(`PASS: session rate limiter rejected ${rejected} excess local requests.`);
