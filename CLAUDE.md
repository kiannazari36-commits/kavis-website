# Kavis Study

## Who I am
- Pharmacy student, not a developer. **Always talk to me in Turkish** (since 23 Oct 2026), short and simple. Explain every command I have to run myself.
- Make reasonable decisions yourself, then tell me briefly what you did. Ask only before something irreversible, something that costs money, or anything that changes the live database.
- **After every step, explain in a few short sentences what we did and why** (in plain words, no jargon) — I want to learn how the app is built.

## What this app is
Kavis Study (old names: Jarvis Study, AIM Study). Slogan: "Always Improve More".
A student uploads the teacher's PDF, a slide photo or a lecture recording. The app turns it into an interactive reading page **without changing the teacher's text**, plus summaries, audio narration, flash cards, quizzes in the teacher's style, a study plan and an AI assistant. The AI only uses the material the student uploaded. For all students, not only pharmacy.

## What is in this folder
- `web/` — React + Vite + TypeScript web app (all screens built). Deployed on Vercel: https://kavis-website.vercel.app (test only, noindex); every push to `main` of `kiannazari36-commits/kavis-website` redeploys it. Server calls live in `web/src/api/` (being moved from mock data to Supabase).
- `ios/` — SwiftUI + XcodeGen iPhone app (`project.yml`). Screens done and still to build are listed in `TODO.md`. Still on mock data.
- `supabase/` — `migrations/` (the live schema) and `tests/` (40 behaviour checks for a local Postgres).
- `docs/BACKEND.md` — the backend: which table / RPC / Edge Function each screen uses. Read it before any server work.
- `design/` — the final UI design, exported from the "Kavis Study" Claude Design canvas. **Source of truth for every client.** Contents: 72 `.dc.html` screens, `canvas.json` (board list) and the images (`icon_star*.png`, `brain*.png`, `star_*.png`, `icon_taba.png`).
- `reference/dc-runtime.js` — the runtime that renders the `.dc.html` format. Read it only to understand the template syntax; do not ship it.

### The `.dc.html` format (how to read the design files)
- Markup lives inside `<x-dc>…</x-dc>`. Logic is in `<script type="text/x-dc">` as `class Component extends DCLogic { renderVals(){ return {...} } }`.
- `{{a.b}}` = value from `renderVals()`; `<sc-for list="{{x}}" as="i">` = loop; `<sc-if value="{{x}}">` = condition; `<dc-import name="Other" prop="...">` = child component (the file `Other.dc.html`); `this.state` / `this.setState` = component state; `this.props` = attributes passed in (kebab-case → camelCase).
- Treat these files as **design reference**: copy the exact layout, colors, spacing, fonts, texts and behavior.

### Most important files for the web
- `DeskApp.dc.html` — the desktop/web app (screens: `landing`, `login`, `home`, `courses`, `settings`, with `frame="web"`, light/dark, 4 languages). **Start here.**
- `DeskWeb*.dc.html` — which DeskApp screen + options each web page uses.
- `DesignSystem.dc.html` — colors, type, components.
- `Main.dc.html` + `New*.dc.html` + `Scr*.dc.html` — the phone app screens (reader, assistant, quiz, cards, plan, progress, upload, paywall, onboarding…). Reuse their content for the matching web pages.
- `NewIPad.dc.html` — full iPad app in one file (useful for wide layouts).

## Visual rules
- Fonts: Poppins (UI), Lora (reading text), JetBrains Mono (numbers), Vazirmatn (Persian/Arabic).
- Brand: bordo `#9C2F3A`, amber `#F2B33D`. Light: ground `#F1E9DA`, card `#FBF6EC`, text `#2A2420`, secondary `#6E645A`, line `#E0D4BE`. Dark: ground `#15120F`, card `#211C18`, text `#EFE8DC`.
- Icon: bordo ground with an amber compass star (`icon_star.png`, dark `icon_star_dark.png`).
- Pill buttons, card radius 22–30. No emoji. In light mode no black/very dark boxes.
- Every button does something; buttons with no real action yet show a short toast.

