// Pure helpers of the pen's storage (kept apart from ink.ts so Node tests can load them).

/** One line of the shared pen format (web, iPhone and iPad all read and write it, `annotations.anchor.strokes`).
 *  Points are parts of the page's (or card's) width and height (0–1); `w` is the line width as a part of the width
 *  (old web lines have none: 3 px); `tool` 'marker' is see-through, 'pencil' a little; no tool = pen. */
export type Stroke = { color: string; w?: number; tool?: 'marker' | 'pencil'; points: [number, number][] };
/** A page's drawing. `others`: more rows of the same page (an old web 'web_pdf' row next to an iPad 'pdf' row);
 *  their lines are shown together, the next save keeps one row and removes these. */
export type PageInk = { id: string | null; strokes: Stroke[]; others?: string[] };
export type InkSurface = 'card' | 'pdf';
export type InkRow = { id: string; page: number; ink_path?: string | null; anchor: unknown };

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

/** The rows of one surface by key. The original PDF is 'pdf' (and 'web_pdf', the web's name before 6 Nov 2026).
 *  An old iPhone/iPad row (a PencilKit file, no `strokes`) is skipped: the app turns it into this format when it
 *  opens the lesson. */
export function groupInk(rows: InkRow[], surface: InkSurface): Record<string, PageInk> {
  const out: Record<string, PageInk> = {};
  for (const r of rows) {
    const a = r.anchor as { surface?: string; block?: number; strokes?: Stroke[] } | null;
    if (r.ink_path && !a?.strokes) continue;
    const on = a?.surface === 'web_pdf' || a?.surface === 'pdf' ? 'pdf' : 'card';
    if (on !== surface) continue;
    const key = inkKey(r.page, surface === 'card' ? (a?.block ?? 0) : undefined);
    const strokes = a?.strokes ?? [];
    const was = out[key];
    out[key] = was ? { ...was, strokes: [...was.strokes, ...strokes], others: [...(was.others ?? []), r.id] } : { id: r.id, strokes };
  }
  return out;
}

/** The colour a stored line is shown in on a card. The file keeps the colour as drawn (theme-free); only the
 *  screen changes it: on a dark card a very dark line (the iOS paper ink, black) is lifted toward white so it can
 *  be read. The original PDF page is always white, so it is never changed. Same rule on iOS (`InkFormat.shown`). */
export function shownColor(hex: string, onDark: boolean): string {
  const v = parseInt(hex.replace('#', '').slice(0, 6), 16);
  if (!onDark || Number.isNaN(v)) return hex;
  const c = [v >> 16, (v >> 8) & 0xff, v & 0xff];
  const lum = (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255;
  if (lum >= 0.2) return hex;
  const k = 0.65; // how far toward white
  return '#' + c.map((x) => Math.round(x + (255 - x) * k).toString(16).padStart(2, '0')).join('').toUpperCase();
}
