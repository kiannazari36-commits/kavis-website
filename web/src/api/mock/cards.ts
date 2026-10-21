// Flash cards mock data from design/NewIPad.dc.html (Hypertension deck; the design shows 3 of 12 cards).
import type { FlashCard } from '../types';

export const HYPERTENSION_CARDS: FlashCard[] = [
  {
    "q": {
      "tr": "Tiyazid diüretiklerin zorunlu kontrendikasyonu nedir?",
      "en": "What is the compelling contraindication of thiazide diuretics?",
      "fa": "منع مصرف قطعی دیورتیک‌های تیازیدی چیست؟",
      "ar": "ما هو مضاد الاستطباب المطلق لمدرات البول الثيازيدية؟"
    },
    "a": {
      "tr": "Gut",
      "en": "Gout",
      "fa": "نقرس",
      "ar": "النقرس"
    },
    "note": {
      "tr": "Tiyazidler serum ürik asit düzeyini artırır.",
      "en": "Thiazides raise serum uric acid.",
      "fa": "تیازیدها اسید اوریک سرم را بالا می‌برند.",
      "ar": "ترفع الثيازيدات حمض اليوريك في المصل."
    },
    "page": 14
  },
  {
    "q": {
      "tr": "Alfa-1 blokerlerin ilk dozundan sonra ne görülebilir?",
      "en": "What can occur after the first dose of alpha-1 blockers?",
      "fa": "پس از دوز اول مسدودکننده‌های آلفا-1 چه ممکن است دیده شود؟",
      "ar": "ماذا قد يحدث بعد الجرعة الأولى من حاصرات ألفا-1؟"
    },
    "a": {
      "tr": "Ortostatik hipotansiyon",
      "en": "Orthostatic hypotension",
      "fa": "افت فشار خون وضعیتی",
      "ar": "هبوط الضغط الانتصابي"
    },
    "note": {
      "tr": "Bu yüzden ilk dozun yatmadan önce alınması önerilir.",
      "en": "That's why the first dose is recommended at bedtime.",
      "fa": "به همین دلیل توصیه می‌شود دوز اول قبل از خواب مصرف شود.",
      "ar": "لذلك يُنصح بأخذ الجرعة الأولى قبل النوم."
    },
    "page": 13
  },
  {
    "q": {
      "tr": "ACE inhibitörlerine bağlı kuru öksürük neyin birikimiyle ilişkilidir?",
      "en": "Dry cough from ACE inhibitors is linked to the buildup of what?",
      "fa": "سرفهٔ خشک ناشی از مهارکننده‌های ACE با تجمع چه چیزی مرتبط است؟",
      "ar": "يرتبط السعال الجاف الناتج عن مثبطات ACE بتراكم ماذا؟"
    },
    "a": {
      "tr": "Bradikinin",
      "en": "Bradykinin",
      "fa": "برادی‌کینین",
      "ar": "البراديكينين"
    },
    "note": {
      "tr": "ACE inhibitörleri nadiren anjiyoödem de yapabilir.",
      "en": "ACE inhibitors can also rarely cause angioedema.",
      "fa": "مهارکننده‌های ACE به‌ندرت آنژیوادم هم ایجاد می‌کنند.",
      "ar": "قد تسبب مثبطات ACE نادرًا الوذمة الوعائية أيضًا."
    },
    "page": 13
  }
];
