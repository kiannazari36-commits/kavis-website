// Copies texts and mock data from the web app into the iOS app, so both use the same words and numbers.
// Run from the repo root:  node ios/scripts/sync-from-web.mjs
// Needs Node 22.18+ (it reads the web's .ts mock files directly).
import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
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

// 2. Mock data: web/src/api/mock/*.ts -> JSON
const load = (file) => import(pathToFileURL(join(web, 'api', 'mock', file)).href);
const write = (name, data) => writeFileSync(join(out, name), JSON.stringify(data, null, 2) + '\n');

const { COURSES } = await load('courses.ts');
write('mock-courses.json', COURSES);

const { COMPARE_ROWS, PREMIUM_PLANS } = await load('premium.ts');
write('mock-premium.json', { rows: COMPARE_ROWS, plans: PREMIUM_PLANS });

const { HYPERTENSION_DOC } = await load('readerDoc.ts');
write('mock-reader.json', HYPERTENSION_DOC);

console.log(`Synced to ${out}`);
