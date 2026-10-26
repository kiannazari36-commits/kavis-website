// Copies texts and mock data from the web app into the iOS app, so both use the same words and numbers.
// Run from the repo root:  node ios/scripts/sync-from-web.mjs
// Needs Node 22.18+ (it reads the web's .ts mock files directly).
import { copyFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const web = join(root, 'web', 'src');
const out = join(root, 'ios', 'KavisStudy', 'Resources', 'Data');
mkdirSync(out, { recursive: true });

// 1. Texts: web/src/i18n/*.json -> i18n-*.json (same shape: { tr, en, fa, ar } -> key -> text)
for (const name of ['desk', 'auth', 'app', 'reader', 'study', 'pages']) {
  copyFileSync(join(web, 'i18n', `${name}.json`), join(out, `i18n-${name}.json`));
}

// 2. Mock data: web/src/api/mock/*.ts -> JSON. The web is on the server now and removed most mock files; the iOS
// copies made earlier stay as they are when the web file is gone.
const load = async (file) => (existsSync(join(web, 'api', 'mock', file)) ? import(pathToFileURL(join(web, 'api', 'mock', file)).href) : null);
const write = (name, data) => writeFileSync(join(out, name), JSON.stringify(data, null, 2) + '\n');

const courses = await load('courses.ts');
if (courses) write('mock-courses.json', courses.COURSES);

const premium = await load('premium.ts');
if (premium) write('mock-premium.json', { rows: premium.COMPARE_ROWS, plans: premium.PREMIUM_PLANS });

const reader = await load('readerDoc.ts');
if (reader) write('mock-reader.json', reader.HYPERTENSION_DOC);

const assistant = await load('assistant.ts');
if (assistant) write('mock-assistant.json', { topics: assistant.ASSISTANT_TOPICS, attachments: assistant.SAMPLE_ATTACHMENTS });

console.log(`Synced to ${out}`);
