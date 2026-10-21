import { fakeRequest } from './client';
import type { Lang } from '../i18n/I18nProvider';

/** Language for quiz questions, cards and summaries. */
export type ContentLangChoice = 'pdf' | 'app' | Lang;

export type Settings = {
  contentLang: ContentLangChoice;
  /** Per-course override; missing = use the general setting. */
  courseContentLang: Record<string, ContentLangChoice>;
  planMode: 'aim' | 'own' | 'none';
  /** Study days per week and hours per day (chosen at sign-up, editable in Settings). */
  studyDays: number;
  studyHours: number;
};

const KEY = 'kavis.settings';
export const DEFAULT_SETTINGS: Settings = { contentLang: 'pdf', courseContentLang: {}, planMode: 'aim', studyDays: 4, studyHours: 1.5 };

// The mock keeps settings in the browser; a real server will store them in the account.
export function loadSettingsNow(): Settings {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return { ...DEFAULT_SETTINGS, ...(JSON.parse(raw) as Partial<Settings>) };
  } catch {
    /* ignore */
  }
  return DEFAULT_SETTINGS;
}

export function saveSettings(s: Settings) {
  try {
    localStorage.setItem(KEY, JSON.stringify(s));
  } catch {
    /* ignore */
  }
  return fakeRequest(s, 0);
}
