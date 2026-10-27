// Premium page content (fixed text, not student data) from design/NewIPad.dc.html: 3-day trial vs Premium table and the three plans.
// There is no monthly free plan: the left column is the trial (CLAUDE.md).
// No prices here: Apple sets the local price per country (CLAUDE.md).
import type { L10n, PremiumPlan } from './types';

export const COMPARE_ROWS: [L10n, L10n, L10n][] = [
  [
    {
      "tr": "Ders yükleme",
      "en": "Lesson upload",
      "fa": "بارگذاری درس",
      "ar": "رفع الدرس"
    },
    {
      "tr": "2 PDF",
      "en": "2 PDFs",
      "fa": "۲ PDF",
      "ar": "ملفا PDF"
    },
    {
      "tr": "Sınırsız*",
      "en": "Unlimited*",
      "fa": "نامحدود*",
      "ar": "بلا حدود*"
    }
  ],
  [
    {
      "tr": "Asistan soruları",
      "en": "Assistant questions",
      "fa": "سؤال‌های دستیار",
      "ar": "أسئلة المساعد"
    },
    {
      "tr": "60 soru",
      "en": "60 questions",
      "fa": "۶۰ سؤال",
      "ar": "60 سؤالًا"
    },
    {
      "tr": "Sınırsız*",
      "en": "Unlimited*",
      "fa": "نامحدود*",
      "ar": "بلا حدود*"
    }
  ],
  [
    {
      "tr": "Sesli anlatım ve “Ben anlatayım”",
      "en": "Audio lessons and “Let me explain”",
      "fa": "توضیح صوتی و «بگذار توضیح بدهم»",
      "ar": "الشرح الصوتي و«دعني أشرح»"
    },
    {
      "tr": "Sınırlı",
      "en": "Limited",
      "fa": "محدود",
      "ar": "محدود"
    },
    {
      "tr": "✓",
      "en": "✓",
      "fa": "✓",
      "ar": "✓"
    }
  ],
  [
    {
      "tr": "Sınava özel özet ve sorular",
      "en": "Exam-focused summary and questions",
      "fa": "خلاصه و سؤال‌های ویژه امتحان",
      "ar": "ملخص وأسئلة خاصة بالامتحان"
    },
    {
      "tr": "✓",
      "en": "✓",
      "fa": "✓",
      "ar": "✓"
    },
    {
      "tr": "✓",
      "en": "✓",
      "fa": "✓",
      "ar": "✓"
    }
  ],
  [
    {
      "tr": "Çevrimdışı okuma ve tekrar (internetsiz)",
      "en": "Offline reading and review",
      "fa": "مطالعه و مرور آفلاین",
      "ar": "القراءة والمراجعة دون اتصال"
    },
    {
      "tr": "✓",
      "en": "✓",
      "fa": "✓",
      "ar": "✓"
    },
    {
      "tr": "✓",
      "en": "✓",
      "fa": "✓",
      "ar": "✓"
    }
  ],
  [
    {
      "tr": "Ders paylaşma",
      "en": "Lesson sharing",
      "fa": "اشتراک‌گذاری درس",
      "ar": "مشاركة الدرس"
    },
    {
      "tr": "—",
      "en": "—",
      "fa": "—",
      "ar": "—"
    },
    {
      "tr": "✓",
      "en": "✓",
      "fa": "✓",
      "ar": "✓"
    }
  ]
];

export const PREMIUM_PLANS: PremiumPlan[] = [
  {
    "id": "year",
    "title": {
      "tr": "Yıllık",
      "en": "Yearly",
      "fa": "سالانه",
      "ar": "سنوي"
    },
    "tag": {
      "tr": "En avantajlı",
      "en": "Best value",
      "fa": "به‌صرفه‌ترین",
      "ar": "الأوفر"
    }
  },
  {
    "id": "term",
    "title": {
      "tr": "Dönemlik · 5 ay",
      "en": "5-month term",
      "fa": "ترمی · ۵ ماه",
      "ar": "فصلي · 5 أشهر"
    }
  },
  {
    "id": "month",
    "title": {
      "tr": "Aylık",
      "en": "Monthly",
      "fa": "ماهانه",
      "ar": "شهري"
    },
    "tag": {
      "tr": "Lansmana özel",
      "en": "Launch offer",
      "fa": "ویژهٔ عرضه",
      "ar": "عرض الإطلاق"
    }
  }
];
