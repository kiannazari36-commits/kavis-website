import { supabase } from './supabase';
import { currentUser } from './auth';
import { clearProfile } from './account';
import type { CourseColor } from './types';

// After sign-up ("Hoş geldin", design ScrOnboarding + NewCourses "setup"): language, school / department / year,
// weekly study plan, this term's courses. Until it is done (profiles.onboarding_done) the app opens it first.

/** Departments as the design writes them; the Turkish word is stored in the profile. */
export const DEPARTMENTS = ['Eczacılık', 'Tıp', 'Diş Hekimliği', 'Hemşirelik', 'Sağlık Bilimleri', 'Diğer'] as const;

/**
 * Course suggestions per department (the course_catalog table is still empty; these come from the design for
 * pharmacy and common first courses elsewhere). The student can always type any other course.
 */
export const SUGGESTIONS: Record<string, string[]> = {
  Eczacılık: ['Farmakoterapi', 'Toksikoloji', 'Farmasötik Teknoloji', 'Farmakognozi', 'Farmasötik Kimya', 'Biyofarmasötik', 'Klinik Eczacılık', 'Farmakoloji', 'Biyokimya'],
  Tıp: ['Anatomi', 'Fizyoloji', 'Histoloji', 'Biyokimya', 'Farmakoloji', 'Patoloji', 'Mikrobiyoloji', 'İç Hastalıkları'],
  'Diş Hekimliği': ['Anatomi', 'Diş Morfolojisi', 'Oral Diagnoz', 'Endodonti', 'Periodontoloji', 'Protetik Diş Tedavisi', 'Ortodonti'],
  Hemşirelik: ['Hemşirelik Esasları', 'Anatomi', 'Fizyoloji', 'Farmakoloji', 'İç Hastalıkları Hemşireliği', 'Cerrahi Hastalıkları Hemşireliği'],
  'Sağlık Bilimleri': ['Anatomi', 'Fizyoloji', 'Biyokimya', 'Halk Sağlığı', 'Beslenme İlkeleri'],
  Diğer: [],
};

const COLORS: CourseColor[] = ['red', 'amb', 'vio', 'grn', 'teal'];

/** The term name like the design: "2026–2027 Güz" from September to January, else "Bahar". */
export function termName(d = new Date()) {
  const m = d.getMonth() + 1;
  const start = m >= 8 ? d.getFullYear() : d.getFullYear() - 1;
  return `${start}–${start + 1} ${m >= 8 || m === 1 ? 'Güz' : 'Bahar'}`;
}

/** true when this account has not finished the first steps yet. */
export async function needsOnboarding(): Promise<boolean> {
  const user = currentUser();
  if (!user) return false;
  const { data, error } = await supabase.from('profiles').select('onboarding_done').eq('id', user.id).maybeSingle();
  if (error) console.error('needsOnboarding', error);
  return data ? !data.onboarding_done : false;
}

/** New courses (own rows), with the next free colours; "started" ones get a placement test later. */
export async function createCourses(names: string[], started: string[] = []) {
  const user = currentUser();
  if (!user || !names.length) return [];
  const { count } = await supabase.from('courses').select('id', { count: 'exact', head: true });
  const term = termName();
  const { data, error } = await supabase
    .from('courses')
    .insert(
      names.map((name, i) => ({
        user_id: user.id,
        name: name.trim(),
        color: COLORS[((count ?? 0) + i) % COLORS.length],
        term,
        started_before: started.includes(name),
        sort_order: (count ?? 0) + i,
      })),
    )
    .select('id');
  if (error) console.error('createCourses', error);
  return (data ?? []).map((r) => r.id as string);
}

/** Saves the profile answers and marks the first steps as done. */
export async function finishOnboarding(p: { school: string; department: string; classYear: number | null }) {
  const user = currentUser();
  if (!user) return false;
  const { error } = await supabase
    .from('profiles')
    .update({ school: p.school.trim() || null, department: p.department || null, class_year: p.classYear, onboarding_done: true })
    .eq('id', user.id);
  if (error) console.error('finishOnboarding', error);
  clearProfile();
  return !error;
}
