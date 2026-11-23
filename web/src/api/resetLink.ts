/**
 * What the reset page (/login?mode=reset) should do with the address it was opened with. Pure, so it can be tested.
 *
 *  - `verify`  : the email carries `token_hash` (Supabase "Reset password" template, see docs/BACKEND.md). The page
 *                trades it for a session itself with verifyOtp. Works for web and iPhone requests alike, and email
 *                scanners that only fetch the link cannot burn it.
 *  - `app`     : the old-style link made by the iPhone app (PKCE) arrived as `?code=`. The web has no code verifier,
 *                so it can never be used here: say so and offer a fresh link, instead of a silent dead end.
 *  - `expired` : Supabase sent `#error=...` (link used or too old), or there is no session at all.
 *  - `form`    : a session exists (the old-style link signed this browser in) and nothing says otherwise.
 */
export type ResetPlan = 'verify' | 'app' | 'expired' | 'form';

export function resetPlan(search: string, hash: string, hasSession: boolean): ResetPlan {
  const q = new URLSearchParams(search);
  const h = new URLSearchParams(hash.replace(/^#/, ''));
  if (q.get('token_hash') && (q.get('type') ?? 'recovery') === 'recovery') return 'verify';
  if (h.get('error') || h.get('error_code') || q.get('error') || q.get('error_code')) return 'expired';
  if (q.get('code') && !hasSession) return 'app';
  return hasSession ? 'form' : 'expired';
}
