// Pulls the 4-language texts of the phone design screens (design/*.dc.html) into one JSON file for the iOS app.
// Run from the repo root:  node ios/scripts/extract-design-texts.mjs
// Each design file has a table of texts (_TK: key -> Turkish, _I18N: the 4 languages). Keys come out as
// "<screen>.<designKey>", e.g. "home.k599", so every text can be traced back to the design file.
// Texts that the design builds in its script (not in _TK) are listed in EXTRA with a name of our own.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const SCREENS = { splash: 'NewSplash', welcome: 'NewWelcome', signup: 'NewSignup', home: 'NewHome' };
// Screens whose texts are looked up by their Turkish design text: `prefs.d("Hesap bilgilerim")` (see Strings.design).
// The design script writes every text as _x('Turkish text'), so this table needs no hand-made keys.
const DESIGN_FILES = ['NewProfile', 'ScrOnboarding', 'NewCourses', 'NewPlacement', 'ScrUpload', 'NewReader', 'NewAssistant', 'ScrAssistant', 'ScrCards', 'ScrQuiz', 'NewStudyPlan', 'NewProgress', 'ScrPlan', 'ScrProgress', 'NewExamPrep'];

// "<screen>.<name>": Turkish text exactly as written in the design script (_x('...')).
const EXTRA = {
  'signup.tabSignup': 'Kayıt ol',
  'signup.tabLogin': 'Giriş yap',
  'signup.titleUp1': 'Hesabını',
  'signup.titleUp2': 'oluştur',
  'signup.titleIn1': 'Tekrar',
  'signup.titleIn2': 'hoş geldin',
  'signup.appleUp': 'Apple ile devam et',
  'signup.appleIn': 'Apple ile giriş yap',
  'signup.googleUp': 'Google ile devam et',
  'signup.googleIn': 'Google ile giriş yap',
  'signup.hidePw': 'Şifreyi gizle',
  'signup.showPw': 'Şifreyi göster',
  'signup.createAccount': 'Hesap oluştur',
  'signup.needConsent': 'Önce kullanım koşullarını onayla (kutuyu işaretle)',
  'signup.needCode': 'Önce e-postadaki 6 haneli kodu gir',
  'signup.haveAccount': 'Zaten hesabın var mı?',
  'signup.noAccount': 'Hesabın yok mu?',
  'signup.login': 'Giriş yap',
  'signup.signup': 'Kayıt ol',
  'home.offlineTitle': 'İnternet yok · çevrimdışı mod',
  'home.offlineText': "Daha önce çalıştığın PDF'ler cihazında. Okuyabilir, kartlarını ve hazır sorularını çözebilirsin.",
  'home.reviewEvening': "Bu akşam 20:00'de hatırlat",
  'home.reviewTomorrow': 'Yarına ertele',
  'home.reviewSkip': 'Bugünlük kaldır',
  'home.msgEvening': "Tekrar bu akşam 20:00'ye ertelendi",
  'home.msgEveningSub': 'Zamanı gelince hatırlatacağım',
  'home.msgTomorrow': 'Tekrar yarına ertelendi',
  'home.msgTomorrowSub': 'Yarın sabah planına eklendi',
  'home.msgSkip': 'Bugünkü tekrar kaldırıldı',
  'home.msgSkipSub': 'Konular sonraki tekrar gününe kaydırıldı',
  'home.msgUndo': 'Geri alındı · tekrar bugün planında',
  'home.uploadOffline': 'Yüklemek için internet gerekli. Kayıtlı derslerini okumaya devam edebilirsin.',
  'home.navProgress': 'İlerleme',
  'home.navSettings': 'Ayarlar',
  'home.tileExam': 'Sınav merkezi',
  'home.tileCards': 'Kartlar',
  'home.tileSummary': 'Ders özeti',
  'home.plan1': '09:00 · Hipertansiyon sınavı',
  'home.plan1s': '8 soru · 40 dk',
  'home.plan2': '09:40 · Tekrar kartları',
  'home.plan2s': '12 kart · 15 dk',
  'home.plan3': 'Ses kaydı · Farmakoterapi',
  'home.plan3s': 'Hocanın vurguladığı 3 konu',
};

