// Pure rules of group-sections (no database, no AI): when a lesson has too many small sections, and how the
// AI's grouping is applied without losing or reordering any of the teacher's text.

export type Section = { title: string; blocks: { pageFrom: number; pageTo: number }[] };
export type Part = { title: string; first: number };

/** About one section per 8 pages, at least 4: more than that is too fine to study section by section. */
export const maxSections = (pages: number) => Math.max(4, Math.ceil(pages / 8));

/** At most how many parts: about one per 15 pages, 2–8 (the AI may make fewer). */
export const targetParts = (pages: number) => Math.min(8, Math.max(2, Math.round(pages / 15)));

export const pagesOf = (sections: Section[]) => new Set(sections.flatMap((s) => s.blocks.map((b) => b.pageFrom))).size;

/** One line per section for the AI: "3. Vitamin Eksikliği (p. 4-5)". */
export function outline(sections: Section[]): string {
  return sections
    .map((s, i) => {
      const from = Math.min(...s.blocks.map((b) => b.pageFrom));
      const to = Math.max(...s.blocks.map((b) => b.pageTo));
      return `${i}. ${s.title} (p. ${from}${to !== from ? `-${to}` : ''})`;
    })
    .join('\n');
}

/**
 * Merges the sections into the parts. Each part starts at section `first`; the first part must start at 0 and
 * the starts must go up. Returns null if the grouping is not valid (then nothing is changed).
 */
export function applyParts<T extends Section>(sections: T[], parts: Part[]): T[] | null {
  if (!parts.length || parts[0].first !== 0) return null;
  for (let i = 1; i < parts.length; i++) if (!(parts[i].first > parts[i - 1].first) || parts[i].first >= sections.length) return null;
  return parts.map((p, i) => {
    const end = i + 1 < parts.length ? parts[i + 1].first : sections.length;
    const title = p.title.trim() || sections[p.first].title;
    return { ...sections[p.first], title, blocks: sections.slice(p.first, end).flatMap((s) => s.blocks) };
  });
}
