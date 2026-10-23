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
export async function latestThread(courseId: string | null, materialId?: string): Promise<ChatMessage[]> {
  let q = supabase.from('assistant_threads').select('id').order('updated_at', { ascending: false }).limit(1);
  if (materialId) q = q.eq('material_id', materialId);
  else q = courseId ? q.eq('course_id', courseId) : q.is('course_id', null);
  const { data: thread, error } = await q.maybeSingle<{ id: string }>();
  if (error) console.error('assistant_threads', error);
  if (!thread) return [];
  const [{ data, error: e2 }, courses] = await Promise.all([
    supabase.from('assistant_messages').select('id, role, content, source_mode, sources, outside_pdf').eq('thread_id', thread.id).order('created_at'),
    listCourses(),
  ]);
  if (e2) console.error('assistant_messages', e2);
  const lessons = new Map(courses.flatMap((c) => c.pdfs.map((p) => [p.id, p.title] as const)));
  type Row = { id: string; role: 'user' | 'assistant'; content: string; source_mode: SourceMode; sources: { material_id?: string; page?: number }[]; outside_pdf: boolean };
  return ((data ?? []) as Row[]).map((m) => ({
    id: m.id,
    role: m.role,
    text: m.content,
    mode: m.source_mode,
    sources: (m.sources ?? []).map((x) => ({ lesson: (x.material_id && lessons.get(x.material_id)) || '', page: x.page ?? null })),
    outsidePdf: m.outside_pdf,
  }));
}

/** Uploads a file; the server guesses which course it belongs to. Not connected yet (sample answer). */
export function uploadForAssistant(kind: AttachmentKind): Promise<Attachment> {
  return fakeRequest(SAMPLE_ATTACHMENTS[kind], 300);
}
