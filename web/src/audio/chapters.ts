import type { RecapPoint, WeakTopic } from '../api/summary';

// "Sesli anlatım" (design NewIPad, assistant chip "Önemli ve zayıf konularımı anlat"): up to 5 short parts of one
// lesson, weak topics first, then what the lecturer stressed, read aloud by the browser. The text is the lesson's
// review summary (Edge lesson-summary, only facts from the PDF); here it is only grouped by topic and ordered.

export type Topic = {
  id: string;
  title: string;
  page_from: number | null;
  page_to: number | null;
  importance: number;
  teacher_minutes: number | null;
  teacher_repeats: number | null;
  teacher_said_exam: boolean;
};

/** Why a part was chosen; the screen turns it into "Zayıf · %38", "Hoca 9 dk durdu", … */
export type ChapterTag =
  | { k: 'weak'; n: number | null }
  | { k: 'exam' }
  | { k: 'minutes'; n: number }
  | { k: 'repeats'; n: number }
  | { k: 'important' }
  | { k: 'summary' };

export type Chapter = { title: string; pageFrom: number; pageTo: number; tag: ChapterTag; sentences: string[] };

export const MAX_CHAPTERS = 5;
/** Reading speeds of the player, in the design's order (1,0× → 1,25× → 1,5× → 0,8×). */
export const SPEEDS = [1, 1.25, 1.5, 0.8];

/** Sentences small enough for the browser voice (one long utterance stops after a while in Chrome). */
export function sentences(text: string): string[] {
  return text
    .split(/\n+|(?<=[.!?…؟])\s+/)
    .map((x) => x.trim())
    .filter(Boolean);
}

const overlaps = (p: RecapPoint, t: Topic) => t.page_from != null && p.page_from <= (t.page_to ?? t.page_from) && p.page_to >= t.page_from;

/** Groups the summary points by the lesson topic they belong to (by pages) and keeps the most useful 5. */
export function buildChapters(points: RecapPoint[], topics: Topic[], weak: WeakTopic[]): Chapter[] {
  type Group = { topic: Topic | null; points: RecapPoint[] };
  const groups = new Map<string, Group>();
  for (const p of points) {
    const topic = topics.find((t) => overlaps(p, t)) ?? null;
    const key = topic ? topic.id : `p${p.page_from}`;
    const g = groups.get(key) ?? { topic, points: [] };
    g.points.push(p);
    groups.set(key, g);
  }
  const mastery = new Map(weak.map((w) => [w.id, w.mastery]));

  const scored = [...groups.values()].map((g, order) => {
    const t = g.topic;
    const pageFrom = Math.min(...g.points.map((p) => p.page_from));
    const pageTo = Math.max(...g.points.map((p) => p.page_to));
    let tag: ChapterTag;
    let rank: number;
    if ((t && mastery.has(t.id)) || g.points.some((p) => p.weak)) {
      const m = t ? mastery.get(t.id) : undefined;
      tag = { k: 'weak', n: m != null ? Math.round(m) : null };
      rank = 0 + (m ?? 50) / 1000;
    } else if (t?.teacher_said_exam) {
      tag = { k: 'exam' };
      rank = 1;
    } else if (t?.teacher_minutes && t.teacher_minutes >= 3) {
      tag = { k: 'minutes', n: Math.round(t.teacher_minutes) };
      rank = 2 - t.teacher_minutes / 1000;
    } else if (t?.teacher_repeats && t.teacher_repeats >= 2) {
      tag = { k: 'repeats', n: t.teacher_repeats };
      rank = 3 - t.teacher_repeats / 1000;
    } else if (t && t.importance >= 2) {
      tag = { k: 'important' };
      rank = 4 - t.importance / 10;
    } else {
      tag = { k: 'summary' };
      rank = 5;
    }
    const chapter: Chapter = { title: t?.title ?? '', pageFrom, pageTo, tag, sentences: g.points.flatMap((p) => sentences(p.text)) };
    return { chapter, rank, order };
  });

  return scored
    .filter((x) => x.chapter.sentences.length)
    .sort((a, b) => a.rank - b.rank || a.order - b.order)
    .slice(0, MAX_CHAPTERS)
    .map((x) => x.chapter);
}

/** Rough reading time: about 14 letters a second at normal speed. */
export const secondsOf = (chars: number) => Math.round(chars / 14);
