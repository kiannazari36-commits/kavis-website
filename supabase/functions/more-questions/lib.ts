// Pure helpers (no database, no AI), the same rules as generate-quiz.

// Page references in a hint: "(s. 4)", "(p. 12)", "(ص. 3)", "sayfa 4", "page 12".
const PAGE_REF = /\(\s*(?:s|p|pp|ص)\.\s*\d+(?:\s*[–-]\s*\d+)?\s*\)|\b(?:sayfa|page)\s+\d+/giu;

/** Hints never point to a page or contain the right option (same rule as process-material). */
export function cleanHints(hints: string[], options: string[], answerIndex: number): string[] {
  const answer = (options[answerIndex] ?? '').trim().toLocaleLowerCase('tr').replace(/[.!]+$/, '');
  return hints
    .map((h) => h.replace(PAGE_REF, '').replace(/\s{2,}/g, ' ').trim())
    .filter((h) => h.length >= 8)
    .filter((h) => answer.length < 3 || !h.toLocaleLowerCase('tr').includes(answer));
}

/** Claude Sonnet 5.5 list price in US dollars (input $2, output $10 per million tokens). */
// Cache writes (5 minutes) $2.50, cache reads $0.20 per million tokens.
export const costUsd = (input: number, output: number, cacheWrite = 0, cacheRead = 0) =>
  Math.round(((input * 2 + output * 10 + cacheWrite * 2.5 + cacheRead * 0.2) / 1_000_000) * 10000) / 10000;
