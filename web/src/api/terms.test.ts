// Run: node --experimental-strip-types web/src/api/terms.test.ts
import { termHits } from './terms.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
const word = (text: string, surface: string) => termHits(text, surface).map(([a, b]) => text.slice(a, b));

check('exact word', word('Kaptopril bir ACE inhibitörüdür.', 'kaptopril').join() === 'Kaptopril');
check('genitive ending', word('Kaptoprilin yan etkisi öksürüktür.', 'Kaptopril').join() === 'Kaptoprilin');
check('ending after ö', word('ACE inhibitörleri anjiyoödemi yapabilir.', 'anjiyoödem').join() === 'anjiyoödemi');
check('ending after an apostrophe', word("ACE'nin yıkımı azalır.", 'ACE').join() === "ACE'nin");
check('short word not inside another word', word('acele et, surface', 'ace').length === 0);
check('not inside a longer word at the start', word('antihipertansif ilaç', 'hipertansif').length === 0);
check('different word with the same start is not taken', word('hipertansiyon', 'hipertansif').length === 0);
check('softened last letter', word('Bu ilacı aç karnına al.', 'ilaç').join() === 'ilacı');
check('two-word term with an ending', word('Primer  hipertansiyonda tedavi', 'primer hipertansiyon').join() === 'Primer  hipertansiyonda');
check('Turkish capital İ', word('ACE İnhibitörleri etkili', 'ace inhibitörleri').join() === 'ACE İnhibitörleri');
check('capital I and dotless ı', word('IBUPROFEN alındı', 'ibuprofen').join() === 'IBUPROFEN');
check('every place is found', termHits('ödem, ödemi ve ödemde', 'ödem').length === 3);
check('places are those of the original text', termHits('Bİr kaptoprilin', 'kaptopril')[0].join() === '4,15');
if (fails) throw new Error(`${fails} failed`);
