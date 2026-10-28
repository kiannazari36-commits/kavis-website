import type { Lang } from './I18nProvider';

// DRAFT legal texts (terms of use + privacy policy / KVKK + GDPR). NOT checked by a lawyer yet.
// Placeholders in [SQUARE BRACKETS] must be filled in before launch. Facts follow CLAUDE.md product rules.
export type Section = { h: string; p: string[] };
export type LegalDoc = { title: string; sections: Section[] };
type Chrome = { draft: string; updated: string; back: string; terms: string; privacy: string; footer: string };

export const CONTACT_EMAIL = 'kavisstudy@gmail.com';

export const LEGAL_CHROME: Record<Lang, Chrome> = {
  tr: {
    draft: 'TASLAK – Bu metin henüz bir avukat tarafından kontrol edilmedi ve hukuki geçerliliği yoktur. Yayından önce avukat kontrolü gerekir.',
    updated: 'Son güncelleme: 27 Ekim 2026 (taslak)',
    back: 'Ana sayfa',
    terms: 'Kullanım koşulları',
    privacy: 'Gizlilik ve KVKK',
    footer: 'Kavis Study',
  },
  en: {
    draft: 'DRAFT – This text has not yet been reviewed by a lawyer and has no legal force. A lawyer’s check is required before launch.',
    updated: 'Last updated: 27 October 2026 (draft)',
    back: 'Home',
    terms: 'Terms of use',
    privacy: 'Privacy policy',
    footer: 'Kavis Study',
  },
  fa: {
    draft: 'پیش‌نویس – این متن هنوز توسط وکیل بررسی نشده و اعتبار حقوقی ندارد. پیش از انتشار باید توسط وکیل بررسی شود.',
    updated: 'آخرین به‌روزرسانی: ۲۷ اکتبر ۲۰۲۶ (پیش‌نویس)',
    back: 'صفحه اصلی',
    terms: 'شرایط استفاده',
    privacy: 'حریم خصوصی',
    footer: 'Kavis Study',
  },
  ar: {
    draft: 'مسودة – لم يراجع محامٍ هذا النص بعد وليس له أي قوة قانونية. تلزم مراجعة محامٍ قبل الإطلاق.',
    updated: 'آخر تحديث: 27 أكتوبر 2026 (مسودة)',
    back: 'الصفحة الرئيسية',
    terms: 'شروط الاستخدام',
    privacy: 'سياسة الخصوصية',
    footer: 'Kavis Study',
  },
};

const M = CONTACT_EMAIL;

