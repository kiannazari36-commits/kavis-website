import type { CourseColor } from '../api/types';

// Course palette from design/DeskApp.dc.html (bar, icon tile) and NewCourses.dc.html (folder header).
export const COURSE_COLOR: Record<CourseColor, { main: string; soft: string; fg: string }> = {
  red: { main: 'var(--pri)', soft: 'var(--pri-soft)', fg: 'var(--pri-t)' },
  amb: { main: 'var(--amb)', soft: 'var(--amb-soft)', fg: 'var(--amb-t)' },
  vio: { main: 'var(--vio)', soft: 'var(--vio-soft)', fg: 'var(--vio)' },
  grn: { main: 'var(--good)', soft: 'var(--good-soft)', fg: 'var(--good)' },
  teal: { main: '#2F8C95', soft: 'var(--teal-soft)', fg: 'var(--teal-fg)' },
};
