# App Store Connect: iOS 1.0 version page, copy-paste texts (updated 19 Nov 2026)

Everything below is ready to paste. Turkish is the main language (Turkey-only release), English is a second localization. Counts in brackets are the character limits Apple sets. Rules followed: no price or currency in any text, no emoji, no Android, no medical claims, no "free trial charged after" wording (our own 3-day trial, no card). Do NOT press "Add for Review" until Kian decides.

## 1. App information (left menu: App Information)
| Field | Value |
|---|---|
| Name (30) | `Kavis Study` |
| Subtitle tr (30) | `PDF'inden akıllı çalışma` |
| Subtitle en (30) | `Study smarter from your PDF` |
| Primary category | Education |
| Secondary category | Productivity |
| Content rights | "No, it does not contain, show or access third-party content" (the student uploads their own material; the app never ships anyone's PDFs) |
| Bundle ID | `study.kavis.app` |
| Price | Free (Premium = in-app purchase) |
| Availability | Turkey only (already set) |

## 2. Version page (iOS 1.0) fields
| Field | Value |
|---|---|
| Support URL | `https://kavis.study` (public landing page; it has the "contact support" e-mail button, kavisstudy@gmail.com). Do not use `/help`: it needs a login |
| Marketing URL (optional) | `https://kavis.study` |
| Privacy Policy URL (App Information page) | `https://kavis.study/privacy` |
| Terms of Use (EULA) | Either leave Apple's standard EULA, or paste `https://kavis.study/terms` into the description (done below) and the license agreement field. Both pages exist (`web/src/App.tsx`). They are still drafts: lawyer check pending (`TODO.md`) |
| Copyright | `2026 Melisa Ferahani` (legal name of the Apple account holder = publisher in the legal texts; no © sign, Apple adds it) |
| Version | `1.0` (project.yml still says 0.1.0: set `MARKETING_VERSION: "1.0"` before archiving) |
| Release | "Manually release this version" |

## 3. Turkish (primary localization)
**Promotional text (170, changeable any time)**
```text
Hocanın PDF'ini yükle; metni değişmeden okunur sayfaya, özete, sesli anlatıma, kartlara ve sınava dönüşsün. 3 gün ücretsiz dene.
```
**Description (4000)**
```text
Kavis Study, hocanın verdiği PDF'i, slayt fotoğrafını veya ders kaydını çalışabileceğin bir derse çevirir. Hocanın metni değişmez; üstüne çalışma araçları eklenir.

NE YAPAR
• Etkileşimli okuma sayfası: orijinal metni olduğu gibi oku, vurgula, not al
• Özetler: PDF'inin diliyle, kısa ve net
• Sesli anlatım: yolda, yürürken dinle
• Kartlar: unuttuğun şeyleri doğru zamanda tekrar ettirir
• Hocanın tarzında sınav soruları ve yazılı cevap değerlendirme
• Çalışma planı ve ilerleme takibi
• Asistan: yalnızca senin yüklediğin materyale dayanarak cevap verir

NEDEN FARKLI
• Yalnızca senin materyalin kullanılır; asistan PDF'inde olmayan bilgiyi kaynak gibi sunmaz
• PDF'in kendi dilinde kalır; çeviri düğmesi var
• Türkçe, İngilizce, Farsça ve Arapça arayüz (Farsça ve Arapça sağdan sola)
• İnternetsiz çalışma: indirdiğin dersler her planda çevrimdışı açılır
• Ders kayıtları telefonunda metne çevrilir; sunucuya yalnızca metin gider

YAPAY ZEKÂ HAKKINDA
Cevaplar, özetler ve sorular yapay zekâ ile hazırlanır ve hata içerebilir. Önemli bilgileri her zaman kendi ders materyalinle karşılaştır. Kavis Study bir çalışma aracıdır; tıbbi, klinik veya hukuki tavsiye vermez ve hasta bakımında kullanılmak için tasarlanmamıştır.

DENEME VE PREMIUM
Kredi kartı istemeden 3 gün deneyebilirsin (en fazla 2 ders, 60 asistan sorusu, her PDF en fazla 100 sayfa). Deneme bittikten sonra çalıştığın PDF'ler, notların, vurguların, mevcut kartların ve özetlerin seninle kalır. Yeni PDF yüklemek, yeni asistan soruları sormak ve yeni sınav/kart üretmek için Premium gerekir.

Premium, uygulama içinden aylık veya yıllık otomatik yenilenen abonelik olarak alınır; fiyat satın alma ekranında App Store'da gösterilir. Ödeme, satın alma onayında Apple ID hesabından tahsil edilir. Abonelik, dönem bitmeden en az 24 saat önce iptal edilmezse otomatik yenilenir. Aboneliği satın aldıktan sonra App Store hesap ayarlarından yönetebilir veya iptal edebilirsin. Premium aynı hesapla tüm cihazlarında açılır. Hesap başına en fazla 2 cihaz.

Kullanım Koşulları: https://kavis.study/terms
Gizlilik Politikası: https://kavis.study/privacy

Kavis Study eczacılık öğrencileri için yola çıktı, ama her bölümden öğrenci için tasarlandı.
```
**Keywords (100)** — 97 characters
```text
pdf,ders,çalışma,sınav,kart,özet,not,eczacılık,tıp,üniversite,asistan,tekrar,test,okuma,flashcard
```
**What's New (4000)**
```text
İlk sürüm. PDF'ini yükle, okuma sayfası, özet, sesli anlatım, kartlar, sınav ve asistan hazır.
```

## 4. English (second localization)
**Promotional text (170)**
```text
Upload your teacher's PDF and get an interactive reading page with the text unchanged, plus summaries, audio, flash cards and quizzes. Try free for 3 days.
```
**Description (4000)**
```text
Kavis Study turns the PDF, slide photo or lecture recording your teacher gave you into a lesson you can actually study from. Your teacher's text is never changed; study tools are added around it.

WHAT IT DOES
• Interactive reading page: read the original text as it is, highlight, take notes
• Summaries in the language of your PDF
• Audio narration for commutes and walks
• Flash cards that bring back what you forget at the right time
• Quizzes in your teacher's style, with graded written answers
• Study plan and progress tracking
• Assistant that answers only from the material you uploaded

WHY IT IS DIFFERENT
• Only your own material is used; the assistant does not present facts missing from your PDF as sources
• Your PDF stays in its own language, with a translate button
• Turkish, English, Persian and Arabic interface (Persian and Arabic right-to-left)
• Offline use on every plan: downloaded lessons open without internet
• Lecture recordings are turned into text on your phone; only the text is sent to the server

ABOUT THE AI
Answers, summaries and questions are written by AI and can contain mistakes. Always check important facts against your own course material. Kavis Study is a study tool; it does not give medical, clinical or legal advice and is not designed for patient care.

TRIAL AND PREMIUM
Try it for 3 days with no card needed (up to 2 lessons, 60 assistant questions, each PDF up to 100 pages). After the trial you keep the PDFs you studied, your notes, highlights, existing cards and summaries. Uploading new PDFs, asking new assistant questions and generating new quizzes or cards need Premium.

Premium is an auto-renewing monthly or yearly subscription bought inside the app; the price is shown on the purchase screen in the App Store. Payment is charged to your Apple ID account when you confirm the purchase. The subscription renews automatically unless it is cancelled at least 24 hours before the end of the current period. You can manage or cancel it in your App Store account settings after purchase. Premium unlocks all your devices with the same account. Up to 2 devices per account.

Terms of Use: https://kavis.study/terms
Privacy Policy: https://kavis.study/privacy

Kavis Study started with pharmacy students, and is built for students of every field.
```
**Keywords (100)** — 97 characters
```text
study,pdf,flashcards,quiz,notes,summary,lecture,exam,university,medical,pharmacy,assistant,reader
```
**What's New**
```text
First release. Upload your PDF and get a reading page, summary, audio, cards, quizzes and an assistant.
```
**Subtitle / name:** see section 1.

## 5. Age rating questionnaire (App Information > Age Rating > Edit)
Apple changes the exact wording from time to time. If a question below looks different, answer by the idea in the "Why" column. Expected result: **4+** (or 9+ if Apple counts the medical-information question; accept whatever Apple calculates and do not change true answers to get a lower rating).
| Question | Answer | Why |
|---|---|---|
| Cartoon / fantasy violence, realistic violence, prolonged graphic violence, guns | None | App has no such content of its own |
| Sexual content or nudity, mature/suggestive themes | None | |
| Profanity or crude humor | None | |
| Horror / fear themes | None | |
| Alcohol, tobacco or drug use or references | None | The app's own content has none. Students may upload pharmacology PDFs that name drugs; that is study material, not promotion. If you want to be extra careful choose "Infrequent/Mild"; it can raise the rating |
| Medical or treatment information | None (own content). Careful option: "Infrequent/Mild" | The app gives no medical advice; the text is whatever the student uploads. Tell Apple the truth in the review notes if asked |
| Health or wellness topics | No | |
| Gambling (simulated or real money), contests | None / No | |
| Unrestricted web access | No | No built-in browser. The AI "research" mode only returns links the student may open in Safari |
| User-generated content | No | Everything a student uploads is private to their account and is never published. The Premium share link sends only app-made quizzes/summaries/cards to someone the student chooses; there is no feed, profile search or public posting |
| Messaging and chat between users | No | The assistant chat is student-to-AI only; users cannot message each other |
| AI chatbot / generative AI | Yes if asked | The assistant and summaries are generated by Claude (Anthropic). Answers only use the student's own material, can be wrong, and there is a visible AI notice. Content filters on harmful topics: yes, handled by the model provider |
| Parental controls / age assurance | No | |
| Made for Kids | No | General student audience (aimed at university students) |

## 6. Screenshots (needed before "Add for Review")
Sizes Apple requires now: **iPhone 6.9"** (iPhone 17 Pro Max simulator, 1320x2868) and **iPad 13"** (iPad Pro 13-inch (M5/M4) simulator, 2064x2752) because the app runs on iPad. Apple scales the smaller iPhone sizes (6.5", 6.3", 5.5") from the 6.9" set, so one iPhone set is enough. Take them in the simulator with the local server off the live user data: use the demo account (`kavis.server` = live, demo account with the finished demo lesson) so the screens show real-looking content and no real student.

How: Simulator > File > Save Screen (or `Cmd+S`). Light mode, language Turkish, status bar is clean in the simulator. Same screens in English later if wanted (add the English localization screenshots only if you add that localization).

Take these 7, in this order (the first 3 sell the app in the search results):
1. **Home**: courses and today's plan
2. **Reader**: reading page with a few highlights on the original text
3. **Assistant**: a question answered from the PDF, with the source page shown
4. **Summary** of the lesson
5. **Quiz**: a question in the teacher's style
6. **Flash cards**
7. **Plan / progress**

Do for both iPhone 6.9" and iPad 13" (same 7 screens; Apple allows up to 10). Rules: no prices, no Paywall screenshot in the listing, no real names, no "Android" or web mention, no status bar with a real carrier name. Cut 1 or 2 screens if one looks empty. Upload them in Version page > Screenshots (drag the files, order = this list).

## In-app purchases (done in App Store Connect, 13 Nov 2026)
Group "Kavis Premium": `study.kavis.premium.month` (monthly) and `study.kavis.premium.year` (yearly), auto-renewable, Turkey only. The 5-month term is NOT sold. Launch offer: monthly intro price (pay as you go, first 3 months), already set. Never write a price in listing texts.

## App Privacy ("nutrition label") answers (App Privacy page, "Get Started")
Must match `ios/KavisStudy/PrivacyInfo.xcprivacy`. First question "Do you or your third-party partners collect data from this app?" = **Yes**. **Tracking = No** for every type (no ads, no analytics SDK, no data broker; the AI provider only processes the lesson text to answer, not for its own purposes). Every type below: **Linked to the user = Yes**, **Used for tracking = No**, **Purpose = App Functionality** only.
| Apple category > type | In the manifest? | What it is |
|---|---|---|
| Contact Info > Email Address | yes | Sign-in code and account |
| Contact Info > Name | yes | Name the student sets in the profile |
| Identifiers > User ID | yes | Account id |
| Identifiers > Device ID | yes | Device list and the 2-device limit |
| User Content > Photos or Videos | yes | Slide / page photos the student uploads |
| User Content > Other User Content | yes | Uploaded PDFs, notes, highlights, lecture transcripts, quiz answers |
| User Content > Audio Data | **NO, add it** | The lecture recording file is stored in the student's own folder (`materials`, `recording.m4a`; `ios/KavisStudy/API/Recording.swift`), only the transcript is used by the AI. Declare Audio Data too, and add `NSPrivacyCollectedDataTypeAudioData` to the manifest (same flags) before the Release build so label and manifest agree |
| Purchases > Purchase History | yes | Premium status and Apple transaction id |
Not collected: location, contacts, health and fitness, financial info (Apple handles the card), browsing history, search history, diagnostics, advertising data. Study progress and streaks are stored in the account as part of the user content above; if Apple's review wants it separate, add Usage Data > Product Interaction (App Functionality, linked, no tracking). Push token: not collected now (`aps-environment` is still `development`); if push is turned on, Device ID already covers it.
Required-reason API answers in the manifest (already set): UserDefaults `CA92.1`, disk space `E174.1`.
Privacy policy must say the same (what is collected, that lesson text goes to Anthropic only to write answers, how long data is kept, how to ask for deletion): lawyer check item in `TODO.md`.

## App Review information
- **Demo account is required** (Apple will not enter an email code from a real inbox). Make a reviewer account in the **live** Supabase (ask Kian first, it writes to the live database) with a fixed login Apple can use, a trial that does not expire during review, and one finished lesson inside. Put the login in the "Sign-in required" fields and describe the code flow in the notes. Never put this login in git.
- Notes for the reviewer (English, paste into App Review > Notes):
```text
Kavis Study turns a student's own uploaded PDF (or slide photo or lecture transcript) into an interactive study lesson, with summaries, flash cards, quizzes and an AI assistant that only uses the student's own material.

SIGN IN: use the demo account in the Sign-in fields (email + password; no code needed). It is a normal account on our own free trial (extended so it does not run out during review) with one finished lesson, so every screen can be tried and you can test the purchase in the sandbox. A new account gets our own 3-day free trial (no card).

PREMIUM: sold only through Apple in-app purchase (auto-renewable monthly and yearly, in the subscription group "Kavis Premium"). To see the paywall and test a purchase: sign in with the demo account and tap "Premium'a geç" on the home screen, or Settings > Premium. Restore Purchases, Terms of Use and Privacy Policy links are on the paywall. Premium unlocks all of the user's devices through our server.

AI: lesson text is sent to a third-party AI service (Anthropic) only to write answers, summaries and quizzes; this is disclosed at sign-up and in the privacy policy, and the user agrees to it when creating an account.

ACCOUNT DELETION: Settings > Delete account.
LECTURE RECORDING: speech-to-text runs on the device; only the transcript is uploaded.
SHARING (Premium): shares only app-made quizzes/summaries/cards, never the original PDF.
```
- Contact: Kian's phone and email (Apple needs a real person).

## Things Apple checks that we must have ready
- **Sign in with Apple** must be offered if Google sign-in is offered (guideline 4.8). The iOS button is not done yet (needs the account): do it before submitting, or remove Google on iOS.
- **Delete account** inside the app: done.
- **Restore Purchases**: exists in code (`Store.restore()`); check the button is visible on the paywall before submitting.
- Privacy policy and terms linked in the app and in App Store Connect; "draft" banner gone after the lawyer check.
- No mention of other platforms' payments or of web prices inside the iPhone app.
- Permission texts (camera, photos, microphone, speech): done in `ios/project.yml` (other languages in `Resources/<lang>.lproj/InfoPlist.strings`).
- Export compliance: the app only uses HTTPS (standard encryption) → answer "uses standard encryption, exempt". `ITSAppUsesNonExemptEncryption: false` is already in `ios/project.yml`.
