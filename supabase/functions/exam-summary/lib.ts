// Pure helpers of exam-summary (no network): the texts in four languages and the reading page built from the AI's parts.

export type Lang = 'tr' | 'en' | 'fa' | 'ar';
export type StyleKey = 'case' | 'side_effects' | 'dose' | 'knowledge' | 'structure';

export const WORDS: Record<Lang, { title: string; overview: string; explain: string; asked: string; shape: string; times: string; cols: [string, string, string, string]; pdf: string; page: string; style: Record<StyleKey, string> }> = {
  tr: { title: 'Sınav özeti', overview: 'Bir bakışta: hangi PDF’ten, hangi konu, hangi tarz', explain: 'Konu anlatımı', asked: 'Sınavda sorulan noktalar', shape: 'Sorulan şekil', times: 'soru', cols: ['Konu', 'PDF · sayfa', 'Soru tarzı', 'Soru'], pdf: 'PDF', page: 's.', style: { case: 'Hasta vakası', side_effects: 'Yan etki', dose: 'Mekanizma / doz', knowledge: 'Bilgi', structure: 'Yapı' } },
  en: { title: 'Exam summary', overview: 'At a glance: which PDF, which topic, which style', explain: 'Topic explained', asked: 'Points asked in the exam', shape: 'How it was asked', times: 'questions', cols: ['Topic', 'PDF · page', 'Question style', 'Questions'], pdf: 'PDF', page: 'p.', style: { case: 'Patient case', side_effects: 'Side effect', dose: 'Mechanism / dose', knowledge: 'Knowledge', structure: 'Structure' } },
  fa: { title: 'خلاصهٔ امتحان', overview: 'در یک نگاه: کدام PDF، کدام مبحث، کدام سبک', explain: 'شرح مبحث', asked: 'نکته‌های پرسیده‌شده در امتحان', shape: 'شکل پرسش', times: 'سؤال', cols: ['مبحث', 'PDF · صفحه', 'سبک سؤال', 'سؤال'], pdf: 'PDF', page: 'ص.', style: { case: 'مورد بیمار', side_effects: 'عارضهٔ جانبی', dose: 'مکانیسم / دوز', knowledge: 'دانش', structure: 'ساختار' } },
  ar: { title: 'ملخص الامتحان', overview: 'نظرة سريعة: أي ملف وأي موضوع وأي أسلوب', explain: 'شرح الموضوع', asked: 'النقاط المسؤول عنها في الامتحان', shape: 'شكل السؤال', times: 'أسئلة', cols: ['الموضوع', 'PDF · الصفحة', 'أسلوب السؤال', 'الأسئلة'], pdf: 'PDF', page: 'ص.', style: { case: 'حالة مريض', side_effects: 'أثر جانبي', dose: 'آلية / جرعة', knowledge: 'معلومة', structure: 'بنية' } },
};

export type Topic = {
  title: string;
  questions: number;
  lessonTitle: string;
  pageFrom: number;
  pageTo: number;
  styles: StyleKey[];
  points: string[];
  examples: string[];
  parts: { heading: string; text: string }[];
};

/** The reading page: page 1 is the overview, every topic is the next page. Sentences are selectable so the student can highlight them. */
export function buildDoc(lang: Lang, topics: Topic[]) {
  const w = WORDS[lang];
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
            topics.map((t) => `${t.title} — ${w.pdf}: ${t.lessonTitle}, ${w.page} ${t.pageFrom}-${t.pageTo} — ${t.styles.map((s) => w.style[s]).join(', ')} — ${t.questions} ${w.times}`),
          ),
          table: { head: [...w.cols], rows: topics.map((t) => [t.title, `${t.lessonTitle} · ${w.page} ${t.pageFrom}-${t.pageTo}`, t.styles.map((s) => w.style[s]).join(', '), String(t.questions)]) },
        },
      ],
    },
    ...topics.map((t, i) => ({
      title: t.title,
      blocks: [
        ...t.parts.map((p, k) => block(i + 2, k === 0 ? `${w.explain} · ${p.heading}` : p.heading, [p.text])),
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
  const overview = topics.map((t) => `${t.title} — ${t.lessonTitle}, ${w.page} ${t.pageFrom}-${t.pageTo}`).join('\n');
  return [
    { page: 1, text: `${w.overview}\n${overview}` },
    ...topics.map((t, i) => ({
      page: i + 2,
      text: [t.title, ...t.parts.map((p) => `${p.heading}\n${p.text}`), t.points.length ? `${w.asked}\n${t.points.join('\n')}` : '', t.examples.length ? `${w.shape}\n${t.examples.join('\n')}` : ''].filter(Boolean).join('\n\n'),
    })),
  ];
}