export const TERMS: Record<Lang, LegalDoc> = {
  tr: {
    title: 'Kullanım koşulları',
    sections: [
      { h: '1. Taraflar ve hizmet', p: [
        'Kavis Study (“Kavis”), [ŞİRKET ADI], [ADRES] tarafından sunulur. İletişim: ' + M + '.',
        'Kavis, öğrencinin yüklediği PDF, slayt fotoğrafı veya ders kaydını; öğretmenin metnini değiştirmeden okuma sayfasına, özetlere, sesli anlatıma, kartlara, sınavlara, çalışma planına ve bir yapay zekâ asistanına dönüştüren bir çalışma uygulamasıdır. Uygulamayı kullanarak bu koşulları kabul etmiş olursun.',
      ] },
      { h: '2. Hesap ve cihazlar', p: [
        'Hesap açmak için doğru bir e-posta adresi vermelisin; hesabının güvenliğinden sen sorumlusun.',
        'Bir hesap en fazla 2 cihazda açık olabilir (web bir cihaz sayılır). Üçüncü bir cihazda oturum açmak için mevcut cihazlardan birinin oturumunu kapatman gerekir.',
      ] },
      { h: '3. Senin içeriğin', p: [
        'Yüklediğin PDF’ler, fotoğraflar, kayıtlar ve notlar sana aittir. Bunları yüklemek için gerekli haklara (ör. ders materyalini kişisel çalışma için kullanma hakkı) sahip olduğunu kabul edersin.',
        'Kavis içeriğini yalnızca sana hizmet sunmak için işler. Yapay zekâ yalnızca senin yüklediğin materyali kullanır; başka kişilerin materyalini sana göstermez.',
        'Yasa dışı, başkalarının haklarını ihlal eden veya zararlı içerik yükleyemezsin.',
      ] },
      { h: '4. Ücretsiz deneme ve Premium', p: [
        'Ücretsiz deneme kart bilgisi gerektirmez ve 3 gün sürer; en fazla 2 ders (PDF), 60 asistan sorusu ve PDF başına en fazla 100 sayfa içerir. Deneme bittiğinde ücretlendirme yapılmaz.',
        'Deneme bittikten sonra eski PDF’lerini okumaya, kendi notlarına, vurgulamalarına, mevcut kartlarına ve özetlerine ve çevrimdışı kullanıma devam edersin. Yeni PDF yükleme, yeni asistan soruları, yeni sınav/kart üretme ve paylaşma yalnızca Premium’dadır.',
        'Premium, iPhone uygulamasında Apple uygulama içi satın alma ile satılır; fiyatı ve para birimini Apple ülkene göre belirler. Ödeme Apple ID hesabından alınır, abonelik süre bitiminden en az 24 saat önce iptal edilmezse otomatik yenilenir. Aboneliği iPhone’un Ayarlar › Apple ID › Abonelikler bölümünden yönetebilir ve iptal edebilirsin. İade talepleri Apple’ın kurallarına tabidir. Web sitesinde Premium satılmaz; Premium, hesabına bağlıdır ve giriş yaptığın tüm cihazlarda geçerlidir.',
      ] },
      { h: '5. Paylaşım', p: [
        'Paylaşım yalnızca Premium’dadır ve yalnızca uygulamanın ürettiği içerikleri (sınavlar, özetler, kartlar) kapsar; orijinal PDF asla paylaşılmaz. Paylaşım bağlantısı, uygulamayı indirmeni isteyen bir sayfa açar. Premium’u olmayan alıcı dersi açamaz.',
      ] },
      { h: '6. Yapay zekâ ve doğruluk', p: [
        'Özetler, sorular, kartlar ve asistan cevapları yapay zekâ ile üretilir ve hata içerebilir. Bunlar öğretmeninin ders materyalinin ve resmî kaynakların yerine geçmez. Sağlık ve ilaç konularında uygulama tıbbi tavsiye vermez; hasta bakımı kararlarında kullanılmamalıdır.',
      ] },
      { h: '7. Kabul edilemez kullanım', p: [
        'Hizmeti kötüye kullanamaz, güvenliğini aşmaya çalışamaz, otomatik araçlarla toplu veri çekemez, hesabını başkasıyla paylaşamaz ve hizmeti yasa dışı amaçla kullanamazsın. Bu kuralları ihlal edersen hesabını askıya alabilir veya kapatabiliriz.',
      ] },
      { h: '8. Hesabı silme', p: [
        'Hesabını istediğin zaman Ayarlar’dan silebilirsin. Silme talebinden 30 gün sonra hesabın ve tüm içeriğin kalıcı olarak silinir; bu sürede talebi iptal edebilirsin. Aktif bir abonelik varsa Apple’dan ayrıca iptal etmen gerekir.',
      ] },
      { h: '9. Sorumluluğun sınırı', p: [
        'Hizmet “olduğu gibi” sunulur. Yasanın izin verdiği ölçüde, Kavis hizmetin kesintisiz veya hatasız olacağını garanti etmez ve dolaylı zararlardan sorumlu değildir. Tüketici olarak sahip olduğun yasal haklar saklıdır. [AVUKAT KONTROL EDECEK: sorumluluk sınırı]',
      ] },
      { h: '10. Değişiklikler, hukuk ve iletişim', p: [
        'Bu koşulları değiştirebiliriz; önemli değişiklikleri uygulama veya e-posta ile duyururuz. Uyuşmazlıklarda [YETKİLİ HUKUK VE MAHKEME – avukat belirleyecek] geçerlidir. Sorular için: ' + M + '.',
      ] },
    ],
  },
  en: {
    title: 'Terms of use',
    sections: [
      { h: '1. Who we are and the service', p: [
        'Kavis Study (“Kavis”) is provided by [COMPANY NAME], [ADDRESS]. Contact: ' + M + '.',
        'Kavis is a study app that turns the PDF, slide photo or lecture recording you upload into a reading page (without changing your teacher’s text), summaries, audio narration, flash cards, quizzes, a study plan and an AI assistant. By using the app you accept these terms.',
      ] },
      { h: '2. Account and devices', p: [
        'You must give a valid email address and keep your account secure.',
        'One account can be signed in on at most 2 devices (the web counts as one). To sign in on a third device you must sign out one of the others.',
      ] },
      { h: '3. Your content', p: [
        'The PDFs, photos, recordings and notes you upload belong to you. You confirm that you have the right to upload them (for example, to use course material for your own study).',
        'Kavis processes your content only to provide the service to you. The AI uses only the material you uploaded and never shows you other people’s material.',
        'You may not upload content that is unlawful, infringes others’ rights or is harmful.',
      ] },
      { h: '4. Free trial and Premium', p: [
        'The free trial needs no payment card and lasts 3 days, with up to 2 lessons (PDFs), 60 assistant questions and up to 100 pages per PDF. You are not charged when the trial ends.',
        'After the trial you keep reading your existing PDFs, your own notes, highlights, existing cards and summaries, and offline use. Uploading new PDFs, new assistant questions, generating new quizzes/cards and sharing are Premium only.',
        'Premium is sold only in the iPhone app through Apple in-app purchase; Apple sets the price and currency for your country. Payment is charged to your Apple ID and the subscription renews automatically unless cancelled at least 24 hours before the period ends. You can manage or cancel it in iPhone Settings › Apple ID › Subscriptions. Refunds are subject to Apple’s rules. Premium is not sold on the website; it is tied to your account and works on every device you sign in on.',
      ] },
      { h: '5. Sharing', p: [
        'Sharing is Premium only and covers only what the app made (quizzes, summaries, flash cards); the original PDF is never shared. A share link opens a page asking the receiver to download the app. A receiver without Premium cannot open the lesson.',
      ] },
      { h: '6. AI and accuracy', p: [
        'Summaries, questions, cards and assistant answers are produced by AI and may contain mistakes. They do not replace your teacher’s material or official sources. The app gives no medical advice and must not be used for patient-care decisions.',
      ] },
      { h: '7. Unacceptable use', p: [
        'You may not abuse the service, try to break its security, scrape it with automated tools, share your account or use it for unlawful purposes. We may suspend or close accounts that break these rules.',
      ] },
      { h: '8. Deleting your account', p: [
        'You can delete your account in Settings at any time. 30 days after the request your account and all content are permanently deleted; you can cancel the request during that time. If you have an active subscription, cancel it separately with Apple.',
      ] },
      { h: '9. Limit of liability', p: [
        'The service is provided “as is”. To the extent allowed by law, Kavis does not guarantee uninterrupted or error-free service and is not liable for indirect damages. Your statutory consumer rights remain. [LAWYER TO CHECK: limitation of liability]',
      ] },
      { h: '10. Changes, governing law and contact', p: [
        'We may change these terms and will announce important changes in the app or by email. Disputes are governed by [GOVERNING LAW AND COURTS – to be set by a lawyer]. Questions: ' + M + '.',
      ] },
    ],
  },
  fa: {
    title: 'شرایط استفاده',
    sections: [
      { h: '۱. ارائه‌دهنده و خدمت', p: [
        'Kavis Study («کاویس») توسط [نام شرکت]، [نشانی] ارائه می‌شود. تماس: ' + M + '.',
        'کاویس یک برنامه مطالعه است که PDF، عکس اسلاید یا ضبط کلاسی را که بارگذاری می‌کنی بدون تغییر متن استاد به صفحه مطالعه، خلاصه، روخوانی صوتی، فلش‌کارت، آزمون، برنامه مطالعه و دستیار هوش مصنوعی تبدیل می‌کند. با استفاده از برنامه، این شرایط را می‌پذیری.',
      ] },
      { h: '۲. حساب و دستگاه‌ها', p: [
        'باید ایمیل معتبر بدهی و امنیت حسابت را حفظ کنی.',
        'هر حساب حداکثر روی ۲ دستگاه باز می‌ماند (وب یک دستگاه حساب می‌شود). برای ورود در دستگاه سوم باید از یکی از دستگاه‌های دیگر خارج شوی.',
      ] },
      { h: '۳. محتوای تو', p: [
        'PDFها، عکس‌ها، ضبط‌ها و یادداشت‌هایی که بارگذاری می‌کنی متعلق به توست. تأیید می‌کنی که حق بارگذاری آن‌ها را داری (مثلاً استفاده از مطالب درسی برای مطالعه شخصی).',
        'کاویس محتوای تو را فقط برای ارائه خدمت به خودت پردازش می‌کند. هوش مصنوعی فقط از مطالبی که خودت بارگذاری کرده‌ای استفاده می‌کند و مطالب دیگران را به تو نشان نمی‌دهد.',
        'بارگذاری محتوای غیرقانونی، ناقض حقوق دیگران یا زیان‌بار مجاز نیست.',
      ] },
      { h: '۴. دوره آزمایشی و پریمیوم', p: [
        'دوره آزمایشی رایگان به کارت بانکی نیاز ندارد و ۳ روز است؛ حداکثر ۲ درس (PDF)، ۶۰ پرسش از دستیار و حداکثر ۱۰۰ صفحه برای هر PDF. پس از پایان دوره، پولی از تو گرفته نمی‌شود.',
        'پس از پایان دوره، خواندن PDFهای قبلی، یادداشت‌ها، هایلایت‌ها، کارت‌ها و خلاصه‌های موجود و استفاده آفلاین برایت می‌ماند. بارگذاری PDF جدید، پرسش‌های جدید از دستیار، ساخت آزمون/کارت جدید و اشتراک‌گذاری فقط در پریمیوم است.',
        'پریمیوم فقط در برنامه آیفون و از طریق خرید درون‌برنامه‌ای اپل فروخته می‌شود؛ قیمت و واحد پول را اپل برای کشور تو تعیین می‌کند. هزینه از Apple ID تو کسر می‌شود و اشتراک خودکار تمدید می‌شود مگر دست‌کم ۲۴ ساعت پیش از پایان دوره لغو شود. می‌توانی آن را در تنظیمات آیفون › Apple ID › اشتراک‌ها مدیریت یا لغو کنی. بازپرداخت تابع قوانین اپل است. پریمیوم در وب‌سایت فروخته نمی‌شود؛ به حساب تو وابسته است و روی همه دستگاه‌هایی که وارد می‌شوی معتبر است.',
      ] },
      { h: '۵. اشتراک‌گذاری', p: [
        'اشتراک‌گذاری فقط در پریمیوم است و فقط شامل چیزهایی می‌شود که برنامه ساخته (آزمون، خلاصه، فلش‌کارت)؛ PDF اصلی هرگز به اشتراک گذاشته نمی‌شود. لینک اشتراک صفحه‌ای باز می‌کند که از گیرنده می‌خواهد برنامه را دانلود کند. گیرنده بدون پریمیوم نمی‌تواند درس را باز کند.',
      ] },
      { h: '۶. هوش مصنوعی و دقت', p: [
        'خلاصه‌ها، پرسش‌ها، کارت‌ها و پاسخ‌های دستیار با هوش مصنوعی ساخته می‌شوند و ممکن است خطا داشته باشند. جایگزین مطالب استاد و منابع رسمی نیستند. برنامه توصیه پزشکی نمی‌دهد و نباید برای تصمیم‌های مراقبت از بیمار استفاده شود.',
      ] },
      { h: '۷. استفاده غیرمجاز', p: [
        'نباید از خدمت سوءاستفاده کنی، امنیت آن را دور بزنی، با ابزار خودکار داده جمع کنی، حسابت را با دیگری شریک شوی یا برای مقاصد غیرقانونی استفاده کنی. در صورت نقض، ممکن است حساب را معلق یا مسدود کنیم.',
      ] },
      { h: '۸. حذف حساب', p: [
        'هر زمان می‌توانی حسابت را از تنظیمات حذف کنی. ۳۰ روز پس از درخواست، حساب و همه محتوا برای همیشه پاک می‌شود و در این مدت می‌توانی درخواست را لغو کنی. اگر اشتراک فعال داری، آن را جداگانه از اپل لغو کن.',
      ] },
      { h: '۹. محدودیت مسئولیت', p: [
        'خدمت «به همان صورت که هست» ارائه می‌شود. تا حدی که قانون اجازه می‌دهد، کاویس بی‌وقفه یا بی‌خطا بودن خدمت را تضمین نمی‌کند و مسئول خسارت‌های غیرمستقیم نیست. حقوق قانونی تو به‌عنوان مصرف‌کننده محفوظ است. [وکیل بررسی کند: محدودیت مسئولیت]',
      ] },
      { h: '۱۰. تغییرات، قانون حاکم و تماس', p: [
        'ممکن است این شرایط را تغییر دهیم و تغییرات مهم را در برنامه یا با ایمیل اعلام می‌کنیم. قانون حاکم و دادگاه صالح: [توسط وکیل تعیین شود]. پرسش‌ها: ' + M + '.',
      ] },
    ],
  },
  ar: {
    title: 'شروط الاستخدام',
    sections: [
      { h: '1. الجهة المقدّمة والخدمة', p: [
        'تقدّم [اسم الشركة]، [العنوان] تطبيق Kavis Study («كافيس»). للتواصل: ' + M + '.',
        'كافيس تطبيق للدراسة يحوّل ملف PDF أو صورة الشريحة أو تسجيل المحاضرة الذي ترفعه إلى صفحة قراءة (دون تغيير نص أستاذك) وملخصات وسرد صوتي وبطاقات واختبارات وخطة دراسة ومساعد بالذكاء الاصطناعي. باستخدامك التطبيق فأنت توافق على هذه الشروط.',
      ] },
      { h: '2. الحساب والأجهزة', p: [
        'يجب أن تقدّم بريدًا إلكترونيًا صحيحًا وأن تحافظ على أمان حسابك.',
        'يمكن فتح الحساب الواحد على جهازين كحدّ أقصى (يُحتسب الويب جهازًا واحدًا). لتسجيل الدخول على جهاز ثالث عليك تسجيل الخروج من أحد الجهازين الآخرين.',
      ] },
      { h: '3. محتواك', p: [
        'ملفات PDF والصور والتسجيلات والملاحظات التي ترفعها ملك لك. وتقرّ بأن لديك الحق في رفعها (مثل استخدام المادة الدراسية لدراستك الشخصية).',
        'يعالج كافيس محتواك فقط لتقديم الخدمة لك. يستخدم الذكاء الاصطناعي المواد التي رفعتها أنت فقط ولا يعرض عليك مواد الآخرين.',
        'لا يجوز رفع محتوى غير قانوني أو ينتهك حقوق الآخرين أو ضارّ.',
      ] },
      { h: '4. التجربة المجانية وبريميوم', p: [
        'التجربة المجانية لا تتطلب بطاقة بنكية وتدوم 3 أيام، بحد أقصى درسان (PDF) و60 سؤالًا للمساعد و100 صفحة لكل PDF. لا يتم أي خصم عند انتهاء التجربة.',
        'بعد التجربة تحتفظ بقراءة ملفات PDF السابقة وملاحظاتك وتمييزاتك وبطاقاتك وملخصاتك الحالية والاستخدام دون اتصال. رفع PDF جديد وأسئلة المساعد الجديدة وإنشاء اختبارات/بطاقات جديدة والمشاركة متاحة في بريميوم فقط.',
        'يُباع بريميوم في تطبيق الآيفون فقط عبر الشراء داخل التطبيق من Apple، وتحدد Apple السعر والعملة لبلدك. يُخصم المبلغ من حساب Apple ID ويتجدد الاشتراك تلقائيًا ما لم يُلغَ قبل 24 ساعة على الأقل من نهاية المدة. يمكنك إدارته أو إلغاؤه من إعدادات الآيفون › Apple ID › الاشتراكات. تخضع المبالغ المستردة لقواعد Apple. لا يُباع بريميوم على الموقع؛ فهو مرتبط بحسابك ويعمل على كل جهاز تسجّل الدخول منه.',
      ] },
      { h: '5. المشاركة', p: [
        'المشاركة لمشتركي بريميوم فقط وتشمل ما أنشأه التطبيق فقط (اختبارات وملخصات وبطاقات)؛ ولا يُشارك ملف PDF الأصلي أبدًا. يفتح رابط المشاركة صفحة تطلب من المستلم تنزيل التطبيق. لا يستطيع المستلم غير المشترك في بريميوم فتح الدرس.',
      ] },
      { h: '6. الذكاء الاصطناعي والدقة', p: [
        'تُنتَج الملخصات والأسئلة والبطاقات وإجابات المساعد بالذكاء الاصطناعي وقد تحتوي على أخطاء. ولا تغني عن مادة أستاذك أو المصادر الرسمية. لا يقدّم التطبيق نصيحة طبية ولا يجوز استخدامه في قرارات رعاية المرضى.',
      ] },
      { h: '7. الاستخدام غير المقبول', p: [
        'لا يجوز إساءة استخدام الخدمة أو محاولة اختراق أمانها أو جمع البيانات منها بأدوات آلية أو مشاركة حسابك أو استخدامها لأغراض غير قانونية. قد نعلّق الحسابات المخالفة أو نغلقها.',
      ] },
      { h: '8. حذف الحساب', p: [
        'يمكنك حذف حسابك من الإعدادات في أي وقت. بعد 30 يومًا من الطلب يُحذف حسابك وكل المحتوى نهائيًا، ويمكنك إلغاء الطلب خلال هذه المدة. إذا كان لديك اشتراك نشط فألغِه بشكل منفصل لدى Apple.',
      ] },
      { h: '9. حدود المسؤولية', p: [
        'تُقدَّم الخدمة «كما هي». بالقدر الذي يسمح به القانون، لا يضمن كافيس أن تكون الخدمة بلا انقطاع أو أخطاء ولا يتحمل مسؤولية الأضرار غير المباشرة. تبقى حقوقك القانونية كمستهلك محفوظة. [على المحامي المراجعة: حدود المسؤولية]',
      ] },
      { h: '10. التغييرات والقانون الواجب التطبيق والتواصل', p: [
        'قد نغيّر هذه الشروط وسنعلن التغييرات المهمة في التطبيق أو بالبريد الإلكتروني. القانون والمحاكم المختصة: [يحددها المحامي]. للاستفسار: ' + M + '.',
      ] },
    ],
  },
};

