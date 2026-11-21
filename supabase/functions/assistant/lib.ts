// Pure helpers of the assistant (no database, no AI): which words to search, and which text pieces fit best.

// Very common words that do not help finding the right page (Turkish and English).
const STOP = new Set(
  'acaba ama ancak bir biri bu bunu bunun da de daha diye en gibi hangi hangisi her için ile ise kadar ki mi mu mü mı ne neden nedir nasıl niçin o olan olarak olur sonra şu ve veya ya yani the and for what which why how does are with from that this into about'.split(' '),
);

/** Search words of a question: letters only, at least 3 characters, no common words, at most 8. */
export function queryTerms(question: string): string[] {
  const words = question.toLocaleLowerCase('tr').match(/[\p{L}\p{N}]+/gu) ?? [];
  return [...new Set(words.filter((w) => w.length >= 3 && !STOP.has(w)))].slice(0, 8);
}

/**
 * Postgres full-text query that matches any of the words. Long words are cut to their first 6 letters with a
 * prefix match, so Turkish endings still match ("hipertansiyonda" finds "hipertansiyon").
 */
export function tsQuery(terms: string[]): string {
  return terms.map((w) => `${w.length > 6 ? w.slice(0, 6) : w}:*`).join(' | ');
}

/** Orders text pieces by how many of the search words they contain (more different words first). */
export function rankChunks<T extends { text: string }>(chunks: T[], terms: string[], limit: number): T[] {
  const stems = terms.map((w) => (w.length > 6 ? w.slice(0, 6) : w));
  const score = (text: string) => {
    const t = text.toLocaleLowerCase('tr');
    return stems.reduce((a, s) => a + (t.includes(s) ? 1 : 0), 0);
  };
  return chunks
    .map((c, i) => ({ c, s: score(c.text), i }))
    .filter((x) => x.s > 0)
    .sort((a, b) => b.s - a.s || a.i - b.i)
    .slice(0, limit)
    .map((x) => x.c);
}

/**
 * The whole text of one lesson, page by page, for the assistant — or null when it is longer than maxChars
 * (then only the open pages and the best search pieces are sent).
 */
export function lessonText(chunks: { page: number | null; text: string }[], maxChars: number): string | null {
  const pages = [...chunks].sort((a, b) => (a.page ?? 0) - (b.page ?? 0)).map((c) => `[Page ${c.page ?? '?'}]\n${c.text.trim()}`);
  const text = pages.join('\n\n');
  return text.length <= maxChars ? text : null;
}

/**
 * List price in US dollars per million tokens: input, output, cache write (5 minutes), cache read.
 * Sonnet 5.5: $2 / $10 / $2.50 / $0.20. Haiku 5.5: $0.10 / $0.50 / $0.125 / $0.01.
 */
const PRICES: Record<string, [number, number, number, number]> = {
  'claude-sonnet-5-5': [2, 10, 2.5, 0.2],
  'claude-haiku-5-5': [0.1, 0.5, 0.125, 0.01],
};
export const costUsd = (input: number, output: number, cacheWrite = 0, cacheRead = 0, model = 'claude-sonnet-5-5') => {
  const [i, o, w, r] = PRICES[model] ?? PRICES['claude-sonnet-5-5'];
  return Math.round(((input * i + output * o + cacheWrite * w + cacheRead * r) / 1_000_000) * 10000) / 10000;
};

/**
 * The streamed answer ends with one line "SOURCES: [2, 5] OUTSIDE: no". This splits it off: the answer text, the
 * source numbers and whether general knowledge was used. A missing line gives no sources.
 */
export function splitTail(text: string): { answer: string; sources: number[]; outside: boolean } {
  const at = text.lastIndexOf('SOURCES:');
  // Bold marks (**) are dropped: the apps show plain text.
  const plain = (x: string) => x.replace(/\*\*/g, '').trim();
  if (at < 0) return { answer: plain(text), sources: [], outside: false };
  const tail = text.slice(at);
  const nums = (tail.match(/\[([^\]]*)\]/)?.[1] ?? '').split(/[,\s]+/).map(Number).filter((n) => Number.isInteger(n) && n > 0);
  return { answer: plain(text.slice(0, at)), sources: [...new Set(nums)], outside: /OUTSIDE:\s*yes/i.test(tail) };
}

export type AnswerLang = 'tr' | 'en' | 'fa' | 'ar';
export const ANSWER_LANG_NAMES: Record<AnswerLang, string> = { tr: 'Turkish', en: 'English', fa: 'Persian', ar: 'Arabic' };
/** The label that marks what did not come from the student's PDFs, in the answer language ("AI + research"). */
export const OUTSIDE_LABELS: Record<AnswerLang, string> = { tr: 'PDF DIŞI BİLGİ', en: 'OUTSIDE YOUR PDF', fa: 'اطلاعات خارج از PDF', ar: 'معلومات من خارج ملف PDF' };

const TR_WORDS = new Set('nedir nasıl neden niçin için bir ve veya ile mi mı mu mü hangi hangisi olan nedenle anlat anlatır açıkla özetle özet bunu bunun şunu şu bu bana bende hoca hocanın vurguladı vurgulanan sayfa sayfayı ders dersin konu konuyu konular nelerdir yapar yapılır göre kadar gibi değil var yok olur çok daha tablo cetvel zayıf kart ekle çözdür'.split(' '));
const EN_WORDS = new Set('what the is are how why explain summarize summarise this page of and does do can which when where who with for from that about teacher emphasize emphasized topic lesson table give list me my'.split(' '));

/**
 * The language the answer must be written in. The language of the question wins (Persian and Arabic by script, Persian
 * by its own letters; Turkish and English by letters and common words); when the question gives no clear sign (a
 * single term, an "ACE?" question), the student's app language `lang` is used. Never left to the model's own guess.
 */
export function answerLang(question: string, lang: string): AnswerLang {
  const fallback: AnswerLang = lang === 'en' || lang === 'fa' || lang === 'ar' ? lang : 'tr';
  const arabic = (question.match(/\p{Script=Arabic}/gu) ?? []).length;
  const latin = (question.match(/[A-Za-zçğıöşüÇĞİÖŞÜ]/g) ?? []).length;
  if (arabic > latin) {
    if (/[پچژگ]/.test(question) || /(?:^|\s)(?:چیست|چرا|چگونه|است|را|این|برای|توضیح)(?:\s|$|؟)/.test(question)) return 'fa';
    if (/[يكةى]/.test(question)) return 'ar';
    return fallback === 'fa' ? 'fa' : 'ar';
  }
  if (!latin) return fallback;
  const words = question.toLocaleLowerCase('tr').match(/[\p{L}]+/gu) ?? [];
  let tr = (question.match(/[çğıöşüÇĞİÖŞÜ]/g) ?? []).length ? 2 : 0;
  let en = 0;
  for (const w of words) {
    if (TR_WORDS.has(w)) tr++;
    if (EN_WORDS.has(w)) en++;
  }
  if (tr > en) return 'tr';
  if (en > tr) return 'en';
  return fallback;
}
