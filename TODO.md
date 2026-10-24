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
  - [ ] "Forgot password" (now a toast): reset with a 6-digit code
  - [ ] Sign in with Apple and Google (buttons now show "coming soon"): needs Apple developer account (Services ID + key) and a Google Cloud OAuth client, then enable both in Supabase → Authentication → Providers
  - [x] Example data: `supabase/seed.sql` (re-runnable; fills the kiannazari36 account with 5 courses, 13 lessons, exams, timetable, reading progress, study time). Applied to the live project. Each newly connected area adds its rows there
  - [x] Courses (menu, home "continue", My Courses, course folder, reader title), profile (name, school, department, year) and settings (`user_settings`, per-course content language) now come from Supabase. `web/src/api/mock/courses.ts` removed
  - [x] Reader: text (`material_content.reader_doc`), hard words (`material_terms`, tap → `tap_term`), saved translations, highlights (`annotations`), pages read (`reading_progress`), stopwatch → `study_sessions`. Example: the "Hipertansiyon" lesson; other lessons show "reading page not ready yet". `web/src/api/mock/readerDoc.ts` removed
  - [ ] Reader still mock: the assistant side panel, molecule viewer, read aloud, pen
  - [x] Cards: today's round = cards due now (`flashcards` + `card_decks`, optional `?course=`); Bildim / Zor / Bilmedim saves the review state (simple spaced repetition: 1 min / 10 min / 4 days × ease). Example: Hipertansiyon (12) and Parasetamol toksisitesi (6) decks. `web/src/api/mock/cards.ts` removed
  - [ ] "Add to cards" from a hard word, and "add mistakes to cards": need the server (the app may not create cards)
  - [x] Quiz ("Sınava özel"): exam-prep summary (`summaries` kind exam_prep: topics by importance with the reason), questions in the lecturer's style (`quizzes` + `quiz_questions`, hints, molecule), the reader's section check (`section_check`), course chips = nearest exams (pack ready or "ready 7 days before"); answers saved (`quiz_attempts` + `quiz_answers`); reminder time → `user_settings.notify_time`. Example: Farmakoterapi pack (5 topics, 6 questions) + 2-question section check. `web/src/api/mock/quiz.ts` removed
  - [x] Edge Function `grade-quiz` (deployed 24 Oct 2026): grades a finished attempt (right = 1, with hint = 0.5), sets `quiz_answers.correct`, score and level, `topic_progress` mastery (weak < 60) and next review, and adds wrong "sure" answers to the course's "Hatalarım" deck. Rules in `supabase/functions/grade-quiz/grade.ts`, tests: `node --experimental-strip-types supabase/functions/grade-quiz/grade.test.ts`. The web calls it after saving a quiz
  - [ ] Written answers: graded later by AI (now left empty)
  - [x] Study plan: this week from `study_plans` + `plan_items` (real dates, course colors, reasons from the plan), tick tasks (status/done_at), "Dünü kaçırdım" moves unfinished past tasks to the coming days with the least time. Home: today's plan (times from the reminder time), today's review box from `review_sessions` (start = done, later = tomorrow), days to the next exam. Example: a 6-day week around today with 2 missed tasks yesterday. `web/src/api/mock/plan.ts` removed
  - [ ] Edge Function `build-plan` / daily planner: make the weekly plan, basic → smart stage, "Bugün az vaktim var" (light day; now only shown, not saved), "add wrong answers to my plan"
  - [ ] Own plan ("Kendi planım"): not saved yet — needs a table (or user_settings JSON) the app may write
  - [x] Progress: week minutes (`daily_minutes`), streak (`study_streak()`), last score + level and course ranking from graded `quiz_attempts`, growth and congratulation (>10%), best-hours tip (average score by 2-hour window), weak topics (`topic_progress`), words learned (`term_lookups`). Example: 12 graded tries over 30 days in 3 courses, 4 weak topics. `web/src/api/mock/progress.ts` removed
  - [ ] Congratulation as a push notification when the app is closed: scheduled job `send-notifications`
  - [x] Notifications: new web page `/notifications` (design ScrNotifications: Today / Yesterday / This week), from `notifications`; opening marks them read; the bell dot shows unread; the flame button shows the real streak. Example: 9 notifications matching the example data
  - [ ] Scheduled job `send-notifications` (push, snooze) and the server writing notifications (planner, lesson ready, exam result, weekly report)
  - [x] Assistant: course choice = real courses + "all"; the chat and the reader's side panel show the saved conversation (`assistant_threads` + `assistant_messages`, sources = lesson + page). A new question is shown with "real answers come once the assistant is connected" (the app may not write answers). Example: 5 conversations, 14 messages
  - [ ] Edge Function `assistant`: answer only from the student's lessons (`material_chunks` search), "AI + research" mode, save thread + messages, count trial questions, cost limit — needs the Claude API key as a Supabase secret
  - [ ] Assistant "+" menu (upload PDF / photo / audio, solve a question photo): still sample data (`web/src/api/mock/assistant.ts`) until upload is built
  - [ ] Still mock: Premium page offer → connect them next, with example rows in `seed.sql`
  - [ ] Class rank on course cards ("Sıralama #3") has no data on the server; hidden until it exists
  - [ ] App language and theme are still saved only in the browser (`profiles.app_lang`, `user_settings.app_theme` exist)
  - [x] Trial card and Premium status from `access_status()`; devices: login registers the web (all browsers share install id `web` = one slot), My devices list, sign out, 3rd-device screen, signed-out-elsewhere check at start, log out frees the slot
  - [x] School timetable screen `/schedule` (design NewSchedule; from the plan page's "Okul programım"): tomorrow's classes, day tabs, reminder bell per class, add / delete classes (`timetable_entries`), reminder switches and time (`user_settings.class_*`), notification preview + sample browser notification
  - [ ] Timetable from a photo / PDF: Edge Function `import-timetable` (buttons say "coming soon")
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
- [ ] "Request my data" and "Delete account" (email confirmation, 30 days)

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
- [ ] Real share links for app-made content (quizzes, summaries, cards — never the PDF). Web UI ready: share dialog in the reader (Premium only) and the link page `/s/:id` with mock links
- [ ] iPhone app opens share links (universal links); non-Premium receiver sees "This lesson can only be opened with Premium." (text is ready in `web/src/i18n/app.json` → `sharePremiumOnly`)

## Web app — not built yet
- [ ] Upload screen (PDF, photo, audio recording)
- [ ] Onboarding after sign-up (language, plan days/hours, courses)
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
