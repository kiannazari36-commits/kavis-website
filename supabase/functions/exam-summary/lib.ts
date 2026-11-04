// Pure helpers of exam-summary (no network): the texts in four languages, finding a topic's pages in the lesson text,
// and the reading page built from the AI's parts.

export type Lang = 'tr' | 'en' | 'fa' | 'ar';
export type StyleKey = 'case' | 'side_effects' | 'dose' | 'knowledge' | 'structure';

export const WORDS: Record<Lang, { title: string; overview: string; explain: string; asked: string; shape: string; times: string; cols: [string, string, string, string]; pdf: string; page: string; notFound: string; skipped: string; sample: string; style: Record<StyleKey, string> }> = {
  tr: { title: 'Sınav özeti', overview: 'Bir bakışta: hangi PDF’ten, hangi konu, hangi tarz', explain: 'Konu anlatımı', asked: 'Sınavda sorulan noktalar', shape: 'Sorulan şekil', times: 'soru', cols: ['Konu', 'PDF · sayfa', 'Soru tarzı', 'Soru'], pdf: 'PDF', page: 's.', notFound: 'PDF’te bulunamadı', skipped: 'Konusu çıkarılamayan sorular', sample: 'Örnek', style: { case: 'Hasta vakası', side_effects: 'Yan etki', dose: 'Mekanizma / doz', knowledge: 'Bilgi', structure: 'Yapı' } },
  en: { title: 'Exam summary', overview: 'At a glance: which PDF, which topic, which style', explain: 'Topic explained', asked: 'Points asked in the exam', shape: 'How it was asked', times: 'questions', cols: ['Topic', 'PDF · page', 'Question style', 'Questions'], pdf: 'PDF', page: 'p.', notFound: 'Not found in the PDFs', skipped: 'Questions whose topic could not be read', sample: 'Sample', style: { case: 'Patient case', side_effects: 'Side effect', dose: 'Mechanism / dose', knowledge: 'Knowledge', structure: 'Structure' } },
  fa: { title: 'خلاصهٔ امتحان', overview: 'در یک نگاه: کدام PDF، کدام مبحث، کدام سبک', explain: 'شرح مبحث', asked: 'نکته‌های پرسیده‌شده در امتحان', shape: 'شکل پرسش', times: 'سؤال', cols: ['مبحث', 'PDF · صفحه', 'سبک سؤال', 'سؤال'], pdf: 'PDF', page: 'ص.', notFound: 'در PDFها پیدا نشد', skipped: 'سؤال‌هایی که مبحثشان خوانده نشد', sample: 'نمونه', style: { case: 'مورد بیمار', side_effects: 'عارضهٔ جانبی', dose: 'مکانیسم / دوز', knowledge: 'دانش', structure: 'ساختار' } },
  ar: { title: 'ملخص الامتحان', overview: 'نظرة سريعة: أي ملف وأي موضوع وأي أسلوب', explain: 'شرح الموضوع', asked: 'النقاط المسؤول عنها في الامتحان', shape: 'شكل السؤال', times: 'أسئلة', cols: ['الموضوع', 'PDF · الصفحة', 'أسلوب السؤال', 'الأسئلة'], pdf: 'PDF', page: 'ص.', notFound: 'لم يُعثر عليه في ملفات PDF', skipped: 'أسئلة تعذّر معرفة موضوعها', sample: 'نموذج', style: { case: 'حالة مريض', side_effects: 'أثر جانبي', dose: 'آلية / جرعة', knowledge: 'معلومة', structure: 'بنية' } },
};

export type Topic = {
  title: string;
  questions: number;
  lessonTitle: string;
  /** Lesson pages the explanation comes from; empty when the PDFs do not explain the topic. */
  pages: number[];
  styles: StyleKey[];
  points: string[];
  examples: string[];
  parts: { heading: string; text: string }[];
};

/** The reading page: page 1 is the overview, every topic is the next page. Sentences are selectable so the student can highlight them. */
export function buildDoc(lang: Lang, topics: Topic[], skipped: string[] = []) {
  const w = WORDS[lang];
  const where = (t: Topic) => (t.pages.length ? `${t.lessonTitle} · ${w.page} ${pageList(t.pages)}` : w.notFound);
  const sel = (text: string) => ({ selectable: true as const, text });
  const block = (page: number, heading: string, lines: string[]) => ({ pageFrom: page, pageTo: page, tag: 'general' as const, heading, paragraphs: lines.map(sel) });
  const sections = [
    {
      title: w.overview,
      blocks: [
        {
          ...block(
            1,
            w.overview,
            topics.map((t) => `${t.title} — ${t.pages.length ? `${w.pdf}: ${t.lessonTitle}, ${w.page} ${pageList(t.pages)}` : w.notFound} — ${t.styles.map((s) => w.style[s]).join(', ')} — ${t.questions} ${w.times}`),
          ),
          table: { head: [...w.cols], rows: topics.map((t) => [t.title, where(t), t.styles.map((s) => w.style[s]).join(', '), String(t.questions)]) },
        },
        ...(skipped.length ? [block(1, w.skipped, skipped)] : []),
      ],
    },
    ...topics.map((t, i) => ({
      title: t.title,
      blocks: [
        ...(t.parts.length ? t.parts.map((p, k) => block(i + 2, k === 0 ? `${w.explain} · ${p.heading}` : p.heading, [p.text])) : [block(i + 2, w.explain, [w.notFound])]),
        ...(t.points.length ? [block(i + 2, w.asked, t.points)] : []),
        ...(t.examples.length ? [block(i + 2, w.shape, t.examples)] : []),
      ],
    })),
  ];
  return { language: lang, grouped: true, sections };
}

