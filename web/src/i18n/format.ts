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
