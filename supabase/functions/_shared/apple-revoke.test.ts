// Run: node --experimental-strip-types supabase/functions/_shared/apple-revoke.test.ts
import { appleClientSecret, appleConfigured, appleEnvFrom, exchangeAppleCode, revokeAppleToken, type FetchLike } from './apple-revoke.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};

// A throw-away P-256 key in the same PEM form as Apple's .p8 file.
const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey));
let bin = '';
for (const b of der) bin += String.fromCharCode(b);
const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(bin).replace(/(.{64})/g, '$1\n')}\n-----END PRIVATE KEY-----`;
const env = { teamId: 'TEAM123456', keyId: 'KEY1234567', clientId: 'study.kavis.app', privateKey: pem };

const dec = (s: string) => JSON.parse(atob(s.replace(/-/g, '+').replace(/_/g, '/')));
const jwt = await appleClientSecret(env, 1_800_000_000);
const [h, c, sg] = jwt.split('.');
check('client secret header', dec(h).alg === 'ES256' && dec(h).kid === 'KEY1234567');
check('client secret claims', dec(c).iss === 'TEAM123456' && dec(c).sub === 'study.kavis.app' && dec(c).aud === 'https://appleid.apple.com' && dec(c).exp === 1_800_000_300);
const raw = Uint8Array.from(atob(sg.replace(/-/g, '+').replace(/_/g, '/') + '=='.slice(0, (4 - (sg.length % 4)) % 4)), (x) => x.charCodeAt(0));
check('client secret signature is valid ES256 (64 bytes)', raw.length === 64 && (await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, pair.publicKey, raw, new TextEncoder().encode(`${h}.${c}`))));
check('secret with "\\n" written as text still works', (await appleClientSecret({ ...env, privateKey: pem.replace(/\n/g, '\\n') }, 1)).split('.').length === 3);

const calls: { url: string; body: string }[] = [];
const ok: FetchLike = async (url, init) => (calls.push({ url, body: init.body }), { ok: true, status: 200, json: async () => ({ refresh_token: 'r-tok' }) });
check('not configured → skipped, nothing called', (await revokeAppleToken('tok', {}, ok)) === 'skipped' && calls.length === 0);
check('no token → skipped', (await revokeAppleToken(null, env, ok)) === 'skipped' && calls.length === 0);
check('configured → revoked, form sent to Apple', (await revokeAppleToken('tok', env, ok)) === 'revoked' && calls[0].url === 'https://appleid.apple.com/auth/revoke' && calls[0].body.includes('token=tok') && calls[0].body.includes('client_id=study.kavis.app') && calls[0].body.includes('token_type_hint=refresh_token'));
check('Apple error → failed (never throws)', (await revokeAppleToken('tok', env, async () => ({ ok: false, status: 400, json: async () => ({}) }))) === 'failed');
check('network error → failed (never throws)', (await revokeAppleToken('tok', env, async () => { throw new Error('down'); })) === 'failed');
check('code exchange returns the refresh token', (await exchangeAppleCode('abc', env, ok)) === 'r-tok' && calls[1].url === 'https://appleid.apple.com/auth/token' && calls[1].body.includes('grant_type=authorization_code'));
check('code exchange not configured → null', (await exchangeAppleCode('abc', {}, ok)) === null);
check('env reader', appleConfigured(appleEnvFrom((k) => ({ APPLE_TEAM_ID: 'a', APPLE_KEY_ID: 'b', APPLE_CLIENT_ID: 'c', APPLE_PRIVATE_KEY: 'd' } as Record<string, string>)[k])) && !appleConfigured(appleEnvFrom(() => undefined)));
if (fails) process.exit(1);