/** Plain text per page, for the assistant's search (material_chunks). */
export function pageTexts(lang: Lang, topics: Topic[]) {
  const w = WORDS[lang];
  const overview = topics.map((t) => `${t.title} — ${t.pages.length ? `${t.lessonTitle}, ${w.page} ${pageList(t.pages)}` : w.notFound}`).join('\n');
  return [
    { page: 1, text: `${w.overview}\n${overview}` },
    ...topics.map((t, i) => ({
      page: i + 2,
      text: [t.title, ...(t.parts.length ? t.parts.map((p) => `${p.heading}\n${p.text}`) : [w.notFound]), t.points.length ? `${w.asked}\n${t.points.join('\n')}` : '', t.examples.length ? `${w.shape}\n${t.examples.join('\n')}` : ''].filter(Boolean).join('\n\n'),
    })),
  ];
}

/** Pages as a short list: [3, 4, 5, 12] → "3-5, 12". */
export function pageList(pages: number[]): string {
  const p = [...new Set(pages)].sort((a, b) => a - b);
  const out: string[] = [];
  for (let i = 0; i < p.length; i++) {
    let j = i;
    while (p[j + 1] === p[j] + 1) j++;
    out.push(j > i ? `${p[i]}-${p[j]}` : String(p[i]));
    i = j;
  }
  return out.join(', ');
}

// Very common words that do not help finding the right page (Turkish and English), as in the assistant.
const STOP = new Set(
  'acaba ama ancak bir biri bu bunu bunun da de daha diye en gibi hangi hangisi her için ile ise kadar ki mi mu mü mı ne neden nedir nasıl niçin o olan olarak olur sonra şu ve veya ya yani the and for what which why how does are with from that this into about'.split(' '),
);

/** Search words of a topic (its title and the AI's search words): letters only, at least 3 characters, at most 10. */
export function searchTerms(words: string[]): string[] {
  const all = words.join(' ').toLocaleLowerCase('tr').match(/[\p{L}\p{N}]+/gu) ?? [];
  return [...new Set(all.filter((w) => w.length >= 3 && !STOP.has(w)))].slice(0, 10);
}

const stem = (w: string) => (w.length > 6 ? w.slice(0, 6) : w);

/** Postgres full-text query matching any of the words; long words by their first 6 letters (Turkish endings). */
export const tsQuery = (terms: string[]) => terms.map((w) => `${stem(w)}:*`).join(' | ');

export type Chunk = { material_id: string; page: number | null; text: string };

/**
 * Where a topic is taught, found in the lesson text itself (not guessed): each page scores the number of different
 * search words on it; the lesson with the best pages wins (the AI's guess only breaks ties) and its best pages,
 * at most `max`, are returned. Null when no page has enough of the words.
 */
export function pickPages(chunks: Chunk[], terms: string[], guess: { materialId: string; from: number; to: number } | null, max = 5) {
  const stems = terms.map(stem);
  if (!stems.length) return null;
  const pages = new Map<string, { materialId: string; page: number; hit: Set<string> }>();
  for (const c of chunks) {
    if (c.page === null) continue;
    const key = `${c.material_id}:${c.page}`;
    const p = pages.get(key) ?? { materialId: c.material_id, page: c.page, hit: new Set<string>() };
    const t = c.text.toLocaleLowerCase('tr');
    for (const s of stems) if (t.includes(s)) p.hit.add(s);
    pages.set(key, p);
  }
  const need = stems.length === 1 ? 1 : 2;
  const near = (p: { materialId: string; page: number }) => !!guess && p.materialId === guess.materialId && p.page >= guess.from - 1 && p.page <= guess.to + 1;
  const scored = [...pages.values()].filter((p) => p.hit.size >= need).map((p) => ({ ...p, score: p.hit.size + (near(p) ? 0.5 : 0) }));
  if (!scored.length) return null;
  const byLesson = new Map<string, number[]>();
  for (const p of scored) byLesson.set(p.materialId, [...(byLesson.get(p.materialId) ?? []), p.score]);
  const lessonScore = (id: string) => (byLesson.get(id) ?? []).sort((a, b) => b - a).slice(0, 3).reduce((a, b) => a + b, 0);
  const best = [...byLesson.keys()].sort((a, b) => lessonScore(b) - lessonScore(a) || (a === guess?.materialId ? -1 : b === guess?.materialId ? 1 : 0))[0];
  const mine = scored.filter((p) => p.materialId === best).sort((a, b) => b.score - a.score || a.page - b.page);
  const top = mine[0].score;
  return {
    materialId: best,
    pages: mine.filter((p) => p.score >= Math.max(need, top * 0.6)).slice(0, max).map((p) => p.page).sort((a, b) => a - b),
  };
}

/** The lesson pages an explanation cites, like "(s. 12)" / "(p. 12)" / "(ص. 12)", among the pages it was given; null when none. */
export function citedPages(parts: { text: string }[], given: number[]): number[] | null {
  const found = new Set<number>();
  for (const p of parts) for (const m of p.text.matchAll(/(?<!\p{L})(?:s|p|ص)\.\s*(\d+)/gu)) if (given.includes(Number(m[1]))) found.add(Number(m[1]));
  return found.size ? [...found].sort((a, b) => a - b) : null;
}
