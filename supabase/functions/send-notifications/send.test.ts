// Run: node --experimental-strip-types supabase/functions/send-notifications/send.test.ts
import { apnsConfig, apnsJwt, deadToken, importKey, payload } from './apns.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};

check('no Apple key → off', apnsConfig(() => undefined) === null);
// A throwaway P-256 key in the .p8 format (PKCS#8 PEM), like the file Apple gives.
const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey));
const pem = `-----BEGIN PRIVATE KEY-----\\n${btoa(String.fromCharCode(...der))}\\n-----END PRIVATE KEY-----`;
const env: Record<string, string> = { APNS_KEY_ID: 'ABC123DEFG', APNS_TEAM_ID: 'TEAM123456', APNS_PRIVATE_KEY: pem, APNS_ENV: 'sandbox' };
const cfg = apnsConfig((k) => env[k])!;
check('config read, default bundle id, sandbox', cfg.topic === 'study.kavis.app' && cfg.sandbox);
const jwt = await apnsJwt(cfg, await importKey(cfg.privateKey), 1_800_000_000);
const [h, c, s] = jwt.split('.');
const dec = (x: string) => JSON.parse(atob(x.replace(/-/g, '+').replace(/_/g, '/')));
check('JWT header', dec(h).alg === 'ES256' && dec(h).kid === 'ABC123DEFG');
check('JWT claims', dec(c).iss === 'TEAM123456' && dec(c).iat === 1_800_000_000);
const sig = Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/') + '=='.slice(0, (4 - (s.length % 4)) % 4)), (x) => x.charCodeAt(0));
check('signature is raw r‖s (64 bytes)', sig.length === 64);
check('signature verifies', await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, pair.publicKey, sig, new TextEncoder().encode(`${h}.${c}`)));
const p = payload({ id: 'n1', title: 'Hazır', body: null, data: { to: '/plan' } });
check('payload', p.aps.alert.title === 'Hazır' && p.aps.alert.body === '' && p.to === '/plan');
check('dead tokens', deadToken(410, 'Unregistered') && deadToken(400, 'BadDeviceToken') && !deadToken(429, 'TooManyRequests'));

if (fails) process.exit(1);
