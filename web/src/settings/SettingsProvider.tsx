import { createContext, useCallback, useContext, useState, type ReactNode } from 'react';
import { useI18n, type Lang } from '../i18n/I18nProvider';
import { loadSettingsNow, saveSettings, type ContentLangChoice, type Settings } from '../api/settings';
import type { Course } from '../api/types';

type Ctx = {
  settings: Settings;
  setContentLang: (c: ContentLangChoice) => void;
  /** null removes the course override. */
  setCourseContentLang: (courseId: string, c: ContentLangChoice | null) => void;
};

const SettingsContext = createContext<Ctx | null>(null);

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<Settings>(loadSettingsNow);

  const update = useCallback((next: Settings) => {
    setSettings(next);
    saveSettings(next);
  }, []);

  const setContentLang = useCallback((c: ContentLangChoice) => update({ ...settings, contentLang: c }), [settings, update]);

  const setCourseContentLang = useCallback(
    (courseId: string, c: ContentLangChoice | null) => {
      const courseContentLang = { ...settings.courseContentLang };
      if (c === null) delete courseContentLang[courseId];
      else courseContentLang[courseId] = c;
      update({ ...settings, courseContentLang });
    },
    [settings, update],
  );

  return <SettingsContext.Provider value={{ settings, setContentLang, setCourseContentLang }}>{children}</SettingsContext.Provider>;
}

export function useSettings() {
  const ctx = useContext(SettingsContext);
  if (!ctx) throw new Error('useSettings must be used inside SettingsProvider');
  return ctx;
}

export const dirOf = (l: Lang) => (l === 'fa' || l === 'ar' ? 'rtl' : 'ltr');

/**
 * Language for a course's quiz questions, cards and summaries (CLAUDE.md "Content language"):
 * course setting → general setting → "Same as PDF" (the course PDF language).
 */
export function useContentLang(course?: Pick<Course, 'id' | 'language'>): Lang {
  const { lang } = useI18n();
  const { settings } = useSettings();
  const choice = (course && settings.courseContentLang[course.id]) || settings.contentLang;
  if (choice === 'app') return lang;
  if (choice === 'pdf') return course?.language ?? 'tr';
  return choice;
}
