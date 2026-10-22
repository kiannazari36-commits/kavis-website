# Kavis Study — TODO

Everything that is not finished yet. Updated after every step.

## Server (nothing real yet — the web uses mock data in `web/src/api/`)
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
- [ ] Server check of the Apple subscription so Premium also unlocks the web
- [ ] Prices come from the App Store (never hardcoded) — web shows "Price in the App Store"
- [ ] Android payment later (Google Play or a web payment) — no Android app yet. The web tells Android users (Premium page, share link page, Google Play button) to use the web with the free trial
- [ ] Android app (later); then update the Google Play button and the Android notes
- [ ] Trial limits enforced on the server (3 days, 2 PDFs, 60 questions, 100 pages per PDF). The web shows the limits and locks Premium-only actions with mock data (`web/src/api/trial.ts`; try `?trial=active|full|ended`)
- [ ] Check the 100-page limit when a PDF is uploaded (upload screen not built yet)

## Devices
- [ ] Device limit on the server (max 2 devices, the web counts as one); real device list and sign-out. The web UI is ready with mock data: Settings → My devices, and the 3rd-device screen `/devices` (try login with `?devices=full`)
- [ ] Real device names from the apps (the web name comes from the browser)

## Sharing
- [ ] Real share links for app-made content (quizzes, summaries, cards — never the PDF). Web UI ready: share dialog in the reader (Premium only) and the link page `/s/:id` with mock links
- [ ] iPhone app opens share links (universal links); non-Premium receiver sees "This lesson can only be opened with Premium." (text is ready in `web/src/i18n/app.json` → `sharePremiumOnly`)

## Web app — not built yet
- [ ] Upload screen (PDF, photo, audio recording)
- [ ] Onboarding after sign-up (language, plan days/hours, courses)
- [ ] Notifications screen, help & live support chat, school timetable
- [ ] Live audio lesson, "Let me explain" (teach-back), solve a question photo
- [ ] Pen / handwritten notes on the PDF, full PDF page view
- [ ] Lesson summary / review pages ("Bugünün tekrarı", exam center)
- [ ] Turn on the App Store button when the iPhone app is live: put the link in `APP_STORE_URL` (`web/src/config.ts`). Until then every store button shows "Yakında" and cannot be clicked (landing, Premium page, share link page)
- [ ] Same for Google Play (`PLAY_STORE_URL`) and the Mac App Store (`MAC_STORE_URL`) when those apps exist; then update the line under the store buttons (`storesSoon`)

## iOS app (`ios/`, SwiftUI + XcodeGen)
- [x] Step 1: project skeleton (`ios/project.yml`; run `xcodegen generate` in `ios/`, then open `KavisStudy.xcodeproj`), colors, fonts, light/dark, RTL, app icon
- [x] Step 2: texts in tr/en/fa/ar (copied from the web) and the fake API in `ios/KavisStudy/API/` (auth, account, courses, trial, devices, settings, premium, share). After the web texts or mock data change, run `node ios/scripts/sync-from-web.mjs`
- [ ] Step 3: screens (login/signup, onboarding, home, course folder, reader, assistant, quiz, cards, plan, progress, upload, settings, paywall). The big mock data (reader PDF, assistant, quiz, cards, plan, progress) is added to the sync script together with each screen
- [ ] Step 4: StoreKit (Apple in-app purchase, prices from the App Store), trial limits, 2-device screen, share links, delete account
- [ ] Set the Apple developer team and the final bundle id (now `study.kavis.app`) before TestFlight / App Store
- [ ] Remove the mock test switches (`-kavis.trial`, `-kavis.devices`, `-kavis.premium`, `-kavis.lang`, `-kavis.theme`) and the temporary `DesignCheckView` before the public launch
- [ ] Fonts do not scale with the system text size yet (fixed sizes like the design); decide on Dynamic Type later
- [ ] iPad version later (wide layouts from `design/NewIPad.dc.html`; now `TARGETED_DEVICE_FAMILY` is iPhone only)
- [ ] Check text conflict: `offFreeT` ("Offline use · Premium") and `pwWhyOffline` ("Offline reading is Premium-only") in `web/src/i18n/pages.json` say offline is Premium-only, but CLAUDE.md says offline use is in every plan

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
- [ ] Remove sample data: mock courses, PDFs, sample answers, `?trial=` / `?devices=` / `?lang=` test switches, the sample lesson in the reader
- [ ] Then remove noindex: `web/public/robots.txt`, the robots meta tag in `web/index.html` and the `X-Robots-Tag` header in `web/vercel.json`
- [ ] Custom domain (e.g. kavis.study) in Vercel
