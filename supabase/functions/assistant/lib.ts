// Pure helpers of the assistant (no database, no AI): which words to search, and which text pieces fit best.

// Very common words that do not help finding the right page (Turkish and English).
const STOP = new Set(
  'acaba ama ancak bir biri bu bunu bunun da de daha diye en gibi hangi hangisi her için ile ise kadar ki mi mu mü mı ne neden nedir nasıl niçin o olan olarak olur sonra şu ve veya ya yani the and for what which why how does are with from that this into about'.split(' '),
);

/** Search words of a question: letters only, at least 3 characters, no common words, at most 8. */
export function queryTerms(question: string): string[] {
  const words = question.toLocaleLowerCase('tr').match(/[\p{L}\p{N}]+/gu) ?? [];
  return [...new Set(words.filter((w) => w.length >= 3 && !STOP.has(w)))].slice(0, 8);
}

/**
 * Postgres full-text query that matches any of the words. Long words are cut to their first 6 letters with a
 * prefix match, so Turkish endings still match ("hipertansiyonda" finds "hipertansiyon").
 */
export function tsQuery(terms: string[]): string {
  return terms.map((w) => `${w.length > 6 ? w.slice(0, 6) : w}:*`).join(' | ');
}

/** Orders text pieces by how many of the search words they contain (more different words first). */
export function rankChunks<T extends { text: string }>(chunks: T[], terms: string[], limit: number): T[] {
  const stems = terms.map((w) => (w.length > 6 ? w.slice(0, 6) : w));
  const score = (text: string) => {
    const t = text.toLocaleLowerCase('tr');
    return stems.reduce((a, s) => a + (t.includes(s) ? 1 : 0), 0);
  };
  return chunks
    .map((c, i) => ({ c, s: score(c.text), i }))
    .filter((x) => x.s > 0)
    .sort((a, b) => b.s - a.s || a.i - b.i)
    .slice(0, limit)
    .map((x) => x.c);
}

/**
 * The whole text of one lesson, page by page, for the assistant — or null when it is longer than maxChars
 * (then only the open pages and the best search pieces are sent).
 */
export function lessonText(chunks: { page: number | null; text: string }[], maxChars: number): string | null {
  const pages = [...chunks].sort((a, b) => (a.page ?? 0) - (b.page ?? 0)).map((c) => `[Page ${c.page ?? '?'}]\n${c.text.trim()}`);
  const text = pages.join('\n\n');
  return text.length <= maxChars ? text : null;
}

/**
 * Claude Sonnet 5.5 list price in US dollars: input $2, output $10 per million tokens; cache writes (5 minutes)
 * $2.50, cache reads $0.20.
 */
export const costUsd = (input: number, output: number, cacheWrite = 0, cacheRead = 0) =>
  Math.round(((input * 2 + output * 10 + cacheWrite * 2.5 + cacheRead * 0.2) / 1_000_000) * 10000) / 10000;

/**
 * The streamed answer ends with one line "SOURCES: [2, 5] OUTSIDE: no". This splits it off: the answer text, the
 * source numbers and whether general knowledge was used. A missing line gives no sources.
 */
export function splitTail(text: string): { answer: string; sources: number[]; outside: boolean } {
  const at = text.lastIndexOf('SOURCES:');
  // Bold marks (**) are dropped: the apps show plain text.
  const plain = (x: string) => x.replace(/\*\*/g, '').trim();
  if (at < 0) return { answer: plain(text), sources: [], outside: false };
  const tail = text.slice(at);
  const nums = (tail.match(/\[([^\]]*)\]/)?.[1] ?? '').split(/[,\s]+/).map(Number).filter((n) => Number.isInteger(n) && n > 0);
  return { answer: plain(text.slice(0, at)), sources: [...new Set(nums)], outside: /OUTSIDE:\s*yes/i.test(tail) };
}
