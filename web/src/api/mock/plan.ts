// Study plan mock data from design/NewIPad.dc.html ("Ders planım"): one list of tasks per weekday, Monday first. Minutes are for 1.5 h a day.
import type { PlanItem } from '../types';

export const SMART_WEEK: PlanItem[][] = [
  [
    {
      "kind": "pharmacotherapy",
      "label": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "title": {
        "tr": "Hipertansif kriz",
        "en": "Hypertensive crisis",
        "fa": "بحران فشار خون بالا",
        "ar": "أزمة ارتفاع ضغط الدم"
      },
      "minutes": 35,
      "why": {
        "tr": "zayıf konun · %38",
        "en": "weak topic · 38%",
        "fa": "مبحث ضعیف · %38",
        "ar": "موضوع ضعيف · 38%"
      },
      "to": "reader"
    },
    {
      "kind": "toxicology",
      "label": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "title": {
        "tr": "Organofosfat zehirlenmesi",
        "en": "Organophosphate poisoning",
        "fa": "مسمومیت با ارگانوفسفات",
        "ar": "التسمم بالفوسفات العضوية"
      },
      "minutes": 35,
      "why": {
        "tr": "sınava 10 gün",
        "en": "10 days to exam",
        "fa": "10 روز تا امتحان",
        "ar": "10 أيام على الامتحان"
      },
      "to": "reader"
    },
    {
      "kind": "review",
      "label": {
        "tr": "Tekrar",
        "en": "Review",
        "fa": "مرور",
        "ar": "مراجعة"
      },
      "title": {
        "tr": "3 gün önceki konular",
        "en": "Topics from 3 days ago",
        "fa": "موضوعات 3 روز پیش",
        "ar": "مواضيع قبل 3 أيام"
      },
      "minutes": 20,
      "why": {
        "tr": "unutmaman için",
        "en": "so you don't forget",
        "fa": "تا فراموش نکنی",
        "ar": "حتى لا تنسى"
      },
      "to": "reader"
    }
  ],
  [
    {
      "kind": "pharmacotherapy",
      "label": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "title": {
        "tr": "ACE inh. yan etkileri",
        "en": "ACE inh. side effects",
        "fa": "عوارض مهارکننده‌های ACE",
        "ar": "آثار مثبطات ACE الجانبية"
      },
      "minutes": 40,
      "why": {
        "tr": "zayıf konun · %54",
        "en": "weak topic · 54%",
        "fa": "مبحث ضعیف · %54",
        "ar": "موضوع ضعيف · 54%"
      },
      "to": "reader"
    },
    {
      "kind": "pharm-tech-3",
      "label": {
        "tr": "Farm. Tek. III",
        "en": "Pharm. Tech. III",
        "fa": "فناوری دارویی III",
        "ar": "التقنية الصيدلانية III"
      },
      "title": {
        "tr": "Tablet formülasyonu",
        "en": "Tablet formulation",
        "fa": "فرمولاسیون قرص",
        "ar": "تركيب الأقراص"
      },
      "minutes": 30,
      "why": {
        "tr": "hoca 12 dk durdu",
        "en": "lecturer spent 12 min",
        "fa": "استاد 12 دقیقه رویش ماند",
        "ar": "توقف المحاضر 12 د"
      },
      "to": "reader"
    },
    {
      "kind": "review",
      "label": {
        "tr": "Tekrar",
        "en": "Review",
        "fa": "مرور",
        "ar": "مراجعة"
      },
      "title": {
        "tr": "10 soruluk kısa sınav",
        "en": "Short 10-question quiz",
        "fa": "آزمون کوتاه 10 سؤالی",
        "ar": "اختبار قصير من 10 أسئلة"
      },
      "minutes": 20,
      "why": {
        "tr": "hocanın tarzında",
        "en": "in your lecturer's style",
        "fa": "به سبک استاد",
        "ar": "بأسلوب المحاضر"
      },
      "to": "reader"
    }
  ],
  [
    {
      "kind": "toxicology",
      "label": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "title": {
        "tr": "Parasetamol zehirlenmesi",
        "en": "Paracetamol poisoning",
        "fa": "مسمومیت با پاراستامول",
        "ar": "التسمم بالباراسيتامول"
      },
      "minutes": 45,
      "why": {
        "tr": "sorularında 3 kez",
        "en": "3× in their questions",
        "fa": "3 بار در سؤال‌هایش",
        "ar": "3 مرات في أسئلته"
      },
      "to": "reader"
    },
    {
      "kind": "pharmacotherapy",
      "label": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "title": {
        "tr": "Gebelikte hipertansiyon",
        "en": "Hypertension in pregnancy",
        "fa": "فشار خون بالا در بارداری",
        "ar": "ارتفاع ضغط الدم في الحمل"
      },
      "minutes": 25,
      "why": {
        "tr": "sorularında 4 kez",
        "en": "4× in their questions",
        "fa": "4 بار در سؤال‌هایش",
        "ar": "4 مرات في أسئلته"
      },
      "to": "reader"
    },
    {
      "kind": "review",
      "label": {
        "tr": "Tekrar",
        "en": "Review",
        "fa": "مرور",
        "ar": "مراجعة"
      },
      "title": {
        "tr": "Kartlar",
        "en": "Cards",
        "fa": "کارت‌ها",
        "ar": "البطاقات"
      },
      "minutes": 20,
      "why": {
        "tr": "tekrar günü",
        "en": "review day",
        "fa": "روز مرور",
        "ar": "يوم المراجعة"
      },
      "to": "reader"
    }
  ],
  [
    {
      "kind": "pharmacotherapy",
      "label": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "title": {
        "tr": "Tiyazid kontrendikasyonları",
        "en": "Thiazide contraindications",
        "fa": "منع مصرف تیازیدها",
        "ar": "مضادات استطباب الثيازيدات"
      },
      "minutes": 30,
      "why": {
        "tr": "hoca: \"sınavda soruyorum\"",
        "en": "lecturer: \"I ask this in the exam\"",
        "fa": "استاد: \"در امتحان می‌پرسم\"",
        "ar": "المحاضر: \"أسأل عنه في الامتحان\""
      },
      "to": "reader"
    },
    {
      "kind": "toxicology",
      "label": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "title": {
        "tr": "Ağır metaller",
        "en": "Heavy metals",
        "fa": "فلزات سنگین",
        "ar": "المعادن الثقيلة"
      },
      "minutes": 40,
      "why": {
        "tr": "zayıf konun · %49",
        "en": "weak topic · 49%",
        "fa": "مبحث ضعیف · %49",
        "ar": "موضوع ضعيف · 49%"
      },
      "to": "reader"
    },
    {
      "kind": "review",
      "label": {
        "tr": "Tekrar",
        "en": "Review",
        "fa": "مرور",
        "ar": "مراجعة"
      },
      "title": {
        "tr": "Haftanın tekrarı",
        "en": "Review of the week",
        "fa": "مرور هفته",
        "ar": "مراجعة الأسبوع"
      },
      "minutes": 20,
      "why": {
        "tr": "unutmaman için",
        "en": "so you don't forget",
        "fa": "تا فراموش نکنی",
        "ar": "حتى لا تنسى"
      },
      "to": "reader"
    }
  ],
  [
    {
      "kind": "pharm-tech-3",
      "label": {
        "tr": "Farm. Tek. III",
        "en": "Pharm. Tech. III",
        "fa": "فناوری دارویی III",
        "ar": "التقنية الصيدلانية III"
      },
      "title": {
        "tr": "Granülasyon",
        "en": "Granulation",
        "fa": "گرانولاسیون",
        "ar": "التحبيب"
      },
      "minutes": 45,
      "why": {
        "tr": "sınava 13 gün",
        "en": "13 days to exam",
        "fa": "13 روز تا امتحان",
        "ar": "13 يومًا على الامتحان"
      },
      "to": "reader"
    },
    {
      "kind": "toxicology",
      "label": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "title": {
        "tr": "Toksikoloji tekrarı",
        "en": "Toxicology review",
        "fa": "مرور سم‌شناسی",
        "ar": "مراجعة علم السموم"
      },
      "minutes": 45,
      "why": {
        "tr": "sınava 8 gün",
        "en": "8 days to exam",
        "fa": "8 روز تا امتحان",
        "ar": "8 أيام على الامتحان"
      },
      "to": "reader"
    }
  ],
  [
    {
      "kind": "exam",
      "label": {
        "tr": "Sınava özel",
        "en": "Exam prep",
        "fa": "ویژه امتحان",
        "ar": "خاص بالامتحان"
      },
      "title": {
        "tr": "Farmakoterapi özeti",
        "en": "Pharmacotherapy summary",
        "fa": "خلاصه دارودرمانی",
        "ar": "ملخص العلاج الدوائي"
      },
      "minutes": 40,
      "why": {
        "tr": "vize 19 Ekim",
        "en": "midterm Oct 19",
        "fa": "میان‌ترم 19 اکتبر",
        "ar": "النصفي 19 أكتوبر"
      },
      "to": "quiz"
    },
    {
      "kind": "exam",
      "label": {
        "tr": "Sınava özel",
        "en": "Exam prep",
        "fa": "ویژه امتحان",
        "ar": "خاص بالامتحان"
      },
      "title": {
        "tr": "Sınava özel 6 soru",
        "en": "6 exam-focused questions",
        "fa": "6 سؤال ویژه امتحان",
        "ar": "6 أسئلة خاصة بالامتحان"
      },
      "minutes": 30,
      "why": {
        "tr": "zayıf konulardan",
        "en": "from weak topics",
        "fa": "از مباحث ضعیف",
        "ar": "من المواضيع الضعيفة"
      },
      "to": "quiz"
    },
    {
      "kind": "review",
      "label": {
        "tr": "Tekrar",
        "en": "Review",
        "fa": "مرور",
        "ar": "مراجعة"
      },
      "title": {
        "tr": "Yanlışlarını tekrar",
        "en": "Review your mistakes",
        "fa": "مرور اشتباهاتت",
        "ar": "راجع أخطاءك"
      },
      "minutes": 20,
      "why": {
        "tr": "son sınavdan",
        "en": "from last exam",
        "fa": "از آزمون قبلی",
        "ar": "من الاختبار الأخير"
      },
      "to": "quiz"
    }
  ],
  [
    {
      "kind": "exam",
      "label": {
        "tr": "Sınava özel",
        "en": "Exam prep",
        "fa": "ویژه امتحان",
        "ar": "خاص بالامتحان"
      },
      "title": {
        "tr": "Genel tekrar",
        "en": "General review",
        "fa": "مرور کلی",
        "ar": "مراجعة عامة"
      },
      "minutes": 45,
      "why": {
        "tr": "vizeden önceki gün",
        "en": "day before midterm",
        "fa": "روز قبل از میان‌ترم",
        "ar": "اليوم السابق للنصفي"
      },
      "to": "quiz"
    },
    {
      "kind": "exam",
      "label": {
        "tr": "Sınava özel",
        "en": "Exam prep",
        "fa": "ویژه امتحان",
        "ar": "خاص بالامتحان"
      },
      "title": {
        "tr": "Toksikoloji soruları",
        "en": "Toxicology questions",
        "fa": "سؤال‌های سم‌شناسی",
        "ar": "أسئلة علم السموم"
      },
      "minutes": 45,
      "why": {
        "tr": "zayıf konulardan",
        "en": "from weak topics",
        "fa": "از مباحث ضعیف",
        "ar": "من المواضيع الضعيفة"
      },
      "to": "quiz"
    }
  ]
];

