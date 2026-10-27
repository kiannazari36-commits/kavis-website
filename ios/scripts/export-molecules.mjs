// Copies the web's molecule library (web/src/components/molecules.ts) to a JSON file for the iPhone viewer.
// Run: node ios/scripts/export-molecules.mjs   (uses the esbuild that comes with the web app)
import { build } from '../../web/node_modules/esbuild/lib/main.js';
import { writeFileSync } from 'node:fs';

const out = await build({
  entryPoints: [new URL('../../web/src/components/molecules.ts', import.meta.url).pathname],
  bundle: true, format: 'esm', write: false, platform: 'neutral',
});
const code = out.outputFiles[0].text;
const mod = await import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'));
const list = Object.values(mod.MOLECULES).map((m) => ({ ...m, match: m.match.source, matchFlags: m.match.flags }));
writeFileSync(new URL('../KavisStudy/Resources/Data/molecules.json', import.meta.url).pathname, JSON.stringify(list));
console.log(`${list.length} molecules written`);
