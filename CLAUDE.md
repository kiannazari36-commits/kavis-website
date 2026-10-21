# Kavis Study — web frontend project

## Who I am
- Pharmacy student, not a developer. Talk to me in **Persian (فارسی)** or Turkish, short and simple. Explain every terminal command before running it.
- Make reasonable decisions yourself, then tell me briefly what you did. Ask only before something irreversible.

## What this app is
Kavis Study (old names: Jarvis Study, AIM Study). Slogan: "Always Improve More".
A student uploads the teacher's PDF, a slide photo or a lecture recording. The app turns it into an interactive reading page **without changing the teacher's text**, plus summaries, audio narration, flash cards, quizzes in the teacher's style, a study plan and an AI assistant. The AI only uses the material the student uploaded. For all students, not only pharmacy.

## What is in this folder
- `design/` — the full design prototype exported from a Claude Design canvas: 72 `.dc.html` screens, `canvas.json` (board list) and the images (`icon_star*.png`, `brain*.png`, `star_*.png`, `icon_taba.png`).
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
- Content language: quiz questions, flash cards and summaries are written in the language of the uploaded PDF, not the interface language. Settings has a "Content language" option: "Same as PDF" (default), "Same as app", or a chosen language (tr/en/fa/ar). It can also be changed per course on the course page (the course setting wins over the global one). Buttons and menus always stay in the app language.
- Offline use in every plan (free included); sharing only in Premium.
- Free trial: 3 days, max 2 PDFs and 60 assistant questions; each PDF max 100 pages. "Delete account" exists everywhere.

## The task (do it step by step, tell me after each step)
1. Read `design/canvas.json`, `design/DeskApp.dc.html` and `design/DesignSystem.dc.html`; give me a 5-line summary of the pages you will build.
2. Create a modern web frontend in a new folder `web/`: **Vite + React + TypeScript**, plain CSS or CSS modules with the design tokens above, React Router, i18n for tr/en/fa/ar with RTL.
3. Build the pages to match the design exactly: landing, login/signup, home (my courses), course folder, reader, assistant, quiz, cards, study plan, progress, settings, paywall. Light and dark mode.
4. No real backend yet: use mock data and fake API functions in one `src/api/` folder so a real server can be plugged in later.
5. Run it locally (`npm install`, `npm run dev`) and tell me exactly what to open in the browser.
6. Make it deploy-ready (static build) and explain the simplest free way to publish it (e.g. Vercel or Netlify), step by step.

Do not change anything inside `design/`.
