// Run: node --experimental-strip-types supabase/functions/grade-quiz/grade.test.ts
import { grade, levelFor, sameAnswer, topicState, type AnswerRow, type QuestionRow } from './grade.ts';

const q = (id: string, answer: number, kind: QuestionRow['kind'] = 'multiple_choice'): QuestionRow => ({
  id, kind, answer_index: kind === 'written' ? null : answer, topic_id: 't', text: `Q${id}`, options: ['a', 'b', 'c'], explanation: null, source_page: 1,
});
const a = (id: string, chosen: number | null, extra: Partial<AnswerRow> = {}): AnswerRow => ({
  question_id: id, chosen_index: chosen, dont_know: false, hints_used: 0, confidence: null, ...extra,
});
let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};

const qs = [q('1', 0), q('2', 1), q('3', 2), q('4', 0), q('w', 0, 'written')];
const r = grade(qs, [a('1', 0), a('2', 1, { hints_used: 2 }), a('3', 0, { confidence: 'sure' }), a('4', null, { dont_know: true }), a('w', null)]);
check('right = 1, right with hint = 0.5, wrong = 0, dont know = 0 → 1.5/4 = 37.5', r.score === 37.5);
check('level for 37.5 is beginner', r.level === 'beginner');
check('written answer is not graded (null)', r.results.find((x) => x.question_id === 'w')?.correct === null);
check('wrong + sure → confident mistake', r.confidentMistakes.length === 1 && r.confidentMistakes[0].id === '3');
check('"I don\'t know" is never a confident mistake', !r.confidentMistakes.some((x) => x.id === '4'));
check('all right → 100, expert', grade([q('1', 0)], [a('1', 0)]).score === 100 && levelFor(100) === 'expert');
check('nothing gradable → score null', grade([q('w', 0, 'written')], [a('w', null)]).score === null);
check('unknown question ids are ignored', grade([q('1', 0)], [a('x', 0), a('1', 0)]).results.length === 1);
check('levels: 49 beginner, 50 improving, 70 very_good, 85 expert',
  levelFor(49) === 'beginner' && levelFor(50) === 'improving' && levelFor(70) === 'very_good' && levelFor(85) === 'expert');
check('topic weak under 60', topicState(59) === 'weak' && topicState(60) === 'known');
const wr = grade([q('1', 0), q('w', 0, 'written')], [a('1', 0), a('w', null, { confidence: 'sure' })], new Map([['w', false]]));
check('written answer judged wrong → 0 points, counted, confident mistake', wr.score === 50 && wr.results[1].correct === false && wr.confidentMistakes.length === 1);
check('written answer judged right → 1 point', grade([q('w', 0, 'written')], [a('w', null)], new Map([['w', true]])).score === 100);
check('sameAnswer ignores case, accents, spaces, punctuation', sameAnswer(' Bradikinin. ', 'bradıkinin') && sameAnswer('ACE inhibitörü', 'ace inhibitoru') && !sameAnswer('a', 'b') && !sameAnswer('', ''));
if (fails) process.exit(1);
