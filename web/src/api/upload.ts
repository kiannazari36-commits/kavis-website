import { normalizeImage } from './heic';
import { supabase } from './supabase';
import { currentUser } from './auth';

// Uploading a lecture PDF: the browser checks it, the file goes to the private "materials" bucket
// (<user id>/<lesson id>/original.pdf), the lesson row is created (only while the trial or Premium allows it,
// checked by the database), and the server prepares the reading page (Edge Function process-material).

export const MAX_PAGES = 100;
/** Largest file the storage accepts (Supabase free plan: 50 MB per file). */
export const MAX_MB = 50;

export type PdfInfo = { pages: number; hasText: boolean; sizeMb: number };

/** Reads the PDF in the browser: page count and whether it has selectable text (scanned pages have none). */
export async function inspectPdf(file: File): Promise<PdfInfo> {
  const { extractText, getDocumentProxy } = await import('unpdf');
  const pdf = await getDocumentProxy(new Uint8Array(await file.arrayBuffer()));
  const { totalPages, text } = await extractText(pdf, { mergePages: false });
  const chars = text.reduce((a, t) => a + t.replace(/\s/g, '').length, 0);
  return { pages: totalPages, hasText: chars >= 20 * Math.min(totalPages, 5), sizeMb: Math.max(0.1, Math.round((file.size / 1048576) * 10) / 10) };
}

/** How many lessons a long PDF becomes: parts of at most MAX_PAGES pages. */
export const partsFor = (pages: number) => Math.ceil(pages / MAX_PAGES);

/**
 * A PDF longer than MAX_PAGES is cut in the browser into equal parts (each at most MAX_PAGES pages), every part a
 * PDF of its own with the teacher's pages unchanged; each part becomes its own lesson.
 */
export async function splitPdf(file: File): Promise<File[]> {
  const { PDFDocument } = await import('pdf-lib');
  const src = await PDFDocument.load(await file.arrayBuffer(), { ignoreEncryption: true });
  const total = src.getPageCount();
  const k = partsFor(total);
  const size = Math.ceil(total / k);
  const parts: File[] = [];
  for (let i = 0; i < k; i++) {
    const doc = await PDFDocument.create();
    const pages = await doc.copyPages(src, Array.from({ length: Math.min(size, total - i * size) }, (_, j) => i * size + j));
    pages.forEach((p) => doc.addPage(p));
    const bytes = await doc.save();
    parts.push(new File([bytes], file.name.replace(/\.pdf$/i, '') + `-${i + 1}.pdf`, { type: 'application/pdf' }));
  }
  return parts;
}

export class UploadFail extends Error {
  reason: 'trial' | 'network' | 'tooBig';
  constructor(reason: 'trial' | 'network' | 'tooBig') {
    super(reason);
    this.reason = reason;
  }
}

/**
 * Uploads the file, then creates the lesson; returns the lesson id. Then asks the server to prepare it.
 * The file goes first: a failed upload must not use up a trial lesson (the lesson row counts it).
 */
export async function uploadLesson(file: File, title: string, courseId: string | null, ocr = false): Promise<string> {
  const user = currentUser();
  if (!user) throw new UploadFail('network');
  if (file.size > MAX_MB * 1048576) throw new UploadFail('tooBig');
  const id = crypto.randomUUID();
  const path = `${user.id}/${id}/original.pdf`;

  const up = await supabase.storage.from('materials').upload(path, file, { contentType: 'application/pdf', upsert: false });
  if (up.error) {
    console.error('upload', up.error);
    throw new UploadFail('network');
  }

  const row = await supabase.from('materials').insert({ id, user_id: user.id, course_id: courseId, kind: 'pdf', title: title.trim() });
  if (row.error) {
    // Refused (trial over or its 2 lessons used): remove the file again.
    await supabase.storage.from('materials').remove([path]);
    throw new UploadFail(row.error.code === '42501' ? 'trial' : 'network');
  }
  const f = await supabase
    .from('material_files')
    .insert({ material_id: id, user_id: user.id, storage_path: path, mime_type: 'application/pdf', size_bytes: file.size });
  if (f.error) console.error('material_files', f.error);

  supabase.functions.invoke('process-material', { body: { material_id: id, ocr } }).then(({ error }) => error && console.error('process-material', error));
  return id;
}

/** Photos of one lesson at most (each photo is one page). */
export const MAX_PHOTOS = 30;
const PHOTO_SIDE = 2000;

/**
 * A photo made ready for text recognition: turned upright, at most 2000 px on its long side, saved as JPEG
 * (HEIC from iPhones is turned into JPEG first, see heic.ts; a file the browser cannot read throws → the page shows a message).
 */
