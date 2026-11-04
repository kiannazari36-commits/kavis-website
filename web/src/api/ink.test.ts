// Run: node --experimental-strip-types web/src/api/ink.test.ts
import { blockOrdinals, inkKey } from './inkKey.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  if (!ok) fails++;
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}`);
};

check('blocks sharing a page get 0,1,2 in reading order', JSON.stringify(blockOrdinals([1, 2, 2, 2, 3, 2])) === '[0,0,1,2,0,3]');
check('card key = page:block', inkKey(2, 1) === '2:1');
check('original PDF key = page', inkKey(2) === '2');
process.exit(fails ? 1 : 0);
