import type { Lang } from '../i18n/I18nProvider';

/** A text in all four interface languages. */
export type L10n = Record<Lang, string>;

export type CourseColor = 'red' | 'amb' | 'vio' | 'grn' | 'teal';

export type Pdf = {
  id: string;
  title: L10n;
  /** Percent read, 0–100. */
  read: number;
  /** Minutes studied. */
  minutes: number;
  pages: number;
};

export type Course = {
  id: string;
  name: L10n;
  /** Shorter name for the sidebar. */
  short?: L10n;
  color: CourseColor;
  exam: L10n;
  /** ISO date of the next exam. */
  examDate?: string;
  /** Rank among classmates. */
  rank: number;
  pdfs: Pdf[];
};

/** Part of a paragraph: plain text, or a hard word that opens an explanation. */
export type Segment = string | { term: string; text: string };

export type ReaderBlock = {
  /** Keys in src/i18n/reader.json for the page label and tag. */
  page: string;
  tag: string;
  tagStyle: 'vio' | 'red';
  heading?: string;
  /** A paragraph is a list of segments, or one sentence the student can select. */
  paragraphs: (Segment[] | { selectable: true; text: string })[];
  molecule?: boolean;
  audio?: boolean;
};

export type ReaderSection = {
  tab: string;
  blocks: ReaderBlock[];
  /** Key in reader.json for the "section finished" line. */
  end: string;
};

export type ReaderDoc = {
  id: string;
  /** Language of the teacher's PDF; the text is never changed. */
  language: string;
  title: string;
  course: string;
  pages: number;
  page: number;
  sections: ReaderSection[];
  terms: Record<string, { page: number; en: string }>;
  sampleSentence: string;
  sampleTranslations: Record<string, { l: string; dir: 'ltr' | 'rtl'; lit: string; nat: string }>;
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

export type FlashCard = { q: L10n; a: L10n; note: L10n; page: number };
export type CardRating = 'again' | 'hard' | 'good';
