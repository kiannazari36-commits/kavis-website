import { supabase } from './supabase';
import { currentUser } from './auth';
import type { Lang } from '../i18n/I18nProvider';
import type { ThemePref } from '../theme/ThemeProvider';

export type Prefs = { lang: Lang; theme: ThemePref };

/** App language (profiles.app_lang) and theme (user_settings.app_theme) saved in the account, so every device has them. */
export async function loadPrefs(): Promise<Prefs | null> {
  const user = currentUser();
  if (!user) return null;
  const [p, s] = await Promise.all([
    supabase.from('profiles').select('app_lang').eq('id', user.id).single<{ app_lang: Lang }>(),
    supabase.from('user_settings').select('app_theme').eq('user_id', user.id).single<{ app_theme: ThemePref }>(),
  ]);
  if (p.error || s.error) {
    console.error('loadPrefs', p.error ?? s.error);
    return null;
  }
  return { lang: p.data.app_lang, theme: s.data.app_theme };
}

/** The language also decides the language of the server's texts (e.g. "lesson ready" notifications). */
export async function saveLang(lang: Lang) {
  const user = currentUser();
  if (!user) return;
  const { error } = await supabase.from('profiles').update({ app_lang: lang }).eq('id', user.id);
  if (error) console.error('saveLang', error);
}

export async function saveTheme(theme: ThemePref) {
  const user = currentUser();
  if (!user) return;
  const { error } = await supabase.from('user_settings').update({ app_theme: theme }).eq('user_id', user.id);
  if (error) console.error('saveTheme', error);
}
