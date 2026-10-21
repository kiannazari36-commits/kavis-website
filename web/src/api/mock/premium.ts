// Premium (paywall) mock data from design/NewIPad.dc.html: free vs Premium table and the three plans (prices in TL as in the design).
import type { L10n, PremiumPlan } from '../types';

export const COMPARE_ROWS: [L10n, L10n, L10n][] = [
  [
    {
      "tr": "Ders yükleme",
      "en": "Lesson upload",
      "fa": "بارگذاری درس",
      "ar": "رفع الدرس"
    },
    {
      "tr": "Ayda 2",
      "en": "2 a month",
      "fa": "ماهی 2",
      "ar": "2 شهريًا"
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
      "tr": "Ayda 20",
      "en": "20 a month",
      "fa": "ماهی 20",
      "ar": "20 شهريًا"
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
    "price": "1.999,99 TL",
    "old": "3.599,88 TL",
    "sub": {
      "tr": "Ayda ~167 TL · %44 tasarruf",
      "en": "About 167 TL/month · save 44%",
      "fa": "حدود ۱۶۷ لیر در ماه · ۴۴٪ صرفه‌جویی",
      "ar": "حوالي 167 ليرة شهريًا · توفير 44%"
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
    },
    "price": "1.199,99 TL",
    "old": "1.499,95 TL",
    "sub": {
      "tr": "Ayda ~240 TL · %20 tasarruf",
      "en": "About 240 TL/month · save 20%",
      "fa": "حدود ۲۴۰ لیر در ماه · ۲۰٪ صرفه‌جویی",
      "ar": "حوالي 240 ليرة شهريًا · توفير 20%"
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
    "price": "299,99 TL",
    "old": "",
    "sub": {
      "tr": "İlk aboneler bu fiyatta kalır",
      "en": "Early subscribers keep this price",
      "fa": "مشترکان اول با همین قیمت می‌مانند",
      "ar": "المشتركون الأوائل يبقون على هذا السعر"
    },
    "tag": {
      "tr": "Lansmana özel",
      "en": "Launch offer",
      "fa": "ویژهٔ عرضه",
      "ar": "عرض الإطلاق"
    }
  }
];
