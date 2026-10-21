import { fakeRequest } from './client';
import { HYPERTENSION_DOC } from './mock/readerDoc';
import type { ReaderDoc } from './types';

/** The reading page for a PDF. The mock has one sample lesson, used for every PDF. */
export function getReaderDoc(_courseId: string, _pdfId: string): Promise<ReaderDoc> {
  return fakeRequest(HYPERTENSION_DOC, 150);
}

export type TranslationStyle = 'literal' | 'natural';

/** Translates a sentence of the PDF. Returns null when the mock has no translation for it. */
export function translate(doc: ReaderDoc, text: string, lang: string, style: TranslationStyle): Promise<string | null> {
  const t = text === doc.sampleSentence ? doc.sampleTranslations[lang] : undefined;
  return fakeRequest(t ? (style === 'literal' ? t.lit : t.nat) : null, 200);
}
