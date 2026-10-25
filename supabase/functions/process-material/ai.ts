// What process-material asks the AI for one batch of pages, and the exact JSON shape of the answer.

export type AiPage = { page: number; section_title: string; tag: 'definition' | 'dose' | 'side_effect' | 'special' | 'emergency' | 'general'; heading: string };
export type Expl = { name: string; kind: string; text: string };
export type AiTerm = { surface: string; page: number; explanations: { tr: Expl; en: Expl; fa: Expl; ar: Expl } };
export type AiTopic = { title: string; page_from: number; page_to: number; importance: number };
export type AiCard = { question: string; answer: string; note: string; page: number };
export type AiQuestion = {
  style: 'case' | 'side_effects' | 'dose' | 'knowledge' | 'structure';
  text: string;
  options: string[];
  answer_index: number;
  explanation: string;
  page: number;
  hints: string[];
};
export type AiBatch = { language: 'tr' | 'en' | 'fa' | 'ar' | 'other'; pages: AiPage[]; terms: AiTerm[]; topics: AiTopic[]; cards: AiCard[]; questions: AiQuestion[] };

const str = { type: 'string' };
const int = { type: 'integer' };
const obj = (properties: Record<string, unknown>) => ({ type: 'object', properties, required: Object.keys(properties), additionalProperties: false });
const expl = obj({ name: str, kind: str, text: str });

export const SCHEMA = obj({
  language: { type: 'string', enum: ['tr', 'en', 'fa', 'ar', 'other'] },
  pages: { type: 'array', items: obj({ page: int, section_title: str, tag: { type: 'string', enum: ['definition', 'dose', 'side_effect', 'special', 'emergency', 'general'] }, heading: str }) },
  terms: { type: 'array', items: obj({ surface: str, page: int, explanations: obj({ tr: expl, en: expl, fa: expl, ar: expl }) }) },
  topics: { type: 'array', items: obj({ title: str, page_from: int, page_to: int, importance: int }) },
  cards: { type: 'array', items: obj({ question: str, answer: str, note: str, page: int }) },
  questions: {
    type: 'array',
    items: obj({
      style: { type: 'string', enum: ['case', 'side_effects', 'dose', 'knowledge', 'structure'] },
      text: str,
      options: { type: 'array', items: str },
      answer_index: int,
      explanation: str,
      page: int,
      hints: { type: 'array', items: str },
    }),
  },
});

export const SYSTEM = `You prepare a university lecture (a teacher's PDF) for a study app used by students (pharmacy, medicine and other subjects).
You receive the PDF text of some pages, split into numbered paragraphs. The teacher's text is shown to the student exactly as written; you never rewrite it. You add structure and study material around it.

Return JSON with:
- language: the language of the teacher's text.
- pages: one entry per page you received. section_title: a short title (2-5 words, in the text's language) when a new section of the lecture starts on this page, otherwise "". The first page you receive starts a section only if its content starts something new. tag: what the page is mainly about (definition, dose = treatment/dosing, side_effect, special = special populations or cases, emergency, general). heading: the page's own heading line copied character for character from a paragraph, or "" if the page has none.
- terms: the hard technical words a student would tap for an explanation (about one per page, at most 8). surface: copied exactly as it appears in the text (same spelling and inflection). explanations in Turkish (tr), English (en), Persian (fa) and Arabic (ar): name = the term in that language, kind = 1-3 words (e.g. "drug group", "side effect", "concept"), text = one or two plain sentences a second-year student understands.
- topics: the main topics of these pages with their page range and importance (3 = central/exam-relevant, 2 = important, 1 = background).
- cards: flash cards, about one per page (at most 10). question and answer short; note = one sentence that helps remember.
- questions: exam-style multiple-choice questions, about one per two pages (at most 5), each answerable from these pages. Prefer short patient cases where the topic allows (style "case"). Exactly 5 options, answer_index 0-4, explanation = why the answer is right (1-2 sentences), and 3 hints that help the student THINK their way to the answer: hint 1 = the key concept or property to recall (e.g. a rule, a mnemonic, a mechanism); hint 2 = something that rules out some options; hint 3 = narrows it down to about two options. Hints must NEVER mention page numbers or where to look ("see page 4", "check the table" are not hints), and must NEVER state the answer or contain the text of the correct option; the student still has to choose.

Rules: use only facts from the given text for cards and questions; term explanations may use general textbook knowledge. Write cards, notes, topics, questions, options, explanations and hints in the CONTENT LANGUAGE given by the user message. Page numbers are the PDF page numbers shown in the input. If the pages contain no teachable content (title page, references, blank), return empty arrays for that material.`;

/**
 * The user message: lesson, content language, the lecturer's question style when it is known (from their old
 * questions, "Soru örneklerim"), and the numbered paragraphs of each page.
 */
export function userMessage(title: string, course: string, contentLang: string, pages: { page: number; paragraphs: string[] }[], style = '') {
  const body = pages.map((p) => `[Page ${p.page}]\n${p.paragraphs.map((t, i) => `¶${i + 1} ${t}`).join('\n')}`).join('\n\n');
  const styleLine = style ? `LECTURER'S QUESTION STYLE (write the questions like this): ${style}\n` : '';
  return `Lesson: ${title}\nCourse: ${course || '-'}\nCONTENT LANGUAGE: ${contentLang}\n${styleLine}\n${body}`;
}

type Style = { distribution: { types?: Record<string, number>; options?: number; patterns?: string[] }; use_in_quizzes: boolean } | null;

/** The lecturer's style in one line for the AI, or "" when it is unknown or switched off for exams. */
export function styleNote(style: Style) {
  if (!style || !style.use_in_quizzes || !style.distribution?.types) return '';
  const types = Object.entries(style.distribution.types)
    .filter(([, v]) => v > 0)
    .map(([k, v]) => `${k} ${v}%`)
    .join(', ');
  return [`question types ${types}`, `${style.distribution.options ?? 5} options`, ...(style.distribution.patterns ?? [])].join('; ');
}

const LANG_NAMES: Record<string, string> = { tr: 'Turkish', en: 'English', fa: 'Persian', ar: 'Arabic' };

/** Content language (CLAUDE.md): course setting, then the general setting; "pdf" = the language of the text. */
export function contentLanguage(courseOverride: string | null, setting: string, appLang: string) {
  const choice = courseOverride ?? setting;
  if (choice === 'pdf') return 'the same language as the teacher\'s text';
  if (choice === 'app') return LANG_NAMES[appLang] ?? 'Turkish';
  return LANG_NAMES[choice] ?? 'the same language as the teacher\'s text';
}
