import { supabase } from './supabase';
import { currentUser } from './auth';
import { MAX_MB } from './upload';
import type { Segment } from '../speech/transcribe';

// Lecture recordings (CLAUDE.md): the browser turns the sound into text (speech/transcribe.ts); only the text goes to
// the server (Edge Function process-recording), which matches it to the PDF lesson's pages and finds what the
// lecturer stressed. The sound file is kept in the student's private folder when it fits (50 MB), for listening.

/** Sound types the storage accepts (supabase migration: bucket "materials"). */
const STORABLE = ['audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/mpeg', 'audio/wav', 'audio/aac'];

export type LessonPick = { id: string; title: string; courseId: string | null; courseName: string; language: string | null };

/** Ready lessons a recording can belong to. */
export async function lessonsForRecording(): Promise<LessonPick[]> {
  const { data, error } = await supabase
    .from('materials')
    .select('id, title, course_id, language, courses(name)')
    .in('kind', ['pdf', 'photo'])
    .eq('status', 'ready')
    .order('created_at', { ascending: false });
  if (error) console.error('lessonsForRecording', error);
  return (data ?? []).map((m) => ({
    id: m.id,
    title: m.title,
    courseId: m.course_id,
    courseName: (m.courses as unknown as { name: string } | null)?.name ?? '',
    language: m.language,
  }));
}

/**
 * Saves the recording: the sound (when it fits) and the recording lesson, then sends the text to the server.
 * Returns the recording's id. Recordings do not use a trial lesson.
 */
export async function addRecording(sound: Blob | null, lesson: LessonPick, title: string, segments: Segment[], seconds: number): Promise<string> {
  const user = currentUser();
  if (!user) throw new Error('not signed in');
  const id = crypto.randomUUID();
  const type = sound?.type.split(';')[0] ?? '';
  const keep = !!sound && STORABLE.includes(type) && sound.size <= MAX_MB * 1048576;
  const path = `${user.id}/${id}/recording.${type === 'audio/mpeg' ? 'mp3' : type === 'audio/wav' ? 'wav' : 'm4a'}`;
  if (keep) {
    const up = await supabase.storage.from('materials').upload(path, sound!, { contentType: type, upsert: false });
    if (up.error) throw up.error;
  }
  const row = await supabase.from('materials').insert({ id, user_id: user.id, course_id: lesson.courseId, linked_material_id: lesson.id, kind: 'audio', title: title.trim() });
  if (row.error) {
    if (keep) await supabase.storage.from('materials').remove([path]);
    throw row.error;
  }
  if (keep) {
    const f = await supabase.from('material_files').insert({ material_id: id, user_id: user.id, storage_path: path, mime_type: type, size_bytes: sound!.size });
    if (f.error) console.error('material_files', f.error);
  }
  const { error } = await supabase.functions.invoke('process-recording', { body: { material_id: id, segments, duration: seconds } });
  if (error) console.error('process-recording', error);
  return id;
}

export type LecturePart = { start: number; end: number; page: number; topic_id: string | null };
export type LectureTopic = { topic_id: string; title: string; minutes: number; repeats: number; said_exam: boolean };
export type LectureQuote = { at: number; kind: 'exam' | 'stress'; text: string; topic_id: string | null };
export type Recording = {
  id: string;
  title: string;
  status: string;
  seconds: number;
  pdf: { id: string; title: string; courseId: string | null } | null;
  /** Signed link to the sound for 1 hour, or null when only the text was kept. */
  audioUrl: string | null;
  segments: Segment[];
  parts: LecturePart[];
  topics: LectureTopic[];
  quotes: LectureQuote[];
};

export async function getRecording(id: string): Promise<Recording | null> {
  const { data: m, error } = await supabase
    .from('materials')
    .select('id, title, status, duration_sec, linked_material_id, material_files(storage_path), material_content(lecture)')
    .eq('id', id)
    .maybeSingle();
  if (error) console.error('getRecording', error);
  if (!m) return null;
  const content = m.material_content as unknown as { lecture: Record<string, unknown> | null } | { lecture: Record<string, unknown> | null }[] | null;
  const lecture = ((Array.isArray(content) ? content[0]?.lecture : content?.lecture) ?? {}) as {
    segments?: Segment[];
    parts?: LecturePart[];
    topics?: LectureTopic[];
    quotes?: LectureQuote[];
  };
  const files = (m.material_files as unknown as { storage_path: string }[]) ?? [];
  const link = files[0] ? (await supabase.storage.from('materials').createSignedUrl(files[0].storage_path, 3600)).data?.signedUrl ?? null : null;
  const { data: pdf } = m.linked_material_id
    ? await supabase.from('materials').select('id, title, course_id').eq('id', m.linked_material_id).maybeSingle()
    : { data: null };
  return {
    id: m.id,
    title: m.title,
    status: m.status,
    seconds: m.duration_sec ?? 0,
    pdf: pdf ? { id: pdf.id, title: pdf.title, courseId: pdf.course_id } : null,
    audioUrl: link,
    segments: lecture.segments ?? [],
    parts: lecture.parts ?? [],
    topics: [...(lecture.topics ?? [])].sort((a, b) => b.minutes - a.minutes),
    quotes: lecture.quotes ?? [],
  };
}

/** Recordings made for a lesson (newest first), for the link in the reader and the course page. */
export async function recordingsOf(pdfId: string) {
  const { data, error } = await supabase
    .from('materials')
    .select('id, title, status, duration_sec')
    .eq('kind', 'audio')
    .eq('linked_material_id', pdfId)
    .order('created_at', { ascending: false });
  if (error) console.error('recordingsOf', error);
  return (data ?? []).map((r) => ({ id: r.id, title: r.title, status: r.status, seconds: r.duration_sec ?? 0 }));
}
