# Kavis Study — TODO

Everything that is not finished yet. Updated after every step.

## Decisions (23 Oct 2026 — do not reopen)
- Supabase region stays eu-west-1 (Ireland); the EU-hosting sentence goes in the privacy notice
- Lecture recordings: speech-to-text runs on the device; the app sends only the transcript to the server
- Trial: only our own app trial (3 days, 2 lessons, 60 questions, 100 pages per lesson, no bank card). No Apple free-trial offer
- Payments: only Apple in-app purchase. Premium unlocks every device through the server. Prices are never hardcoded
- Max 2 devices (the web counts as one). Offline use in every plan. Sharing is Premium only and never includes the PDF
- Content language: course setting, then general setting, then the PDF's language
- iPhone bottom tab bar has 3 tabs; the assistant stays at the top right

## Backend (Supabase project "Kavis", `lnbfcfxxrqohcnkhlcur`) — details in `docs/BACKEND.md`
- [x] Schema v1: 44 tables, RLS on all, 5 private buckets, 7 RPCs; both migrations applied live; 40 local behaviour tests pass
- [x] Claude Code connected to the project (Supabase MCP connector)
- [ ] Connect the web app (`web/src/api/`), one area at a time:
  - [x] Auth with email: sign up (name, email, password) → confirmation **link** in the email → signed in (opens `/home`); log in; log out; app pages need a signed-in student. `web/src/api/supabase.ts` + `auth.ts`; keys in `web/.env.local` (git-ignored) and in the Vercel project settings
  - [ ] Supabase dashboard → Authentication → URL Configuration: Site URL `https://kavis-website.vercel.app`, Redirect URLs `http://localhost:5173/**` and `https://kavis-website.vercel.app/**` (add the real domain later)
  - [ ] Later: switch back to the 6-digit code of the design (`EMAIL_CODE = true` in `web/src/pages/Login.tsx` + `{{ .Token }}` in the "Confirm sign up" template); iOS needs the code anyway. Kavis-styled email texts in 4 languages
  - [x] "Şifremi unuttum": email link → `/login?mode=reset` → new password (Supabase `resetPasswordForEmail` + `updateUser`); expired link → ask for a new one
  - [ ] Sign in with Apple and Google (buttons now show "coming soon"): needs Apple developer account (Services ID + key) and a Google Cloud OAuth client, then enable both in Supabase → Authentication → Providers
  - [x] Example data: `supabase/seed.sql` (re-runnable; fills the kiannazari36 account with 5 courses, 13 lessons, exams, timetable, reading progress, study time). Applied to the live project. Each newly connected area adds its rows there
  - [x] Courses (menu, home "continue", My Courses, course folder, reader title), profile (name, school, department, year) and settings (`user_settings`, per-course content language) now come from Supabase. `web/src/api/mock/courses.ts` removed
  - [x] Reader: text (`material_content.reader_doc`), hard words (`material_terms`, tap → `tap_term`), saved translations, highlights (`annotations`), pages read (`reading_progress`), stopwatch → `study_sessions`. Example: the "Hipertansiyon" lesson; other lessons show "reading page not ready yet". `web/src/api/mock/readerDoc.ts` removed
  - [x] Reader (25 Oct 2026): "Çevir" translates the whole page with the AI (Edge `translate`, kept in `translations`, never paid twice); the dock speaker reads the open section aloud (browser voice); the pen draws over pages (annotations kind 'ink', points 0–1 per page, undo, 4 colors)
  - [ ] Reader still mock: molecule viewer
  - [x] Cards: today's round = cards due now (`flashcards` + `card_decks`, optional `?course=`); Bildim / Zor / Bilmedim saves the review state (simple spaced repetition: 1 min / 10 min / 4 days × ease). Example: Hipertansiyon (12) and Parasetamol toksisitesi (6) decks. `web/src/api/mock/cards.ts` removed
  - [x] "Add to cards" from a hard word (Edge Function `add-card`); mistakes go to "Hatalarım" through `grade-quiz`
  - [x] Quiz ("Sınava özel"): exam-prep summary (`summaries` kind exam_prep: topics by importance with the reason), questions in the lecturer's style (`quizzes` + `quiz_questions`, hints, molecule), the reader's section check (`section_check`), course chips = nearest exams (pack ready or "ready 7 days before"); answers saved (`quiz_attempts` + `quiz_answers`); reminder time → `user_settings.notify_time`. Example: Farmakoterapi pack (5 topics, 6 questions) + 2-question section check. `web/src/api/mock/quiz.ts` removed
  - [x] Edge Function `grade-quiz` (deployed 24 Oct 2026): grades a finished attempt (right = 1, with hint = 0.5), sets `quiz_answers.correct`, score and level, `topic_progress` mastery (weak < 60) and next review, and adds wrong "sure" answers to the course's "Hatalarım" deck. Rules in `supabase/functions/grade-quiz/grade.ts`, tests: `node --experimental-strip-types supabase/functions/grade-quiz/grade.test.ts`. The web calls it after saving a quiz
  - [ ] Written answers: graded later by AI (now left empty)
  - [x] Study plan: this week from `study_plans` + `plan_items` (real dates, course colors, reasons from the plan), tick tasks (status/done_at), "Dünü kaçırdım" moves unfinished past tasks to the coming days with the least time. Home: today's plan (times from the reminder time), today's review box from `review_sessions` (start = done, later = tomorrow), days to the next exam. Example: a 6-day week around today with 2 missed tasks yesterday. `web/src/api/mock/plan.ts` removed
  - [x] Edge Function `build-plan` (25 Oct 2026, rules only, no AI, free): plans the rest of the week from study days/hours, timetable (fewest-class days), exams (review in the last 7 days, max 2 a day), unread pages (12-page parts), weak topics, "Hatalarım" and due cards; basic plan the first 2 weeks, then smart (forgetting, lecturer's emphasis). Built again when the Plan page opens on a new day; "Planı yenile", "Bugün az vaktim var" (keeps 2 tasks, moves the rest), "Yanlışları plana ekle" (15 min tomorrow). Rules in `planner.ts` (25 Node tests)
  - [ ] Later: a nightly job (`daily-planner`) so the plan is ready before the app opens, and the "Bugünün tekrarı" box (`review_sessions`) made by it
  - [x] Own plan ("Kendi planım"): new table `own_plan_items` (migration `20261024140202_own_plan.sql`, tested on live in a rolled-back transaction: 5/5, then applied); add a course per day, tap = change length (30/45/60/90 min), × = remove
  - [x] Progress: week minutes (`daily_minutes`), streak (`study_streak()`), last score + level and course ranking from graded `quiz_attempts`, growth and congratulation (>10%), best-hours tip (average score by 2-hour window), weak topics (`topic_progress`), words learned (`term_lookups`). Example: 12 graded tries over 30 days in 3 courses, 4 weak topics. `web/src/api/mock/progress.ts` removed
  - [ ] Congratulation as a push notification when the app is closed: scheduled job `send-notifications`
  - [x] Notifications: new web page `/notifications` (design ScrNotifications: Today / Yesterday / This week), from `notifications`; opening marks them read; the bell dot shows unread; the flame button shows the real streak. Example: 9 notifications matching the example data
  - [ ] Scheduled job `send-notifications` (push, snooze) and the server writing notifications (planner, lesson ready, exam result, weekly report)
  - [x] Assistant: course choice = real courses + "all"; the chat and the reader's side panel show the saved conversation (`assistant_threads` + `assistant_messages`, sources = lesson + page). A new question is shown with "real answers come once the assistant is connected" (the app may not write answers). Example: 5 conversations, 14 messages
  - [ ] Test account kiannazari36@gmail.com: trial moved by 30 days for development (25 Oct 2026, ends 25 Nov 2026 15:41; `profiles.trial_started_at` set in the future; trial counters reset to 0 the same day). Before launch: set it back or delete the test data
  - [ ] Renew the Anthropic API key every 90 days (created 24 Oct 2026 → expires ~22 Jan 2027): new key in the Console, replace the Supabase secret `ANTHROPIC_API_KEY`
  - [x] Edge Function `process-material` (deployed, not yet tested with a real PDF): text cut from the PDF by unpdf (never rewritten), 8 pages per AI call (Claude Sonnet 5.5, structured JSON, server-side refusal fallback), writes reading page, hard words (4 languages), topics, search pieces, cards, questions, section check, usage + cost, "lesson ready" notification; scanned / >100 pages give the trial lesson back; $3 per student per month AI budget. Rules in `lib.ts` (12 Node tests)
  - [x] First real test (24 Oct 2026): 5-page PDF ready in 23 s for $0.026. Fixed after it: hints never give the answer or point to a page (AI rule + server filter `cleanHints`, tested), the reader's section check uses only questions from that section's pages; the section-check box shows only on sections that have questions, with the real count (else just "Sonraki bölüm")
  - [x] Photos of pages (up to 30, shrunk to JPEG in the browser) and scanned PDFs ("Metin tanıma ile dene"): text recognition with the AI, 4 pages per run, text copied exactly (`process-material/ocr.ts`). Tested locally with fake files 25 Oct 2026: text exact, ≈1 cent per page
  - [x] Lecture recordings (25 Oct 2026): file or live recording → speech-to-text in the browser (Whisper small on WebGPU, ~6 min per lecture hour on a Mac; base on the processor) → Edge `process-recording` matches the text to the PDF pages and finds the lecturer's emphasis (`material_content.lecture`, `material_topics.teacher_*`) → page "Ders ses kaydı" (`/recording`). Tested locally with a fake recording: "sınavda soruyorum" found, $0.008 per minute-long test
  - [x] Recordings are listed on the course page ("Ders ses kayıtları"), and the reading page shows the lecturer's notes on each page ("Hoca burada sınavda çıkar dedi" with the quote, "… dk durdu"); a tap opens the recording at that moment
  - [ ] Recordings over 50 MB: only the text is kept (no playback) until the Pro plan; Whisper still mishears some drug names (the text shown is not exact)
  - [x] "Soru örneklerim" (25 Oct 2026): the lecturer's old/class questions per course (photo, PDF, typed) → Edge `analyze-style` → `teacher_styles` (question types %, topics asked most, patterns, options); switches Sınavlarda/Kartlarda/Özetlerde. Edge `generate-quiz` makes the course's exam pack ("Sınava özel": 10 questions + exam summary) from its lessons in that style, weighting what the lecturer said will be in the exam and weak topics; new PDFs get their questions in the style too. Tested locally: style found from 4 sample questions, 10 questions in the style, $0.05 for both
  - [x] No claimed lecturer style (25 Oct 2026): "Örnek sorularına benzer" shows only when the student added sample questions; the exam pack asks "Hangi tarzda soru istersin?" (types → Edge generate-quiz `styles`); card/summary style switches removed
  - [x] Lectures longer than 100 pages: cut in the browser (pdf-lib) into equal parts of at most 100 pages, each its own lesson "Name (1/3)"; in the trial each part counts as a lesson
  - [ ] HEIC photos from iPhones: only Safari can read them in the browser; the iOS app will send JPEG
  - [ ] PDFs over 50 MB (slides with many images are often bigger): Supabase free plan allows 50 MB per file. Before launch: Pro plan (higher limit) or shrink / split the PDF in the browser before uploading. Now the upload screen stops them with a message
  - [x] Notification text of "lesson ready" in the student's app language (`profiles.app_lang`, `readyNotice` in `process-material/lib.ts`)
  - [x] Delete a lesson (trash button on the course page, asked once more): the row goes (everything made from it by cascade), then its files in Storage. The trial lesson does not come back
  - [ ] One old test file `…/8fc2be66…/original.pdf` is still in the materials bucket (its lesson was deleted before this existed): delete it in the Supabase dashboard → Storage → materials
  - [x] Edge Function `assistant` (deployed, not yet tested with a real question): searches the student's lessons (`material_chunks`, full-text with Turkish-friendly prefixes), answers only from them ("AI + research" may add general knowledge, marked), saves thread + messages, counts the trial question and AI cost. The web chat and the reader's side panel use it. Rules in `lib.ts` (6 Node tests)
  - [x] Reader panel knows where the student is (24 Oct 2026): the open section's pages are sent and their text always goes to the AI first ("this page" works); the header names the open lesson; "Asistana sor" on a hard word or a sentence really sends the question
  - [x] With one chosen lesson the assistant gets the whole lesson text (up to ~120,000 characters, prompt-cached for 5 minutes so follow-ups cost ~10%) and only talks about that lesson; sources are page numbers. Longer lessons: open pages + search pieces
  - [x] Term card "Dinle": the browser's own voice reads the word + explanation (Web Speech API, free, offline); press again to stop. Later in the iOS app: AVSpeechSynthesizer. "Kartlara ekle" makes a real card (Edge Function `add-card`: "<word> nedir?" + the explanation, in the lesson's deck and content language, no AI, a word is added only once)
  - [x] Reader clock counts real time (not timer ticks) and only while studying: stops when the tab is hidden and after 5 minutes without activity (reading aloud counts), starts again on activity (25 Oct 2026)
  - [x] Reader clock remembers each lesson for the day (this browser): leaving and coming back goes on from the same time, a paused clock stays paused; study time is saved on leaving or closing the tab (short visits add up until a minute)
  - [x] Quiz: pick an option (can still change it), then "Ne kadar eminsin?" — only then right (green) or wrong (red) with the right answer and "Neden?"; then locked. Wrong answers open already explained in the results
  - [x] Assistant extras (25 Oct 2026): answers stream while written (chat + reader panel); "Soruyu çözdür" (photo of a question → step-by-step solution); voice question (microphone → Whisper on the device → text in the box); "Önemli ve zayıf konularımı anlat" (weak topics from quiz results); "Ben anlatayım" (the student explains, the assistant checks against the notes); "+" menu opens upload / "Soru örneklerim" / recording. Fixed: messages were not saved (null `sources` on the question row). Teach-back score /10 not stored yet
  - [x] Reader fixes (25 Oct 2026): assistant star in the dock in full screen; after a section check "Sonraki bölüme geç" opens the next section of the same lesson; a lesson opens at its first section; cards from a lesson show only that lesson's deck; mistake cards keep their A-E options. Too many small sections (e.g. 57 for 86 pages) are grouped once into a few general parts by Edge `group-sections` (only titles go to the AI, ~$0.005, text untouched). Reader assistant has "Sadece PDF'lerim / Yapay zekâ + araştırma"; research mode may search the web (max 3 searches, ~$0.01 each) and lists the pages it used. Reading place (25 Oct 2026): the page at the top of the screen is saved as `reading_progress.last_page` while scrolling (pages that came on screen count as read); a lesson opened again starts at that section and page with "Kaldığın yerden devam". Assistant actions: when asked it marks a topic weak (`topic_progress` weak, review today; new `material_topics` row if needed) or makes a flash card in the lesson deck; shown under the answer
  - [ ] Still mock: Premium page offer → connect them next, with example rows in `seed.sql`
  - [ ] Class rank on course cards ("Sıralama #3") has no data on the server; hidden until it exists
  - [x] App language and theme are saved in the account (`profiles.app_lang`, `user_settings.app_theme`): used after sign-in on every device, saved on change (`settings/PrefsSync.tsx`)
  - [x] Trial card and Premium status from `access_status()`; devices: login registers the web (all browsers share install id `web` = one slot), My devices list, sign out, 3rd-device screen, signed-out-elsewhere check at start, log out frees the slot
  - [x] School timetable screen `/schedule` (design NewSchedule; from the plan page's "Okul programım"): tomorrow's classes, day tabs, reminder bell per class, add / delete classes (`timetable_entries`), reminder switches and time (`user_settings.class_*`), notification preview + sample browser notification
  - [x] Timetable from a photo / PDF: Edge Function `import-timetable` reads it (AI, ~1-2 cents), the student unticks wrong rows and adds the rest
- [x] Local test copy of the backend (`supabase start` + `dev:local`), so Claude can test with fake accounts (25 Oct 2026)
- [ ] Email sending for the 6-digit code: Supabase's built-in email is only for testing (few emails per hour); a real email provider (custom SMTP) before launch
- [ ] Edge Functions (none built yet; list in `docs/BACKEND.md`); secrets only in Supabase secrets
- [ ] Fill `course_catalog` per department (the design has the pharmacy list)
- [ ] Connect the iOS app (`supabase-swift`)
- [ ] Next phase, after the web is connected: build the iOS and iPad app with the UI design at https://claude.ai/artifact/SoArzVrar1Yo8usieABRB3

## Server features (the web still uses mock data in `web/src/api/`)
- [ ] Real backend: accounts, login (email + Apple + Google), email verification code
- [ ] Store PDFs, notes, highlights, cards, summaries, quiz results per account
- [ ] PDF processing: turn the PDF into the reading page without changing the teacher's text, hard-word explanations
- [ ] AI: assistant answers only from the student's material (optional "AI + research"), lecturer-style questions, cards, summaries, audio narration
- [ ] Content language: generate questions / cards / summaries in the chosen language
- [ ] Translation of PDF sentences (literal / natural)
- [ ] Study plan generation (starter → smart plan), progress data, weak topics
- [ ] Settings saved in the account (now only in the browser)
- [ ] Notifications (study reminders, congratulations)
- [x] "Request my data": Edge `export-data` → one JSON file downloaded at once (all own rows + 7-day PDF links)
- [x] "Delete account": password asked again (Edge `delete-account`), deleted after 30 days, banner "Hesabın … silinecek · Vazgeç" until then
- [x] Nightly purge job (03:30 UTC): migration `20261024213309_account_purge.sql` applied 25 Oct 2026 with Kian's OK (pg_cron + pg_net, random key in `private.app_secrets`); a manual run answered `{deleted: 0}`
- [ ] Later: email for both (needs an email provider): export sent by email, deletion confirmed by an email link (the design's text); accounts with Apple/Google sign-in have no password → confirm by email then

## Payments and plans
- [ ] Apple in-app purchase in the iPhone app (the only way to buy Premium)
- [ ] Paywall text: no Apple free trial, so never show "After the 3-day trial, your plan is charged to your Apple / Google Play account" or "Premium · 3 günlük ücretsiz deneme başladı" (both are in `design/ScrPaywall.dc.html`). Not in the web or iOS code now (the web Premium page has no billing text, the iOS paywall is not built yet); write the correct text when the iOS paywall is built, in 4 languages
- [ ] Server check of the Apple subscription so Premium also unlocks the web
- [ ] Prices come from the App Store (never hardcoded) — web shows "Price in the App Store"
- [ ] Android payment later (Google Play or a web payment) — no Android app yet. The web tells Android users (Premium page, share link page, Google Play button) to use the web with the free trial
- [ ] Android app (later); then update the Google Play button and the Android notes
- [ ] Trial limits enforced on the server (3 days, 2 PDFs, 60 questions, 100 pages per PDF). The web reads the status from `access_status()` and locks Premium-only actions; the counters are raised by the server (Edge Functions, not built yet)
- [ ] Check the 100-page limit when a PDF is uploaded (upload screen not built yet)

## Devices
- [x] Device limit on the server (max 2 devices, the web counts as one); real device list and sign-out on the web
- [ ] Edge Function `sign-out-device`: also end the signed-out device's login at once (now the web notices on its next visit)
- [ ] Real device names from the apps (the web name comes from the browser)

## Sharing
- [x] Big PDFs no longer stop half way (26 Oct 2026): process-material reads the page texts once and keeps them as `pages.json` next to the PDF (migration `materials_page_texts` allows JSON in the bucket); a lesson still "processing" after 5 minutes goes on from its last batch when the app opens (`resumeStuckLessons` in the web)
- [x] Owner page `/admin` (25 Oct 2026, not in any menu): sign-ups, trial / Premium, lessons, AI cost this month (Edge `admin-stats`, answers only the owner id in the function; `ADMIN_USER_IDS` in `supabase/functions/.env` for the local copy)
- [x] Real share links for app-made content (quizzes, summaries, cards — never the PDF, it belongs to the teacher): Edge `create-share` (Premium only) writes `shares`; the link page `/s/:id` only says "download the app". Receiving / copying the items happens in the iPhone app
- [ ] iPhone app opens share links (universal links); non-Premium receiver sees "This lesson can only be opened with Premium." (text is ready in `web/src/i18n/app.json` → `sharePremiumOnly`)

## Web app — not built yet
- [x] Upload screen for PDF (`/upload`, design ScrUpload) — [ ] photo and audio recording still "coming soon"
- [x] Onboarding after sign-up on the web (25 Oct 2026, `/welcome`, until `profiles.onboarding_done`): language, school + department + class year, weekly plan (days, hours), this term's courses (suggestions per department in `web/src/api/onboarding.ts` + typed). "Ders ekle" on My Courses makes a course. Later: fill `course_catalog` per department and year; the 3 intro cards of the phone design are not on the web
- [ ] Help & live support chat
- [ ] Live audio lesson, "Let me explain" (teach-back), solve a question photo
- [ ] Pen / handwritten notes on the PDF, full PDF page view
- [ ] Lesson summary / review pages ("Bugünün tekrarı", exam center)
- [ ] Turn on the App Store button when the iPhone app is live: put the link in `APP_STORE_URL` (`web/src/config.ts`). Until then every store button shows "Yakında" and cannot be clicked (landing, Premium page, share link page)
- [ ] Same for Google Play (`PLAY_STORE_URL`) and the Mac App Store (`MAC_STORE_URL`) when those apps exist; then update the line under the store buttons (`storesSoon`)

## iOS app (`ios/`, SwiftUI + XcodeGen)
Done and checked in the simulator (each screen follows its design file and has UI tests):
- [x] Splash, welcome, sign up / log in / email code, home, profile (+ "Hesap bilgilerim" edit), onboarding (language, weekly plan, department, 3 intro cards), term course setup, upload (PDF / photos / audio / processing / OCR error / 100-page sheet), reader, assistant start + chat
- [x] Texts of the phone designs come from `node ios/scripts/extract-design-texts.mjs` (corrected web translations win); web data from `node ios/scripts/sync-from-web.mjs`. Screens read design texts with `prefs.d("Turkish design text")`; a unit test checks that every such text exists in 4 languages

Still to build (screens):
- [ ] **Settings** (language, appearance, study plan, notifications, offline, privacy, devices). Language and theme can only be changed in the onboarding (language) and by the phone's own dark mode until this exists
- [ ] Course folder ("Derslerim") + course page, quiz, cards, study plan, progress, paywall (Apple in-app purchase, prices from the App Store), notifications, "Bugünün tekrarı" review flow, exam center, share sheet, placement test after upload
- [ ] Reader extras: molecule viewer, audio per page, notes with Apple Pencil, section check quiz ("Başla"), translations of sentences other than the sample one (needs the server)
- [ ] Assistant extras: "Ben anlatayım" (teach-back), voice mode, easy explanation, "Soruyu çözdür", conversation history, real "Sürekli dinle" (speech recognition), real AI answers (now a mock that knows a few lesson answers and says "bulamadım" otherwise)
- [ ] Upload extras: real camera and microphone capture (permission texts), the trial-limit sheet and fair-use sheet of the design (the lock dialog is used now); processing is a mock and always opens the sample lesson
- [ ] Step 4: StoreKit, trial limits on the server, 3rd-device screen (after login with `-kavis.devices full` only a toast is shown), share links, delete account
- [ ] Onboarding: course suggestions are the design's pharmacy list for every department; the chosen courses are only saved on the phone
- [ ] Real "Sign in with Apple" and Google sign-in; real email code (every account uses the demo code 481920 and "Kodu e-postadan yapıştır" fills it)
- [ ] Profile photo picker (now a toast); profile and settings are saved on the phone, not in the account
- [ ] Home: the three course chips and "Güz dönemi · 5 ders…" are fixed design texts until real course data

Known differences from the designs (decided on purpose):
- The designs still show the old free plan ("Bu ay 2 dersten 1'i kullanıldı", "BU AY 1/2 ÜCRETSİZ DERS"). The app shows the 3-day trial (2 PDFs, 60 questions) instead, as in CLAUDE.md
- The home screen shows the remaining trial limits (the design has no place for it)
- Offline use is in every plan; the design files still contain the old "Premium-only" offline text (not copied)

Technical notes and decisions:
- [ ] Texts I wrote myself (not from the design) need a native-speaker check: the Persian / Arabic "not found in your PDF" message, "Erkek sesi" labels, the 100-page sheet texts of the design were copied as they are
- [ ] Minimum iOS version is 17. The exact line height of the design (`.lineHeight`) needs iOS 26; on iOS 17–25 lines are a little looser
- [ ] Remove the mock test switches before the public launch: `-kavis.trial`, `-kavis.devices`, `-kavis.premium`, `-kavis.lang`, `-kavis.theme`, `-kavis.offline`, `-kavis.route` (welcome, login, signup, verify, onboarding, setup, home, profile, profileEdit, upload, uploadPhoto, uploadAudio, reader, assistant, chat), `-kavis.onboardingStep`, `-kavis.uploadMode`, `-kavis.readerTerm`, `-kavis.readerSheet`, `-kavis.assistantPanel`
- [ ] Fonts do not scale with the system text size yet (fixed sizes like the design); decide on Dynamic Type later
- [ ] Never read `UIApplication` / `safeAreaInsets` inside a SwiftUI body (it froze the home screen); use `KLayout.top`. Shapes are mirrored by SwiftUI in right-to-left layouts by default; `SVGShape` turns that off, only arrows opt in (`flipsInRTL`)
- [ ] Set the Apple developer team and the final bundle id (now `study.kavis.app`) before TestFlight / App Store
- [ ] iPad version later (wide layouts from `design/NewIPad.dc.html`; now `TARGETED_DEVICE_FAMILY` is iPhone only)
- [x] Offline use is in every plan (free included): fixed `offFreeT`, `offFreeS`, removed `pwWhyOffline` (web + iOS)

## Texts and legal
- [ ] Legal check of all texts: terms of use, KVKK / privacy notice, Premium and trial texts, delete-account texts
- [ ] Native-speaker check of the English, Persian and Arabic translations (some design translations were wrong and were fixed)

## Release
- [x] Static build ready for Vercel (`web/vercel.json`: page routing + noindex header)
- [x] Test deploy on Vercel (free): https://kavis-website.vercel.app — no custom domain, search engines blocked; every push to `main` updates it
- [ ] Split the JavaScript into smaller parts per page (now one ~190 KB gzip file)

## Public launch checklist (do all of these before opening the site to everyone)
- [ ] Real accounts and a real server (login, email verification, data per account) — replace `web/src/api/` mock functions
- [ ] PDF processing and AI (reading page, questions, cards, summaries, assistant) with a cost limit per user and per month
- [ ] Trial limits on the server (3 days, 2 PDFs, 60 assistant questions, 100 pages per PDF)
- [ ] 2-device limit on the server (the web counts as one)
- [ ] KVKK texts and privacy policy (and terms of use) written and checked by a lawyer; link them from sign-up and the site
- [ ] Remove sample data: sample answers, the `?lang=` test switch, the sample lesson in the reader, and the example rows of `supabase/seed.sql`
- [ ] Then remove noindex: `web/public/robots.txt`, the robots meta tag in `web/index.html` and the `X-Robots-Tag` header in `web/vercel.json`
- [ ] Custom domain (e.g. kavis.study) in Vercel
