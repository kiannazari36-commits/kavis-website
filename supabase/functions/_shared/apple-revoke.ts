// Sign in with Apple: revoking the student's Apple token when the account is deleted (App Store rule 5.1.1(v)).
// Apple's endpoint https://appleid.apple.com/auth/revoke needs a "client secret": a short-lived ES256 JWT signed with the
// Sign in with Apple key (.p8) Kian creates in the Apple Developer account. Everything here is guarded by secrets:
// without APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_CLIENT_ID and APPLE_PRIVATE_KEY nothing is called (revoke is "skipped").
// Pure code (no Deno-only globals), so the unit test runs anywhere.

export type AppleEnv = { teamId?: string; keyId?: string; clientId?: string; privateKey?: string };
export type FetchLike = (url: string, init: { method: string; headers: Record<string, string>; body: string }) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>;

/** The four secrets, read from Deno.env by the callers (APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_CLIENT_ID, APPLE_PRIVATE_KEY). */
export const appleEnvFrom = (get: (k: string) => string | undefined): AppleEnv => ({
  teamId: get('APPLE_TEAM_ID')?.trim(),
  keyId: get('APPLE_KEY_ID')?.trim(),
  clientId: get('APPLE_CLIENT_ID')?.trim(),
  privateKey: get('APPLE_PRIVATE_KEY'),
});

/** True when every secret the revoke needs is set. */
export const appleConfigured = (e: AppleEnv): e is Required<AppleEnv> => !!(e.teamId && e.keyId && e.clientId && e.privateKey);

const b64url = (data: Uint8Array | string) => {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data;
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

/** The .p8 file (PEM, "-----BEGIN PRIVATE KEY-----"; "\n" written as backslash-n in a secret is accepted) as key bytes. */
function pemToDer(pem: string): Uint8Array {
  const body = pem.replace(/\\n/g, '\n').replace(/-----[A-Z ]+-----/g, '').replace(/\s+/g, '');
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

/** Apple's client secret: ES256 JWT (iss = team id, sub = client id, aud = appleid.apple.com), valid 5 minutes. */
export async function appleClientSecret(e: Required<AppleEnv>, nowSec = Math.floor(Date.now() / 1000)): Promise<string> {
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: e.keyId, typ: 'JWT' }));
  const claims = b64url(JSON.stringify({ iss: e.teamId, iat: nowSec, exp: nowSec + 300, aud: 'https://appleid.apple.com', sub: e.clientId }));
  const key = await crypto.subtle.importKey('pkcs8', pemToDer(e.privateKey), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  // WebCrypto gives the raw r||s signature that JWT ES256 wants.
  const sig = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(`${header}.${claims}`)));
  return `${header}.${claims}.${b64url(sig)}`;
}

/**
 * Revokes the student's Apple refresh token. Returns 'skipped' when the secrets or the token are missing (nothing is
 * called), 'revoked' when Apple accepted it, 'failed' otherwise (the caller logs it and still deletes the account:
 * deleting the account must never be blocked by Apple being unreachable).
 */
export async function revokeAppleToken(refreshToken: string | null | undefined, env: AppleEnv, fetcher: FetchLike): Promise<'skipped' | 'revoked' | 'failed'> {
  if (!refreshToken || !appleConfigured(env)) return 'skipped';
  try {
    const body = new URLSearchParams({ client_id: env.clientId, client_secret: await appleClientSecret(env), token: refreshToken, token_type_hint: 'refresh_token' }).toString();
    const r = await fetcher('https://appleid.apple.com/auth/revoke', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
    return r.ok ? 'revoked' : 'failed';
  } catch {
    return 'failed';
  }
}

/**
 * Exchanges the authorization code the iPhone app gets from Sign in with Apple for Apple's refresh token (the only
 * thing the revoke needs). null when the secrets are missing or Apple refuses the code.
 */
export async function exchangeAppleCode(code: string, env: AppleEnv, fetcher: FetchLike): Promise<string | null> {
  if (!code || !appleConfigured(env)) return null;
  try {
    const body = new URLSearchParams({ client_id: env.clientId, client_secret: await appleClientSecret(env), code, grant_type: 'authorization_code' }).toString();
    const r = await fetcher('https://appleid.apple.com/auth/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
    if (!r.ok) return null;
    const j = (await r.json()) as { refresh_token?: string };
    return typeof j.refresh_token === 'string' ? j.refresh_token : null;
  } catch {
    return null;
  }
}
