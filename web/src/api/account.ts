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

/**
 * "Hesap bilgilerimi iste": the server (Edge Function export-data) puts all the student's data in one JSON file,
 * with 7-day download links for the PDFs; it is downloaded at once (by email later, once email is set up).
 */
export async function requestMyData() {
  const { data, error } = await supabase.functions.invoke('export-data', { body: {} });
  if (error) {
    console.error('export-data', error);
    return false;
  }
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `kavis-study-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  return true;
}

/** Told to the menu bar when the deletion date changes (asked for or cancelled). */
export const DELETION_EVENT = 'kavis:deletion';

/**
 * "Hesabı sil": the password is checked once more by the server (Edge Function delete-account), then the account
 * is deleted in 30 days; until then it works as before and the deletion can be cancelled.
 */
export async function deleteAccount(password: string): Promise<{ scheduledFor: string } | { error: 'password' | 'other' }> {
  const { data, error } = await supabase.functions.invoke('delete-account', { body: { action: 'request', password } });
  if (error) {
    const status = (error as { context?: { status?: number } }).context?.status;
    return { error: status === 403 ? 'password' : 'other' };
  }
  window.dispatchEvent(new Event(DELETION_EVENT));
  return { scheduledFor: (data as { scheduled_for: string }).scheduled_for };
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
