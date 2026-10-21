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
