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
export type ReaderTag = 'definition' | 'dose' | 'side_effect' | 'special' | 'emergency' | 'general';

export type ReaderBlock = {
  pageFrom: number;
  pageTo: number;
  tag: ReaderTag;
  heading?: string;
  /** A paragraph is a list of segments, or one sentence the student can select. */
  paragraphs: (Segment[] | { selectable: true; text: string })[];
  /** true: the server marked a molecule; the viewer finds which one from the text (components/molecules.ts). */
  molecule?: boolean;
};

export type ReaderSection = { title: string; blocks: ReaderBlock[] };

/** The reading page (material_content.reader_doc). The teacher's text is never changed. */
/** grouped: the server already checked the sections (Edge group-sections). */
export type ReaderDoc = { language: string; grouped?: boolean; sections: ReaderSection[] };

/** A hard word of the lesson (material_terms); explanation per app language. */
export type ReaderTerm = {
  id: string;
  surface: string;
  page: number | null;
  explanation: Partial<Record<Lang, { name: string; kind: string; text: string }>>;
};

/** Why a topic is in the exam summary (shown as its tag). */
export type TopicReason =
  | { type: 'weak'; mastery: number }
  | { type: 'teacher'; minutes: number }
  | { type: 'samples'; count: number }
  | { type: 'base' };

/** One topic of the exam-prep summary (summaries.content.topics), in the content language. */
export type ExamTopic = {
  title: string;
  kind: 'weak' | 'imp' | 'base';
  reason: TopicReason;
  pageFrom: number;
  pageTo: number;
  points: string[];
  /** What the lecturer said about it (from the lecture recording). */
  teacher?: string;
  molecule?: 'captopril' | 'paracetamol';
};

/** A question (quiz_questions), in the content language. */
/** The three question types: multiple_choice, fill_blank (one "____" in the text), written (open question). */
export type QuestionKind = 'multiple_choice' | 'fill_blank' | 'written';

export type QuizQuestion = {
  id: string;
  kind: QuestionKind;
  /** fill_blank / written: the right answer, shown after the answer was judged. */
  modelAnswer?: string;
  /** case | side_effects | dose | knowledge | structure — label in study.json (style_*). */
  style: string;
  text: string;
  options: string[];
  /** Index of the right option. For fill_blank / written the app stores the judge's verdict here: 1 = right, 0 = wrong. */
  answer: number;
  why: string;
  page: number | null;
  /** Topic title, for the source line. */
  topic: string;
  hints: string[];
  molecule?: 'captopril' | 'paracetamol';
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

/** A Premium plan. No price: it comes from the App Store for the student's country. */
export type PremiumPlan = { id: 'year' | 'term' | 'month'; title: L10n; tag?: L10n };
