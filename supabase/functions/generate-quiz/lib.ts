// Pure helpers of generate-quiz (no database, no AI).

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

export type Page = { lesson: number; page: number; text: string; weight: number };

/**
 * The pages sent to the AI, most important first, within a size limit: pages of topics the lecturer said will be
 * in the exam, weak topics and central topics come before the rest; each page shortened to perPage characters.
 * Returned in lesson and page order, so the text reads naturally.
 */
export function pickPages(pages: Page[], maxChars: number, perPage = 1200): Page[] {
  const chosen: Page[] = [];
  let used = 0;
  for (const p of [...pages].sort((a, b) => b.weight - a.weight || a.lesson - b.lesson || a.page - b.page)) {
    const text = p.text.slice(0, perPage);
    if (used + text.length > maxChars) continue;
    chosen.push({ ...p, text });
    used += text.length;
  }
  return chosen.sort((a, b) => a.lesson - b.lesson || a.page - b.page);
}

/** Claude Sonnet 5.5 list price in US dollars (input $2, output $10 per million tokens). */
export const costUsd = (input: number, output: number) => Math.round(((input * 2 + output * 10) / 1_000_000) * 10000) / 10000;
