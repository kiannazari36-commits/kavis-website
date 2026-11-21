// Text recognition (OCR) for photos of pages and scanned PDFs: the AI copies the text it sees, page by page,
// exactly as written (the teacher's text is never rewritten). The result then goes through the same steps as a
// PDF with text.

const obj = (properties: Record<string, unknown>) => ({ type: 'object', properties, required: Object.keys(properties), additionalProperties: false });

export const OCR_SCHEMA = obj({
  pages: { type: 'array', items: obj({ page: { type: 'integer' }, text: { type: 'string' } }) },
});
export type OcrBatch = { pages: { page: number; text: string }[] };

export const OCR_SYSTEM = `You copy the text of lecture pages (slides, printed notes, handwriting, scanned PDF pages) for a study app.
Return JSON: pages = one entry per page you receive, with its page number and its full text.
Rules for text:
- Copy every word exactly as written, in its own language and spelling. Never translate, summarise, correct or add anything.
- A paragraph that wraps over several printed lines is ONE line of text: do not break the line where the printed line ends. Keep headings as their own line; start bullet points with "• " (one line each).
- Read tables row by row, one line per row, cells separated by " | " (the header row first). Never put table text into a paragraph.
- A word you cannot read: write [?]. A page with no readable text: "".
- Leave out only page numbers, running headers/footers and watermarks.`;

/** Base64 of bytes (for image and PDF blocks), in pieces so long files do not overflow the call stack. */
export function toBase64(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

const TERMINAL = /[.!?:;…)”"»]$/;
const isRow = (l: string) => l.split(' | ').filter((c) => c.trim()).length >= 2;
const isBullet = (l: string) => /^([•\-–▪●*]|\d+[.)])\s/.test(l);

/**
 * Joins the lines of one paragraph that text recognition cut at the end of each printed line. Two lines are joined
 * (with a space; the words stay exactly as written) only when there is a clear sign of one sentence: the first line
 * does not end a sentence, neither is a bullet or a table row, and the next one starts with a lowercase letter (or,
 * in scripts without capitals, the first line is a full-width line). Headings, bullets and table rows stay apart.
 */
export function joinWrappedLines(text: string): string {
  const out: string[] = [];
  for (const raw of text.replace(/\r/g, '').split('\n')) {
    const line = raw.trim();
    const prev = out[out.length - 1];
    if (!line) {
      out.push('');
      continue;
    }
    const joinable =
      prev && !TERMINAL.test(prev) && !isBullet(prev) && !isRow(prev) && !isBullet(line) && !isRow(line) &&
      (/^\p{Ll}/u.test(line) || (/^\p{Script=Arabic}/u.test(line) && prev.length >= 40));
    if (joinable) out[out.length - 1] = prev.endsWith('-') && /^\p{Ll}/u.test(line) ? prev.slice(0, -1) + line : `${prev} ${line}`;
    else out.push(line);
  }
  return out.join('\n');
}

/** The text of one OCR page in our page order: missing pages become "". */
export function pageTexts(out: OcrBatch, from: number, to: number): string[] {
  const texts: string[] = [];
  for (let p = from; p <= to; p++) texts.push(joinWrappedLines((out.pages.find((x) => x.page === p)?.text ?? '').trim()));
  return texts;
}
