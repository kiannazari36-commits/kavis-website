import { supabase } from './supabase';
import { currentUser } from './auth';

// "Soru örneklerim": the lecturer's old or class questions per course (table question_samples, files in the private
// "question-samples" bucket). The server reads them and finds the lecturer's question style (Edge analyze-style →
// teacher_styles), which then shapes new questions (process-material, Edge generate-quiz).

export type Sample = { id: string; kind: 'photo' | 'pdf' | 'text'; title: string; questions: number | null; added: string };
export type QuestionType = 'case' | 'side_effects' | 'dose' | 'knowledge' | 'structure';
export type TeacherStyle = {
  types: Record<QuestionType, number>;
  options: number;
  patterns: string[];
  questions: number;
  topTopics: { title: string; count: number }[];
  useInQuizzes: boolean;
  useInCards: boolean;
  useInSummaries: boolean;
  analyzedAt: string;
};

export async function listSamples(courseId: string): Promise<Sample[]> {
  const { data, error } = await supabase.from('question_samples').select('id, kind, title, question_count, created_at').eq('course_id', courseId).order('created_at', { ascending: false });
  if (error) console.error('listSamples', error);
  return (data ?? []).map((r) => ({ id: r.id, kind: r.kind, title: r.title ?? '', questions: r.question_count, added: r.created_at }));
}

/** Photos or PDFs of questions: each file is one sample (at most 15 MB). */
export async function addSampleFiles(courseId: string, files: File[]) {
  const user = currentUser();
  if (!user) return false;
  for (const f of files) {
    const pdf = f.type === 'application/pdf' || f.name.toLowerCase().endsWith('.pdf');
    const ext = pdf ? 'pdf' : f.type === 'image/png' ? 'png' : f.type === 'image/webp' ? 'webp' : 'jpg';
    const path = `${user.id}/${courseId}/${crypto.randomUUID()}.${ext}`;
    const up = await supabase.storage.from('question-samples').upload(path, f, { contentType: pdf ? 'application/pdf' : f.type || 'image/jpeg' });
    if (up.error) {
      console.error('sample upload', up.error);
      return false;
    }
    const row = await supabase.from('question_samples').insert({ user_id: user.id, course_id: courseId, kind: pdf ? 'pdf' : 'photo', title: f.name, storage_path: path });
    if (row.error) {
      console.error('question_samples', row.error);
      await supabase.storage.from('question-samples').remove([path]);
      return false;
    }
  }
  return true;
}

/** Questions typed or pasted ("Yazarak"). */
export async function addSampleText(courseId: string, title: string, text: string) {
  const user = currentUser();
  if (!user) return false;
  const { error } = await supabase.from('question_samples').insert({ user_id: user.id, course_id: courseId, kind: 'text', title: title.trim() || null, text: text.trim() });
  if (error) console.error('question_samples', error);
  return !error;
}

export async function deleteSample(id: string) {
  const { data } = await supabase.from('question_samples').select('storage_path').eq('id', id).maybeSingle();
  const { error } = await supabase.from('question_samples').delete().eq('id', id);
  if (error) console.error('deleteSample', error);
  if (!error && data?.storage_path) await supabase.storage.from('question-samples').remove([data.storage_path]);
  return !error;
}

type StyleRow = {
  distribution: { types?: Record<QuestionType, number>; options?: number; patterns?: string[]; questions?: number };
  top_topics: { title: string; count: number }[];
  use_in_quizzes: boolean;
  use_in_cards: boolean;
  use_in_summaries: boolean;
  analyzed_at: string;
};
const toStyle = (r: StyleRow): TeacherStyle => ({
  types: { case: 0, side_effects: 0, dose: 0, knowledge: 0, structure: 0, ...(r.distribution.types ?? {}) },
  options: r.distribution.options ?? 5,
  patterns: r.distribution.patterns ?? [],
  questions: r.distribution.questions ?? 0,
  topTopics: r.top_topics ?? [],
  useInQuizzes: r.use_in_quizzes,
  useInCards: r.use_in_cards,
  useInSummaries: r.use_in_summaries,
  analyzedAt: r.analyzed_at,
});

export async function getStyle(courseId: string): Promise<TeacherStyle | null> {
  const { data, error } = await supabase
    .from('teacher_styles')
    .select('distribution, top_topics, use_in_quizzes, use_in_cards, use_in_summaries, analyzed_at')
    .eq('course_id', courseId)
    .maybeSingle<StyleRow>();
  if (error) console.error('getStyle', error);
  return data ? toStyle(data) : null;
}

type Fail = { error: 'locked' | 'budget' | 'failed' };
const fail = (error: unknown): Fail => {
  const status = (error as { context?: { status?: number } }).context?.status;
  return { error: status === 403 ? 'locked' : status === 429 ? 'budget' : 'failed' };
};

/** "Hocanın tarzını çıkar": the server reads all samples of the course (AI). */
export async function analyzeStyle(courseId: string): Promise<TeacherStyle | Fail> {
  const { data, error } = await supabase.functions.invoke('analyze-style', { body: { course_id: courseId } });
  if (error) return fail(error);
  return toStyle(data as StyleRow);
}

/** "Sınavlarda / Kartlarda / Özetlerde": where the style is used (the student may change these). */
export async function setStyleUse(courseId: string, field: 'use_in_quizzes' | 'use_in_cards' | 'use_in_summaries', on: boolean) {
  const { error } = await supabase.from('teacher_styles').update({ [field]: on }).eq('course_id', courseId);
  if (error) console.error('setStyleUse', error);
}

/** "Hocanın tarzında yeni sorular": a new exam pack for the course (Edge generate-quiz, AI). */
export async function generateExamPack(courseId: string, count = 10): Promise<{ questions: number } | Fail> {
  const { data, error } = await supabase.functions.invoke('generate-quiz', { body: { course_id: courseId, count } });
  if (error) return fail(error);
  return { questions: (data as { questions: number }).questions };
}
