import { supabase } from './supabase';
import { currentUser } from './auth';

export type Profile = { name: string; email: string; school: string; department: string; classYear: number | null };

let cache: Profile | null = null;

/** The signed-in student's profile (table profiles; the email comes from the login). Cached until it changes. */
export async function getProfile(): Promise<Profile | null> {
  const user = currentUser();
  if (!user) return null;
  if (cache) return cache;
  const { data, error } = await supabase.from('profiles').select('full_name, school, department, class_year').eq('id', user.id).single();
  if (error) {
    console.error('getProfile', error);
    return { name: user.name, email: user.email, school: '', department: '', classYear: null };
  }
  cache = { name: data.full_name, email: user.email, school: data.school ?? '', department: data.department ?? '', classYear: data.class_year };
  return cache;
}

/** Saves name and school. A new email address needs a confirmation link sent to it (Supabase Auth). */
export async function saveProfile(p: Pick<Profile, 'name' | 'email' | 'school'>) {
  const user = currentUser();
  if (!user) throw new Error('not signed in');
  const { error } = await supabase.from('profiles').update({ full_name: p.name.trim(), school: p.school.trim() || null }).eq('id', user.id);
  if (error) throw error;
  // Keep the login's name in step, so the menu shows it right away.
  await supabase.auth.updateUser({
    data: { full_name: p.name.trim() },
    ...(p.email.trim() && p.email.trim() !== user.email ? { email: p.email.trim() } : {}),
  });
  cache = { ...(cache ?? { department: '', classYear: null }), name: p.name.trim(), email: user.email, school: p.school.trim() };
  return cache;
}

/** Forget the cached profile (after logging out). */
export function clearProfile() {
  cache = null;
}

/** HTTP status of a failed Edge Function call (429 = too many emails this hour). */
const statusOf = (error: unknown) => (error as { context?: { status?: number } }).context?.status;

/**
 * "Hesap bilgilerimi iste": the server (Edge Function export-data) puts all the student's data in one JSON file
 * and emails a download link valid for 7 days (with 7-day links for the PDFs inside).
 */
export async function requestMyData(): Promise<'sent' | 'limit' | 'error'> {
  const { error } = await supabase.functions.invoke('export-data', { body: {} });
  if (!error) return 'sent';
  console.error('export-data', error);
  return statusOf(error) === 429 ? 'limit' : 'error';
}

/** Told to the menu bar when the deletion date changes (asked for or cancelled). */
export const DELETION_EVENT = 'kavis:deletion';

/**
 * "Hesabı sil": the server (Edge Function delete-account) emails a one-time confirmation link (24 h); the deletion
 * starts only when the link's page is confirmed (confirmDeletion). Already scheduled → its date comes back.
 */
export async function deleteAccount(): Promise<'sent' | { scheduledFor: string } | { error: 'limit' | 'other' }> {
  const { data, error } = await supabase.functions.invoke('delete-account', { body: { action: 'request' } });
  if (error) return { error: statusOf(error) === 429 ? 'limit' : 'other' };
  const r = data as { sent?: boolean; scheduled_for?: string };
  return r.scheduled_for ? { scheduledFor: r.scheduled_for } : 'sent';
}

/** The page behind the email link: the account is deleted in 30 days. No login needed, the token is the proof. */
export async function confirmDeletion(token: string): Promise<{ scheduledFor: string } | { error: 'invalid' | 'expired' | 'other' }> {
  const { data, error } = await supabase.functions.invoke('delete-account', { body: { action: 'confirm', token } });
  if (!error) {
    window.dispatchEvent(new Event(DELETION_EVENT));
    return { scheduledFor: (data as { scheduled_for: string }).scheduled_for };
  }
  const body = await ((error as { context?: Response }).context?.json?.().catch(() => null) ?? null);
  return { error: body?.error === 'expired' ? 'expired' : body?.error === 'invalid' ? 'invalid' : 'other' };
}

export async function cancelDeletion() {
  const { error } = await supabase.functions.invoke('delete-account', { body: { action: 'cancel' } });
  if (error) console.error('cancelDeletion', error);
  window.dispatchEvent(new Event(DELETION_EVENT));
  return !error;
}

/** The day the account will be deleted, or null. */
export async function deletionDate(): Promise<string | null> {
  if (!currentUser()) return null;
  const { data, error } = await supabase
    .from('account_requests')
    .select('scheduled_for')
    .eq('kind', 'delete')
    .eq('status', 'confirmed')
    .maybeSingle<{ scheduled_for: string }>();
  if (error) console.error('deletionDate', error);
  return data?.scheduled_for ?? null;
}
