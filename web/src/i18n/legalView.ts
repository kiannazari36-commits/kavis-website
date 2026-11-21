// Hides the "draft / not checked by a lawyer" parts of the legal texts (one switch: LEGAL_DRAFT_VISIBLE in config.ts).
// The notes stay in legal.ts; they are only removed when the page is drawn.

/** A square-bracket note for the lawyer: "[AVUKAT KONTROL EDECEK: …]", "[LAWYER TO CHECK]", "[VERBİS / …]", Persian / Arabic ones. */
const NOTE = /\s*\[[^\]]*(?:AVUKAT|LAWYER|VERBİS|Registration|وکیل|محامي|المحامي)[^\]]*\]/gu;
/** The "(taslak)" / "(draft)" mark after the date of the last update. */
const DRAFT_MARK = /\s*\((?:taslak|draft|پیش‌نویس|مسودة)\)/giu;

/** A paragraph without lawyer notes; null when nothing is left of it. */
export function cleanParagraph(p: string): string | null {
  const t = p.replace(NOTE, '').trim();
  return t || null;
}

export const cleanUpdated = (s: string) => s.replace(DRAFT_MARK, '').trim();

type Doc = { title: string; sections: { h: string; p: string[] }[] };

/** The document as it is drawn: unchanged while the draft is visible, else without any lawyer note. */
export function visibleDoc(doc: Doc, draftVisible: boolean): Doc {
  if (draftVisible) return doc;
  return { ...doc, sections: doc.sections.map((s) => ({ ...s, p: s.p.map(cleanParagraph).filter((x): x is string => x !== null) })) };
}
