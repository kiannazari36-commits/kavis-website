// Pure helpers of process-material (no database, no AI), so they can be tested anywhere.
// The teacher's text is never rewritten: paragraphs are cut from the PDF text, hard words are only marked.

/** A paragraph is plain text and hard words (term keys), as in material_content.reader_doc. */
export type Segment = string | { term: string; text: string };

const END = /[.!?:;…)]$/;

/**
 * Splits one page of extracted PDF text into paragraphs. Lines are joined with spaces; a word broken with a
 * hyphen at the end of a line is joined back. A new paragraph starts at an empty line, after a line that ends a
 * sentence, at a bullet, or around a short heading-like line.
 */
export function paragraphsOf(pageText: string): string[] {
  const lines = pageText.replace(/\r/g, '').split('\n').map((l) => l.trim());
  const out: string[] = [];
  let cur = '';
  const flush = () => {
    if (cur.trim()) out.push(cur.trim());
    cur = '';
  };
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line) {
      flush();
      continue;
    }
    const bullet = /^([•\-–▪●*]|\d+[.)])\s/.test(line);
    const heading = line.length < 60 && !END.test(line) && /^[\p{Lu}\d]/u.test(line) && !cur;
    if (bullet) flush();
    if (cur.endsWith('-') && /^\p{Ll}/u.test(line)) cur = cur.slice(0, -1) + line;
    else cur = cur ? `${cur} ${line}` : line;
    if (heading || END.test(line)) flush();
  }
  flush();
  return out;
}

export type TermRef = { key: string; surface: string };

/**
 * Marks the first place each hard word appears (case-insensitive, whole word) in a paragraph.
 * `used` holds the term keys already marked in the lesson, so each word is marked once.
 */
export function markTerms(paragraph: string, terms: TermRef[], used: Set<string>): Segment[] {
  const hits: { start: number; end: number; key: string }[] = [];
  const lower = paragraph.toLocaleLowerCase('tr');
  for (const t of terms) {
    if (used.has(t.key) || !t.surface.trim()) continue;
    const needle = t.surface.toLocaleLowerCase('tr');
    let from = 0;
    while (from < lower.length) {
      const at = lower.indexOf(needle, from);
      if (at < 0) break;
      const before = at === 0 ? ' ' : lower[at - 1];
      const after = lower[at + needle.length] ?? ' ';
      const whole = !/[\p{L}\p{N}]/u.test(before) && !/[\p{L}\p{N}]/u.test(after);
      const free = hits.every((h) => at >= h.end || at + needle.length <= h.start);
      if (whole && free) {
        hits.push({ start: at, end: at + needle.length, key: t.key });
        used.add(t.key);
        break;
      }
      from = at + 1;
    }
  }
  if (!hits.length) return [paragraph];
  hits.sort((a, b) => a.start - b.start);
  const segs: Segment[] = [];
  let pos = 0;
  for (const h of hits) {
    if (h.start > pos) segs.push(paragraph.slice(pos, h.start));
    segs.push({ term: h.key, text: paragraph.slice(h.start, h.end) });
    pos = h.end;
  }
  if (pos < paragraph.length) segs.push(paragraph.slice(pos));
  return segs;
}

/** Joins segments back into text (to check that marking never changed the teacher's words). */
export const plain = (segs: Segment[]) => segs.map((x) => (typeof x === 'string' ? x : x.text)).join('');

/** Pages of a lesson split into batches the AI handles in one call. */
export function batches(totalPages: number, size: number): [number, number][] {
  const out: [number, number][] = [];
  for (let p = 1; p <= totalPages; p += size) out.push([p, Math.min(totalPages, p + size - 1)]);
  return out;
}

/** Claude Sonnet 5.5 list price in US dollars (input $2, output $10 per million tokens). */
export const costUsd = (input: number, output: number) => Math.round(((input * 2 + output * 10) / 1_000_000) * 10000) / 10000;

// Page references in a hint: "(s. 4)", "(p. 12)", "(ص. 3)", "sayfa 4", "page 12".
const PAGE_REF = /\(\s*(?:s|p|pp|ص)\.\s*\d+(?:\s*[–-]\s*\d+)?\s*\)|\b(?:sayfa|page)\s+\d+/giu;

/**
 * Hints must help the student think, not point to a page or give the answer away: page references are cut out,
 * and a hint that contains the correct option's text (case-insensitive) or is left with almost nothing is dropped.
 * Short options (1-2 letters, e.g. "A") are not checked against.
 */
export function cleanHints(hints: string[], options: string[], answerIndex: number): string[] {
  const answer = (options[answerIndex] ?? '').trim().toLocaleLowerCase('tr').replace(/[.!]+$/, '');
  return hints
    .map((h) => h.replace(PAGE_REF, '').replace(/\s{2,}/g, ' ').trim())
    .filter((h) => h.length >= 8)
    .filter((h) => answer.length < 3 || !h.toLocaleLowerCase('tr').includes(answer));
}