## Product rules
- Interface languages: Turkish, English, Persian, Arabic (Persian and Arabic right-to-left). An uploaded PDF stays in its own language; there is a translate button. The assistant speaks the language the student wants.
- Content language: course setting, then general setting, then the PDF's language. Quiz questions, flash cards and summaries are written in the language of the uploaded PDF, not the interface language. Settings has a "Content language" option: "Same as PDF" (default), "Same as app", or a chosen language (tr/en/fa/ar). The course page has no language buttons (decided 25 Oct 2026); the server still honours a per-course override if one exists. Buttons and menus always stay in the app language.
- Offline use in every plan (free included). "Delete account" exists everywhere.
- Payments: only Apple in-app purchase in the iPhone app. Premium unlocks every device through the server (`access_status()`). The web never sells Premium: the web Premium page has no buy buttons and no App Store billing text; it says "Upgrade to Premium in the Kavis Study iPhone app" with an App Store button.
- Prices: Apple sets the local price per country, so never hardcode prices or currencies. On the web show "Price in the App Store".
- Free trial: only our own app trial (no bank card, no Apple free-trial offer): 3 days, max 2 lessons (PDFs), 60 assistant questions, each PDF max 100 pages. So no paywall text may say the plan is charged after the trial. Show the remaining limits during the trial. After the trial the student keeps: reading old PDFs, own notes, highlights, existing cards and summaries, and offline use. Premium only: new PDF upload, new assistant questions, generating new quizzes/cards, sharing. Locked message: "Deneme süren doldu. Çalıştığın PDF'ler seninle kalıyor; yeni PDF yüklemek için Premium'a geç." (also in en/fa/ar). There is no "2 courses / 20 questions per month" free plan.
- Devices: max 2 devices per account; the web counts as one. On a 3rd device show "You're signed in on 2 devices. Choose one to sign out." with the device list. Settings has "My devices" with the list and a sign-out button for each. Enforced on the server by the RPC `register_device`.
- Sharing (Premium only): only what the app made (quizzes, summaries, flash cards), never the original PDF. A share link opens a web page "To open this, download the Kavis Study app" with an App Store button and no preview. In the app, a non-Premium receiver sees "This lesson can only be opened with Premium."
- Android: no Android app yet. Android users use the web with the free trial; Premium for them comes later (Google Play or a web payment).
- Lecture recordings: speech-to-text runs on the device; the app sends only the transcript to the server.
- iPhone: bottom tab bar has 3 tabs; the assistant button stays at the top right.
- `TODO.md` lists everything not finished yet (server, real payments, Android payment, device limit on the server, legal check of texts, …). Update it after every step.

## Backend (Supabase)
- Project **Kavis**, ref `lnbfcfxxrqohcnkhlcur`, region eu-west-1 (stays there), Postgres 17. One backend for every client (web, iOS, later Android).
- Schema: `supabase/migrations/` — **already applied** to the live project (45 tables, RLS on all, 5 private buckets, RPCs `access_status`, `can_i`, `register_device`, `sign_out_device`, `content_lang_for`, `tap_term`, `study_streak`; nightly pg_cron job `purge-deleted-accounts`). File names match the live migration versions. Any new schema change = a new migration file, tested locally first, and applied to the live database only after I say yes.
- Full API map: `docs/BACKEND.md`. The 7 remaining security-advisor warnings are intentional (explained there).
- **Rule:** AI output, scores, usage counters, subscriptions and shares are written **only by Edge Functions** (service role). The apps never write them.
- **AI model (decided 24 Oct 2026):** Claude Sonnet 5.5 (`claude-sonnet-5-5`) for PDF processing and the assistant (cheaper than Opus). The key is the Supabase secret `ANTHROPIC_API_KEY` (Anthropic Console, Default Workspace, expires after 90 days — renew it). Ask me before every paid test and say what it cost.
- **Secrets:** never put the service role key, the Claude API key, Apple keys or any secret in code or git. Clients use only the URL and the publishable (anon) key from `.env` files that git ignores (`web/.env.local`). Edge Functions read secrets from Supabase secrets.
- Claude Code reaches the project through the Supabase MCP connector (read freely; ask before writing to the live database).
- **Local copy for testing (since 25 Oct 2026):** Docker Desktop (on the Desktop folder) + Supabase CLI (`brew`). `supabase start` runs the whole backend on this Mac with all migrations (seed off); `npm --prefix web run dev:local` (port 5174, `.claude/launch.json` "web-local") opens the web app on it. Claude tests there with its own fake accounts (`supabase/local-test-users.local.md`, git-ignored) and fake PDFs — never on the live site or Kian's account. Edge Functions run locally too; AI calls need `ANTHROPIC_API_KEY` in `supabase/functions/.env` (git-ignored). The nightly purge job is switched off in the local copy.

## Current task: connect the web app to Supabase
Replace the mock functions in `web/src/api/` one area at a time, with `@supabase/supabase-js`:
1. Auth: email + 6-digit code, then Apple and Google.
2. Profile and settings (`profiles`, `user_settings`).
3. Devices: `register_device` after every login, "My devices", the 3rd-device screen.
4. Courses and timetable.
5. Trial status (`access_status`).

After each area: test it in the browser, commit, push, update `TODO.md`, and stop so I can check. Keep the screens exactly as designed.

## Order of work (decided 24 Oct 2026)
1. **Finish the website completely first** (all pages on real data + the Edge Functions it needs), then
2. the iOS and iPad app on the same backend.

## Next phase (after the web is finished)
Build the iOS **and iPad** app with the UI design at https://claude.ai/artifact/SoArzVrar1Yo8usieABRB3 (read it with the Artifact tool, not a web fetch). Use it together with `design/` for the iPhone/iPad screens.

Do not change anything inside `design/`.
