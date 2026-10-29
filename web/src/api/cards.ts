import { supabase } from './supabase';
import type { CardRating, FlashCard } from './types';

type Row = {
  id: string;
  question: string;
  answer: string;
  note: string | null;
  page: number | null;
  interval_days: number;
  ease: number;
  reps: number;
  again_count: number;
  material_id: string | null;
  card_decks: { title: string | null; lang: FlashCard['lang']; course_id: string | null; material_id: string | null };
};

type WeakTopic = { material_topics: { material_id: string; page_from: number | null; page_to: number | null } };

/**
 * Cards due now (spaced repetition), cards on the student's weak topics first, then oldest first; optionally only one course's decks, or one lesson's deck
 * (from the reader).
 * Cards are made by the server (lesson processing, "add mistakes to cards"); the app only updates the review state.
 */
export async function dueCards(where: { courseId?: string; materialId?: string } = {}, limit = 30): Promise<FlashCard[]> {
  // Take more than needed, so weak-topic cards can move to the front before the cut.
  let q = supabase
    .from('flashcards')
    .select('id, question, answer, note, page, interval_days, ease, reps, again_count, material_id, card_decks!inner(title, lang, course_id, material_id)')
    .lte('due_at', new Date().toISOString())
    .order('due_at')
    .limit(Math.max(limit * 5, 150));
  if (where.materialId) q = q.eq('card_decks.material_id', where.materialId);
  else if (where.courseId) q = q.eq('card_decks.course_id', where.courseId);
  const { data, error } = await q.returns<Row[]>();
  if (error) {
    console.error('dueCards', error);
    return [];
  }
  // A card is on a weak topic when its page lies in the page range of a weak topic of the same lesson (mistake cards
  // carry their lesson in `material_id`, lesson cards in their deck).
  const { data: weakRows } = await supabase
    .from('topic_progress')
    .select('material_topics!inner(material_id, page_from, page_to)')
    .eq('state', 'weak')
    .returns<WeakTopic[]>();
  const weak = (weakRows ?? []).map((w) => w.material_topics);
  const onWeakTopic = (r: Row) => {
    const lesson = r.material_id ?? r.card_decks.material_id;
    return r.page !== null && weak.some((t) => t.material_id === lesson && t.page_from !== null && r.page! >= t.page_from && r.page! <= (t.page_to ?? t.page_from));
  };
  const sorted = [...data].sort((a, b) => Number(onWeakTopic(b)) - Number(onWeakTopic(a))).slice(0, limit);
  return sorted.map((r) => ({
    id: r.id,
    q: r.question,
    a: r.answer,
    note: r.note ?? '',
    page: r.page,
    deck: r.card_decks.title ?? '',
    lang: r.card_decks.lang,
    intervalDays: Number(r.interval_days),
    ease: Number(r.ease),
    reps: r.reps,
    againCount: r.again_count,
  }));
}

const MIN = 60_000;
const DAY = 86_400_000;

/** Days until the card comes back when the student knew it (first time 4 days, as in the design). */
export function goodInterval(c: FlashCard) {
  return c.reps === 0 ? 4 : Math.round(Math.max(4, c.intervalDays) * c.ease);
}

/** Saves a rating: Didn't know → 1 min, Hard → 10 min, Knew it → goodInterval days. */
export async function rateCard(c: FlashCard, rating: CardRating) {
  const now = Date.now();
  const ease = Math.max(1.3, c.ease + (rating === 'again' ? -0.2 : rating === 'hard' ? -0.15 : 0));
  const days = rating === 'good' ? goodInterval(c) : c.intervalDays;
  const due = rating === 'again' ? now + MIN : rating === 'hard' ? now + 10 * MIN : now + days * DAY;
  const { error } = await supabase
    .from('flashcards')
    .update({
      due_at: new Date(due).toISOString(),
      interval_days: rating === 'again' ? 0 : days,
      ease: Number(ease.toFixed(2)),
      reps: rating === 'again' ? 0 : c.reps + (rating === 'good' ? 1 : 0),
      again_count: c.againCount + (rating === 'again' ? 1 : 0),
      last_rating: rating,
      last_reviewed_at: new Date(now).toISOString(),
    })
    .eq('id', c.id);
  if (error) console.error('rateCard', error);
}

/**
 * "Kartlara ekle" on a hard word: the server (Edge Function add-card) makes the card from the word's explanation
 * in the lesson's deck. 'already' = the word was added before.
 */
export async function addTermCard(termId: string): Promise<'added' | 'already' | 'failed'> {
  const { data, error } = await supabase.functions.invoke('add-card', { body: { term_id: termId } });
  if (error) {
    console.error('add-card', error);
    return 'failed';
  }
  return (data as { already?: boolean }).already ? 'already' : 'added';
}
