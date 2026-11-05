// Pure helpers of the pen's storage keys (kept apart from ink.ts so Node tests can load them).

/** Key of one drawing: the original PDF's page, or a reading card = page + the card's number among the cards of that
 *  page (several cards can share a page, like the topics of an exam summary). Old rows have no number: first card. */
export const inkKey = (page: number, block?: number) => (block === undefined ? String(page) : `${page}:${block}`);

/** For each block (by its page, in reading order): its number among the blocks of the same page. */
export function blockOrdinals(pages: number[]): number[] {
  const seen = new Map<number, number>();
  return pages.map((p) => {
    const n = seen.get(p) ?? 0;
    seen.set(p, n + 1);
    return n;
  });
}
