import { pickQuestions, topicResult } from './pick.ts';

const check = (name: string, ok: boolean) => {
  if (!ok) throw new Error(`failed: ${name}`);
  console.log(`ok  ${name}`);
};

const qs = ['a', 'a', 'a', 'b', 'c', 'c', 'd', 'e', 'e', 'f', 'g', 'h', 'h', 'i'].map((t, i) => ({ id: `q${i}`, topic_id: t }));
const all = pickQuestions(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'], qs);
check('at most 8 questions', all.length === 8);
check('every topic first, before seconds', new Set(all.map((q) => q.topic_id)).size === 8);
check('lesson order', all.map((q) => q.topic_id).join('') === 'abcdefgh');

const two = pickQuestions(['c', 'a'], qs);
check('two per chosen topic, only chosen ones', two.map((q) => q.id).join(',') === 'q4,q5,q0,q1');
check('topic without questions is left out', pickQuestions(['x'], qs).length === 0);

check('all right = known in 5 days', JSON.stringify(topicResult(2, 2)) === JSON.stringify({ state: 'known', mastery: 100, nextReview: 5 }));
check('half right = weak tomorrow', JSON.stringify(topicResult(1, 2)) === JSON.stringify({ state: 'weak', mastery: 50, nextReview: 1 }));
check('none right = to study', topicResult(0, 2).state === 'todo');
