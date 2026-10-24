import { supabase } from './supabase';
import { currentUser } from './auth';

// Uploading a lecture PDF: the browser checks it, the file goes to the private "materials" bucket
// (<user id>/<lesson id>/original.pdf), the lesson row is created (only while the trial or Premium allows it,
// checked by the database), and the server prepares the reading page (Edge Function process-material).

export const MAX_PAGES = 100;

export type PdfInfo = { pages: number; hasText: boolean; sizeMb: number };

/** Reads the PDF in the browser: page count and whether it has selectable text (scanned pages have none). */
export async function inspectPdf(file: File): Promise<PdfInfo> {
  const { extractText, getDocumentProxy } = await import('unpdf');
  const pdf = await getDocumentProxy(new Uint8Array(await file.arrayBuffer()));
  const { totalPages, text } = await extractText(pdf, { mergePages: false });
  const chars = text.reduce((a, t) => a + t.replace(/\s/g, '').length, 0);
  return { pages: totalPages, hasText: chars >= 20 * Math.min(totalPages, 5), sizeMb: Math.round((file.size / 1048576) * 10) / 10 };
}

export class UploadFail extends Error {
  reason: 'trial' | 'network';
  constructor(reason: 'trial' | 'network') {
    super(reason);
    this.reason = reason;
  }
}

/** Creates the lesson and uploads the file; returns the lesson id. Then asks the server to prepare it. */
export async function uploadLesson(file: File, title: string, courseId: string | null): Promise<string> {
  const user = currentUser();
  if (!user) throw new UploadFail('network');
  const id = crypto.randomUUID();
  const path = `${user.id}/${id}/original.pdf`;

  const row = await supabase.from('materials').insert({ id, user_id: user.id, course_id: courseId, kind: 'pdf', title: title.trim() });
  // The insert policy refuses it when the trial is over or its 2 lessons are used.
  if (row.error) throw new UploadFail(row.error.code === '42501' ? 'trial' : 'network');

  const up = await supabase.storage.from('materials').upload(path, file, { contentType: 'application/pdf', upsert: false });
  if (up.error) {
    console.error('upload', up.error);
    throw new UploadFail('network');
  }
  const f = await supabase
    .from('material_files')
    .insert({ material_id: id, user_id: user.id, storage_path: path, mime_type: 'application/pdf', size_bytes: file.size });
  if (f.error) console.error('material_files', f.error);

  supabase.functions.invoke('process-material', { body: { material_id: id } }).then(({ error }) => error && console.error('process-material', error));
  return id;
}

export type LessonStatus = { status: 'uploaded' | 'processing' | 'ready' | 'needs_ocr' | 'too_long' | 'failed'; pages: number | null; courseId: string | null; stats: Record<string, number> };

/** Where the server is with a lesson (polled by the processing screen). */
export async function lessonStatus(id: string): Promise<LessonStatus | null> {
  const { data } = await supabase.from('materials').select('status, page_count, course_id, material_content(stats)').eq('id', id).maybeSingle();
  if (!data) return null;
  const content = data.material_content as unknown as { stats: Record<string, number> } | { stats: Record<string, number> }[] | null;
  const stats = (Array.isArray(content) ? content[0]?.stats : content?.stats) ?? {};
  return { status: data.status, pages: data.page_count, courseId: data.course_id, stats };
}
