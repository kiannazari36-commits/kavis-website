import { supabase } from './supabase';
import { currentUser } from './auth';
import { courseContentLangs } from './courses';
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
  /** Default reading paper and text size in the reader. */
  readerPaper: 'light' | 'sepia' | 'dark';
  readerFontSize: number;
  translationStyle: 'literal' | 'natural';
  browserNotifications: boolean;
  sync: boolean;
  cheerNotifications: boolean;
  offlineMode: boolean;
  autoDownload: boolean;
  /** Study / review reminder time, "09:00" (also the start of today's plan on home). */
  notifyTime: string;
};

const KEY = 'kavis.settings';
export const DEFAULT_SETTINGS: Settings = {
  contentLang: 'pdf',
  courseContentLang: {},
  planMode: 'aim',
  studyDays: 4,
  studyHours: 1.5,
  readerPaper: 'sepia',
  readerFontSize: 20,
  translationStyle: 'natural',
  browserNotifications: true,
  sync: true,
  cheerNotifications: true,
  offlineMode: false,
  autoDownload: true,
  notifyTime: '09:00',
};

// Settings live in the account (table user_settings, one row per student). The browser keeps a copy so the
// first screen opens with the right reader paper / text size before the server answers.
// The per-course content language is courses.content_lang_override (see setCourseContentLangOnServer).

type Row = {
  content_lang: ContentLangChoice;
  plan_mode: Settings['planMode'];
  study_days: number;
  study_hours: number;
  reader_paper: Settings['readerPaper'];
  reader_font_size: number;
  translation_style: Settings['translationStyle'];
  push_notifications: boolean;
  sync: boolean;
  cheer_notifications: boolean;
  offline_mode: boolean;
  auto_download: boolean;
  notify_time: string;
};
const COLUMNS =
  'content_lang, plan_mode, study_days, study_hours, reader_paper, reader_font_size, translation_style, push_notifications, sync, cheer_notifications, offline_mode, auto_download, notify_time';

const fromRow = (r: Row, courseContentLang: Record<string, ContentLangChoice>): Settings => ({
  contentLang: r.content_lang,
  courseContentLang,
  planMode: r.plan_mode,
  studyDays: r.study_days,
  studyHours: Number(r.study_hours),
  readerPaper: r.reader_paper,
  readerFontSize: r.reader_font_size,
  translationStyle: r.translation_style,
  browserNotifications: r.push_notifications,
  sync: r.sync,
  cheerNotifications: r.cheer_notifications,
  offlineMode: r.offline_mode,
  autoDownload: r.auto_download,
  notifyTime: r.notify_time.slice(0, 5),
});

const toRow = (s: Settings): Row => ({
  content_lang: s.contentLang,
  plan_mode: s.planMode,
  study_days: s.studyDays,
  study_hours: s.studyHours,
  reader_paper: s.readerPaper,
  reader_font_size: s.readerFontSize,
  translation_style: s.translationStyle,
  push_notifications: s.browserNotifications,
  sync: s.sync,
  cheer_notifications: s.cheerNotifications,
  offline_mode: s.offlineMode,
  auto_download: s.autoDownload,
  notify_time: s.notifyTime,
});

function cache(s: Settings) {
  try {
    localStorage.setItem(KEY, JSON.stringify(s));
  } catch {
    /* ignore */
  }
}

/** The browser copy (instant, may be old). */
export function loadSettingsNow(): Settings {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return { ...DEFAULT_SETTINGS, ...(JSON.parse(raw) as Partial<Settings>) };
  } catch {
    /* ignore */
  }
  return DEFAULT_SETTINGS;
}

/** The account's settings from the server, or null when signed out / offline. */
export async function fetchSettings(): Promise<Settings | null> {
  const user = currentUser();
  if (!user) return null;
  const [{ data, error }, overrides] = await Promise.all([
    supabase.from('user_settings').select(COLUMNS).eq('user_id', user.id).single<Row>(),
    courseContentLangs().catch(() => ({})),
  ]);
  if (error) {
    console.error('fetchSettings', error);
    return null;
  }
  const s = fromRow(data, overrides);
  cache(s);
  return s;
}

export async function saveSettings(s: Settings) {
  cache(s);
  const user = currentUser();
  if (!user) return s;
  const { error } = await supabase.from('user_settings').update(toRow(s)).eq('user_id', user.id);
  if (error) console.error('saveSettings', error);
  return s;
}
