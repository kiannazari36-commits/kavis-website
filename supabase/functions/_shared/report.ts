// Readable HTML report of a student's data (Edge Function export-data), next to the JSON copy.
// One self-contained file: inline CSS, no scripts, no external requests. Language = profiles.app_lang (fa/ar = RTL).
// Ids / uuids are never shown; rows are turned into lists and tables, empty sections are left out.
import type { Lang } from './mail.ts';

type Row = Record<string, unknown>;
export type ReportInput = {
  lang: Lang;
  exportedAt: Date;
  email: string;
  createdAt?: string;
  profile: Row | null;
  data: Record<string, Row[]>;
  pdfs: { material_id: string; link: string | null }[];
  linkDays: number;
};

const T = {
  tr: {
    locale: 'tr-TR', title: 'Hesap bilgilerin', sub: 'Kavis Study\'de sakladığımız bilgilerin okunabilir özeti. Aynı bilgilerin makine tarafından okunabilir kopyası (JSON) e-postadaki ikinci bağlantıdadır.',
    made: 'Hazırlanma', valid: 'Bu dosyadaki PDF bağlantıları {n} gün geçerlidir.', contents: 'İçindekiler',
    profile: 'Profil ve hesap', settings: 'Ayarlar', devices: 'Cihazlar', courses: 'Dersler ve ders programı', lessons: 'Dersler ve PDF\'ler',
    notes: 'Notlar ve vurgular', cards: 'Bilgi kartları', quizzes: 'Sınavlar ve sonuçlar', plan: 'Çalışma planı ve ilerleme', assistant: 'Asistan sohbetleri', sub_: 'Abonelik ve deneme',
    name: 'Ad', email: 'E-posta', school: 'Okul', department: 'Bölüm', classYear: 'Sınıf', appLang: 'Uygulama dili', joined: 'Kayıt tarihi', termsAt: 'Şartları kabul tarihi', trialStart: 'Deneme başlangıcı',
    langs: { tr: 'Türkçe', en: 'İngilizce', fa: 'Farsça', ar: 'Arapça' } as Record<string, string>,
    yes: 'Evet', no: 'Hayır', on: 'Açık', off: 'Kapalı',
    theme: 'Görünüm', contentLang: 'İçerik dili', sameAsPdf: 'PDF ile aynı', sameAsApp: 'Uygulama ile aynı', transLangs: 'Çeviri dilleri', transStyle: 'Çeviri stili', studyDays: 'Haftada çalışma günü', studyHours: 'Günde çalışma saati', timeZone: 'Saat dilimi',
    paper: 'Okuma kâğıdı', fontSize: 'Yazı boyutu', voice: 'Okuma sesi', rate: 'Okuma hızı', push: 'Bildirimler', reviewReminder: 'Tekrar hatırlatması', notifyTime: 'Bildirim saati', cheer: 'Teşvik bildirimleri', weekly: 'Haftalık rapor', offline: 'Çevrimdışı mod', autoDl: 'Otomatik indirme',
    themes: { light: 'Açık', dark: 'Koyu', system: 'Sisteme göre' } as Record<string, string>,
    device: 'Cihaz', type: 'Tür', firstSeen: 'İlk giriş', lastSeen: 'Son görülme', signedOut: 'Çıkış',
    kinds: { web: 'Web', iphone: 'iPhone', ipad: 'iPad', pdf: 'PDF' } as Record<string, string>,
    course: 'Ders', term: 'Dönem', color: 'Renk', archived: 'Arşivde', exams: 'Sınav tarihleri', examKinds: { midterm: 'Vize', final: 'Final', makeup: 'Bütünleme', quiz: 'Küçük sınav' } as Record<string, string>,
    periods: 'Sınav dönemleri', timetable: 'Ders programı', day: 'Gün', time: 'Saat', room: 'Sınıf', teacher: 'Hoca', ownPlan: 'Kendi haftalık planım', minutes: 'dk',
    days: ['', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'],
    lesson: 'Ders', title_: 'Başlık', pages: 'Sayfa', added: 'Eklenme', status: 'Durum', download: 'PDF\'yi indir', original: 'Orijinal dosya',
    mkinds: { pdf: 'PDF', photo: 'Fotoğraf', audio: 'Ses kaydı', recording: 'Ders kaydı', text: 'Metin', exam_summary: 'Sınav özeti', exam_brief: 'Sınav gecesi özeti' } as Record<string, string>,
    mstatus: { ready: 'Hazır', failed: 'Hata', processing: 'İşleniyor', pending: 'Sırada', uploaded: 'Yüklendi' } as Record<string, string>,
    topics: 'Konu başlıkları', hardWords: 'Zor kelimeler', summaries: 'Özetler', page: 'sayfa', pp: 'sayfa', weak: 'zayıf konu',
    skinds: { lesson: 'Ders özeti', exam_prep: 'Sınav hazırlığı', exam_summary: 'Sınav özeti', exam_brief: 'Sınav kısa notu', section: 'Bölüm özeti' } as Record<string, string>,
    highlights: 'Vurgular', myNotes: 'Notlarım', inkNotes: 'El yazısı notlar', inkCount: '{n} el yazısı not (JSON dosyasında)', readProg: 'Okuma ilerlemesi', read: 'okundu', lastPage: 'Son sayfa',
    deck: 'Deste', question: 'Soru', answer: 'Cevap', note: 'Not', nextReview: 'Sonraki tekrar',
    quiz: 'Sınav', qCount: 'soru', date: 'Tarih', score: 'Puan', level: 'Seviye', yourAnswer: 'Cevabın', correct: 'Doğru', wrong: 'Yanlış', unknown: 'Bilmiyorum', options: 'Seçenekler', explanation: 'Açıklama', attempts: 'Çözümler', questions: 'Sorular',
    qkinds: { exam_prep: 'Sınav hazırlığı', basic: 'Konu testi', combined: 'Karma sınav', placement: 'Seviye belirleme', lesson_end: 'Ders sonu' } as Record<string, string>,
    levels: { beginner: 'Başlangıç', basic: 'Temel', intermediate: 'Orta', advanced: 'İleri' } as Record<string, string>,
    week: 'Hafta', stage: 'Aşama', item: 'Görev', done: 'Yapıldı', todo: 'Bekliyor', sessions: 'Çalışma oturumları', total: 'Toplam', activity: 'Etkinlik', mastery: 'Konu durumu',
    acts: { read: 'Okuma', cards: 'Kartlar', quiz: 'Sınav', review: 'Tekrar', assistant: 'Asistan', record: 'Kayıt' } as Record<string, string>,
    states: { known: 'Biliyor', weak: 'Zayıf', learning: 'Öğreniyor', new: 'Yeni' } as Record<string, string>,
    you: 'Sen', ai: 'Asistan', thread: 'Sohbet', modes: { lesson: 'Ders', pdf: 'Ders', course: 'Ders grubu', ai: 'Yapay zekâ + araştırma' } as Record<string, string>,
    plan_: 'Plan', provider: 'Sağlayıcı', started: 'Başlangıç', expires: 'Bitiş', trial: 'Deneme kullanımı', lessonsUsed: 'Kullanılan ders', questionsUsed: 'Asistan sorusu', monthUsage: 'Aylık kullanım', month: 'Ay', gens: 'Üretim', noSub: 'Aktif abonelik yok.',
    sstatus: { active: 'Aktif', expired: 'Bitti', grace: 'Ek süre', billing_retry: 'Ödeme yeniden deneniyor', refunded: 'İade', revoked: 'İptal' } as Record<string, string>,
    support: 'Destek yazışmaları', footer: 'Kavis Study · Always Improve More',
  },
  en: {
    locale: 'en-GB', title: 'Your account data', sub: 'A readable summary of the information we keep in Kavis Study. The machine-readable copy of the same data (JSON) is the second link in the email.',
    made: 'Prepared', valid: 'The PDF links in this file work for {n} days.', contents: 'Contents',
    profile: 'Profile and account', settings: 'Settings', devices: 'Devices', courses: 'Courses and timetable', lessons: 'Lessons and PDFs',
    notes: 'Notes and highlights', cards: 'Flash cards', quizzes: 'Quizzes and results', plan: 'Study plan and progress', assistant: 'Assistant conversations', sub_: 'Subscription and trial',
    name: 'Name', email: 'Email', school: 'School', department: 'Department', classYear: 'Year', appLang: 'App language', joined: 'Joined', termsAt: 'Terms accepted', trialStart: 'Trial started',
    langs: { tr: 'Turkish', en: 'English', fa: 'Persian', ar: 'Arabic' },
    yes: 'Yes', no: 'No', on: 'On', off: 'Off',
    theme: 'Appearance', contentLang: 'Content language', sameAsPdf: 'Same as the PDF', sameAsApp: 'Same as the app', transLangs: 'Translation languages', transStyle: 'Translation style', studyDays: 'Study days per week', studyHours: 'Study hours per day', timeZone: 'Time zone',
    paper: 'Reading paper', fontSize: 'Text size', voice: 'Reading voice', rate: 'Reading speed', push: 'Notifications', reviewReminder: 'Review reminder', notifyTime: 'Notification time', cheer: 'Cheer notifications', weekly: 'Weekly report', offline: 'Offline mode', autoDl: 'Automatic download',
    themes: { light: 'Light', dark: 'Dark', system: 'System' },
    device: 'Device', type: 'Type', firstSeen: 'First sign-in', lastSeen: 'Last seen', signedOut: 'Signed out',
    kinds: { web: 'Web', iphone: 'iPhone', ipad: 'iPad', pdf: 'PDF' },
    course: 'Course', term: 'Term', color: 'Colour', archived: 'Archived', exams: 'Exam dates', examKinds: { midterm: 'Midterm', final: 'Final', makeup: 'Make-up', quiz: 'Quiz' },
    periods: 'Exam periods', timetable: 'Timetable', day: 'Day', time: 'Time', room: 'Room', teacher: 'Teacher', ownPlan: 'My weekly plan', minutes: 'min',
    days: ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
    lesson: 'Lesson', title_: 'Title', pages: 'Pages', added: 'Added', status: 'Status', download: 'Download the PDF', original: 'Original file',
    mkinds: { pdf: 'PDF', photo: 'Photo', audio: 'Audio', recording: 'Lecture recording', text: 'Text', exam_summary: 'Exam summary', exam_brief: 'Exam-night summary' },
    mstatus: { ready: 'Ready', failed: 'Failed', processing: 'Processing', pending: 'Waiting', uploaded: 'Uploaded' },
    topics: 'Topics', hardWords: 'Hard words', summaries: 'Summaries', page: 'page', pp: 'pages', weak: 'weak topic',
    skinds: { lesson: 'Lesson summary', exam_prep: 'Exam preparation', exam_summary: 'Exam summary', exam_brief: 'Exam brief', section: 'Section summary' },
    highlights: 'Highlights', myNotes: 'My notes', inkNotes: 'Handwritten notes', inkCount: '{n} handwritten notes (in the JSON file)', readProg: 'Reading progress', read: 'read', lastPage: 'Last page',
    deck: 'Deck', question: 'Question', answer: 'Answer', note: 'Note', nextReview: 'Next review',
    quiz: 'Quiz', qCount: 'questions', date: 'Date', score: 'Score', level: 'Level', yourAnswer: 'Your answer', correct: 'Correct', wrong: 'Wrong', unknown: "Don't know", options: 'Options', explanation: 'Explanation', attempts: 'Attempts', questions: 'Questions',
    qkinds: { exam_prep: 'Exam preparation', basic: 'Topic test', combined: 'Mixed exam', placement: 'Placement test', lesson_end: 'End of lesson' },
    levels: { beginner: 'Beginner', basic: 'Basic', intermediate: 'Intermediate', advanced: 'Advanced' },
    week: 'Week', stage: 'Stage', item: 'Task', done: 'Done', todo: 'To do', sessions: 'Study sessions', total: 'Total', activity: 'Activity', mastery: 'Topic status',
    acts: { read: 'Reading', cards: 'Cards', quiz: 'Quiz', review: 'Review', assistant: 'Assistant', record: 'Recording' },
    states: { known: 'Known', weak: 'Weak', learning: 'Learning', new: 'New' },
    you: 'You', ai: 'Assistant', thread: 'Conversation', modes: { lesson: 'Lesson', pdf: 'Lesson', course: 'Course', ai: 'AI + research' },
    plan_: 'Plan', provider: 'Provider', started: 'Started', expires: 'Ends', trial: 'Trial usage', lessonsUsed: 'Lessons used', questionsUsed: 'Assistant questions', monthUsage: 'Monthly usage', month: 'Month', gens: 'Generations', noSub: 'No active subscription.',
    sstatus: { active: 'Active', expired: 'Ended', grace: 'Grace period', billing_retry: 'Retrying payment', refunded: 'Refunded', revoked: 'Revoked' },
    support: 'Support messages', footer: 'Kavis Study · Always Improve More',
  },
  fa: {
    locale: 'fa-IR', title: 'اطلاعات حساب تو', sub: 'خلاصه‌ی خوانای اطلاعاتی که در Kavis Study نگه می‌داریم. نسخه‌ی قابل‌خواندن برای ماشین (JSON) همین اطلاعات، لینک دوم ایمیل است.',
    made: 'زمان تهیه', valid: 'لینک‌های PDF در این فایل {n} روز معتبرند.', contents: 'فهرست',
    profile: 'پروفایل و حساب', settings: 'تنظیمات', devices: 'دستگاه‌ها', courses: 'درس‌ها و برنامه‌ی کلاسی', lessons: 'درس‌ها و PDFها',
    notes: 'یادداشت‌ها و هایلایت‌ها', cards: 'فلش‌کارت‌ها', quizzes: 'آزمون‌ها و نتایج', plan: 'برنامه‌ی مطالعه و پیشرفت', assistant: 'گفتگوهای دستیار', sub_: 'اشتراک و دوره‌ی آزمایشی',
    name: 'نام', email: 'ایمیل', school: 'دانشگاه', department: 'رشته', classYear: 'سال', appLang: 'زبان برنامه', joined: 'تاریخ ثبت‌نام', termsAt: 'تاریخ پذیرش شرایط', trialStart: 'شروع دوره‌ی آزمایشی',
    langs: { tr: 'ترکی استانبولی', en: 'انگلیسی', fa: 'فارسی', ar: 'عربی' },
    yes: 'بله', no: 'خیر', on: 'روشن', off: 'خاموش',
    theme: 'ظاهر', contentLang: 'زبان محتوا', sameAsPdf: 'مثل PDF', sameAsApp: 'مثل برنامه', transLangs: 'زبان‌های ترجمه', transStyle: 'سبک ترجمه', studyDays: 'روز مطالعه در هفته', studyHours: 'ساعت مطالعه در روز', timeZone: 'منطقه‌ی زمانی',
    paper: 'کاغذ خواندن', fontSize: 'اندازه‌ی متن', voice: 'صدای خواندن', rate: 'سرعت خواندن', push: 'اعلان‌ها', reviewReminder: 'یادآوری مرور', notifyTime: 'ساعت اعلان', cheer: 'اعلان‌های تشویقی', weekly: 'گزارش هفتگی', offline: 'حالت آفلاین', autoDl: 'دانلود خودکار',
    themes: { light: 'روشن', dark: 'تیره', system: 'مطابق سیستم' },
    device: 'دستگاه', type: 'نوع', firstSeen: 'اولین ورود', lastSeen: 'آخرین بازدید', signedOut: 'خروج',
    kinds: { web: 'وب', iphone: 'آیفون', ipad: 'آیپد', pdf: 'PDF' },
    course: 'درس', term: 'ترم', color: 'رنگ', archived: 'بایگانی', exams: 'تاریخ امتحان‌ها', examKinds: { midterm: 'میان‌ترم', final: 'پایان‌ترم', makeup: 'جبرانی', quiz: 'کوییز' },
    periods: 'دوره‌های امتحانی', timetable: 'برنامه‌ی کلاسی', day: 'روز', time: 'ساعت', room: 'کلاس', teacher: 'استاد', ownPlan: 'برنامه‌ی هفتگی من', minutes: 'دقیقه',
    days: ['', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه'],
    lesson: 'درس', title_: 'عنوان', pages: 'صفحه', added: 'افزوده شد', status: 'وضعیت', download: 'دانلود PDF', original: 'فایل اصلی',
    mkinds: { pdf: 'PDF', photo: 'عکس', audio: 'صوت', recording: 'ضبط کلاس', text: 'متن', exam_summary: 'خلاصه‌ی امتحان', exam_brief: 'خلاصه‌ی شب امتحان' },
    mstatus: { ready: 'آماده', failed: 'خطا', processing: 'در حال پردازش', pending: 'در صف', uploaded: 'بارگذاری شد' },
    topics: 'سرفصل‌ها', hardWords: 'واژه‌های سخت', summaries: 'خلاصه‌ها', page: 'صفحه', pp: 'صفحه', weak: 'مبحث ضعیف',
    skinds: { lesson: 'خلاصه‌ی درس', exam_prep: 'آمادگی امتحان', exam_summary: 'خلاصه‌ی امتحان', exam_brief: 'یادداشت کوتاه امتحان', section: 'خلاصه‌ی بخش' },
    highlights: 'هایلایت‌ها', myNotes: 'یادداشت‌های من', inkNotes: 'یادداشت‌های دست‌نویس', inkCount: '{n} یادداشت دست‌نویس (در فایل JSON)', readProg: 'پیشرفت مطالعه', read: 'خوانده شده', lastPage: 'آخرین صفحه',
    deck: 'دسته', question: 'پرسش', answer: 'پاسخ', note: 'یادداشت', nextReview: 'مرور بعدی',
    quiz: 'آزمون', qCount: 'پرسش', date: 'تاریخ', score: 'نمره', level: 'سطح', yourAnswer: 'پاسخ تو', correct: 'درست', wrong: 'نادرست', unknown: 'نمی‌دانم', options: 'گزینه‌ها', explanation: 'توضیح', attempts: 'دفعات حل', questions: 'پرسش‌ها',
    qkinds: { exam_prep: 'آمادگی امتحان', basic: 'آزمون مبحث', combined: 'آزمون ترکیبی', placement: 'تعیین سطح', lesson_end: 'پایان درس' },
    levels: { beginner: 'مبتدی', basic: 'پایه', intermediate: 'متوسط', advanced: 'پیشرفته' },
    week: 'هفته', stage: 'مرحله', item: 'کار', done: 'انجام شد', todo: 'در انتظار', sessions: 'جلسه‌های مطالعه', total: 'جمع', activity: 'فعالیت', mastery: 'وضعیت مباحث',
    acts: { read: 'خواندن', cards: 'کارت‌ها', quiz: 'آزمون', review: 'مرور', assistant: 'دستیار', record: 'ضبط' },
    states: { known: 'بلد', weak: 'ضعیف', learning: 'در حال یادگیری', new: 'جدید' },
    you: 'تو', ai: 'دستیار', thread: 'گفتگو', modes: { lesson: 'درس', pdf: 'درس', course: 'گروه درس', ai: 'هوش مصنوعی + تحقیق' },
    plan_: 'طرح', provider: 'ارائه‌دهنده', started: 'شروع', expires: 'پایان', trial: 'مصرف دوره‌ی آزمایشی', lessonsUsed: 'درس‌های استفاده‌شده', questionsUsed: 'پرسش از دستیار', monthUsage: 'مصرف ماهانه', month: 'ماه', gens: 'تولید', noSub: 'اشتراک فعالی وجود ندارد.',
    sstatus: { active: 'فعال', expired: 'پایان‌یافته', grace: 'مهلت اضافه', billing_retry: 'تلاش مجدد پرداخت', refunded: 'بازپرداخت', revoked: 'لغو شده' },
    support: 'پیام‌های پشتیبانی', footer: 'Kavis Study · Always Improve More',
  },
  ar: {
    locale: 'ar', title: 'بيانات حسابك', sub: 'ملخص مقروء للمعلومات التي نحتفظ بها في Kavis Study. النسخة القابلة للقراءة آليًا (JSON) من البيانات نفسها هي الرابط الثاني في الرسالة.',
    made: 'تاريخ الإعداد', valid: 'روابط PDF في هذا الملف صالحة {n} أيام.', contents: 'المحتويات',
    profile: 'الملف الشخصي والحساب', settings: 'الإعدادات', devices: 'الأجهزة', courses: 'المواد والجدول الدراسي', lessons: 'الدروس وملفات PDF',
    notes: 'الملاحظات والتظليل', cards: 'البطاقات التعليمية', quizzes: 'الاختبارات والنتائج', plan: 'خطة الدراسة والتقدم', assistant: 'محادثات المساعد', sub_: 'الاشتراك والتجربة',
    name: 'الاسم', email: 'البريد الإلكتروني', school: 'الجامعة', department: 'القسم', classYear: 'السنة', appLang: 'لغة التطبيق', joined: 'تاريخ التسجيل', termsAt: 'تاريخ قبول الشروط', trialStart: 'بداية التجربة',
    langs: { tr: 'التركية', en: 'الإنجليزية', fa: 'الفارسية', ar: 'العربية' },
    yes: 'نعم', no: 'لا', on: 'مفعّل', off: 'متوقف',
    theme: 'المظهر', contentLang: 'لغة المحتوى', sameAsPdf: 'مثل PDF', sameAsApp: 'مثل التطبيق', transLangs: 'لغات الترجمة', transStyle: 'أسلوب الترجمة', studyDays: 'أيام الدراسة في الأسبوع', studyHours: 'ساعات الدراسة يوميًا', timeZone: 'المنطقة الزمنية',
    paper: 'ورق القراءة', fontSize: 'حجم النص', voice: 'صوت القراءة', rate: 'سرعة القراءة', push: 'الإشعارات', reviewReminder: 'تذكير المراجعة', notifyTime: 'وقت الإشعار', cheer: 'إشعارات التشجيع', weekly: 'التقرير الأسبوعي', offline: 'وضع عدم الاتصال', autoDl: 'التنزيل التلقائي',
    themes: { light: 'فاتح', dark: 'داكن', system: 'حسب النظام' },
    device: 'الجهاز', type: 'النوع', firstSeen: 'أول دخول', lastSeen: 'آخر ظهور', signedOut: 'تسجيل الخروج',
    kinds: { web: 'ويب', iphone: 'آيفون', ipad: 'آيباد', pdf: 'PDF' },
    course: 'المادة', term: 'الفصل', color: 'اللون', archived: 'مؤرشفة', exams: 'مواعيد الامتحانات', examKinds: { midterm: 'نصفي', final: 'نهائي', makeup: 'إكمال', quiz: 'اختبار قصير' },
    periods: 'فترات الامتحانات', timetable: 'الجدول الدراسي', day: 'اليوم', time: 'الوقت', room: 'القاعة', teacher: 'المدرّس', ownPlan: 'خطتي الأسبوعية', minutes: 'د',
    days: ['', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'],
    lesson: 'الدرس', title_: 'العنوان', pages: 'الصفحات', added: 'تاريخ الإضافة', status: 'الحالة', download: 'تنزيل PDF', original: 'الملف الأصلي',
    mkinds: { pdf: 'PDF', photo: 'صورة', audio: 'تسجيل صوتي', recording: 'تسجيل محاضرة', text: 'نص', exam_summary: 'ملخص الامتحان', exam_brief: 'ملخص ليلة الامتحان' },
    mstatus: { ready: 'جاهز', failed: 'فشل', processing: 'قيد المعالجة', pending: 'في الانتظار', uploaded: 'تم الرفع' },
    topics: 'المواضيع', hardWords: 'الكلمات الصعبة', summaries: 'الملخصات', page: 'صفحة', pp: 'صفحات', weak: 'موضوع ضعيف',
    skinds: { lesson: 'ملخص الدرس', exam_prep: 'التحضير للامتحان', exam_summary: 'ملخص الامتحان', exam_brief: 'مذكرة الامتحان', section: 'ملخص القسم' },
    highlights: 'التظليل', myNotes: 'ملاحظاتي', inkNotes: 'ملاحظات بخط اليد', inkCount: '{n} ملاحظة بخط اليد (في ملف JSON)', readProg: 'تقدم القراءة', read: 'مقروء', lastPage: 'آخر صفحة',
    deck: 'المجموعة', question: 'السؤال', answer: 'الجواب', note: 'ملاحظة', nextReview: 'المراجعة التالية',
    quiz: 'الاختبار', qCount: 'سؤال', date: 'التاريخ', score: 'الدرجة', level: 'المستوى', yourAnswer: 'إجابتك', correct: 'صحيح', wrong: 'خطأ', unknown: 'لا أعرف', options: 'الخيارات', explanation: 'الشرح', attempts: 'المحاولات', questions: 'الأسئلة',
    qkinds: { exam_prep: 'التحضير للامتحان', basic: 'اختبار موضوع', combined: 'امتحان مختلط', placement: 'تحديد المستوى', lesson_end: 'نهاية الدرس' },
    levels: { beginner: 'مبتدئ', basic: 'أساسي', intermediate: 'متوسط', advanced: 'متقدم' },
    week: 'الأسبوع', stage: 'المرحلة', item: 'المهمة', done: 'تم', todo: 'قيد الانتظار', sessions: 'جلسات الدراسة', total: 'المجموع', activity: 'النشاط', mastery: 'حالة المواضيع',
    acts: { read: 'قراءة', cards: 'بطاقات', quiz: 'اختبار', review: 'مراجعة', assistant: 'المساعد', record: 'تسجيل' },
    states: { known: 'متقن', weak: 'ضعيف', learning: 'قيد التعلم', new: 'جديد' },
    you: 'أنت', ai: 'المساعد', thread: 'محادثة', modes: { lesson: 'درس', pdf: 'درس', course: 'مادة', ai: 'ذكاء اصطناعي + بحث' },
    plan_: 'الخطة', provider: 'المزوّد', started: 'البداية', expires: 'النهاية', trial: 'استخدام التجربة', lessonsUsed: 'الدروس المستخدمة', questionsUsed: 'أسئلة المساعد', monthUsage: 'الاستخدام الشهري', month: 'الشهر', gens: 'عمليات التوليد', noSub: 'لا يوجد اشتراك نشط.',
    sstatus: { active: 'نشط', expired: 'منتهٍ', grace: 'فترة سماح', billing_retry: 'إعادة محاولة الدفع', refunded: 'مُسترد', revoked: 'ملغى' },
    support: 'رسائل الدعم', footer: 'Kavis Study · Always Improve More',
  },
} as const;

const esc = (v: unknown) => String(v ?? '').replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const str = (v: unknown) => (typeof v === 'string' ? v : v == null ? '' : String(v));
const num = (v: unknown) => (typeof v === 'number' ? v : Number(v));

export function buildReport(i: ReportInput): string {
  const t = T[i.lang];
  const rtl = i.lang === 'fa' || i.lang === 'ar';
  const d = i.data;
  const get = (k: string) => d[k] ?? [];
  const date = (v: unknown, withTime = false) => {
    if (!v) return '';
    const x = new Date(String(v));
    if (isNaN(x.getTime())) return str(v);
    return x.toLocaleDateString(t.locale, { day: 'numeric', month: 'long', year: 'numeric', ...(withTime ? { hour: '2-digit', minute: '2-digit' } : {}) });
  };
  const pick = (m: Record<string, string>, k: unknown) => m[str(k)] ?? str(k);
  const bool = (v: unknown) => (v ? t.on : t.off);
  const dash = (v: unknown) => (v === null || v === undefined || v === '' ? '' : esc(v));

  const courses = new Map(get('courses').map((c) => [str(c.id), str(c.name)]));
  const courseName = (id: unknown) => courses.get(str(id)) ?? '';
  const materials = get('materials');
  const matTitle = new Map(materials.map((m) => [str(m.id), str(m.title)]));

  // Hard-word explanations come per language: {tr: {name, text}, en: ...}; the report language first.
  const expl = (v: unknown): string => {
    if (typeof v === 'string') return v;
    const o = (v ?? {}) as Record<string, { text?: string } | string>;
    const x = o[i.lang] ?? Object.values(o)[0];
    return typeof x === 'string' ? x : x?.text ?? '';
  };
  const kv = (rows: [string, unknown][]) => {
    const r = rows.filter(([, v]) => v !== null && v !== undefined && v !== '');
    return r.length ? `<dl>${r.map(([k, v]) => `<dt>${esc(k)}</dt><dd>${v}</dd>`).join('')}</dl>` : '';
  };
  const table = (head: string[], rows: unknown[][]) =>
    rows.length ? `<div class="tw"><table><thead><tr>${head.map((h) => `<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>${rows.map((r) => `<tr>${r.map((c) => `<td>${c ?? ''}</td>`).join('')}</tr>`).join('')}</tbody></table></div>` : '';
  const sec: { id: string; title: string; html: string }[] = [];
  const add = (id: string, title: string, html: string) => { if (html.trim()) sec.push({ id, title, html }); };
  const h3 = (s: string) => `<h3>${esc(s)}</h3>`;

  // 1. profile
  const p = i.profile ?? {};
  add('profile', t.profile, kv([
    [t.name, dash(p.full_name)], [t.email, esc(i.email)], [t.school, dash(p.school)], [t.department, dash(p.department)], [t.classYear, dash(p.class_year)],
    [t.appLang, esc(pick(t.langs, p.app_lang))], [t.joined, esc(date(i.createdAt ?? p.created_at))], [t.termsAt, esc(date(p.terms_accepted_at))], [t.trialStart, esc(date(p.trial_started_at))],
  ]));

  // 2. settings
  const s = get('user_settings')[0];
  if (s) {
    const cl = str(s.content_lang);
    add('settings', t.settings, kv([
      [t.theme, esc(pick(t.themes, s.app_theme))],
      [t.contentLang, esc(!cl || cl === 'pdf' ? t.sameAsPdf : cl === 'app' ? t.sameAsApp : pick(t.langs, cl))],
      [t.transLangs, esc(((s.translation_langs as string[]) ?? []).map((l) => pick(t.langs, l)).join(', '))],
      [t.transStyle, dash(s.translation_style)], [t.studyDays, dash(s.study_days)], [t.studyHours, dash(s.study_hours)], [t.timeZone, dash(s.time_zone)],
      [t.paper, dash(s.reader_paper)], [t.fontSize, dash(s.reader_font_size)], [t.voice, dash(s.tts_voice)], [t.rate, dash(s.tts_rate)],
      [t.push, bool(s.push_notifications)], [t.reviewReminder, bool(s.review_reminder)], [t.notifyTime, dash(str(s.notify_time).slice(0, 5))], [t.cheer, bool(s.cheer_notifications)], [t.weekly, bool(s.weekly_report)],
      [t.offline, bool(s.offline_mode)], [t.autoDl, bool(s.auto_download)],
    ]));
  }

  // 3. devices
  add('devices', t.devices, table([t.device, t.type, t.firstSeen, t.lastSeen, t.signedOut], get('user_devices').map((r) => [
    esc(r.name), esc(pick(t.kinds, r.kind)), esc(date(r.created_at)), esc(date(r.last_seen_at)), esc(date(r.signed_out_at)),
  ])));

  // 4. courses + timetable
  {
    let h = '';
    const exams = get('course_exams');
    h += table([t.course, t.term, t.exams], get('courses').map((c) => [
      esc(c.name) + (c.archived_at ? ` <span class="tag">${esc(t.archived)}</span>` : ''), dash(c.term),
      exams.filter((e) => e.course_id === c.id).map((e) => `${esc(e.label || pick(t.examKinds, e.kind))}: ${esc(date(e.exam_date))}`).join('<br>'),
    ]));
    const per = get('exam_periods');
    if (per.length) h += h3(t.periods) + table([t.type, t.date], per.map((r) => [esc(pick(t.examKinds, r.kind)), `${esc(date(r.start_date))} – ${esc(date(r.end_date))}`]));
    const tt = [...get('timetable_entries')].sort((a, b) => num(a.weekday) - num(b.weekday) || str(a.start_time).localeCompare(str(b.start_time)));
    if (tt.length) h += h3(t.timetable) + table([t.day, t.time, t.course, t.room, t.teacher], tt.map((r) => [esc(t.days[num(r.weekday)] ?? ''), `${esc(str(r.start_time).slice(0, 5))} – ${esc(str(r.end_time).slice(0, 5))}`, esc(r.title || courseName(r.course_id)), dash(r.room), dash(r.teacher)]));
    const own = get('own_plan_items');
    if (own.length) h += h3(t.ownPlan) + table([t.day, t.course, t.minutes], own.map((r) => [esc(t.days[num(r.weekday)] ?? ''), esc(courseName(r.course_id)), esc(r.minutes)]));
    add('courses', t.courses, h);
  }

  // 5. lessons + PDFs (+ topics, hard words, summaries)
  const linkOf = new Map(i.pdfs.map((x) => [x.material_id, x.link]));
  const summaryHtml = (c: unknown): string => {
    const o = c as Row | null;
    if (!o || typeof o !== 'object') return `<p>${esc(c)}</p>`;
    const pts = o.points as Row[] | undefined;
    if (Array.isArray(pts)) return `<ul>${pts.map((x) => `<li>${esc(typeof x === 'string' ? x : x.text)}${x.page_from ? ` <span class="pg">(${esc(t.page)} ${esc(x.page_from)}${x.page_to && x.page_to !== x.page_from ? '–' + esc(x.page_to) : ''})</span>` : ''}${x.weak ? ` <span class="tag">${esc(t.weak)}</span>` : ''}</li>`).join('')}</ul>`;
    const tps = o.topics as Row[] | undefined;
    if (Array.isArray(tps)) return tps.map((x) => `<h4>${esc(x.title)}${x.pageFrom ? ` <span class="pg">(${esc(t.page)} ${esc(x.pageFrom)}${x.pageTo && x.pageTo !== x.pageFrom ? '–' + esc(x.pageTo) : ''})</span>` : ''}</h4>${Array.isArray(x.points) ? `<ul>${(x.points as unknown[]).map((q) => `<li>${esc(typeof q === 'string' ? q : (q as Row).text)}</li>`).join('')}</ul>` : ''}`).join('');
    return flatten(o);
  };
  // Any other shape: every text found, in order.
  const flatten = (v: unknown): string => {
    const out: string[] = [];
    const walk = (x: unknown) => {
      if (typeof x === 'string') { if (x.trim()) out.push(x); } else if (Array.isArray(x)) x.forEach(walk);
      else if (x && typeof x === 'object') Object.entries(x as Row).forEach(([k, y]) => { if (!/^(id|kind|weakKey|color|reason)$/i.test(k)) walk(y); });
    };
    walk(v);
    return out.length ? `<ul>${out.map((x) => `<li>${esc(x)}</li>`).join('')}</ul>` : '';
  };
  {
    let h = '';
    const bycourse = [...new Set(materials.map((m) => str(m.course_id)))];
    for (const cid of bycourse) {
      const ms = materials.filter((m) => str(m.course_id) === cid);
      h += h3(courseName(cid) || t.lesson);
      h += table([t.title_, t.type, t.pages, t.added, t.status, t.original], ms.map((m) => {
        const l = linkOf.get(str(m.id));
        return [esc(m.title), esc(pick(t.mkinds, m.kind)), m.page_count ? esc(m.page_count) : '', esc(date(m.created_at)), esc(pick(t.mstatus, m.status)), l ? `<a href="${esc(l)}">${esc(t.download)}</a>` : ''];
      }));
    }
    const sums = get('summaries');
    for (const m of materials) {
      const top = get('material_topics').filter((x) => x.material_id === m.id);
      const terms = get('material_terms').filter((x) => x.material_id === m.id);
      const ss = sums.filter((x) => x.material_id === m.id);
      if (!top.length && !terms.length && !ss.length) continue;
      h += `<details><summary>${esc(m.title)}</summary>`;
      if (top.length) h += h3(t.topics) + `<ul>${top.map((x) => `<li>${esc(x.title)}${x.page_from ? ` <span class="pg">(${esc(t.page)} ${esc(x.page_from)}${x.page_to && x.page_to !== x.page_from ? '–' + esc(x.page_to) : ''})</span>` : ''}</li>`).join('')}</ul>`;
      if (terms.length) h += h3(t.hardWords) + table([t.title_, t.note], terms.map((x) => [esc(x.surface), esc(expl(x.explanation))]));
      for (const x of ss) h += h3(`${pick(t.skinds, x.kind)} · ${date(x.created_at)}`) + summaryHtml(x.content);
      h += `</details>`;
    }
    const loose = sums.filter((x) => !x.material_id || !matTitle.has(str(x.material_id)));
    for (const x of loose) h += h3(`${pick(t.skinds, x.kind)}${x.course_id ? ' · ' + courseName(x.course_id) : ''} · ${date(x.created_at)}`) + summaryHtml(x.content);
    if (h && i.pdfs.length) h = `<p class="muted">${esc(t.valid.replace('{n}', String(i.linkDays)))}</p>` + h;
    add('lessons', t.lessons, h);
  }

  // 6. notes + highlights
  {
    let h = '';
    const an = get('annotations');
    const text = (r: Row) => str((r.anchor as Row | null)?.text ?? r.text);
    const hl = an.filter((r) => r.kind === 'highlight');
    const nt = an.filter((r) => r.kind !== 'highlight' && r.kind !== 'ink');
    const ink = an.filter((r) => r.kind === 'ink');
    const rows = (l: Row[]) => table([t.lesson, t.pages, t.note], l.map((r) => [esc(matTitle.get(str(r.material_id))), dash(r.page), esc(text(r) || r.text)]));
    if (hl.length) h += h3(t.highlights) + rows(hl);
    if (nt.length) h += h3(t.myNotes) + rows(nt);
    if (ink.length) h += h3(t.inkNotes) + `<p>${esc(t.inkCount.replace('{n}', String(ink.length)))}</p>`;
    const rp = get('reading_progress');
    if (rp.length) h += h3(t.readProg) + table([t.lesson, t.read, t.lastPage, t.date], rp.map((r) => [esc(matTitle.get(str(r.material_id))), r.percent_read != null ? `${Math.round(num(r.percent_read))}%` : '', dash(r.last_page), esc(date(r.updated_at))]));
    add('notes', t.notes, h);
  }

  // 7. flash cards
  {
    const decks = get('card_decks'); const cards = get('flashcards');
    let h = '';
    for (const dk of decks) {
      const cs = cards.filter((c) => c.deck_id === dk.id);
      if (!cs.length) continue;
      h += `<details><summary>${esc(dk.title || matTitle.get(str(dk.material_id)) || courseName(dk.course_id))} <span class="pg">(${cs.length})</span></summary>${table([t.question, t.answer, t.nextReview], cs.map((c) => [esc(c.question), esc(c.answer), esc(date(c.due_at))]))}</details>`;
    }
    add('cards', t.cards, h);
  }

  // 8. quizzes + results
  {
    const qz = get('quizzes'); const qq = get('quiz_questions'); const at = get('quiz_attempts'); const ans = get('quiz_answers');
    let h = '';
    for (const q of qz) {
      const qs = qq.filter((x) => x.quiz_id === q.id).sort((a, b) => num(a.sort_order) - num(b.sort_order));
      const ats = at.filter((x) => x.quiz_id === q.id);
      if (!qs.length && !ats.length) continue;
      h += `<details><summary>${esc(pick(t.qkinds, q.kind))} · ${esc(courseName(q.course_id) || matTitle.get(str(q.material_id)) || '')} · ${esc(date(q.created_at))} <span class="pg">(${qs.length} ${esc(t.qCount)})</span></summary>`;
      if (ats.length) h += h3(t.attempts) + table([t.date, t.score, t.level], ats.map((a) => [esc(date(a.finished_at ?? a.started_at, true)), a.score != null ? esc(Math.round(num(a.score) * (num(a.score) <= 1 ? 100 : 1)) + '%') : '', esc(a.level ? pick(t.levels, a.level) : '')]));
      if (qs.length) {
        const mine = new Map(ans.map((a) => [str(a.question_id), a]));
        h += h3(t.questions) + `<ol class="qs">${qs.map((x) => {
          const opts = Array.isArray(x.options) ? (x.options as string[]) : [];
          const a = mine.get(str(x.id));
          const right = x.kind === 'multiple_choice' ? opts[num(x.answer_index)] : x.model_answer;
          let mineTxt = '';
          if (a) mineTxt = a.dont_know ? t.unknown : a.written_answer ? str(a.written_answer) : a.chosen_index != null ? opts[num(a.chosen_index)] ?? '' : '';
          return `<li><div>${esc(x.text)}</div>${opts.length ? `<ul class="opts">${opts.map((o, k) => `<li${k === num(x.answer_index) ? ' class="ok"' : ''}>${esc(o)}</li>`).join('')}</ul>` : ''}${right && !opts.length ? `<div class="muted">${esc(t.answer)}: ${esc(right)}</div>` : ''}${a ? `<div class="muted">${esc(t.yourAnswer)}: ${esc(mineTxt)} ${a.correct === true ? `<span class="tag ok">${esc(t.correct)}</span>` : a.correct === false ? `<span class="tag bad">${esc(t.wrong)}</span>` : ''}</div>` : ''}${x.explanation ? `<div class="muted">${esc(t.explanation)}: ${esc(x.explanation)}</div>` : ''}</li>`;
        }).join('')}</ol>`;
      }
      h += `</details>`;
    }
    add('quizzes', t.quizzes, h);
  }

  // 9. plan + progress
  {
    let h = '';
    const items = get('plan_items');
    for (const pl of [...get('study_plans')].sort((a, b) => str(b.week_start).localeCompare(str(a.week_start)))) {
      const its = items.filter((x) => x.plan_id === pl.id).sort((a, b) => str(a.day).localeCompare(str(b.day)) || num(a.sort_order) - num(b.sort_order));
      if (!its.length) continue;
      h += `<details><summary>${esc(t.week)}: ${esc(date(pl.week_start))}</summary>${table([t.date, t.course, t.item, t.minutes, t.status], its.map((x) => [esc(date(x.day)), esc(courseName(x.course_id)), esc(x.title), dash(x.minutes), esc(x.status === 'done' ? t.done : t.todo)]))}</details>`;
    }
    const ss = get('study_sessions');
    if (ss.length) {
      const byAct = new Map<string, number>();
      for (const x of ss) byAct.set(str(x.activity), (byAct.get(str(x.activity)) ?? 0) + (num(x.minutes) || 0));
      h += h3(t.sessions) + table([t.activity, t.minutes], [...byAct].map(([k, v]) => [esc(pick(t.acts, k)), esc(Math.round(v))]).concat([[`<b>${esc(t.total)}</b>`, `<b>${esc(Math.round([...byAct.values()].reduce((a, b) => a + b, 0)))}</b>`]]));
    }
    const tp = get('topic_progress');
    if (tp.length) {
      const cnt = new Map<string, number>();
      for (const x of tp) cnt.set(str(x.state), (cnt.get(str(x.state)) ?? 0) + 1);
      h += h3(t.mastery) + table([t.status, '#'], [...cnt].map(([k, v]) => [esc(pick(t.states, k)), esc(v)]));
    }
    add('plan', t.plan, h);
  }

  // 10. assistant
  {
    const msgs = get('assistant_messages'); let h = '';
    for (const th of [...get('assistant_threads')].sort((a, b) => str(b.updated_at).localeCompare(str(a.updated_at)))) {
      const ms = msgs.filter((m) => m.thread_id === th.id).sort((a, b) => str(a.created_at).localeCompare(str(b.created_at)));
      if (!ms.length) continue;
      const title = str(th.title) || matTitle.get(str(th.material_id)) || courseName(th.course_id) || t.thread;
      h += `<details><summary>${esc(title)} · ${esc(date(th.updated_at ?? th.created_at))}</summary>${ms.map((m) => `<div class="msg ${m.role === 'user' ? 'me' : 'ai'}"><b>${esc(m.role === 'user' ? t.you : t.ai)}</b><p>${esc(m.content).replace(/\n/g, '<br>')}</p></div>`).join('')}</details>`;
    }
    const sup = get('support_messages');
    if (sup.length) h += h3(t.support) + sup.map((m) => `<div class="msg"><p>${esc(m.body ?? m.content ?? m.message ?? '')}</p></div>`).join('');
    add('assistant', t.assistant, h);
  }

  // 11. subscription + trial
  {
    let h = '';
    const subs = get('subscriptions');
    if (subs.length) h += table([t.provider, t.status, t.started, t.expires], subs.map((x) => [esc(x.provider), esc(pick(t.sstatus, x.status)), esc(date(x.started_at)), esc(date(x.expires_at))]));
    const tr = get('trial_usage')[0];
    if (tr) h += h3(t.trial) + kv([[t.lessonsUsed, esc(tr.lessons)], [t.questionsUsed, esc(tr.assistant_questions)]]);
    const um = get('usage_monthly');
    if (um.length) h += h3(t.monthUsage) + table([t.month, t.lessonsUsed, t.questionsUsed, t.gens], um.map((x) => [esc(str(x.month).slice(0, 7)), esc(x.lessons), esc(x.assistant_questions), esc(x.generations)]));
    add('sub', t.sub_, h);
  }

  const font = rtl ? "Vazirmatn, Tahoma, 'Segoe UI', Arial, sans-serif" : "Poppins, -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif";
  const css = `*{box-sizing:border-box}body{margin:0;background:#F1E9DA;color:#2A2420;font:15px/1.6 ${font};-webkit-text-size-adjust:100%}
.w{max-width:860px;margin:0 auto;padding:20px 16px 48px}
header{background:#9C2F3A;color:#FBF6EC;border-radius:28px;padding:26px 24px;margin-bottom:18px}
header .b{font-weight:700;font-size:15px;letter-spacing:.02em;color:#F2B33D}
h1{margin:6px 0 8px;font-size:26px;line-height:1.25}header p{margin:0;font-size:13px;opacity:.92}
nav{background:#FBF6EC;border:1px solid #E0D4BE;border-radius:22px;padding:14px 20px;margin-bottom:18px}
nav b{display:block;margin-bottom:6px;font-size:13px;color:#6E645A}nav a{display:inline-block;margin:3px 0;margin-inline-end:6px;padding:4px 12px;border-radius:999px;background:#F1E9DA;color:#9C2F3A;text-decoration:none;font-size:13px;font-weight:600}
section{background:#FBF6EC;border:1px solid #E0D4BE;border-radius:24px;padding:20px 22px;margin-bottom:16px}
h2{margin:0 0 12px;font-size:19px;color:#9C2F3A;border-bottom:2px solid #F2B33D;padding-bottom:8px}h3{margin:18px 0 8px;font-size:15px}h4{margin:12px 0 4px;font-size:14px}
dl{display:grid;grid-template-columns:minmax(110px,max-content) 1fr;gap:6px 16px;margin:0}dt{color:#6E645A;font-size:13px}dd{margin:0;word-break:break-word}
.tw{overflow-x:auto;margin:6px 0}table{border-collapse:collapse;width:100%;font-size:13px}th,td{text-align:start;padding:7px 10px;border-bottom:1px solid #E0D4BE;vertical-align:top}th{color:#6E645A;font-weight:600;white-space:nowrap}
ul,ol{margin:6px 0;padding-inline-start:22px}li{margin:3px 0}.opts{margin:2px 0 4px;font-size:13px;color:#6E645A}.opts .ok{color:#2A2420;font-weight:600}
details{border:1px solid #E0D4BE;border-radius:16px;padding:10px 14px;margin:8px 0;background:#F1E9DA}summary{cursor:pointer;font-weight:600}
.muted{color:#6E645A;font-size:13px}.pg{color:#6E645A;font-weight:400;font-size:12px}
.tag{display:inline-block;background:#F2B33D;color:#2A2420;border-radius:999px;padding:0 8px;font-size:11px;font-weight:600}.tag.ok{background:#CFE6C8}.tag.bad{background:#EFC4C4}
.msg{border-radius:16px;padding:6px 12px;margin:8px 0;background:#FBF6EC}.msg.me{background:#F6DDDF}.msg p{margin:2px 0}
a{color:#9C2F3A}footer{text-align:center;color:#6E645A;font-size:12px;margin-top:20px}
@media print{body{background:#fff}details{display:block}details>*{display:block}}`;
  return `<!doctype html><html lang="${i.lang}" dir="${rtl ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><meta name="robots" content="noindex"><title>Kavis Study · ${esc(t.title)}</title><style>${css}</style></head><body><div class="w">
<header><div class="b">Kavis Study</div><h1>${esc(t.title)}</h1><p>${esc(t.sub)}</p><p style="margin-top:8px">${esc(t.made)}: ${esc(date(i.exportedAt, true))}</p></header>
<nav><b>${esc(t.contents)}</b>${sec.map((x) => `<a href="#${x.id}">${esc(x.title)}</a>`).join('')}</nav>
${sec.map((x) => `<section id="${x.id}"><h2>${esc(x.title)}</h2>${x.html}</section>`).join('\n')}
<footer>${esc(t.footer)}</footer></div></body></html>`;
}
