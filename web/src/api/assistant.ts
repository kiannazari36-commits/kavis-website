import { fakeRequest } from './client';
import { supabase } from './supabase';
import { listCourses } from './courses';
import { SAMPLE_ATTACHMENTS } from './mock/assistant';
import type { Attachment, AttachmentKind } from './types';
import { COURSE_COLOR } from '../components/courseColors';

export type SourceMode = 'pdf' | 'ai';

/** What the assistant answers about: one course, or "all" my courses. */
export type AssistantTopic = { id: string; courseId: string | null; name: string; sub: string; color: string };

export type ChatMessage = {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  mode: SourceMode;
  /** "Hipertansiyon · s. 13" — lessons and pages the answer came from. */
  sources: { lesson: string; page: number | null }[];
  outsidePdf: boolean;
};

/** "all" first, then the student's courses with their first lessons. */
export async function listAssistantTopics(allName: string, allSub: string): Promise<AssistantTopic[]> {
  const courses = await listCourses();
  return [
    ...courses.map((c) => ({
      id: c.id,
      courseId: c.id,
      name: c.short ?? c.name,
      sub: c.pdfs.slice(0, 2).map((p) => p.title).join(' · '),
      color: COURSE_COLOR[c.color].main,
    })),
    { id: 'all', courseId: null, name: allName, sub: allSub, color: 'var(--amb)' },
  ];
}

/**
 * The latest conversation about a course, all courses (null) or one lesson, oldest message first.
 * Threads and answers are written by the server (Edge Function "assistant", not built yet).
 */
export async function latestThread(courseId: string | null, materialId?: string): Promise<{ id: string | null; messages: ChatMessage[] }> {
  let q = supabase.from('assistant_threads').select('id').order('updated_at', { ascending: false }).limit(1);
  if (materialId) q = q.eq('material_id', materialId);
  else q = courseId ? q.eq('course_id', courseId) : q.is('course_id', null);
  const { data: thread, error } = await q.maybeSingle<{ id: string }>();
  if (error) console.error('assistant_threads', error);
  if (!thread) return { id: null, messages: [] };
  const [{ data, error: e2 }, courses] = await Promise.all([
    supabase.from('assistant_messages').select('id, role, content, source_mode, sources, outside_pdf').eq('thread_id', thread.id).order('created_at'),
    listCourses(),
  ]);
  if (e2) console.error('assistant_messages', e2);
  const lessons = new Map(courses.flatMap((c) => c.pdfs.map((p) => [p.id, p.title] as const)));
  type Row = { id: string; role: 'user' | 'assistant'; content: string; source_mode: SourceMode; sources: { material_id?: string; page?: number }[]; outside_pdf: boolean };
  const messages = ((data ?? []) as Row[]).map((m) => ({
    id: m.id,
    role: m.role,
    text: m.content,
    mode: m.source_mode,
    sources: (m.sources ?? []).map((x) => ({ lesson: (x.material_id && lessons.get(x.material_id)) || '', page: x.page ?? null })),
    outsidePdf: m.outside_pdf,
  }));
  return { id: thread.id, messages };
}

export type AskError = 'locked' | 'budget' | 'declined' | 'other';

/**
 * Asks the assistant (Edge Function "assistant"): it searches the student's lessons, answers only from them
 * (or also from general knowledge in "AI + research"), saves the chat and counts the trial question.
 */
export async function askAssistant(
  question: string,
  where: { courseId?: string | null; materialId?: string | null; threadId?: string | null; mode: SourceMode; lang: string },
): Promise<{ threadId: string; message: ChatMessage } | { error: AskError }> {
  const { data, error } = await supabase.functions.invoke('assistant', {
    body: { question, course_id: where.courseId ?? null, material_id: where.materialId ?? null, thread_id: where.threadId ?? null, mode: where.mode, lang: where.lang },
  });
  if (error) {
    const status = (error as { context?: { status?: number } }).context?.status;
    return { error: status === 403 ? 'locked' : status === 429 ? 'budget' : status === 422 ? 'declined' : 'other' };
  }
  const r = data as { thread_id: string; answer: string; sources: { lesson: string; page: number | null }[]; outside_pdf: boolean };
  return {
    threadId: r.thread_id,
    message: { id: crypto.randomUUID(), role: 'assistant', text: r.answer, mode: where.mode, sources: r.sources, outsidePdf: r.outside_pdf },
  };
}

/** Uploads a file; the server guesses which course it belongs to. Not connected yet (sample answer). */
export function uploadForAssistant(kind: AttachmentKind): Promise<Attachment> {
  return fakeRequest(SAMPLE_ATTACHMENTS[kind], 300);
}
