// Pure rules of the placement test (no database access), so they can be tested anywhere.

/** At most this many questions: "8 soru · yaklaşık 5 dk" (design/NewPlacement.dc.html). */
export const MAX_QUESTIONS = 8;
/** At most this many questions per topic. */
export const PER_TOPIC = 2;

export type Source = { id: string; topic_id: string };

/**
 * Questions for the test: one from each chosen topic in lesson order, then a second one, … until MAX_QUESTIONS.
 * Topics without a question are left out (they stay "to study").
 */
export function pickQuestions<T extends Source>(topicIds: string[], questions: T[]): T[] {
  const byTopic = new Map<string, T[]>();
  for (const q of questions) byTopic.set(q.topic_id, [...(byTopic.get(q.topic_id) ?? []), q]);
  const out: T[] = [];
  for (let round = 0; round < PER_TOPIC; round++)
    for (const t of topicIds) {
      const q = byTopic.get(t)?.[round];
      if (q && out.length < MAX_QUESTIONS) out.push(q);
    }
  // Back in lesson order, topic by topic.
  return out.sort((a, b) => topicIds.indexOf(a.topic_id) - topicIds.indexOf(b.topic_id));
}

export type TopicResult = { state: 'known' | 'weak' | 'todo'; mastery: number; nextReview: number | null };

/**
 * A topic after the test: all right = known (2-minute review in 5 days), none right = to study from the start,
 * some right = weak (short summary + cards tomorrow). "Bilmiyorum" counts as wrong.
 */
export function topicResult(right: number, asked: number): TopicResult {
  const mastery = asked ? Math.round((right / asked) * 100) : 0;
  if (asked && right === asked) return { state: 'known', mastery, nextReview: 5 };
  if (!right) return { state: 'todo', mastery, nextReview: null };
  return { state: 'weak', mastery, nextReview: 1 };
}
