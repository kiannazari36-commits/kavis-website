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

/** Claude Sonnet 5.5 list price in US dollars (input $2, output $10 per million tokens). */
export const costUsd = (input: number, output: number) => Math.round(((input * 2 + output * 10) / 1_000_000) * 10000) / 10000;
