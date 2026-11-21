// Run: node --experimental-strip-types supabase/functions/_shared/paths.test.ts
import { safeStoragePath } from './paths.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
const U = '11111111-1111-1111-1111-111111111111';
const V = '22222222-2222-2222-2222-222222222222';

check('normal path with spaces stays', safeStoragePath(U, `${U}/m1/ders notu.pdf`) === `${U}/m1/ders notu.pdf`);
check('double slash and dot are cleaned', safeStoragePath(U, `${U}//m1/./x.pdf`) === `${U}/m1/x.pdf`);
check('.. is refused', safeStoragePath(U, `${U}/../${V}/secret.json`) === null);
check('another student\'s folder is refused', safeStoragePath(U, `${V}/x.pdf`) === null);
check('leading slash then other folder is refused', safeStoragePath(U, `/${V}/x.pdf`) === null);
check('backslash is refused', safeStoragePath(U, `${U}\\..\\x`) === null);
check('folder only is refused', safeStoragePath(U, `${U}`) === null);
check('null is refused', safeStoragePath(U, null) === null);
if (fails) process.exit(1);
