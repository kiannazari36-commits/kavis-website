# App Store Connect: texts and answers (draft, 7 Nov 2026)

Copy these into App Store Connect when the Apple Developer account is active. Character limits are Apple's. Turkish is the main language, English second. Fa/ar descriptions can be added later (translate the English one, native-speaker check).

## App info
| Field | Value |
|---|---|
| Name (max 30) | Kavis Study |
| Subtitle (max 30) | tr: `PDF'inden akıllı çalışma` · en: `Study smarter from your PDF` |
| Bundle ID | `study.kavis.app` (change in `ios/project.yml` if the final one differs) |
| Primary category | Education |
| Secondary category | Productivity |
| Age rating | 4+ (no user content shared publicly, no web browsing, no gambling). Answer "None" to every content question. |
| Price | Free (Premium is an in-app purchase; never put a price in the texts) |
| Support URL | needs the real domain (now https://kavis-website.vercel.app, test only) |
| Privacy Policy URL | the web Privacy page; lawyer must check it first (see `TODO.md`) |
| Copyright | `2026 Kian Nazari` (fill the real legal name of the account holder) |

## Promotional text (max 170, can change any time)
- tr: `Öğretmeninin PDF'ini yükle; metni değişmeden okunur sayfaya, özete, sesli anlatıma, kartlara ve sınava dönüşsün. 3 gün ücretsiz dene.`
- en: `Upload your teacher's PDF and get an interactive reading page with the text unchanged, plus summaries, audio, flash cards and quizzes. Try free for 3 days.`

## Description (max 4000)
### Turkish
```
Kavis Study, hocanın verdiği PDF'i, slayt fotoğrafını veya ders kaydını çalışabileceğin bir derse çevirir. Hocanın metni değişmez; üstüne çalışma araçları eklenir.

NE YAPAR
• Etkileşimli okuma sayfası: orijinal metni olduğu gibi oku, vurgula, not al
• Özetler: PDF'in diliyle, kısa ve net
• Sesli anlatım: yolda, yürürken dinle
• Kartlar: unuttuğun şeyleri doğru zamanda tekrar ettirir
• Hocanın tarzında sınav soruları ve yazılı cevap değerlendirme
• Çalışma planı ve ilerleme takibi
• Asistan: sadece senin yüklediğin materyale dayanarak cevap verir

NEDEN FARKLI
• Yalnızca senin materyalin kullanılır, internetten uydurma bilgi gelmez
• PDF'in kendi dilinde kalır; çeviri düğmesi var
• Türkçe, İngilizce, Farsça ve Arapça arayüz (Farsça ve Arapça sağdan sola)
• İnternetsiz çalışma: indirdiğin dersler her planda çevrimdışı açılır
• Ders kayıtları telefonunda metne çevrilir; sunucuya sadece metin gider

DENEME VE PREMIUM
Kredi kartı istemeden 3 gün deneyebilirsin (en fazla 2 ders, 60 asistan sorusu, her PDF en fazla 100 sayfa). Deneme bittikten sonra çalıştığın PDF'ler, notların, vurguların, mevcut kartların ve özetlerin seninle kalır. Yeni PDF yüklemek, yeni asistan soruları ve yeni sınav/kart üretmek için Premium gerekir. Premium, App Store'dan satın alınır ve aynı hesapla tüm cihazlarında açılır. Hesap başına en fazla 2 cihaz.

Kavis Study eczacılık öğrencileri için yola çıktı, ama her bölümden öğrenci için tasarlandı.
```
### English
```
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
• Only your own material is used; no made-up facts from the internet
• Your PDF stays in its own language, with a translate button
• Turkish, English, Persian and Arabic interface (Persian and Arabic right-to-left)
• Offline use on every plan: downloaded lessons open without internet
• Lecture recordings are turned into text on your phone; only the text is sent to the server

TRIAL AND PREMIUM
Try it for 3 days with no card needed (up to 2 lessons, 60 assistant questions, each PDF up to 100 pages). After the trial you keep the PDFs you studied, your notes, highlights, existing cards and summaries. Uploading new PDFs, new assistant questions and generating new quizzes or cards need Premium. Premium is bought through the App Store and unlocks all your devices with the same account. Up to 2 devices per account.

Kavis Study started with pharmacy students, and is built for students of every field.
```

## Keywords (max 100 chars, comma separated, no spaces after commas)
- tr: `pdf,ders,çalışma,sınav,kart,özet,not,eczacılık,tıp,üniversite,asistan,tekrar`
- en: `study,pdf,flashcards,quiz,notes,summary,lecture,exam,university,medical,pharmacy,assistant`

## What's new (version 1.0)
- tr: `İlk sürüm.` · en: `First release.`

## Screenshots (iPhone 6.9" required, iPad 13" required because the app runs on iPad)
Take them from the simulator (iPhone 17 Pro Max / iPad Pro 13"), light mode, in Turkish; same set in English later. Suggested order:
1. Home (courses, today's plan)
2. Reading page with highlights over the original PDF
3. Summary
4. Assistant answering from the PDF
5. Quiz
6. Flash cards
7. Study plan / progress
Use no real student data and no mock names of real people. Do not show prices.

## In-app purchases (after the Paid Applications Agreement)
`study.kavis.premium.year`, `study.kavis.premium.month` (auto-renewable, group "Premium") and `study.kavis.premium.term` (non-renewing, 5 months). Details and the price step: `TODO.md` ("App Store Connect"). Each product needs a display name, description and a review screenshot of the paywall.

## App Privacy ("nutrition label") answers
Tracking: **No** (no ads, no analytics SDK, no data sold; confirm no SDK was added before submitting). Data **linked to the user**, used only for **App Functionality**:
| Data type | Why |
|---|---|
| Email address | Sign-in, account |
| Name (if set in profile) | Profile |
| User content: uploaded PDFs, photos, notes, transcripts | The app's main function |
| Audio data: **not collected** (speech-to-text runs on the device; only the transcript is sent) | n/a |
| Purchases | Premium status |
| Device ID / push token | Device limit, notifications |
| Usage data: study progress | Plan, streak |
Not collected: location, contacts, health, financial info, browsing history.

## App Review information
- **Demo account is required** (Apple will not enter an email code from a real inbox). Make a reviewer account in the **live** Supabase (ask Kian first, it writes to the live database) with a fixed login Apple can use, a trial that does not expire during review, and one finished lesson inside. Put the login in the "Sign-in required" fields and describe the code flow in the notes. Never put this login in git.
- Notes for the reviewer (English):
  `Kavis Study turns a student's own PDF into a study lesson. Sign in with the demo account. Premium is sold only through Apple in-app purchase; the free trial is our own (3 days, no card). Lecture recording uses on-device speech recognition and only the transcript is uploaded. Account deletion: Settings > Delete account. Sharing exports only app-generated content, never the original PDF.`
- Contact: Kian's phone and email (Apple needs a real person).

## Things Apple checks that we must have ready
- **Sign in with Apple** must be offered if Google sign-in is offered (guideline 4.8). The iOS button is not done yet (needs the account): do it before submitting, or remove Google on iOS.
- **Delete account** inside the app: done.
- **Restore Purchases**: exists in code (`Store.restore()`); check the button is visible on the paywall before submitting.
- Privacy policy and terms linked in the app and in App Store Connect; "draft" banner gone after the lawyer check.
- No mention of other platforms' payments or of web prices inside the iPhone app.
- Permission texts (camera, photos, microphone, speech): done in `ios/project.yml` (other languages in `Resources/<lang>.lproj/InfoPlist.strings`).
- Export compliance: the app only uses HTTPS (standard encryption) → answer "uses standard encryption, exempt". `ITSAppUsesNonExemptEncryption: false` is already in `ios/project.yml`.
