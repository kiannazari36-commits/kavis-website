// Pure grading rules of a quiz attempt (no database access), so they can be tested anywhere.

export type QuestionRow = {
  id: string;
  kind: 'multiple_choice' | 'written';
  answer_index: number | null;
  topic_id: string | null;
  text: string;
  options: string[] | null;
  explanation: string | null;
  source_page: number | null;
};

export type AnswerRow = {
  question_id: string;
  chosen_index: number | null;
  dont_know: boolean;
  hints_used: number;
  confidence: 'sure' | 'unsure' | 'guess' | null;
};

export type Level = 'beginner' | 'improving' | 'very_good' | 'expert';

export type Graded = {
  /** Right / wrong per question; null = a written answer, graded later by AI. */
  results: { question_id: string; correct: boolean | null }[];
  /** 0–100, over the questions that could be graded. null when none could. */
  score: number | null;
  level: Level | null;
  /** Wrong answers given with "sure": they become cards ("add mistakes to cards"). */
  confidentMistakes: QuestionRow[];
};

export function levelFor(score: number): Level {
  if (score < 50) return 'beginner';
  if (score < 70) return 'improving';
  if (score < 85) return 'very_good';
  return 'expert';
}

/** Right = 1 point, right with any hint = half a point, wrong / "I don't know" = 0. */
export function grade(questions: QuestionRow[], answers: AnswerRow[]): Graded {
  const byId = new Map(questions.map((q) => [q.id, q]));
  const results: Graded['results'] = [];
  const confidentMistakes: QuestionRow[] = [];
  let points = 0;
  let graded = 0;
  for (const a of answers) {
    const q = byId.get(a.question_id);
    if (!q) continue;
    if (q.kind !== 'multiple_choice' || q.answer_index === null) {
      results.push({ question_id: q.id, correct: null });
      continue;
    }
    const correct = !a.dont_know && a.chosen_index === q.answer_index;
    results.push({ question_id: q.id, correct });
    graded++;
    if (correct) points += a.hints_used > 0 ? 0.5 : 1;
    else if (a.confidence === 'sure' && !a.dont_know) confidentMistakes.push(q);
  }
  const score = graded ? Math.round((points / graded) * 10000) / 100 : null;
  return { results, score, level: score === null ? null : levelFor(score), confidentMistakes };
}

/** Mastery of a topic (0–100) from all graded answers on it; weak under 60. */
export function topicState(mastery: number): 'weak' | 'known' {
  return mastery < 60 ? 'weak' : 'known';
}

const LEVEL_NAME: Record<string, Record<Level, string>> = {
  tr: { beginner: 'Başlangıç', improving: 'Gelişiyor', very_good: 'Çok iyi', expert: 'Uzman' },
  en: { beginner: 'Beginner', improving: 'Improving', very_good: 'Very good', expert: 'Expert' },
  fa: { beginner: 'مبتدی', improving: 'در حال پیشرفت', very_good: 'خیلی خوب', expert: 'متخصص' },
  ar: { beginner: 'مبتدئ', improving: 'يتحسن', very_good: 'جيد جدًا', expert: 'خبير' },
};

/** The "exam result" notification in the app language (only for real exams, not the reader's section checks). */
export function resultNotice(lang: string, score: number, level: Level, right: number, total: number) {
  const l = LEVEL_NAME[lang] ? lang : 'tr';
  const s = Math.round(score);
  const name = LEVEL_NAME[l][level];
  switch (l) {
    case 'en': return { title: `Exam result: ${s}% · ${name}`, body: `${right} of ${total} questions right. Your weak topics went into the plan.` };
    case 'fa': return { title: `نتیجهٔ امتحان: ${s}٪ · ${name}`, body: `${right} از ${total} سؤال درست. موضوعات ضعیفت به برنامه اضافه شد.` };
    case 'ar': return { title: `نتيجة الامتحان: ${s}% · ${name}`, body: `${right} من ${total} أسئلة صحيحة. أُضيفت موضوعاتك الضعيفة إلى الخطة.` };
    default: return { title: `Sınav sonucun: %${s} · ${name}`, body: `${total} sorudan ${right} doğru. Zayıf konuların plana eklendi.` };
  }
}