export const PRIVACY: Record<Lang, LegalDoc> = {
  tr: {
    title: 'Gizlilik politikası ve KVKK aydınlatma metni',
    sections: [
      { h: '1. Veri sorumlusu', p: [
        'Veri sorumlusu: [ŞİRKET ADI], [ADRES]. İletişim: ' + M + '. [VERBİS / AB temsilcisi bilgisi – avukat belirleyecek]',
      ] },
      { h: '2. Hangi verileri işliyoruz', p: [
        'Hesap: e-posta adresi, adın (isteğe bağlı), giriş yöntemi (e-posta kodu, Apple veya Google), dil ve tema tercihlerin.',
        'İçerik: yüklediğin PDF’ler, slayt fotoğrafları, ders kaydının metne çevrilmiş hâli (konuşma-yazıya çevirme cihazında yapılır; sunucuya yalnızca metin gönderilir), notların, vurgulamaların ve ders programın.',
        'Kullanım: okuma ilerlemesi, çalışma süreleri, sınav ve kart sonuçları, asistan soruların, kullanım sayaçları (deneme limitleri için).',
        'Cihaz ve abonelik: kayıtlı cihazların (en fazla 2), abonelik durumu (Apple’dan doğrulanan işlem bilgisi). Kart bilgilerini biz görmeyiz ve saklamayız; ödemeyi Apple alır.',
      ] },
      { h: '3. Amaçlar ve hukuki sebepler', p: [
        'Verilerini hizmeti sunmak (sözleşmenin ifası), hesabını ve cihaz sınırını yönetmek, aboneliği doğrulamak, güvenliği sağlamak ve hukuki yükümlülükleri yerine getirmek için işleriz. KVKK m.5/2 (c) sözleşmenin ifası, (ç) hukuki yükümlülük, (f) meşru menfaat; GDPR m.6(1)(b), (c), (f). Pazarlama bildirimi göndermeden önce ayrıca açık rızanı isteriz. [AVUKAT KONTROL EDECEK]',
      ] },
      { h: '4. Yapay zekâ işleme', p: [
        'Özet, soru, kart ve asistan cevaplarını üretmek için içeriğin, Anthropic’in Claude yapay zekâ modeline gönderilir. Model yalnızca senin yüklediğin materyali kullanır. Yardım sohbetine yazdığın mesajlar yalnızca cevap verilmesi için yapay zekâya gönderilir ve kaydedilmez. Anthropic ile veri işleme sözleşmemize göre içeriğin model eğitimi için kullanılmaz. [AVUKAT/SÖZLEŞME KONTROL EDECEK]',
        'Ders verisinin yeniden kullanımı: aynı PDF dosyasını yükleyen öğrenciler için işlenmiş ders verisi (okuma sayfası, kelime açıklamaları, sorular, kartlar, özet) yeniden kullanılabilir; böylece aynı dosya için yapay zekâ işlemi tekrarlanmaz. Notların, ilerlemen, cevapların ve sohbetlerin gibi kişisel verilerin diğer öğrencilere kopyalanmaz ve orijinal PDF’in paylaşılmaz.',
      ] },
      { h: '5. Verilerin saklandığı yer ve aktarım', p: [
        'Verilerin Supabase üzerinde AB’de (İrlanda, eu-west-1) saklanır. Yapay zekâ işleme için içerik Anthropic’e, abonelik doğrulaması için ilgili bilgiler Apple’a aktarılır; bu aktarımlar yurt dışına aktarım sayılabilir. KVKK m.9 ve GDPR Bölüm V kapsamındaki güvenceler uygulanır. [AVUKAT KONTROL EDECEK]',
        'Verilerini reklam amacıyla satmayız veya üçüncü kişilerle paylaşmayız. Paylaşım özelliğinde yalnızca uygulamanın ürettiği içerik paylaşılır, orijinal PDF asla paylaşılmaz.',
      ] },
      { h: '6. Saklama süresi', p: [
        'Verilerini hesabın açık olduğu sürece saklarız. Hesabını silme talebinden 30 gün sonra hesabın ve tüm içeriğin kalıcı olarak silinir; bu sürede talebi iptal edebilirsin. Yasal olarak saklamamız gereken kayıtlar (ör. abonelik işlemleri) ilgili süre boyunca ayrıca tutulabilir.',
      ] },
      { h: '7. Haklarınız', p: [
        'KVKK m.11 ve GDPR kapsamında: verilerinin işlenip işlenmediğini öğrenme, bilgi isteme, düzeltme, silme, işlemeye itiraz etme, verilerini taşıma ve otomatik işlemeye ilişkin haklara sahipsin. Uygulama içinde Ayarlar’dan verilerini dışa aktarabilir ve hesabını silebilirsin. Diğer talepler için: ' + M + '. Ayrıca Kişisel Verileri Koruma Kurulu’na veya bulunduğun ülkenin veri koruma otoritesine başvurabilirsin.',
      ] },
      { h: '8. Çerezler ve cihazdaki veriler', p: [
        'Web sitesi oturum, dil ve tema tercihini tarayıcında saklar. Reklam çerezi kullanmıyoruz. Uygulama, çevrimdışı kullanım için içeriğini cihazında önbelleğe alır.',
      ] },
      { h: '9. Güvenlik ve çocuklar', p: [
        'Verileri aktarım sırasında şifreleriz, erişimi hesap bazında kısıtlarız. Hizmet [MİNİMUM YAŞ – avukat belirleyecek] yaşından küçükler için tasarlanmamıştır.',
      ] },
      { h: '10. Değişiklikler', p: [
        'Bu metni güncelleyebiliriz; önemli değişiklikleri uygulama veya e-posta ile duyururuz. Sorular için: ' + M + '.',
      ] },
    ],
  },
  en: {
    title: 'Privacy policy (GDPR / KVKK notice)',
    sections: [
      { h: '1. Controller', p: [
        'Data controller: [COMPANY NAME], [ADDRESS]. Contact: ' + M + '. [Registration / EU representative details – to be set by a lawyer]',
      ] },
      { h: '2. What data we process', p: [
        'Account: email address, your name (optional), sign-in method (email code, Apple or Google), language and theme preferences.',
        'Content: the PDFs and slide photos you upload, the text of lecture recordings (speech-to-text runs on your device; only the transcript is sent to the server), your notes, highlights and class timetable.',
        'Usage: reading progress, study time, quiz and card results, your assistant questions, usage counters (for trial limits).',
        'Devices and subscription: your registered devices (max 2) and subscription status (transaction data verified with Apple). We never see or store your card details; Apple takes the payment.',
      ] },
      { h: '3. Purposes and legal bases', p: [
        'We process data to provide the service (performance of a contract), manage your account and device limit, verify your subscription, keep the service secure and meet legal obligations. GDPR Art. 6(1)(b), (c), (f); KVKK Art. 5/2 (c), (ç), (f). We ask for your explicit consent separately before sending any marketing. [LAWYER TO CHECK]',
      ] },
      { h: '4. AI processing', p: [
        'To produce summaries, questions, cards and assistant answers, your content is sent to Anthropic’s Claude AI model. The model works only from the material you uploaded. Messages you write in the help chat are sent to the AI only to answer them and are not saved. Under our data-processing terms with Anthropic your content is not used to train models. [LAWYER / CONTRACT TO CHECK]',
        'Reuse of lesson data: for students who upload the identical PDF file, the processed lesson data (reading page, word explanations, questions, cards, summary) may be reused, so the AI processing is not repeated for the same file. Your personal data such as your notes, progress, answers and chats are never copied to other students, and your original PDF is never shared.',
      ] },
      { h: '5. Where data is stored and transfers', p: [
        'Your data is stored with Supabase in the EU (Ireland, eu-west-1). For AI processing content is sent to Anthropic, and for subscription checks relevant data goes to Apple; these may be transfers outside your country. Safeguards under GDPR Chapter V and KVKK Art. 9 apply. [LAWYER TO CHECK]',
        'We do not sell your data for advertising or share it with third parties. When you share, only what the app made is shared; the original PDF is never shared.',
      ] },
      { h: '6. Retention', p: [
        'We keep your data while your account is open. 30 days after you request deletion, your account and all content are permanently deleted; you can cancel the request during that time. Records we must keep by law (e.g. subscription transactions) may be kept for the legally required period.',
      ] },
      { h: '7. Your rights', p: [
        'Under GDPR and KVKK Art. 11 you have the right to know whether your data is processed, to access, correct and erase it, to object, to data portability and rights relating to automated processing. In the app you can export your data and delete your account in Settings. For other requests: ' + M + '. You may also complain to your data-protection authority (in Türkiye, the KVKK Board).',
      ] },
      { h: '8. Cookies and on-device data', p: [
        'The website stores your session, language and theme choice in your browser. We use no advertising cookies. The app caches your content on the device for offline use.',
      ] },
      { h: '9. Security and children', p: [
        'Data is encrypted in transit and access is restricted per account. The service is not designed for people under [MINIMUM AGE – to be set by a lawyer].',
      ] },
      { h: '10. Changes', p: [
        'We may update this text and will announce important changes in the app or by email. Questions: ' + M + '.',
      ] },
    ],
  },
  fa: {
    title: 'سیاست حریم خصوصی (اطلاعیه GDPR / KVKK)',
    sections: [
      { h: '۱. مسئول داده', p: [
        'مسئول داده: [نام شرکت]، [نشانی]. تماس: ' + M + '. [اطلاعات ثبت / نماینده در اتحادیه اروپا – وکیل تعیین کند]',
      ] },
      { h: '۲. چه داده‌هایی را پردازش می‌کنیم', p: [
        'حساب: نشانی ایمیل، نام (اختیاری)، روش ورود (کد ایمیل، Apple یا Google)، ترجیح زبان و حالت نمایش.',
        'محتوا: PDFها و عکس‌های اسلاید که بارگذاری می‌کنی، متن ضبط کلاس (تبدیل گفتار به متن روی دستگاه خودت انجام می‌شود و فقط متن به سرور فرستاده می‌شود)، یادداشت‌ها، هایلایت‌ها و برنامه کلاسی.',
        'استفاده: پیشرفت مطالعه، زمان مطالعه، نتایج آزمون و کارت، پرسش‌های دستیار و شمارنده‌های استفاده (برای محدودیت دوره آزمایشی).',
        'دستگاه و اشتراک: دستگاه‌های ثبت‌شده (حداکثر ۲) و وضعیت اشتراک (اطلاعات تراکنش تأییدشده از اپل). ما اطلاعات کارت تو را نمی‌بینیم و ذخیره نمی‌کنیم؛ پرداخت را اپل دریافت می‌کند.',
      ] },
      { h: '۳. اهداف و مبنای قانونی', p: [
        'داده‌ها را برای ارائه خدمت (اجرای قرارداد)، مدیریت حساب و محدودیت دستگاه، تأیید اشتراک، تأمین امنیت و انجام تعهدات قانونی پردازش می‌کنیم. GDPR ماده ۶(۱) بندهای b، c، f؛ KVKK ماده ۵/۲. پیش از ارسال هر پیام تبلیغاتی، رضایت صریح تو را جداگانه می‌گیریم. [وکیل بررسی کند]',
      ] },
      { h: '۴. پردازش با هوش مصنوعی', p: [
        'برای ساخت خلاصه، پرسش، کارت و پاسخ دستیار، محتوای تو به مدل هوش مصنوعی Claude از شرکت Anthropic فرستاده می‌شود. مدل فقط از مطالبی که خودت بارگذاری کرده‌ای استفاده می‌کند. پیام‌هایی که در گفتگوی راهنما می‌نویسی فقط برای پاسخ دادن به هوش مصنوعی فرستاده می‌شود و ذخیره نمی‌شود. طبق شرایط پردازش داده با Anthropic، محتوای تو برای آموزش مدل استفاده نمی‌شود. [وکیل / قرارداد بررسی کند]',
        'استفادهٔ مجدد از داده‌های درس: برای دانشجویانی که دقیقاً همان فایل PDF را بارگذاری می‌کنند، داده‌های پردازش‌شدهٔ درس (صفحهٔ مطالعه، توضیح واژه‌ها، سؤال‌ها، کارت‌ها، خلاصه) ممکن است دوباره استفاده شود تا پردازش هوش مصنوعی برای همان فایل تکرار نشود. داده‌های شخصی تو مانند یادداشت‌ها، پیشرفت، پاسخ‌ها و گفتگوها هرگز برای دانشجویان دیگر کپی نمی‌شود و PDF اصلی تو هرگز به اشتراک گذاشته نمی‌شود.',
      ] },
      { h: '۵. محل نگهداری و انتقال', p: [
        'داده‌های تو نزد Supabase در اتحادیه اروپا (ایرلند، eu-west-1) ذخیره می‌شود. برای پردازش هوش مصنوعی محتوا به Anthropic و برای تأیید اشتراک اطلاعات لازم به اپل منتقل می‌شود؛ این موارد ممکن است انتقال به خارج از کشور تو باشد. تضمین‌های فصل پنجم GDPR و ماده ۹ KVKK اعمال می‌شود. [وکیل بررسی کند]',
        'داده‌های تو را برای تبلیغات نمی‌فروشیم و با اشخاص ثالث به اشتراک نمی‌گذاریم. در اشتراک‌گذاری فقط آنچه برنامه ساخته به اشتراک گذاشته می‌شود و PDF اصلی هرگز.',
      ] },
      { h: '۶. مدت نگهداری', p: [
        'تا زمانی که حسابت باز است داده‌ها را نگه می‌داریم. ۳۰ روز پس از درخواست حذف، حساب و همه محتوا برای همیشه پاک می‌شود و در این مدت می‌توانی درخواست را لغو کنی. سوابقی که قانوناً باید نگه داریم (مثلاً تراکنش‌های اشتراک) ممکن است به مدت قانونی نگهداری شود.',
      ] },
      { h: '۷. حقوق تو', p: [
        'طبق GDPR و ماده ۱۱ KVKK حق داری بدانی داده‌هایت پردازش می‌شود یا نه، به آن‌ها دسترسی داشته باشی، اصلاح و حذف کنی، اعتراض کنی، انتقال‌پذیری بخواهی و درباره پردازش خودکار حقوقی داری. در برنامه از تنظیمات می‌توانی داده‌هایت را خروجی بگیری و حسابت را حذف کنی. برای درخواست‌های دیگر: ' + M + '. همچنین می‌توانی به مرجع حفاظت از داده کشور خود شکایت کنی.',
      ] },
      { h: '۸. کوکی‌ها و داده‌های روی دستگاه', p: [
        'وب‌سایت نشست، زبان و حالت نمایش تو را در مرورگرت نگه می‌دارد. از کوکی تبلیغاتی استفاده نمی‌کنیم. برنامه برای استفاده آفلاین محتوایت را روی دستگاه ذخیره می‌کند.',
      ] },
      { h: '۹. امنیت و کودکان', p: [
        'داده‌ها هنگام انتقال رمزگذاری می‌شوند و دسترسی برای هر حساب محدود است. این خدمت برای افراد زیر [حداقل سن – وکیل تعیین کند] طراحی نشده است.',
      ] },
      { h: '۱۰. تغییرات', p: [
        'ممکن است این متن را به‌روز کنیم و تغییرات مهم را در برنامه یا با ایمیل اعلام می‌کنیم. پرسش‌ها: ' + M + '.',
      ] },
    ],
  },
  ar: {
    title: 'سياسة الخصوصية (إشعار GDPR / KVKK)',
    sections: [
      { h: '1. المسؤول عن البيانات', p: [
        'المسؤول عن البيانات: [اسم الشركة]، [العنوان]. للتواصل: ' + M + '. [بيانات التسجيل / ممثل الاتحاد الأوروبي – يحددها المحامي]',
      ] },
      { h: '2. ما البيانات التي نعالجها', p: [
        'الحساب: البريد الإلكتروني، اسمك (اختياري)، طريقة الدخول (رمز البريد أو Apple أو Google)، تفضيلات اللغة والمظهر.',
        'المحتوى: ملفات PDF وصور الشرائح التي ترفعها، ونص تسجيلات المحاضرات (يتم تحويل الكلام إلى نص على جهازك ولا يُرسل إلى الخادم سوى النص)، وملاحظاتك وتمييزاتك وجدولك الدراسي.',
        'الاستخدام: تقدّم القراءة ووقت الدراسة ونتائج الاختبارات والبطاقات وأسئلتك للمساعد وعدّادات الاستخدام (لحدود التجربة).',
        'الأجهزة والاشتراك: أجهزتك المسجّلة (حتى جهازين) وحالة الاشتراك (بيانات معاملة موثّقة من Apple). لا نرى بيانات بطاقتك ولا نخزّنها؛ تتولى Apple الدفع.',
      ] },
      { h: '3. الأغراض والأسس القانونية', p: [
        'نعالج البيانات لتقديم الخدمة (تنفيذ العقد) وإدارة حسابك وحد الأجهزة والتحقق من الاشتراك وحفظ الأمان والوفاء بالالتزامات القانونية. GDPR المادة 6(1) البنود b وc وf؛ KVKK المادة 5/2. نطلب موافقتك الصريحة بشكل منفصل قبل إرسال أي رسائل تسويقية. [على المحامي المراجعة]',
      ] },
      { h: '4. المعالجة بالذكاء الاصطناعي', p: [
        'لإنتاج الملخصات والأسئلة والبطاقات وإجابات المساعد، يُرسل محتواك إلى نموذج Claude للذكاء الاصطناعي من شركة Anthropic. يعمل النموذج بالمواد التي رفعتها أنت فقط. تُرسل الرسائل التي تكتبها في محادثة المساعدة إلى الذكاء الاصطناعي للرد عليها فقط ولا تُحفظ. وفق شروط معالجة البيانات مع Anthropic لا يُستخدم محتواك لتدريب النماذج. [على المحامي / العقد المراجعة]',
        'إعادة استخدام بيانات الدرس: بالنسبة للطلاب الذين يرفعون ملف PDF مطابقًا تمامًا، قد يُعاد استخدام بيانات الدرس المعالجة (صفحة القراءة، شرح الكلمات، الأسئلة، البطاقات، الملخص) حتى لا تتكرر معالجة الذكاء الاصطناعي للملف نفسه. لا تُنسخ بياناتك الشخصية مثل ملاحظاتك وتقدمك وإجاباتك ومحادثاتك إلى طلاب آخرين أبدًا، ولا يُشارك ملف PDF الأصلي الخاص بك.',
      ] },
      { h: '5. مكان التخزين والنقل', p: [
        'تُخزَّن بياناتك لدى Supabase في الاتحاد الأوروبي (أيرلندا، eu-west-1). لأغراض الذكاء الاصطناعي يُرسل المحتوى إلى Anthropic، وللتحقق من الاشتراك تُرسل البيانات اللازمة إلى Apple؛ وقد يُعد ذلك نقلًا خارج بلدك. تُطبَّق الضمانات وفق الفصل الخامس من GDPR والمادة 9 من KVKK. [على المحامي المراجعة]',
        'لا نبيع بياناتك للإعلانات ولا نشاركها مع أطراف ثالثة. عند المشاركة يُشارك ما أنشأه التطبيق فقط، ولا يُشارك ملف PDF الأصلي أبدًا.',
      ] },
      { h: '6. مدة الاحتفاظ', p: [
        'نحتفظ ببياناتك ما دام حسابك مفتوحًا. بعد 30 يومًا من طلب الحذف يُحذف حسابك وكل المحتوى نهائيًا، ويمكنك إلغاء الطلب خلال هذه المدة. قد نحتفظ بسجلات يفرض القانون حفظها (مثل معاملات الاشتراك) للمدة القانونية.',
      ] },
      { h: '7. حقوقك', p: [
        'بموجب GDPR والمادة 11 من KVKK لك الحق في معرفة ما إذا كانت بياناتك تُعالج، والاطلاع عليها وتصحيحها ومحوها والاعتراض ونقلها، وحقوق تتعلق بالمعالجة الآلية. يمكنك من الإعدادات في التطبيق تصدير بياناتك وحذف حسابك. لطلبات أخرى: ' + M + '. ويمكنك أيضًا تقديم شكوى إلى هيئة حماية البيانات في بلدك.',
      ] },
      { h: '8. ملفات الارتباط والبيانات على الجهاز', p: [
        'يحفظ الموقع جلستك واختيار اللغة والمظهر في متصفحك. لا نستخدم ملفات ارتباط إعلانية. يخزّن التطبيق محتواك على جهازك مؤقتًا للاستخدام دون اتصال.',
      ] },
      { h: '9. الأمان والأطفال', p: [
        'تُشفَّر البيانات أثناء النقل ويُقيَّد الوصول لكل حساب. الخدمة غير مصممة لمن هم دون [الحد الأدنى للعمر – يحدده المحامي].',
      ] },
      { h: '10. التغييرات', p: [
        'قد نحدّث هذا النص وسنعلن التغييرات المهمة في التطبيق أو بالبريد الإلكتروني. للاستفسار: ' + M + '.',
      ] },
    ],
  },
};
