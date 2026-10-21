// Mock data copied from design/NewCourses.dc.html (same numbers as DeskApp "My Courses").
// read = % read, minutes = time studied, pages = PDF page count.
import type { Course } from '../types';

export const COURSES: Course[] = [
  {
    "id": "pharmacotherapy",
    "name": {
      "tr": "Farmakoterapi",
      "en": "Pharmacotherapy",
      "fa": "دارودرمانی",
      "ar": "العلاج الدوائي"
    },
    "color": "red",
    "language": "tr",
    "exam": {
      "tr": "Vize · 19 Ekim",
      "en": "Midterm · Oct 19",
      "fa": "میان‌ترم · 19 اکتبر",
      "ar": "النصفي · 19 أكتوبر"
    },
    "examDate": "2026-10-19",
    "rank": 3,
    "pdfs": [
      {
        "id": "hypertension",
        "title": {
          "tr": "Hipertansiyon",
          "en": "Hypertension",
          "fa": "فشار خون بالا",
          "ar": "ارتفاع ضغط الدم"
        },
        "read": 62,
        "minutes": 160,
        "pages": 48
      },
      {
        "id": "diabetes",
        "title": {
          "tr": "Diyabet",
          "en": "Diabetes",
          "fa": "دیابت",
          "ar": "السكري"
        },
        "read": 8,
        "minutes": 25,
        "pages": 36
      },
      {
        "id": "heart-failure",
        "title": {
          "tr": "Kalp Yetmezliği",
          "en": "Heart Failure",
          "fa": "نارسایی قلبی",
          "ar": "قصور القلب"
        },
        "read": 100,
        "minutes": 190,
        "pages": 40
      },
      {
        "id": "asthma-copd",
        "title": {
          "tr": "Astım ve KOAH",
          "en": "Asthma and COPD",
          "fa": "آسم و COPD",
          "ar": "الربو وCOPD"
        },
        "read": 45,
        "minutes": 90,
        "pages": 30
      }
    ]
  },
  {
    "id": "toxicology",
    "name": {
      "tr": "Toksikoloji",
      "en": "Toxicology",
      "fa": "سم‌شناسی",
      "ar": "علم السموم"
    },
    "color": "amb",
    "language": "tr",
    "exam": {
      "tr": "Vize · 20 Ekim",
      "en": "Midterm · Oct 20",
      "fa": "میان‌ترم · 20 اکتبر",
      "ar": "النصفي · 20 أكتوبر"
    },
    "examDate": "2026-10-20",
    "rank": 5,
    "pdfs": [
      {
        "id": "organophosphate",
        "title": {
          "tr": "Organofosfat zehirlenmesi",
          "en": "Organophosphate poisoning",
          "fa": "مسمومیت با ارگانوفسفات",
          "ar": "التسمم بالفوسفات العضوية"
        },
        "read": 80,
        "minutes": 120,
        "pages": 28
      },
      {
        "id": "paracetamol",
        "title": {
          "tr": "Parasetamol toksisitesi",
          "en": "Paracetamol toxicity",
          "fa": "سمیت پاراستامول",
          "ar": "سمية الباراسيتامول"
        },
        "read": 100,
        "minutes": 80,
        "pages": 18
      },
      {
        "id": "heavy-metals",
        "title": {
          "tr": "Ağır metaller",
          "en": "Heavy metals",
          "fa": "فلزات سنگین",
          "ar": "المعادن الثقيلة"
        },
        "read": 20,
        "minutes": 35,
        "pages": 34
      }
    ]
  },
  {
    "id": "pharm-tech-3",
    "name": {
      "tr": "Farmasötik Teknoloji III",
      "en": "Pharmaceutical Technology III",
      "fa": "فناوری دارویی III",
      "ar": "التقنية الصيدلانية III"
    },
    "short": {"tr":"Farm. Tek. III","en":"Pharm. Tech. III","fa":"فناوری دارویی III","ar":"التقنية الصيدلانية III"},
    "color": "vio",
    "language": "tr",
    "exam": {
      "tr": "Vize · 21 Ekim",
      "en": "Midterm · Oct 21",
      "fa": "میان‌ترم · 21 اکتبر",
      "ar": "النصفي · 21 أكتوبر"
    },
    "examDate": "2026-10-21",
    "rank": 2,
    "pdfs": [
      {
        "id": "tablet-formulation",
        "title": {
          "tr": "Tablet formülasyonu",
          "en": "Tablet formulation",
          "fa": "فرمولاسیون قرص",
          "ar": "تركيب الأقراص"
        },
        "read": 100,
        "minutes": 180,
        "pages": 52
      },
      {
        "id": "film-coating",
        "title": {
          "tr": "Film kaplama",
          "en": "Film coating",
          "fa": "روکش فیلمی",
          "ar": "التغليف الغشائي"
        },
        "read": 55,
        "minutes": 70,
        "pages": 26
      },
      {
        "id": "capsules",
        "title": {
          "tr": "Kapsüller",
          "en": "Capsules",
          "fa": "کپسول‌ها",
          "ar": "الكبسولات"
        },
        "read": 0,
        "minutes": 0,
        "pages": 22
      }
    ]
  },
  {
    "id": "pharmacognosy",
    "name": {
      "tr": "Farmakognozi",
      "en": "Pharmacognosy",
      "fa": "فارماکوگنوزی",
      "ar": "علم العقاقير"
    },
    "color": "grn",
    "language": "tr",
    "exam": {
      "tr": "Vize · 22 Ekim",
      "en": "Midterm · Oct 22",
      "fa": "میان‌ترم · 22 اکتبر",
      "ar": "النصفي · 22 أكتوبر"
    },
    "examDate": "2026-10-22",
    "rank": 7,
    "pdfs": [
      {
        "id": "alkaloids",
        "title": {
          "tr": "Alkaloitler",
          "en": "Alkaloids",
          "fa": "آلکالوئیدها",
          "ar": "القلويدات"
        },
        "read": 70,
        "minutes": 110,
        "pages": 44
      },
      {
        "id": "glycosides",
        "title": {
          "tr": "Glikozitler",
          "en": "Glycosides",
          "fa": "گلیکوزیدها",
          "ar": "الغليكوسيدات"
        },
        "read": 30,
        "minutes": 40,
        "pages": 30
      }
    ]
  },
  {
    "id": "pharm-chem-2",
    "name": {
      "tr": "Farmasötik Kimya II",
      "en": "Pharmaceutical Chemistry II",
      "fa": "شیمی دارویی II",
      "ar": "الكيمياء الصيدلانية II"
    },
    "color": "teal",
    "language": "tr",
    "exam": {
      "tr": "Vize · 23 Ekim",
      "en": "Midterm · Oct 23",
      "fa": "میان‌ترم · 23 اکتبر",
      "ar": "النصفي · 23 أكتوبر"
    },
    "examDate": "2026-10-23",
    "rank": 9,
    "pdfs": [
      {
        "id": "beta-lactams",
        "title": {
          "tr": "Beta-laktam antibiyotikler",
          "en": "Beta-lactam antibiotics",
          "fa": "آنتی‌بیوتیک‌های بتالاکتام",
          "ar": "المضادات الحيوية بيتا لاكتام"
        },
        "read": 15,
        "minutes": 30,
        "pages": 38
      }
    ]
  }
];
