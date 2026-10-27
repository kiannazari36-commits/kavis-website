// Apple push (APNs) with a token key (.p8): an ES256 JWT, renewed every 50 minutes, sent over HTTP/2 by fetch.
// No database here, so the signing can be tested anywhere (send.test.ts).

export type ApnsConfig = { keyId: string; teamId: string; privateKey: string; topic: string; sandbox: boolean };

/** The APNs settings from Supabase secrets, or null while the Apple key is not added yet. */
export function apnsConfig(env: (k: string) => string | undefined): ApnsConfig | null {
  const keyId = env('APNS_KEY_ID');
  const teamId = env('APNS_TEAM_ID');
  const privateKey = env('APNS_PRIVATE_KEY');
  if (!keyId || !teamId || !privateKey) return null;
  return { keyId, teamId, privateKey, topic: env('APNS_BUNDLE_ID') ?? 'study.kavis.app', sandbox: env('APNS_ENV') === 'sandbox' };
}

const b64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const text = (s: string) => b64url(new TextEncoder().encode(s));

/** The .p8 file's text (PEM, PKCS#8) → a signing key. "\n" written as two characters is allowed (secrets UI). */
export async function importKey(pem: string) {
  const body = pem.replace(/\\n/g, '\n').replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey('pkcs8', der, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
}

/** The provider token APNs wants in "authorization: bearer …". */
export async function apnsJwt(cfg: ApnsConfig, key: CryptoKey, nowSec = Math.floor(Date.now() / 1000)) {
  const head = text(JSON.stringify({ alg: 'ES256', kid: cfg.keyId }));
  const claims = text(JSON.stringify({ iss: cfg.teamId, iat: nowSec }));
  // WebCrypto gives the raw r‖s signature, which is what a JWT uses.
  const sig = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(`${head}.${claims}`)));
  return `${head}.${claims}.${b64url(sig)}`;
}

/** The push body: title, text, and where the app opens (data.to). */
export function payload(n: { id: string; title: string; body: string | null; data: Record<string, unknown> | null }) {
  return { aps: { alert: { title: n.title, body: n.body ?? '' }, sound: 'default' }, id: n.id, to: n.data?.to ?? null };
}

/** Answers that mean the token is dead (app removed, token changed): the token is deleted. */
export const deadToken = (status: number, reason: string) =>
  status === 410 || (status === 400 && ['BadDeviceToken', 'DeviceTokenNotForTopic'].includes(reason));

export async function sendOne(cfg: ApnsConfig, jwt: string, token: string, body: unknown) {
  const host = cfg.sandbox ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com';
  const res = await fetch(`${host}/3/device/${token}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${jwt}`,
      'apns-topic': cfg.topic,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  const reason = res.ok ? '' : ((await res.json().catch(() => ({}))) as { reason?: string }).reason ?? '';
  return { status: res.status, reason };
}
