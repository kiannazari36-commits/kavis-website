import { supabase } from './supabase';
import type { Course, CourseColor, ExamKind, Pdf } from './types';
import type { Lang } from '../i18n/I18nProvider';
import type { ContentLangChoice } from './settings';

type CourseRow = {
  id: string;
  name: string;
  short_name: string | null;
  color: CourseColor;
  language: Lang | null;
  content_lang_override: ContentLangChoice | null;
  course_exams: { kind: ExamKind; exam_date: string }[];
  materials: {
    id: string;
    title: string;
    kind: string;
    parent_id: string | null;
    page_count: number | null;
    reading_progress: { percent_read: number; updated_at: string }[];
  }[];
};

/** The student's courses with their lessons, reading progress, minutes studied and next exam (RLS: own rows only). */
async function load(): Promise<{ courses: Course[]; overrides: Record<string, ContentLangChoice> }> {
  const [courses, sessions] = await Promise.all([
    supabase
      .from('courses')
      .select(
        'id, name, short_name, color, language, content_lang_override, course_exams(kind, exam_date), materials(id, title, kind, parent_id, page_count, reading_progress(percent_read, updated_at))',
      )
      .is('archived_at', null)
      .order('sort_order')
      .order('created_at', { referencedTable: 'materials' })
      .returns<CourseRow[]>(),
    supabase.from('study_sessions').select('material_id, minutes'),
  ]);
  if (courses.error) throw courses.error;
  if (sessions.error) throw sessions.error;

  const minutes = new Map<string, number>();
  for (const r of sessions.data) if (r.material_id) minutes.set(r.material_id, (minutes.get(r.material_id) ?? 0) + Number(r.minutes));

  const today = isoToday();
  const overrides: Record<string, ContentLangChoice> = {};
  const list = courses.data.map((c): Course => {
    if (c.content_lang_override) overrides[c.id] = c.content_lang_override;
    const next = c.course_exams.filter((e) => e.exam_date >= today).sort((a, b) => a.exam_date.localeCompare(b.exam_date))[0];
    const pdfs = c.materials
      .filter((m) => m.parent_id === null && (m.kind === 'pdf' || m.kind === 'photo'))
      .map(
        (m): Pdf => ({
          id: m.id,
          title: m.title,
          pages: m.page_count ?? 0,
          read: m.reading_progress[0]?.percent_read ?? 0,
          minutes: Math.round(minutes.get(m.id) ?? 0),
          lastRead: m.reading_progress[0]?.updated_at,
        }),
      );
    return {
      id: c.id,
      name: c.name,
      short: c.short_name ?? undefined,
      color: c.color,
      language: c.language ?? 'tr',
      examDate: next?.exam_date,
      examKind: next?.kind,
      pdfs,
    };
  });
  return { courses: list, overrides };
}

export async function listCourses(): Promise<Course[]> {
  try {
    return (await load()).courses;
  } catch (e) {
    console.error('listCourses', e);
    return [];
  }
}

/** Per-course content-language choices (courses.content_lang_override), for the settings. */
export async function courseContentLangs(): Promise<Record<string, ContentLangChoice>> {
  return (await load()).overrides;
}

export async function setCourseContentLangOnServer(courseId: string, c: ContentLangChoice | null) {
  const { error } = await supabase.from('courses').update({ content_lang_override: c }).eq('id', courseId);
  if (error) console.error('setCourseContentLang', error);
}

export async function getCourse(id: string): Promise<Course | null> {
  return (await listCourses()).find((c) => c.id === id) ?? null;
}

export async function getPdf(courseId: string, pdfId: string): Promise<{ course: Course; pdf: Pdf } | null> {
  const course = await getCourse(courseId);
  const pdf = course?.pdfs.find((p) => p.id === pdfId);
  return course && pdf ? { course, pdf } : null;
}

/** Lessons read most recently (for "continue" on home). */
export async function recentPdfs(n: number): Promise<{ course: Course; pdf: Pdf }[]> {
  const all = (await listCourses()).flatMap((course) => course.pdfs.map((pdf) => ({ course, pdf })));
  return all
    .filter((x) => x.pdf.lastRead && x.pdf.read < 100)
    .sort((a, b) => b.pdf.lastRead!.localeCompare(a.pdf.lastRead!))
    .slice(0, n);
}

/** Totals used on a course card and folder header. */
export function courseStats(c: Course) {
  const minutes = c.pdfs.reduce((a, p) => a + p.minutes, 0);
  const pages = c.pdfs.reduce((a, p) => a + p.pages, 0);
  const readPages = c.pdfs.reduce((a, p) => a + (p.pages * p.read) / 100, 0);
  return { minutes, pages, pct: pages ? Math.round((readPages / pages) * 100) : 0 };
}

/** Today as YYYY-MM-DD in the student's local time. */
export function isoToday() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function daysUntil(iso: string, today = isoToday()) {
  return Math.round((Date.parse(iso) - Date.parse(today)) / 86_400_000);
}
