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
  /** Rank among classmates. */
  rank: number;
  pdfs: Pdf[];
};
