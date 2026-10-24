# Kavis Study — backend (Supabase)

One backend for every client: web, iPhone, iPad, Mac, Android. Clients use the official Supabase SDKs
(`supabase-js` on web, `supabase-swift` on iOS/iPad/Mac, `supabase-kt` on Android later).

- **Project:** `Kavis` (`lnbfcfxxrqohcnkhlcur`, region eu-west-1, Postgres 17)
- **Schema:** `supabase/migrations/20261023152640_init.sql` (44 tables, Row Level Security on all of them) and
  `20261023152820_hardening.sql` (internal helpers moved to the `private` schema, 5 foreign-key indexes).
  **Both are applied to the Kavis project** (23 Oct 2026); the live schema was checked to be identical to the tested one.
- **Tests:** `supabase/tests/` — 40 behaviour checks (local Postgres with stubbed auth/storage:
  `psql -f 00_local_stub.sql`, both migrations, then `psql -f 10_behaviour.sql`; every line must say PASS).
  A live smoke test on Supabase (inside a rolled-back transaction) also passed.
- **Supabase security advisor:** the 7 remaining warnings are the RPCs the apps are meant to call
  (`access_status`, `can_i`, `content_lang_for`, `register_device`, `sign_out_device`, `study_streak`, `tap_term`);
  each one only answers about the signed-in student. That is intentional.
- **Source of truth for features:** the final design canvas "Kavis Study" + `CLAUDE.md`

## How clients talk to the backend

There are three kinds of API:

1. **Direct table access (REST through the SDK)** for the student's own data. Row Level Security makes sure a
   student only ever sees and changes their own rows, and only the columns the app is allowed to change.
2. **Database functions (RPC)** for small rules that must be the same on every device:
   `access_status`, `can_i`, `register_device`, `sign_out_device`, `content_lang_for`, `tap_term`, `study_streak`.
3. **Edge Functions** for anything that needs a secret (Claude API key, Apple keys), costs money, or must not be
   trusted to the app: processing lessons, AI generation, the assistant, payments, sharing, account deletion.

The app never writes AI output, scores, usage counters, subscriptions or shares itself — only Edge Functions
(service role) do.

## Accounts and devices

| Screen | API |
|---|---|
| Sign up / log in (email + password, Apple, Google), 6-digit email code | Supabase Auth: `signUp` with `data: { full_name, app_lang }`, `verifyOtp({ type: 'signup' })`, `signInWithIdToken` (Apple / Google) |
| Terms + KVKK checkbox | Edge `accept-terms` → `profiles.terms_version`, `terms_accepted_at` |
| After every sign-in | RPC `register_device(install_id, kind, name, app_version)` → `{ ok: true }` or `{ ok: false, devices: [...] }` → "Choose one to sign out" screen |
| Settings › My devices | `select` `user_devices` where `signed_out_at is null` |
| Sign a device out | Edge `sign-out-device` (RPC `sign_out_device` + ends that auth session) |
| Profile, "Hesap bilgilerim" | `profiles` (name, school, department, class year, photo in `avatars` bucket) |
| Settings (theme, content language, translation, reader, voice, notifications, timetable reminders, offline, plan) | `user_settings` (one row per student) |
| Push notifications | `push_tokens` (APNs now; FCM / web push later) |
| Request my data / delete account | Edge `export-data`, `delete-account` → `account_requests`; a daily job deletes 30 days after email confirmation |

## Courses, term, timetable

| Screen | API |
|---|---|
| Onboarding: "Bu dönem hangi dersleri alıyorsun?" | read `course_catalog` (by department) → insert `courses` (`started_before` for "Başladı, bazılarını çalıştım") |
| Derslerim klasörü, course cards | view `course_overview` (lessons, pages, % read, minutes, next exam) |
| Course page content-language switch | `courses.content_lang_override`; RPC `content_lang_for(course_id)` |
| Exam dates, "Sınav haftanı gir" (Vize / Bütünleme) | `course_exams`, `exam_periods` |
| Okul programı (typed in) | `timetable_entries` |
| Okul programı from a photo / PDF | Edge `import-timetable` (reads the image, returns entries for the student to confirm) |

## Lessons (upload and processing)

1. App checks `can_i('upload')` (trial: 3 days, 2 lessons; Premium: always, fair use after 40/month).
2. App inserts `materials` (status `uploaded`) and uploads files to Storage `materials/<user id>/<material id>/…`,
   then `material_files` rows (one PDF, several photos, or one audio file).
