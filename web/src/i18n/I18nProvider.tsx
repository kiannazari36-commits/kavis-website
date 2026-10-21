import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import desk from './desk.json';

export type Lang = 'tr' | 'en' | 'fa' | 'ar';
export const LANGS: Lang[] = ['tr', 'en', 'fa', 'ar'];

// Texts copied from design/DeskApp.dc.html; keys are the design's own (k0, k1, …).
type Dict = Record<string, string>;
const dicts = desk as Record<Lang, Dict>;

type I18n = {
  lang: Lang;
  dir: 'ltr' | 'rtl';
  setLang: (l: Lang) => void;
  t: (key: string) => string;
};

const I18nContext = createContext<I18n | null>(null);
const STORAGE_KEY = 'kavis.lang';

function readStoredLang(): Lang {
  try {
    const v = localStorage.getItem(STORAGE_KEY);
    if (v && (LANGS as string[]).includes(v)) return v as Lang;
  } catch {
    /* storage blocked: fall back to default */
  }
  return 'tr';
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(readStoredLang);
  const dir = lang === 'fa' || lang === 'ar' ? 'rtl' : 'ltr';

  useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = dir;
  }, [lang, dir]);

  const setLang = useCallback((l: Lang) => {
    setLangState(l);
    try {
      localStorage.setItem(STORAGE_KEY, l);
    } catch {
      /* ignore */
    }
  }, []);

  const t = useCallback((key: string) => dicts[lang][key] ?? dicts.en[key] ?? key, [lang]);

  const value = useMemo(() => ({ lang, dir, setLang, t }) as I18n, [lang, dir, setLang, t]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error('useI18n must be used inside I18nProvider');
  return ctx;
}
