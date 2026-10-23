import type { Lang } from '../i18n/I18nProvider';

/** A text in all four interface languages. */
export type L10n = Record<Lang, string>;

export type CourseColor = 'red' | 'amb' | 'vio' | 'grn' | 'teal';

export type Pdf = {
  id: string;
  /** The student's own lesson title (not translated). */
  title: string;
  /** Percent read, 0–100. */
  read: number;
  /** Minutes studied. */
  minutes: number;
  pages: number;
  /** Last time the student read it (ISO), for "continue where you left off". */
  lastRead?: string;
};

export type ExamKind = 'midterm' | 'final' | 'makeup' | 'quiz' | 'other';

export type Course = {
  id: string;
  /** The student's own course name (not translated). */
  name: string;
  /** Shorter name for the sidebar. */
  short?: string;
  color: CourseColor;
  /** Language of the course PDFs (the teacher's material). */
  language: Lang;
  /** Next exam of this course (ISO date) and its kind. */
  examDate?: string;
  examKind?: ExamKind;
  /** Rank among classmates (not on the server yet). */
  rank?: number;
  pdfs: Pdf[];
};

/** Part of a paragraph: plain text, or a hard word (term key) that opens an explanation. */
export type Segment = string | { term: string; text: string };

/** Kind of a page block; the label is an app text (src/i18n/reader.json). */
export type ReaderTag = 'definition' | 'dose' | 'side_effect' | 'special' | 'emergency';

export type ReaderBlock = {
  pageFrom: number;
  pageTo: number;
  tag: ReaderTag;
  heading?: string;
  /** A paragraph is a list of segments, or one sentence the student can select. */
  paragraphs: (Segment[] | { selectable: true; text: string })[];
  molecule?: boolean;
  audio?: boolean;
};

export type ReaderSection = { title: string; blocks: ReaderBlock[] };

/** The reading page (material_content.reader_doc). The teacher's text is never changed. */
export type ReaderDoc = { language: string; sections: ReaderSection[] };

/** A hard word of the lesson (material_terms); explanation per app language. */
export type ReaderTerm = {
  id: string;
  surface: string;
  page: number | null;
  explanation: Partial<Record<Lang, { name: string; kind: string; text: string }>>;
};

/** A course (or "all courses") the assistant can answer about. */
export type AssistantTopic = {
  id: string;
  name: L10n;
  sub: L10n;
  color: string;
  /** Course id for "open the course folder", "all" for My Courses, null if none. */
  folder: string | null;
  sample: { q: L10n; a: L10n; src: L10n };
};

export type AttachmentKind = 'pdf' | 'photo' | 'audio';

export type Attachment = {
  tag: L10n;
  name: L10n;
  meta: L10n;
  /** Topic the app guesses the file belongs to. */
  topic: string;
  why: L10n;
};

export type ExamTopic = {
  title: L10n;
  tag: L10n;
  kind: 'weak' | 'imp' | 'base';
  src: L10n;
  points: L10n[];
  teacher?: L10n;
  molecule?: 'captopril';
};

export type QuizQuestion = {
  kind: L10n;
  text: L10n;
  options: L10n[];
  /** Index of the right option. */
  answer: number;
  why: L10n;
  src: L10n;
  hints: L10n[];
  molecule?: 'captopril';
};

/** A flash card, written in its deck's language (the content language). */
export type FlashCard = {
  id: string;
  q: string;
  a: string;
  note: string;
  page: number | null;
  /** Deck title, e.g. the lesson ("Hipertansiyon"). */
  deck: string;
  lang: Lang;
  intervalDays: number;
  ease: number;
  reps: number;
  againCount: number;
};
export type CardRating = 'again' | 'hard' | 'good';

export type PlanItem = {
  /** Course id, or "review" / "exam" for review and exam-prep tasks. */
  kind: string;
  label: L10n;
  title: L10n;
  /** Minutes for a 1.5 h study day; scaled to the student's hours. */
  minutes: number;
  why: L10n;
  to: 'reader' | 'quiz';
};

export type CourseRank = {
  courseId: string;
  name: L10n;
  badge: L10n;
  icon: 'star' | 'trend' | 'alert';
  level: 'good' | 'mid' | 'low';
  scores: number[];
  note: L10n;
  growth: { from: number; to: number; days: number };
  cta: L10n;
  toast?: L10n;
};

export type WeakTopic = { title: L10n; pdf: L10n; mastery: number; color: string };

/** A Premium plan. No price: it comes from the App Store for the student's country. */
export type PremiumPlan = { id: 'year' | 'term' | 'month'; title: L10n; tag?: L10n };