const LANGS = ['tr', 'en', 'fa', 'ar'];
const literal = (src, name) => {
  const i = src.indexOf(`const ${name} = `);
  if (i < 0) return {};
  let j = src.indexOf('{', i), depth = 0, k = j, inStr = null;
  for (; k < src.length; k++) {
    const ch = src[k];
    if (inStr) { if (ch === '\\') k++; else if (ch === inStr) inStr = null; continue; }
    if (ch === '"' || ch === "'" || ch === '`') inStr = ch;
    else if (ch === '{') depth++;
    else if (ch === '}' && --depth === 0) break;
  }
  return new Function(`return (${src.slice(j, k + 1)})`)();
};

const out = Object.fromEntries(LANGS.map((l) => [l, {}]));
for (const [screen, file] of Object.entries(SCREENS)) {
  const src = readFileSync(join(root, 'design', `${file}.dc.html`), 'utf8');
  const table = literal(src, '_I18N'); // { k: [turkish...], en: [...], fa: [...], ar: [...] }
  const tk = literal(src, '_TK'); // designKey -> Turkish
  const pt = literal(src, '_PT'); // designKey -> { en, fa, ar } overrides
  const index = new Map(table.k.map((t, i) => [t, i]));
  const say = (turkish, lang, key) => {
    if (lang === 'tr') return turkish;
    if (key && pt[key]?.[lang]) return pt[key][lang];
    const i = index.get(turkish);
    if (i == null) throw new Error(`${file}: no ${lang} text for "${turkish}"`);
    return table[lang][i];
  };
  for (const [k, turkish] of Object.entries(tk)) for (const l of LANGS) out[l][`${screen}.${k}`] = say(turkish, l, k);
  for (const [name, turkish] of Object.entries(EXTRA)) {
    if (!name.startsWith(`${screen}.`)) continue;
    for (const l of LANGS) out[l][name] = say(turkish, l);
  }
}
// The web texts were checked and some design translations were fixed (e.g. "Tekrar hoş geldin" was "Review welcome").
// When the web has the same Turkish text, its other languages win.
const web = new Map();
for (const file of ['desk', 'auth', 'app', 'reader', 'study', 'pages']) {
  const d = JSON.parse(readFileSync(join(root, 'web', 'src', 'i18n', `${file}.json`), 'utf8'));
  for (const [k, turkish] of Object.entries(d.tr)) if (!web.has(turkish)) web.set(turkish, Object.fromEntries(LANGS.map((l) => [l, d[l][k]])));
}
let fixed = 0;
for (const [key, turkish] of Object.entries(out.tr)) {
  const w = web.get(turkish);
  if (!w) continue;
  for (const l of ['en', 'fa', 'ar']) if (out[l][key] !== w[l]) { out[l][key] = w[l]; fixed++; }
}
console.log(`Used the web's translation for ${fixed} texts`);

// Texts looked up by Turkish design text (all design files listed in DESIGN_FILES).
const byTurkish = {};
for (const file of DESIGN_FILES) {
  const src = readFileSync(join(root, 'design', `${file}.dc.html`), 'utf8');
  const table = literal(src, '_I18N');
  if (!table.k) continue;
  const pt = literal(src, '_PT');
  const tk = literal(src, '_TK');
  table.k.forEach((turkish, i) => {
    const entry = byTurkish[turkish] ?? (byTurkish[turkish] = { tr: turkish });
    for (const l of ['en', 'fa', 'ar']) entry[l] ??= table[l][i];
  });
  // Texts the design translates differently in one place (the key is the design key, e.g. p0a).
  for (const [k, langs] of Object.entries(pt)) {
    const turkish = tk[k];
    if (turkish && byTurkish[turkish]) Object.assign(byTurkish[turkish], langs);
  }
}
let fixedDesign = 0;
for (const [turkish, entry] of Object.entries(byTurkish)) {
  const w = web.get(turkish);
  if (!w) continue;
  for (const l of ['en', 'fa', 'ar']) if (entry[l] !== w[l]) { entry[l] = w[l]; fixedDesign++; }
}
writeFileSync(join(root, 'ios', 'KavisStudy', 'Resources', 'Data', 'i18n-design.json'), JSON.stringify(byTurkish, null, 1) + '\n');
console.log(`Wrote ${Object.keys(byTurkish).length} design texts (${fixedDesign} fixed from the web)`);

const target = join(root, 'ios', 'KavisStudy', 'Resources', 'Data', 'i18n-phone.json');
writeFileSync(target, JSON.stringify(out, null, 1) + '\n');
console.log(`Wrote ${Object.keys(out.en).length} texts x 4 languages to ${target}`);
