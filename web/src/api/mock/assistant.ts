// Sample attachments for the assistant's "+" menu (design/NewIPad.dc.html). Uploading is not connected yet.
import type { Attachment } from '../types';

export const SAMPLE_ATTACHMENTS: Record<'pdf' | 'photo' | 'audio', Attachment> = {
  "pdf": {
    "tag": {
      "tr": "PDF",
      "en": "PDF",
      "fa": "PDF",
      "ar": "PDF"
    },
    "name": {
      "tr": "Hipertansiyon_hafta5.pdf",
      "en": "Hypertension_week5.pdf",
      "fa": "فشار_خون_بالا_هفته5.pdf",
      "ar": "ارتفاع_ضغط_الدم_الأسبوع5.pdf"
    },
    "meta": {
      "tr": "24 sayfa · 3,2 MB",
      "en": "24 pages · 3.2 MB",
      "fa": "24 صفحه · 3.2 MB",
      "ar": "24 صفحة · 3.2 MB"
    },
    "topic": "hypertension",
    "why": {
      "tr": "sayfalarda \"ACE inhibitörü\" ve \"tiyazid\" geçiyor",
      "en": "pages mention \"ACE inhibitor\" and \"thiazide\"",
      "fa": "در صفحات \"مهارکننده ACE\" و \"تیازید\" آمده",
      "ar": "الصفحات تذكر \"مثبط ACE\" و\"الثيازيد\""
    }
  },
  "photo": {
    "tag": {
      "tr": "FOTO",
      "en": "PHOTO",
      "fa": "عکس",
      "ar": "صورة"
    },
    "name": {
      "tr": "Soru_fotografi.jpg",
      "en": "Question_photo.jpg",
      "fa": "عکس_سؤال.jpg",
      "ar": "صورة_السؤال.jpg"
    },
    "meta": {
      "tr": "3 soru bulundu",
      "en": "3 questions found",
      "fa": "3 سؤال پیدا شد",
      "ar": "تم العثور على 3 أسئلة"
    },
    "topic": "diabetes",
    "why": {
      "tr": "sorularda \"metformin\" ve \"insülin\" geçiyor",
      "en": "questions mention \"metformin\" and \"insulin\"",
      "fa": "در سؤال‌ها \"متفورمین\" و \"انسولین\" آمده",
      "ar": "الأسئلة تذكر \"الميتفورمين\" و\"الأنسولين\""
    }
  },
  "audio": {
    "tag": {
      "tr": "SES",
      "en": "AUDIO",
      "fa": "صوت",
      "ar": "صوت"
    },
    "name": {
      "tr": "Ders_kaydi_14Ekim.m4a",
      "en": "Lecture_recording_14Oct.m4a",
      "fa": "ضبط_کلاس_14اکتبر.m4a",
      "ar": "تسجيل_المحاضرة_14أكتوبر.m4a"
    },
    "meta": {
      "tr": "48 dk ders kaydı",
      "en": "48 min lecture recording",
      "fa": "ضبط کلاس 48 دقیقه‌ای",
      "ar": "تسجيل محاضرة 48 د"
    },
    "topic": "toxicology",
    "why": {
      "tr": "kayıtta \"organofosfat\" ve \"atropin\" geçiyor",
      "en": "recording mentions \"organophosphate\" and \"atropine\"",
      "fa": "در فایل صوتی \"ارگانوفسفات\" و \"آتروپین\" آمده",
      "ar": "التسجيل يذكر \"الفوسفات العضوي\" و\"الأتروبين\""
    }
  }
};