export async function shrinkPhoto(file: File): Promise<Blob> {
  const img = await createImageBitmap(await normalizeImage(file), { imageOrientation: 'from-image' });
  const scale = Math.min(1, PHOTO_SIDE / Math.max(img.width, img.height));
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(img.width * scale);
  canvas.height = Math.round(img.height * scale);
  canvas.getContext('2d')!.drawImage(img, 0, 0, canvas.width, canvas.height);
  img.close();
  return new Promise((ok, fail) => canvas.toBlob((b) => (b ? ok(b) : fail(new Error('jpeg'))), 'image/jpeg', 0.85));
}

/**
 * Photos of pages (slides, notes, handwriting) as one lesson: the pages go up first, in the chosen order, then the
 * lesson; the server reads them with text recognition (process-material).
 */
export async function uploadPhotos(photos: Blob[], title: string, courseId: string | null): Promise<string> {
  const user = currentUser();
  if (!user) throw new UploadFail('network');
  const id = crypto.randomUUID();
  const paths = photos.map((_, i) => `${user.id}/${id}/page-${String(i + 1).padStart(3, '0')}.jpg`);
  for (const [i, photo] of photos.entries()) {
    const up = await supabase.storage.from('materials').upload(paths[i], photo, { contentType: 'image/jpeg', upsert: false });
    if (up.error) {
      console.error('upload', up.error);
      await supabase.storage.from('materials').remove(paths.slice(0, i));
      throw new UploadFail('network');
    }
  }
  const row = await supabase.from('materials').insert({ id, user_id: user.id, course_id: courseId, kind: 'photo', title: title.trim() });
  if (row.error) {
    await supabase.storage.from('materials').remove(paths);
    throw new UploadFail(row.error.code === '42501' ? 'trial' : 'network');
  }
  const f = await supabase.from('material_files').insert(
    photos.map((p, i) => ({ material_id: id, user_id: user.id, storage_path: paths[i], mime_type: 'image/jpeg', size_bytes: p.size, sort_order: i })),
  );
  if (f.error) console.error('material_files', f.error);
  supabase.functions.invoke('process-material', { body: { material_id: id } }).then(({ error }) => error && console.error('process-material', error));
  return id;
}

/** "Metin tanıma ile dene" for a lesson the server found scanned; 'trial' = no trial lesson left. */
export async function retryWithOcr(id: string): Promise<'ok' | 'trial' | 'failed'> {
  const { error } = await supabase.functions.invoke('process-material', { body: { material_id: id, ocr: true } });
  if (!error) return 'ok';
  const status = (error as { context?: { status?: number } }).context?.status;
  return status === 403 ? 'trial' : 'failed';
}

export type LessonStatus = {
  status: 'uploaded' | 'processing' | 'ready' | 'needs_ocr' | 'too_long' | 'failed';
  pages: number | null;
  courseId: string | null;
  stats: Record<string, number>;
  /** Last change on the server (a "processing" lesson unchanged for long was stopped). */
  updatedAt: string | null;
};

/** Where the server is with a lesson (polled by the processing screen). */
export async function lessonStatus(id: string): Promise<LessonStatus | null> {
  const { data } = await supabase.from('materials').select('status, page_count, course_id, updated_at, material_content(stats)').eq('id', id).maybeSingle();
  if (!data) return null;
  const content = data.material_content as unknown as { stats: Record<string, number> } | { stats: Record<string, number> }[] | null;
  const stats = (Array.isArray(content) ? content[0]?.stats : content?.stats) ?? {};
  return { status: data.status, pages: data.page_count, courseId: data.course_id, stats, updatedAt: data.updated_at };
}

/**
 * Deletes a lesson: the row first (its reading page, words, cards, questions and progress go with it by cascade),
 * then its files in Storage (`<user>/<lesson>/…`), which the database cannot remove itself.
 * The trial lesson count does not come back (CLAUDE.md: 2 lessons per trial).
 */
export async function deleteLesson(materialId: string) {
  const user = currentUser();
  if (!user) return false;
  const { error } = await supabase.from('materials').delete().eq('id', materialId);
  if (error) {
    console.error('deleteLesson', error);
    return false;
  }
  const folder = `${user.id}/${materialId}`;
  const { data: files } = await supabase.storage.from('materials').list(folder);
  if (files?.length) {
    const { error: e2 } = await supabase.storage.from('materials').remove(files.map((f) => `${folder}/${f.name}`));
    if (e2) console.error('deleteLesson files', e2);
  }
  return true;
}

/**
 * Lessons whose preparation was stopped on the server (still "processing" after 5 minutes): asking the server
 * again makes it go on from the last finished part. Called once when the app opens.
 */
export async function resumeStuckLessons() {
  const since = new Date(Date.now() - 5 * 60 * 1000).toISOString();
  const { data, error } = await supabase.from('materials').select('id').eq('status', 'processing').lt('updated_at', since);
  if (error) return console.error('resumeStuckLessons', error);
  for (const m of data ?? []) supabase.functions.invoke('process-material', { body: { material_id: m.id } }).then(({ error: e }) => e && console.error('resume', e));
}
