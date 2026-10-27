import { functionsUrl, publishableKey, supabase } from './supabase';
import { listCourses } from './courses';
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
  /** Web pages the answer used ("AI + research" searches the web). */
  links: { url: string; title: string }[];
  /** What the assistant did when asked: a topic added to the weak topics, or a flash card made. */
  acts: { kind: 'weak' | 'card'; title: string }[];
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
 * Threads and answers are written by the server (Edge Function "assistant").
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
  type Row = {
    id: string;
    role: 'user' | 'assistant';
    content: string;
    source_mode: SourceMode;
    sources: { material_id?: string; page?: number; url?: string; title?: string; act?: 'weak' | 'card' }[];
    outside_pdf: boolean;
  };
  const messages = ((data ?? []) as Row[]).map((m) => ({
    id: m.id,
    role: m.role,
    text: m.role === 'assistant' ? clean(m.content) : m.content,
    mode: m.source_mode,
    sources: (m.sources ?? []).filter((x) => x.material_id).map((x) => ({ lesson: lessons.get(x.material_id!) || '', page: x.page ?? null })),
    links: (m.sources ?? []).filter((x) => x.url).map((x) => ({ url: x.url!, title: x.title || x.url! })),
    acts: (m.sources ?? []).filter((x) => x.act).map((x) => ({ kind: x.act!, title: x.title ?? '' })),
    outsidePdf: m.outside_pdf,
  }));
  return { id: thread.id, messages };
}

export type AskError = 'locked' | 'budget' | 'declined' | 'other';

/** A photo of a question for "Soruyu çözdür" (JPEG, base64 without the data: prefix). */
export type QuestionPhoto = { media_type: 'image/jpeg'; data: string };

/** The answer while it is written: the closing "SOURCES: …" line is the server's, not for the student; no ** bold. */
const visible = (text: string) => {
  const at = text.indexOf('SOURCES:');
  return clean(at < 0 ? text.replace(/\n?S(O(U(R(C(E(S)?)?)?)?)?)?$/, '') : text.slice(0, at)).trimEnd();
};

/** No ** bold and no excerpt numbers like "[E1]" or "[E1, E3]" (the server's search labels, not for the student). */
const clean = (text: string) => text.replace(/\*\*/g, '').replace(/ ?\[E\d+(?:\s*,\s*E\d+)*\]/g, '');

/**
 * Asks the assistant (Edge Function "assistant"): it searches the student's lessons, answers only from them
 * (or also from general knowledge in "AI + research"), saves the chat and counts the trial question.
 * The answer arrives piece by piece (onText gets the text so far); the result is the finished message.
 */
export async function askAssistant(
  question: string,
  where: { courseId?: string | null; materialId?: string | null; threadId?: string | null; mode: SourceMode; lang: string; pages?: [number, number]; photo?: QuestionPhoto },
  onText?: (soFar: string) => void,
): Promise<{ threadId: string; message: ChatMessage } | { error: AskError }> {
  const { data: auth } = await supabase.auth.getSession();
  let res: Response;
  try {
    res = await fetch(`${functionsUrl}/assistant`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: publishableKey, Authorization: `Bearer ${auth.session?.access_token ?? ''}` },
      body: JSON.stringify({
        question,
        course_id: where.courseId ?? null,
        material_id: where.materialId ?? null,
        thread_id: where.threadId ?? null,
        mode: where.mode,
        lang: where.lang,
        page_from: where.pages?.[0] ?? null,
        page_to: where.pages?.[1] ?? null,
        image: where.photo ?? null,
      }),
    });
  } catch {
    return { error: 'other' };
  }
  if (!res.ok || !res.body) return { error: res.status === 403 ? 'locked' : res.status === 429 ? 'budget' : 'other' };

  type Event = { t?: string; done?: boolean; error?: string; thread_id?: string; answer?: string; sources?: { lesson: string; page: number | null }[]; links?: { url: string; title: string }[]; acts?: ChatMessage['acts']; outside_pdf?: boolean };
  const reader = res.body.pipeThrough(new TextDecoderStream()).getReader();
  let buffer = '';
  let text = '';
  for (;;) {
    const { value, done } = await reader.read().catch(() => ({ value: undefined, done: true }));
    if (done) break;
    buffer += value;
    let cut: number;
    while ((cut = buffer.indexOf('\n\n')) >= 0) {
      const line = buffer.slice(0, cut);
      buffer = buffer.slice(cut + 2);
      if (!line.startsWith('data: ')) continue;
      const e = JSON.parse(line.slice(6)) as Event;
      if (e.t) {
        text += e.t;
        onText?.(visible(text));
      } else if (e.error) {
        return { error: e.error === 'declined' ? 'declined' : 'other' };
      } else if (e.done) {
        return {
          threadId: e.thread_id!,
          message: { id: crypto.randomUUID(), role: 'assistant', text: e.answer ? clean(e.answer) : visible(text), mode: where.mode, sources: e.sources ?? [], links: e.links ?? [], acts: e.acts ?? [], outsidePdf: !!e.outside_pdf },
        };
      }
    }
  }
  return { error: 'other' };
}

/** A photo as a small JPEG for the assistant (longest side 1600 px). */
export async function photoForAssistant(file: File): Promise<QuestionPhoto> {
  const img = await createImageBitmap(file, { imageOrientation: 'from-image' });
  const scale = Math.min(1, 1600 / Math.max(img.width, img.height));
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(img.width * scale);
  canvas.height = Math.round(img.height * scale);
  canvas.getContext('2d')!.drawImage(img, 0, 0, canvas.width, canvas.height);
  img.close();
  return { media_type: 'image/jpeg', data: canvas.toDataURL('image/jpeg', 0.85).split(',')[1] };
}

/** "Önemli ve zayıf konularımı anlat": the student's weak topics (from quiz results) in a course, or in all. */
export async function weakTopicsOf(courseId: string | null): Promise<string[]> {
  type Row = { material_topics: { title: string; materials: { course_id: string | null } } };
  const { data, error } = await supabase
    .from('topic_progress')
    .select('material_topics(title, materials(course_id))')
    .eq('state', 'weak')
    .order('mastery')
    .limit(20)
    .returns<Row[]>();
  if (error) console.error('weakTopicsOf', error);
  return [...new Set((data ?? []).filter((r) => !courseId || r.material_topics.materials.course_id === courseId).map((r) => r.material_topics.title))].slice(0, 6);
}
