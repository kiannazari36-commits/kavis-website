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
- One line of the page = one line of text. Keep headings as their own line; start bullet points with "• ".
- Read tables row by row, cells separated by " | ".
- A word you cannot read: write [?]. A page with no readable text: "".
- Leave out only page numbers, running headers/footers and watermarks.`;

/** Base64 of bytes (for image and PDF blocks), in pieces so long files do not overflow the call stack. */
export function toBase64(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

/** The text of one OCR page in our page order: missing pages become "". */
export function pageTexts(out: OcrBatch, from: number, to: number): string[] {
  const texts: string[] = [];
  for (let p = from; p <= to; p++) texts.push((out.pages.find((x) => x.page === p)?.text ?? '').trim());
  return texts;
}
