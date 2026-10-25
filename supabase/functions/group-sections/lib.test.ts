// Run: node --experimental-strip-types supabase/functions/group-sections/lib.test.ts
import { applyParts, maxSections, outline, pagesOf, targetParts, type Section } from './lib.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};

const sec = (title: string, ...pages: number[]): Section => ({ title, blocks: pages.map((p) => ({ pageFrom: p, pageTo: p })) });
const s = [sec('A', 1), sec('B', 2, 3), sec('C', 4), sec('D', 5), sec('E', 6, 7)];

check('max sections: 86 pages -> 11, 5 pages -> 4', maxSections(86) === 11 && maxSections(5) === 4);
check('target parts: 86 -> 6, 5 -> 2, 200 -> 8', targetParts(86) === 6 && targetParts(5) === 2 && targetParts(200) === 8);
check('pages counted once', pagesOf(s) === 7);
check('outline lines', outline(s).split('\n')[1] === '1. B (p. 2-3)');

const merged = applyParts(s, [
  { title: 'Giriş', first: 0 },
  { title: 'Vitaminler', first: 2 },
]);
check('two parts', merged?.length === 2 && merged[0].title === 'Giriş' && merged[1].title === 'Vitaminler');
check('no page lost, order kept', JSON.stringify(merged?.flatMap((x) => x.blocks.map((b) => b.pageFrom))) === '[1,2,3,4,5,6,7]');
check('empty title keeps the old one', applyParts(s, [{ title: ' ', first: 0 }])?.[0].title === 'A');
check('must start at 0', applyParts(s, [{ title: 'x', first: 1 }]) === null);
check('starts must go up', applyParts(s, [{ title: 'x', first: 0 }, { title: 'y', first: 3 }, { title: 'z', first: 2 }]) === null);
check('start out of range', applyParts(s, [{ title: 'x', first: 0 }, { title: 'y', first: 5 }]) === null);

if (fails) {
  console.log(`${fails} failed`);
  process.exit(1);
}
