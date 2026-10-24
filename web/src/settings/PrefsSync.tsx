import { useEffect, useRef } from 'react';
import { currentUser, onSignedIn } from '../api/auth';
import { loadPrefs, saveLang, saveTheme, type Prefs } from '../api/prefs';
import { useI18n } from '../i18n/I18nProvider';
import { useTheme } from '../theme/ThemeProvider';

/**
 * Keeps the app language and theme in the account: after signing in the saved ones are used (a new device looks
 * the same), and a change while signed in is saved. Signed out, they stay only in this browser.
 */
export default function PrefsSync() {
  const { lang, setLang } = useI18n();
  const { pref, setPref } = useTheme();
  // What the account has now; null until it is loaded.
  const saved = useRef<Prefs | null>(null);

  useEffect(() => {
    const load = async () => {
      const p = await loadPrefs();
      if (!p) return;
      saved.current = p;
      setLang(p.lang);
      setPref(p.theme);
    };
    if (currentUser()) load();
    return onSignedIn(load);
  }, [setLang, setPref]);

  useEffect(() => {
    const s = saved.current;
    if (!s || !currentUser()) return;
    if (s.lang !== lang) {
      s.lang = lang;
      saveLang(lang);
    }
    if (s.theme !== pref) {
      s.theme = pref;
      saveTheme(pref);
    }
  }, [lang, pref]);

  return null;
}
