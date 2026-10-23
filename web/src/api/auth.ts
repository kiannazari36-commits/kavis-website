import { AuthError, type Session } from '@supabase/supabase-js';
import { supabase } from './supabase';
import type { Lang } from '../i18n/I18nProvider';

export type User = { id: string; name: string; email: string };
export type Provider = 'apple' | 'google';

/** Why an auth call failed; each one is a key in src/i18n/auth.json (prefixed with "err"). */
export type AuthFailReason = 'Code' | 'Login' | 'Unconfirmed' | 'Rate' | 'WeakPw' | 'Taken' | 'Email' | 'Network' | 'Soon' | 'Other';

export class AuthFail extends Error {
  reason: AuthFailReason;
  constructor(reason: AuthFailReason) {
    super(reason);
    this.reason = reason;
  }
}

function fail(e: unknown): never {
  if (!(e instanceof AuthError)) throw new AuthFail('Other');
  if (e.status === 0 || e.name === 'AuthRetryableFetchError') throw new AuthFail('Network');
  const map: Record<string, AuthFailReason> = {
    otp_expired: 'Code',
    invalid_credentials: 'Login',
    email_not_confirmed: 'Unconfirmed',
    over_email_send_rate_limit: 'Rate',
    over_request_rate_limit: 'Rate',
    weak_password: 'WeakPw',
    user_already_exists: 'Taken',
    email_exists: 'Taken',
    email_address_invalid: 'Email',
    validation_failed: 'Email',
  };
  throw new AuthFail(map[e.code ?? ''] ?? 'Other');
}

let user: User | null = null;

function toUser(session: Session | null): User | null {
  const u = session?.user;
  if (!u) return null;
  const meta = u.user_metadata ?? {};
  return { id: u.id, name: (meta.full_name ?? meta.name ?? '') as string, email: u.email ?? '' };
}

/** Reads the saved session once at start-up (main.tsx) and keeps it up to date. */
export async function initAuth() {
  const { data } = await supabase.auth.getSession();
  user = toUser(data.session);
  supabase.auth.onAuthStateChange((_event, session) => {
    user = toUser(session);
  });
}

/** The signed-in student, or null. */
export function currentUser(): User | null {
  return user;
}

/** Creates the account; Supabase then emails a 6-digit code (the "Confirm sign up" template uses {{ .Token }}). */
export async function signUp(name: string, email: string, password: string, lang: Lang) {
  const { data, error } = await supabase.auth.signUp({
    email: email.trim(),
    password,
    options: { data: { full_name: name.trim(), app_lang: lang } },
  });
  if (error) fail(error);
  // An email that already has a confirmed account comes back with no identities and no email is sent.
  if (data.user && data.user.identities?.length === 0) throw new AuthFail('Taken');
  return { pendingEmail: email.trim(), name: name.trim() };
}

export async function verifyEmail(email: string, code: string) {
  if (code.length !== 6) throw new AuthFail('Code');
  const { data, error } = await supabase.auth.verifyOtp({ email, token: code, type: 'signup' });
  if (error) fail(error);
  user = toUser(data.session);
  return user;
}

export async function resendCode(email: string) {
  const { error } = await supabase.auth.resend({ type: 'signup', email });
  if (error) fail(error);
  return true;
}

export async function logIn(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
  if (error) fail(error);
  user = toUser(data.session);
  return user;
}

/** Sign in with Apple / Google: not set up yet (needs the Apple and Google developer settings). */
export async function socialLogIn(_provider: Provider): Promise<User> {
  throw new AuthFail('Soon');
}

export async function logOut() {
  await supabase.auth.signOut();
  user = null;
  return true;
}