3. App calls Edge `process-material`. The server:
   - reads the PDF text (OCR when the pages are scans → status `needs_ocr` first, retry does not use a trial lesson),
   - over 100 pages → status `too_long`; the app shows "Bölümlere ayır / Sayfa aralığı seç";
     Edge `split-material` creates child lessons (`parent_id`) of ≤ 100 pages,
   - writes `material_content.reader_doc` (the teacher's text unchanged), `material_topics`, `material_chunks`
     (for the assistant), `material_terms`, first `card_decks`/`flashcards`, a section-check `quizzes`,
   - sets status `ready` and sends a "Diyabet dersin hazır" notification.
   - Fair use: lessons with `slow_lane = true` are processed after the others.
4. Lecture recording: `materials.kind = 'audio'` with `linked_material_id` → the PDF lesson. **Speech-to-text runs on the
   device** (Apple Speech on iPhone/iPad/Mac, Android SpeechRecognizer later; the web asks for the app or uses the
   browser where supported). The app sends the timestamped transcript to Edge `process-recording`, which matches parts
   to PDF pages and finds topics the lecturer stressed (`material_topics.teacher_*`), stored in `material_content.lecture`.
   The audio file itself stays in the student's `materials` folder.

## Reading page

| Feature | API |
|---|---|
| Open a lesson | `material_content.reader_doc`, `material_terms`, `annotations`, `reading_progress` |
| `reader_doc` shape | `{ language, sections: [{ title, blocks: [{ pageFrom, pageTo, tag (definition / dose / side_effect / special / emergency), heading?, paragraphs: [segments \| { selectable, text }], molecule?, audio? }] }] }`; a segment is a string or `{ term: "<term_key>", text }` |
| `material_terms.explanation` shape | `{ "tr": { name, kind, text }, "en": { … } }` — one entry per app language |
| Translation lookup | `translations.source_hash` = SHA-256 (hex) of the sentence's UTF-8 text |
| Tap a hard word | RPC `tap_term(term_id)`; explanation in `material_terms.explanation[lang]`, missing language → Edge `explain-term` |
| Translate a sentence (literal / natural) | Edge `translate` (cached in `translations`) |
| Highlights, notes, pen | `annotations` (+ `ink` bucket) |
| Page reached, "anladım", finished | `reading_progress` |
| Stopwatch | insert `study_sessions` when a session ends (also cards, quiz, review, assistant, audio) |
| Read aloud | on the device (system voice, `tts_voice`, `tts_rate`) — no server cost |

## Assistant

| Feature | API |
|---|---|
| Chat about one course or all courses | Edge `assistant` (streams). Finds the best `material_chunks` (full-text search), answers **only from them**; "Yapay zekâ + araştırma" (`source_mode = 'ai'`) may add outside knowledge and marks it `outside_pdf`. Saves `assistant_threads` / `assistant_messages` with page sources. Counts a trial question. |
| Quick actions: summarize, quiz me, explain easily, explain this page | same Edge function with an `action` |
| "Ben anlatayım" (teach-back, score /10) | `mode = 'teach_back'`, `assistant_messages.score` |
| "Soruyu çözdür" (photo of a question) | `mode = 'solve_photo'`; the photo can be added to the course's question samples |
| Offline | the app keeps the question and sends it when back online |

## Quizzes, cards, review, exam prep

| Screen | API |
|---|---|
| Section check, lesson-end exam, exam prep, combined exam, placement test | Edge `generate-quiz` (kind, course or all courses, count, weak focus, teacher style) → `quizzes` + `quiz_questions` in `content_lang_for(course)` |
| Answering | app inserts `quiz_attempts`, `quiz_answers` (choice, "Bilmiyorum", hints used, confidence); Edge `grade-quiz` sets `correct`, written-answer `ai_feedback`, score, level, updates `topic_progress.mastery`, adds confident mistakes to cards |
| Result: level, dangerous mistakes, pages to review | `quiz_attempts`, view `topic_mastery` |
| Cards (Bildim / Bilmedim) | `flashcards` (app updates the spaced-repetition columns only) |
| "Bugünün tekrarı" (summary + cards + 3 questions) | `review_sessions` (made by the daily planner); postpone / remove / done = update `status`, `scheduled_for` |
| Ders özeti, genel özet, sınav merkezi | `summaries` (kind lesson / overall / exam_prep / weak), view `topic_mastery`, `term_lookups` (most-tapped words) |
| Soru örneklerim → "Hocanın soru tarzı" | insert `question_samples` (+ `question-samples` bucket) → Edge `analyze-style` → `teacher_styles`; switches "Sınavlarda / Kartlarda / Özetlerde" are app-editable |
| Placement test result (known / weak / todo) | `topic_progress.state` |

## Study plan, progress, notifications

| Screen | API |
|---|---|
| Kendi planım (own plan) | `own_plan_items` (weekday, course, minutes; written by the app — migration `20261024140202_own_plan.sql`) |
| Ders planım (Kavis planı / kendi planım / plansız) | `user_settings.plan_mode`; Edge `build-plan` → `study_plans` + `plan_items` (stage basic → smart, `reasons`) |
| "Bugün az vaktim var", missed tasks | Edge `build-plan` with `action: 'light_day' | 'reschedule'`; the app marks `plan_items.status` |
| İlerleme: weekly minutes, calendar, streak, scores, weak topics, best hours | views `daily_minutes`, `topic_mastery`; RPC `study_streak()`; `quiz_attempts`; `study_sessions` by hour |
| Bildirimler | `notifications` (read, snooze). A scheduled job sends due ones as push (1 h before / at the study time, review day, class tomorrow, streak, weekly report, cheers, trial ending) |

## Premium, trial, fair use

- **Trial:** `profiles.trial_started_at` + `trial_usage` (lessons, questions). `access_status()` gives everything the trial card needs.
- **Premium:** only Apple in-app purchase (StoreKit 2). The app sends the signed transaction to Edge `apple-verify`;
  Apple's server notifications go to Edge `apple-notifications`. Both write `subscriptions`. The web and every other
  device read Premium from `access_status()`. Prices are never stored — StoreKit shows Apple's local price.
- **Fair use:** `access_status().fair_use` → `{ used, limit: 40, slow, resets_on }` for the notice on the upload screen.
- **Cost limit:** every AI call adds tokens and cost to `usage_monthly`; Edge functions refuse or slow down above a per-user monthly budget.

## Sharing (Premium)

- Edge `create-share` (Premium only) → `shares` (only summary / cards / quiz, never the PDF) → link `kavis.study/s/<slug>`.
- The web page `/s/<slug>` only says "download the app" (no preview).
- In the app, Edge `open-share`: signed-in receiver gets a `share_receipts` row ("Ders gelen kutunda bekliyor");
  Premium receivers get a copy in their courses (`copied_material_id`).

## Support

`support_tickets` + `support_messages` (+ `support` bucket for screenshots). Staff answers from the server
(service role); the student gets a notification. FAQ texts stay in the apps.

## Storage buckets (all private, path starts with the student's id)

`materials` (PDF / photos / audio, 100 MB), `avatars`, `question-samples`, `ink`, `support`.

## Edge Functions

**Built:** `assistant` (`verify_jwt = true`; POST `{ question, course_id?, material_id?, mode, thread_id?, lang, page_from?, page_to? }`; with `material_id` the whole lesson text goes to the AI, prompt-cached, and it only talks about that lesson; very long lessons and course chats get the open pages + full-text search pieces), `process-material` (`verify_jwt = false`: checks the student's login itself; the next batch is called with the service key in `x-internal-key`), `ai-health` (free check that the `ANTHROPIC_API_KEY` secret works: lists models, no tokens), `add-card` (`verify_jwt = true`; POST `{ term_id }` → `{ card_id, added | already }`: a flash card from a hard word's explanation, in the lesson's deck), `grade-quiz` (`supabase/functions/grade-quiz/`; `verify_jwt = true`; POST `{ attempt_id }` → `{ score, level, results }`).

### To build (secrets: `ANTHROPIC_API_KEY`, Apple keys)

`accept-terms`, `sign-out-device`, `process-material`, `split-material`, `process-recording`, `import-timetable`,
`explain-term`, `translate`, `assistant`, `generate-quiz`, `grade-quiz`, `generate-summary`, `generate-cards`,
`analyze-style`, `build-plan`, `apple-verify`, `apple-notifications`, `create-share`, `open-share`,
`export-data`, `delete-account`, and scheduled jobs: `send-notifications`, `daily-planner`, `purge-deleted-accounts`.

## Decisions (23 Oct 2026)

- **Region:** stays Ireland (eu-west-1). KVKK wording about EU hosting goes in the privacy notice (lawyer check).
- **Lecture recordings:** speech-to-text on the device (no server transcription cost).
- **Trial:** only the app's own trial (no bank card, 3 days, 2 lessons, 60 questions). No Apple free-trial offer.
  → The Paywall text "After the 3-day trial, your plan is charged to your Apple / Google Play account" must be changed.

## Still open

1. **Search for the assistant:** starts with Postgres full-text search on `material_chunks`; vector search
   (pgvector + embeddings) can be added later without changing the apps.
2. **Course catalog:** fill `course_catalog` per department (the design has the pharmacy list).
3. **Edge Functions:** none is built yet (list above). Next step after this.
