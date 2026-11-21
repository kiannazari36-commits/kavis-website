import { supabase } from './supabase';

/**
 * Consent and age proof (KVKK / GDPR). The server keeps them in profiles (terms_version, terms_accepted_at,
 * adult_confirmed_at, ai_consent_at) and only the RPC record_consent() writes them (migration 20261121120000).
 * The same call is used by the iPhone app.
 */
export const TERMS_VERSION = '2026-11-21';

const PENDING = 'kavis.consent.pending';

/** The sign-up form's boxes were ticked; the account has no session until the email code is entered, so the answer is kept until then. */
export function rememberConsent() {
  try {
    localStorage.setItem(PENDING, TERMS_VERSION);
  } catch {
    /* private window: the one-time consent screen asks again */
  }
}

function takePending(): string | null {
  try {
    const v = localStorage.getItem(PENDING);
    if (v) localStorage.removeItem(PENDING);
    return v;
  } catch {
    return null;
  }
}

export async function recordConsent(adult: boolean, ai: boolean, version = TERMS_VERSION) {
  const { error } = await supabase.rpc('record_consent', { p_terms_version: version, p_adult: adult, p_ai: ai });
  if (error) throw error;
}

/**
 * Called after every sign-in. Writes the sign-up boxes if they are waiting, then says whether the one-time consent
 * screen is needed (Apple / Google sign-in, or an account made before the consent record existed).
 */
export async function consentNeeded(): Promise<boolean> {
  try {
    const pending = takePending();
    if (pending) await recordConsent(true, true, pending);
    const { data: u } = await supabase.auth.getUser();
    if (!u.user) return false;
    const { data, error } = await supabase.from('profiles').select('adult_confirmed_at, ai_consent_at').eq('id', u.user.id).maybeSingle();
    if (error || !data) return false; // never lock someone out because of a network problem
    return !data.adult_confirmed_at || !data.ai_consent_at;
  } catch (e) {
    console.error('consentNeeded', e);
    return false;
  }
}
