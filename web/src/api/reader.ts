import { supabase } from './supabase';
import { currentUser } from './auth';
import type { Lang } from '../i18n/I18nProvider';
import type { ReaderDoc, ReaderTerm } from './types';

export type TranslationStyle = 'literal' | 'natural';

export type Lesson = {
  /** null: the reading page is not made yet (the server makes it from the PDF). */
  doc: ReaderDoc | null;
  /** Hard words by term key. */
  terms: Record<string, ReaderTerm>;
  pagesRead: number[];
  lastPage: number;
  percent: number;
  /** Sentences the student highlighted. */
  highlights: string[];
};

/** Everything the reader needs for one lesson (RLS: only the student's own rows). */
export async function getLesson(materialId: string): Promise<Lesson> {
  const [content, terms, progress, notes] = await Promise.all([
    supabase.from('material_content').select('reader_doc').eq('material_id', materialId).maybeSingle<{ reader_doc: ReaderDoc }>(),
    supabase.from('material_terms').select('id, term_key, surface, page, explanation').eq('material_id', materialId),
    supabase
      .from('reading_progress')
      .select('pages_read, last_page, percent_read')
      .eq('material_id', materialId)
      .maybeSingle<{ pages_read: number[]; last_page: number; percent_read: number }>(),
    supabase.from('annotations').select('anchor').eq('material_id', materialId).eq('kind', 'highlight'),
  ]);
  for (const r of [content, terms, progress, notes]) if (r.error) console.error('getLesson', r.error);
  return {
    doc: content.data?.reader_doc ?? null,
    terms: Object.fromEntries(
      (terms.data ?? []).map((t) => [t.term_key, { id: t.id, surface: t.surface, page: t.page, explanation: t.explanation } as ReaderTerm]),
    ),
    pagesRead: progress.data?.pages_read ?? [],
    lastPage: progress.data?.last_page ?? 1,
    percent: progress.data?.percent_read ?? 0,
    highlights: (notes.data ?? []).map((n) => (n.anchor as { text?: string }).text ?? '').filter(Boolean),
  };
}

/** Marks pages as read; returns the new percent. */
export async function markRead(materialId: string, already: number[], pages: number[], pageCount: number) {
  const user = currentUser();
  if (!user) return null;
  const all = [...new Set([...already, ...pages])].sort((a, b) => a - b);
  const percent = pageCount ? Math.min(100, Math.round((all.length / pageCount) * 100)) : 0;
  const { error } = await supabase.from('reading_progress').upsert({
    user_id: user.id,
    material_id: materialId,
    pages_read: all,
    last_page: Math.max(...pages),
    percent_read: percent,
    finished_at: percent === 100 ? new Date().toISOString() : null,
  });
  if (error) console.error('markRead', error);
  return { pagesRead: all, percent };
}

/** Saves a reading session (the stopwatch). Shorter than a minute is not saved. */
export async function saveStudyTime(courseId: string, materialId: string, seconds: number) {
  const user = currentUser();
  if (!user || seconds < 60) return;
  const ended = new Date();
  const started = new Date(ended.getTime() - seconds * 1000);
  const { error } = await supabase.from('study_sessions').insert({
    user_id: user.id,
    course_id: courseId,
    material_id: materialId,
    activity: 'read',
    started_at: started.toISOString(),
    ended_at: ended.toISOString(),
  });
  if (error) console.error('saveStudyTime', error);
}

export async function addHighlight(materialId: string, page: number, text: string) {
  const user = currentUser();
  if (!user) return;
  const { error } = await supabase.from('annotations').insert({ user_id: user.id, material_id: materialId, page, kind: 'highlight', anchor: { text } });
  if (error) console.error('addHighlight', error);
}

/** Counts a tap on a hard word (for "most tapped words" in the exam center). */
export function tapTerm(termId: string) {
  supabase.rpc('tap_term', { p_term_id: termId }).then(({ error }) => error && console.error('tap_term', error));
}

async function sha256(text: string) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * A saved translation of a sentence (table translations). Returns null when there is none yet:
 * new translations are made by the Edge Function "translate" (not built yet).
 */
export async function translate(materialId: string, text: string, lang: Lang, style: TranslationStyle): Promise<string | null> {
  const { data, error } = await supabase
    .from('translations')
    .select('text')
    .eq('material_id', materialId)
    .eq('source_hash', await sha256(text))
    .eq('target_lang', lang)
    .eq('style', style)
    .maybeSingle<{ text: string }>();
  if (error) console.error('translate', error);
  return data?.text ?? null;
}