export const BASIC_WEEK: PlanItem[][] = [
  [
    {
      "kind": "pharmacotherapy",
      "label": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "title": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "minutes": 45,
      "why": {
        "tr": "eşit dağıtım",
        "en": "evenly split",
        "fa": "تقسیم مساوی",
        "ar": "توزيع متساوٍ"
      },
      "to": "reader"
    },
    {
      "kind": "toxicology",
      "label": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "title": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "minutes": 45,
      "why": {
        "tr": "eşit dağıtım",
        "en": "evenly split",
        "fa": "تقسیم مساوی",
        "ar": "توزيع متساوٍ"
      },
      "to": "reader"
    }
  ],
  [
    {
      "kind": "pharm-tech-3",
      "label": {
        "tr": "Farm. Tek. III",
        "en": "Pharm. Tech. III",
        "fa": "فناوری دارویی III",
        "ar": "التقنية الصيدلانية III"
      },
      "title": {
        "tr": "Farm. Tek. III",
        "en": "Pharm. Tech. III",
        "fa": "فناوری دارویی III",
        "ar": "التقنية الصيدلانية III"
      },
      "minutes": 45,
      "why": {
        "tr": "eşit dağıtım",
        "en": "evenly split",
        "fa": "تقسیم مساوی",
        "ar": "توزيع متساوٍ"
      },
      "to": "reader"
    },
    {
      "kind": "pharmacotherapy",
      "label": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "title": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "minutes": 45,
      "why": {
        "tr": "eşit dağıtım",
        "en": "evenly split",
        "fa": "تقسیم مساوی",
        "ar": "توزيع متساوٍ"
      },
      "to": "reader"
    }
  ],
  [
    {
      "kind": "toxicology",
      "label": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "title": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "minutes": 45,
      "why": {
        "tr": "eşit dağıtım",
        "en": "evenly split",
        "fa": "تقسیم مساوی",
        "ar": "توزيع متساوٍ"
      },
      "to": "reader"
    },
    {
      "kind": "pharm-tech-3",
      "label": {
        "tr": "Farm. Tek. III",
        "en": "Pharm. Tech. III",
        "fa": "فناوری دارویی III",
        "ar": "التقنية الصيدلانية III"
      },
      "title": {
        "tr": "Farm. Tek. III",
        "en": "Pharm. Tech. III",
        "fa": "فناوری دارویی III",
        "ar": "التقنية الصيدلانية III"
      },
      "minutes": 45,
      "why": {
        "tr": "eşit dağıtım",
        "en": "evenly split",
        "fa": "تقسیم مساوی",
        "ar": "توزيع متساوٍ"
      },
      "to": "reader"
    }
  ],
  [
    {
      "kind": "pharmacotherapy",
      "label": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "title": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "minutes": 45,
      "why": {
        "tr": "eşit dağıtım",
        "en": "evenly split",
        "fa": "تقسیم مساوی",
        "ar": "توزيع متساوٍ"
      },
      "to": "reader"
    },
    {
      "kind": "toxicology",
      "label": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "title": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "minutes": 45,
      "why": {
        "tr": "eşit dağıtım",
        "en": "evenly split",
        "fa": "تقسیم مساوی",
        "ar": "توزيع متساوٍ"
      },
      "to": "reader"
    }
  ],
  [
    {
      "kind": "pharm-tech-3",
      "label": {
        "tr": "Farm. Tek. III",
        "en": "Pharm. Tech. III",
        "fa": "فناوری دارویی III",
        "ar": "التقنية الصيدلانية III"
      },
      "title": {
        "tr": "Farm. Tek. III",
        "en": "Pharm. Tech. III",
        "fa": "فناوری دارویی III",
        "ar": "التقنية الصيدلانية III"
      },
      "minutes": 45,
      "why": {
        "tr": "eşit dağıtım",
        "en": "evenly split",
        "fa": "تقسیم مساوی",
        "ar": "توزيع متساوٍ"
      },
      "to": "reader"
    },
    {
      "kind": "review",
      "label": {
        "tr": "Tekrar",
        "en": "Review",
        "fa": "مرور",
        "ar": "مراجعة"
      },
      "title": {
        "tr": "Haftanın tekrarı",
        "en": "Review of the week",
        "fa": "مرور هفته",
        "ar": "مراجعة الأسبوع"
      },
      "minutes": 45,
      "why": {
        "tr": "tekrar günü",
        "en": "review day",
        "fa": "روز مرور",
        "ar": "يوم المراجعة"
      },
      "to": "reader"
    }
  ],
  [
    {
      "kind": "pharmacotherapy",
      "label": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "title": {
        "tr": "Farmakoterapi",
        "en": "Pharmacotherapy",
        "fa": "دارودرمانی",
        "ar": "العلاج الدوائي"
      },
      "minutes": 45,
      "why": {
        "tr": "eşit dağıtım",
        "en": "evenly split",
        "fa": "تقسیم مساوی",
        "ar": "توزيع متساوٍ"
      },
      "to": "reader"
    },
    {
      "kind": "toxicology",
      "label": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "title": {
        "tr": "Toksikoloji",
        "en": "Toxicology",
        "fa": "سم‌شناسی",
        "ar": "علم السموم"
      },
      "minutes": 45,
      "why": {
        "tr": "eşit dağıtım",
        "en": "evenly split",
        "fa": "تقسیم مساوی",
        "ar": "توزيع متساوٍ"
      },
      "to": "reader"
    }
  ],
  [
    {
      "kind": "review",
      "label": {
        "tr": "Tekrar",
        "en": "Review",
        "fa": "مرور",
        "ar": "مراجعة"
      },
      "title": {
        "tr": "Genel tekrar",
        "en": "General review",
        "fa": "مرور کلی",
        "ar": "مراجعة عامة"
      },
      "minutes": 90,
      "why": {
        "tr": "tekrar günü",
        "en": "review day",
        "fa": "روز مرور",
        "ar": "يوم المراجعة"
      },
      "to": "reader"
    }
  ]
];
