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

/** Emails the student a copy of their data (Edge Function "export-data", not built yet). */
export async function requestMyData() {
  return true;
}

/** Starts account deletion (Edge Function "delete-account", not built yet): email confirmation, 30 days to undo. */
export async function deleteAccount() {
  return true;
}
