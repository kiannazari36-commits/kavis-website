// Run: node --experimental-strip-types web/src/api/ink.test.ts
import { blockOrdinals, groupInk, inkKey } from './inkKey.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  if (!ok) fails++;
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}`);
};

check('blocks sharing a page get 0,1,2 in reading order', JSON.stringify(blockOrdinals([1, 2, 2, 2, 3, 2])) === '[0,0,1,2,0,3]');
check('card key = page:block', inkKey(2, 1) === '2:1');
check('original PDF key = page', inkKey(2) === '2');

const line = (x: number) => ({ color: '#9C2F3A', points: [[x, 0], [x, 1]] as [number, number][] });
const rows = [
  { id: 'a', page: 1, anchor: { strokes: [line(0.1)] } },
  { id: 'b', page: 1, anchor: { block: 1, strokes: [line(0.2)] } },
  { id: 'c', page: 2, anchor: { surface: 'web_pdf', strokes: [line(0.3)] } },
  { id: 'd', page: 2, anchor: { surface: 'pdf', strokes: [line(0.4)] } },
  { id: 'e', page: 3, ink_path: 'u/m/pdf-3.json', anchor: { surface: 'pdf' } },
];
const cards = groupInk(rows, 'card');
check('card rows by page:block', Object.keys(cards).sort().join() === '1:0,1:1' && cards['1:1'].id === 'b');
const pdf = groupInk(rows, 'pdf');
check("'web_pdf' and 'pdf' rows of a page are one drawing", pdf['2'].strokes.length === 2 && pdf['2'].id === 'c' && pdf['2'].others?.[0] === 'd');
check('old PencilKit row (no strokes) is skipped', !pdf['3']);
process.exit(fails ? 1 : 0);
