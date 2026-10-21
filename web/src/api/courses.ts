import { fakeRequest } from './client';
import { COURSES } from './mock/courses';
import type { Course, Pdf } from './types';

export function listCourses(): Promise<Course[]> {
  return fakeRequest(COURSES, 150);
}

export function getCourse(id: string): Promise<Course | null> {
  return fakeRequest(COURSES.find((c) => c.id === id) ?? null, 150);
}

export function getPdf(courseId: string, pdfId: string): Promise<{ course: Course; pdf: Pdf } | null> {
  const course = COURSES.find((c) => c.id === courseId);
  const pdf = course?.pdfs.find((p) => p.id === pdfId);
  return fakeRequest(course && pdf ? { course, pdf } : null, 150);
}

/** Totals used on a course card and folder header. */
export function courseStats(c: Course) {
  const minutes = c.pdfs.reduce((a, p) => a + p.minutes, 0);
  const pages = c.pdfs.reduce((a, p) => a + p.pages, 0);
  const readPages = c.pdfs.reduce((a, p) => a + (p.pages * p.read) / 100, 0);
  return { minutes, pages, pct: pages ? Math.round((readPages / pages) * 100) : 0 };
}
