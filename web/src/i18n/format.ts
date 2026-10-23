import type { Lang } from './I18nProvider';

// Number and count formats, following the wording in design/DeskApp.dc.html (k102, k108, k110…).

const FA_DIGITS = '۰۱۲۳۴۵۶۷۸۹';

/** Persian uses Persian digits; the other languages use 0–9. */
export function num(n: number | string, lang: Lang) {
  const s = String(n);
  return lang === 'fa' ? s.replace(/\d/g, (d) => FA_DIGITS[+d]) : s;
}

export function percent(n: number, lang: Lang) {
  if (lang === 'tr') return `%${n}`;
  if (lang === 'fa') return `٪${num(n, lang)}`;
  return `${n}%`;
}

export function pdfCount(n: number, lang: Lang) {
  switch (lang) {
    case 'en':
      return n === 1 ? '1 PDF' : `${n} PDFs`;
    case 'ar':
      return n === 1 ? 'ملف واحد' : n <= 10 ? `${n} ملفات` : `${n} ملفًا`;
    default:
      return `${num(n, lang)} PDF`;
  }
}

/** 465 → "7 h 45 min" (en), "7 sa 45 dk" (tr), "۷ ساعت ۴۵ دقیقه" (fa), "7 س 45 د" (ar). */
export function duration(minutes: number, lang: Lang) {
  const unit = { tr: ['sa', 'dk'], en: ['h', 'min'], fa: ['ساعت', 'دقیقه'], ar: ['س', 'د'] }[lang];
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  const parts = [];
  if (h) parts.push(`${num(h, lang)} ${unit[0]}`);
  if (m || !h) parts.push(`${num(m, lang)} ${unit[1]}`);
  return parts.join(' ');
}

export function rank(n: number, lang: Lang) {
  return { tr: `Sıralama #${n}`, en: `Rank #${n}`, fa: `رتبه ${num(n, lang)}`, ar: `الترتيب ${n}` }[lang];
}

/** Header line on "My Courses": term · courses · PDFs · hours studied. */
export function termSummary(courses: number, pdfs: number, hours: number, lang: Lang) {
  const term = num('2026–2027', lang);
  switch (lang) {
    case 'tr':
      return `${term} · ${courses} ders · ${pdfs} PDF · ${hours} saat çalışma`;
    case 'en':
      return `${term} · ${courses} courses · ${pdfs} PDFs · ${hours} hours studied`;
    case 'fa':
      return `${term} · ${num(courses, lang)} درس · ${num(pdfs, lang)} PDF · ${num(hours, lang)} ساعت مطالعه`;
    case 'ar':
      return `${term} · ${courses} دروس · ${pdfs} ملف PDF · ${hours} ساعة دراسة`;
  }
}

/** 1.5 → "1,5 sa" (tr) / "1.5 h" (en). */
export function hoursLabel(h: number, lang: Lang, t: (k: string) => string) {
  const v = h % 1 && (lang === 'tr' || lang === 'fa') ? String(h).replace('.', ',') : String(h);
  return num(v, lang) + t('hour');
}

const EXAM_KIND: Record<string, Record<Lang, string>> = {
  midterm: { tr: 'Vize', en: 'Midterm', fa: 'میان‌ترم', ar: 'النصفي' },
  final: { tr: 'Final', en: 'Final', fa: 'پایان‌ترم', ar: 'النهائي' },
  makeup: { tr: 'Bütünleme', en: 'Make-up', fa: 'ترمیمی', ar: 'الإكمال' },
  quiz: { tr: 'Quiz', en: 'Quiz', fa: 'کوئیز', ar: 'اختبار قصير' },
  other: { tr: 'Sınav', en: 'Exam', fa: 'امتحان', ar: 'امتحان' },
};
// Gregorian calendar and Latin digits for Arabic; Persian keeps Persian digits (as in the design: "۱۹ اکتبر").
const DATE_LOCALE: Record<Lang, string> = { tr: 'tr-TR', en: 'en-US', fa: 'fa-IR-u-ca-gregory', ar: 'ar-u-ca-gregory-nu-latn' };

/** "2026-10-19" → "19 Ekim" (tr), "Oct 19" (en), "۱۹ اکتبر" (fa), "19 أكتوبر" (ar). */
export function shortDate(iso: string, lang: Lang) {
  return new Intl.DateTimeFormat(DATE_LOCALE[lang], { day: 'numeric', month: lang === 'en' ? 'short' : 'long', timeZone: 'UTC' }).format(
    new Date(`${iso}T00:00:00Z`),
  );
}

/** Next exam tag: "Vize · 19 Ekim" / "Midterm · Oct 19". */
export function examLabel(kind: string | undefined, iso: string | undefined, lang: Lang) {
  if (!iso) return '';
  return `${EXAM_KIND[kind ?? 'other'][lang]} · ${shortDate(iso, lang)}`;
}

/** 4 → "4. sınıf" (tr), "year 4" (en), "سال ۴" (fa), "السنة 4" (ar). */
export function classYear(n: number, lang: Lang) {
  return { tr: `${n}. sınıf`, en: `year ${n}`, fa: `سال ${num(n, lang)}`, ar: `السنة ${n}` }[lang];
}

/** "Eczacılık · 4. sınıf" — the department is the student's own text. */
export function studyLine(department: string, year: number | null, lang: Lang) {
  return [department, year ? classYear(year, lang) : ''].filter(Boolean).join(' · ');
}

export function courseCount(n: number, lang: Lang) {
  return { tr: `${n} ders`, en: n === 1 ? '1 course' : `${n} courses`, fa: `${num(n, lang)} درس`, ar: n === 1 ? 'درس واحد' : `${n} دروس` }[lang];
}

/** Last time a device was used: "Bugün 09:12" / "Today 09:12", "Dün 21:40", else "19 Ekim 21:40". */
export function lastSeen(iso: string, lang: Lang) {
  const d = new Date(iso);
  const time = num(`${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`, lang);
  const day = (x: Date) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  const diff = Math.round((day(new Date()) - day(d)) / 86_400_000);
  if (diff === 0) return `${{ tr: 'Bugün', en: 'Today', fa: 'امروز', ar: 'اليوم' }[lang]} ${time}`;
  if (diff === 1) return `${{ tr: 'Dün', en: 'Yesterday', fa: 'دیروز', ar: 'أمس' }[lang]} ${time}`;
  const date = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  return `${shortDate(date, lang)} ${time}`;
}
