// Progress mock data from design/NewIPad.dc.html ("İlerleme"): course ranking, minutes per weekday, weak topics.
import type { CourseRank, WeakTopic } from '../types';

export const COURSE_RANKING: CourseRank[] = [
  {
    "courseId": "pharm-tech-3",
    "name": {
      "tr": "Farm. Tek. III",
      "en": "Pharm. Tech. III",
      "fa": "فناوری دارویی III",
      "ar": "التقنية الصيدلانية III"
    },
    "badge": {
      "tr": "En güçlü dersin",
      "en": "Your strongest course",
      "fa": "قوی‌ترین درست",
      "ar": "أقوى مادة لديك"
    },
    "icon": "star",
    "level": "good",
    "scores": [
      84,
      88,
      92,
      96
    ],
    "note": {
      "tr": "4 sınav · en iyi konun: Tablet formülasyonu",
      "en": "4 exams · your best topic: Tablet formulation",
      "fa": "4 آزمون · بهترین مبحثت: فرمولاسیون قرص",
      "ar": "4 اختبارات · أفضل موضوع لك: تركيب الأقراص"
    },
    "growth": {
      "from": 86,
      "to": 90,
      "days": 30
    },
    "cta": {
      "tr": "Kartlarla sıcak tut",
      "en": "Keep it fresh with cards",
      "fa": "با کارت‌ها تازه نگهش دار",
      "ar": "حافظ عليه حاضرًا بالبطاقات"
    },
    "toast": {
      "tr": "Farm. Tek. III: haftada 1 kısa tekrar yeterli · plana eklendi",
      "en": "Pharm. Tech. III: 1 short review a week is enough · added to plan",
      "fa": "فناوری دارویی III: هفته‌ای 1 مرور کوتاه کافی است · به برنامه اضافه شد",
      "ar": "التقنية الصيدلانية III: مراجعة قصيرة 1 أسبوعيًا تكفي · أُضيفت إلى الخطة"
    }
  },
  {
    "courseId": "toxicology",
    "name": {
      "tr": "Toksikoloji",
      "en": "Toxicology",
      "fa": "سم‌شناسی",
      "ar": "علم السموم"
    },
    "badge": {
      "tr": "Yükselişte",
      "en": "Rising",
      "fa": "رو به بالا",
      "ar": "في ارتفاع"
    },
    "icon": "trend",
    "level": "mid",
    "scores": [
      64,
      74,
      85
    ],
    "note": {
      "tr": "3 sınav · son sınavda +11 puan",
      "en": "3 exams · +11 points on the last exam",
      "fa": "3 امتحان · +11 امتیاز در آخرین امتحان",
      "ar": "3 امتحانات · +11 نقطة في الامتحان الأخير"
    },
    "growth": {
      "from": 68,
      "to": 74,
      "days": 9
    },
    "cta": {
      "tr": "Planda devam",
      "en": "Stay on plan",
      "fa": "ادامه طبق برنامه",
      "ar": "استمر وفق الخطة"
    }
  },
  {
    "courseId": "pharmacotherapy",
    "name": {
      "tr": "Farmakoterapi",
      "en": "Pharmacotherapy",
      "fa": "دارودرمانی",
      "ar": "العلاج الدوائي"
    },
    "badge": {
      "tr": "En çok çalışman gereken ders",
      "en": "Course you need to study most",
      "fa": "درسی که بیشتر باید بخوانی",
      "ar": "المادة التي تحتاج دراستها أكثر"
    },
    "icon": "alert",
    "level": "low",
    "scores": [
      52,
      58,
      61,
      64,
      70
    ],
    "note": {
      "tr": "5 sınav · en çok zorlandığın konu: Hipertansif kriz (%38)",
      "en": "5 exams · your hardest topic: Hypertensive crisis (38%)",
      "fa": "5 آزمون · سخت‌ترین مبحثت: بحران فشار خون (38%)",
      "ar": "5 اختبارات · أصعب موضوع عليك: نوبة ارتفاع ضغط الدم (38%)"
    },
    "growth": {
      "from": 61,
      "to": 70,
      "days": 12
    },
    "cta": {
      "tr": "Sınava özel hazırlan",
      "en": "Prep for your exam",
      "fa": "برای امتحان آماده شو",
      "ar": "استعد للامتحان"
    }
  }
];

/** Minutes studied this week, Monday first. */
export const WEEK_MINUTES = [75, 60, 55, 60, 0, 0, 0];

export const WEAK_TOPICS: WeakTopic[] = [
  {
    "title": {
      "tr": "Hipertansif kriz",
      "en": "Hypertensive crisis",
      "fa": "بحران فشار خون بالا",
      "ar": "أزمة ارتفاع ضغط الدم"
    },
    "pdf": {
      "tr": "Hipertansiyon",
      "en": "Hypertension",
      "fa": "فشار خون بالا",
      "ar": "ارتفاع ضغط الدم"
    },
    "mastery": 38,
    "color": "#9C2F3A"
  },
  {
    "title": {
      "tr": "ACE inhibitörleri yan etkileri",
      "en": "ACE inhibitor side effects",
      "fa": "عوارض جانبی مهارکننده‌های ACE",
      "ar": "الآثار الجانبية لمثبطات ACE"
    },
    "pdf": {
      "tr": "Hipertansiyon",
      "en": "Hypertension",
      "fa": "فشار خون بالا",
      "ar": "ارتفاع ضغط الدم"
    },
    "mastery": 54,
    "color": "#E8925A"
  },
  {
    "title": {
      "tr": "İnsülin türleri",
      "en": "Insulin types",
      "fa": "انواع انسولین",
      "ar": "أنواع الإنسولين"
    },
    "pdf": {
      "tr": "Diyabet",
      "en": "Diabetes",
      "fa": "دیابت",
      "ar": "السكري"
    },
    "mastery": 61,
    "color": "#F2B33D"
  }
];
