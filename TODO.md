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
- [ ] Android payment later (Google Play or a web payment) — no Android app yet
- [ ] Trial limits enforced on the server (3 days, 2 PDFs, 60 questions, 100 pages per PDF)

## Devices
- [ ] Device limit on the server (max 2 devices, the web counts as one); real device list and sign-out

## Sharing
- [ ] Real share links for app-made content (quizzes, summaries, cards — never the PDF)
- [ ] App opens share links; non-Premium receiver sees the Premium message

## Web app — not built yet
- [ ] Upload screen (PDF, photo, audio recording)
- [ ] Onboarding after sign-up (language, plan days/hours, courses)
- [ ] Notifications screen, help & live support chat, school timetable
- [ ] Live audio lesson, "Let me explain" (teach-back), solve a question photo
- [ ] Pen / handwritten notes on the PDF, full PDF page view
- [ ] Lesson summary / review pages ("Bugünün tekrarı", exam center)
- [ ] Real App Store link: set `APP_STORE_URL` in `web/src/config.ts` (now empty → buttons show a message)

## Texts and legal
- [ ] Legal check of all texts: terms of use, KVKK / privacy notice, Premium and trial texts, delete-account texts
- [ ] Native-speaker check of the English, Persian and Arabic translations (some design translations were wrong and were fixed)

## Release (steps 5–6 of CLAUDE.md, not started)
- [ ] Deploy-ready static build and publishing (Vercel or Netlify)
