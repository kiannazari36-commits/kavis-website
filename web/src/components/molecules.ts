import type { Lang } from '../i18n/I18nProvider';

// Molecule library for the viewer (hand-placed 2D structures in a 300×300 box, from design/MolViewer.dc.html).
// A molecule is shown in the reader when its name appears in the page text. Texts: names and notes in 4 languages.
export type L = Record<Lang, string>;
export type Group = { id: string; name: L; atoms: string[]; bonds: [string, string][]; note: L };
export type Molecule = {
  id: MoleculeId;
  name: L;
  formula: string;
  mw: L;
  cls: L;
  atoms: Record<string, [number, number, string, string?]>;
  /** [from, to, double?, side of the second line (0 = towards the ring centre)] */
  bonds: [string, string, number?, number?][];
  center?: [number, number];
  groups: Group[];
  /** Words that point to this molecule in a page text. */
  match: RegExp;
};
export type MoleculeId = 'captopril' | 'paracetamol';

const CAPTOPRIL: Molecule = {
  id: 'captopril',
  match: /kaptopril|captopril|کاپتوپریل|كابتوبريل/i,
  name: { tr: 'Kaptopril', en: 'Captopril', fa: 'کاپتوپریل', ar: 'كابتوبريل' } ,
  formula: 'C9H15NO3S',
  mw: { tr: '217,3 g/mol', en: '217.3 g/mol', fa: '217.3 g/mol', ar: '217.3 g/mol' } ,
  cls: { tr: 'ACE inhibitörü', en: 'ACE inhibitor', fa: 'مهارکنندهٔ ACE', ar: 'مثبط ACE' } ,
  atoms: {
    S: [34, 160, 'S', 'HS'], C1: [72, 138, 'C'], C2: [110, 160, 'C'], Me: [110, 204, 'C'], C3: [148, 138, 'C'], O3: [148, 94, 'O', 'O'],
    N: [186, 160, 'N', 'N'], Ca: [218, 138, 'C'], Cb: [250, 162, 'C'], Cc: [238, 198, 'C'], Cd: [198, 198, 'C'], Cx: [218, 96, 'C'],
    Ox1: [254, 78, 'O', 'O'], Ox2: [184, 78, 'O', 'OH'],
  },
  // [from, to, double?, side of the second line]
  bonds: [
    ['S', 'C1'], ['C1', 'C2'], ['C2', 'Me'], ['C2', 'C3'], ['C3', 'O3', 2, 1], ['C3', 'N'], ['N', 'Ca'], ['Ca', 'Cb'], ['Cb', 'Cc'],
    ['Cc', 'Cd'], ['Cd', 'N'], ['Ca', 'Cx'], ['Cx', 'Ox1', 2, -1], ['Cx', 'Ox2'],
  ],
  groups: [
    {
      id: 'thiol',
      name: { tr: 'Tiyol (–SH)', en: 'Thiol (–SH)', fa: 'تیول (–SH)', ar: 'ثيول (–SH)' },
      atoms: ['S'],
      bonds: [['S', 'C1']],
      note: {
        tr: "ACE'nin aktif bölgesindeki çinkoya bağlanır. Kaptoprile özgü tat bozukluğu ve döküntü bu gruptan kaynaklanır.",
        en: "Binds the zinc in ACE's active site. Captopril's typical taste disturbance and rash come from this group.",
        fa: 'به روی جایگاه فعال ACE متصل می‌شود. اختلال چشایی و بثورات ویژهٔ کاپتوپریل از همین گروه است.',
        ar: 'يرتبط بالزنك في الموقع النشط لإنزيم ACE. اضطراب التذوق والطفح الخاصان بالكابتوبريل ينتجان عن هذه المجموعة.',
      },
    },
    {
      id: 'proline',
      name: { tr: 'Prolin + karboksil', en: 'Proline + carboxyl', fa: 'پرولین + کربوکسیل', ar: 'برولين + كربوكسيل' },
      atoms: ['N', 'Ca', 'Cb', 'Cc', 'Cd', 'Cx', 'Ox1', 'Ox2'],
      bonds: [['N', 'Ca'], ['Ca', 'Cb'], ['Cb', 'Cc'], ['Cc', 'Cd'], ['Cd', 'N'], ['Ca', 'Cx'], ['Cx', 'Ox1'], ['Cx', 'Ox2']],
      note: {
        tr: "Enzimin bağlandığı peptit ucunu taklit eder; ilacın ACE'ye oturmasını sağlar.",
        en: 'Mimics the peptide end the enzyme binds to, so the drug fits into ACE.',
        fa: 'انتهای پپتیدی را که آنزیم به آن متصل می‌شود تقلید می‌کند تا دارو در ACE جا بیفتد.',
        ar: 'يحاكي طرف الببتيد الذي يرتبط به الإنزيم، فيستقر الدواء في ACE.',
      },
    },
    {
      id: 'amide',
      name: { tr: 'Amit (C=O)', en: 'Amide (C=O)', fa: 'آمید (C=O)', ar: 'أميد (C=O)' },
      atoms: ['C3', 'O3', 'N'],
      bonds: [['C3', 'O3'], ['C3', 'N']],
      note: {
        tr: 'Enzimle hidrojen bağı kurar; prolin halkasını yan zincire bağlar.',
        en: 'Forms a hydrogen bond with the enzyme and links the proline ring to the side chain.',
        fa: 'با آنزیم پیوند هیدروژنی می‌سازد و حلقهٔ پرولین را به زنجیرهٔ جانبی وصل می‌کند.',
        ar: 'يكوّن رابطة هيدروجينية مع الإنزيم ويربط حلقة البرولين بالسلسلة الجانبية.',
      },
    },
  ],
};


const mw2 = (n: string): L => ({ tr: n.replace('.', ',') + ' g/mol', en: n + ' g/mol', fa: n + ' g/mol', ar: n + ' g/mol' });

const PARACETAMOL: Molecule = {
  id: 'paracetamol',
  match: /parasetamol|paracetamol|acetaminophen|پاراستامول|استامینوفن|باراسيتامول|أسيتامينوفين/i,
  name: { tr: 'Parasetamol', en: 'Paracetamol', fa: 'پاراستامول', ar: 'باراسيتامول' },
  formula: 'C8H9NO2',
  mw: mw2('151.2'),
  cls: { tr: 'Analjezik / antipiretik', en: 'Analgesic / antipyretic', fa: 'مسکن / تب‌بر', ar: 'مسكّن / خافض للحرارة' },
  atoms: {
    v0: [186, 150, 'C'], v1: [168, 181, 'C'], v2: [132, 181, 'C'], v3: [114, 150, 'C'], v4: [132, 119, 'C'], v5: [168, 119, 'C'],
    O: [72, 150, 'O', 'HO'], N: [224, 150, 'N', 'NH'], Cam: [256, 128, 'C'], Oam: [256, 86, 'O', 'O'], Me: [288, 150, 'C'],
  },
  bonds: [
    ['v0', 'v1', 2, 0], ['v1', 'v2'], ['v2', 'v3', 2, 0], ['v3', 'v4'], ['v4', 'v5', 2, 0], ['v5', 'v0'], ['v3', 'O'], ['v0', 'N'],
    ['N', 'Cam'], ['Cam', 'Oam', 2, 1], ['Cam', 'Me'],
  ],
  center: [150, 150],
  groups: [
    {
      id: 'phenol',
      name: { tr: 'Fenolik –OH', en: 'Phenolic –OH', fa: 'هیدروکسیل فنولی (–OH)', ar: 'هيدروكسيل فينولي (–OH)' },
      atoms: ['O'],
      bonds: [['v3', 'O']],
      note: {
        tr: 'Karaciğerde glukuronid ve sülfatla bağlanıp güvenli yoldan atılır.',
        en: 'Conjugated with glucuronide and sulfate in the liver and cleared by the safe route.',
        fa: 'در کبد با گلوکورونید و سولفات متصل شده و از مسیر ایمن دفع می‌شود.',
        ar: 'يرتبط في الكبد بالغلوكورونيد والكبريتات ويُطرح بالمسار الآمن.',
      },
    },
    {
      id: 'acetamide',
      name: { tr: 'Asetamid', en: 'Acetamide', fa: 'استامید', ar: 'أسيتاميد' },
      atoms: ['N', 'Cam', 'Oam', 'Me'],
      bonds: [['v0', 'N'], ['N', 'Cam'], ['Cam', 'Oam'], ['Cam', 'Me']],
      note: {
        tr: "Az bir kısmı CYP2E1 ile toksik NAPQI'ye döner. Glutatyon bitince karaciğer hasarı olur; antidot N-asetilsistein.",
        en: 'A small part is turned into toxic NAPQI by CYP2E1. When glutathione runs out the liver is damaged; the antidote is N-acetylcysteine.',
        fa: 'بخش کمی توسط CYP2E1 به NAPQI سمی تبدیل می‌شود. با تمام شدن گلوتاتیون کبد آسیب می‌بیند؛ پادزهر N-استیل‌سیستئین است.',
        ar: 'يتحول جزء صغير بواسطة CYP2E1 إلى NAPQI السام. عند نفاد الغلوتاثيون يتضرر الكبد؛ والترياق هو N-أسيتيل سيستئين.',
      },
    },
    {
      id: 'ring',
      name: { tr: 'Benzen halkası', en: 'Benzene ring', fa: 'حلقهٔ بنزن', ar: 'حلقة البنزين' },
      atoms: ['v0', 'v1', 'v2', 'v3', 'v4', 'v5'],
      bonds: [['v0', 'v1'], ['v1', 'v2'], ['v2', 'v3'], ['v3', 'v4'], ['v4', 'v5'], ['v5', 'v0']],
      note: {
        tr: 'p-Aminofenol iskeleti; iki grubu karşılıklı (para) konumda taşır.',
        en: 'The p-aminophenol skeleton; it carries the two groups opposite each other (para).',
        fa: 'اسکلت پارا-آمینوفنول؛ دو گروه را در موقعیت مقابل (پارا) دارد.',
        ar: 'هيكل بارا-أمينوفينول؛ يحمل المجموعتين في موضع متقابل (بارا).',
      },
    },
  ],
};

export const MOLECULES: Record<MoleculeId, Molecule> = { captopril: CAPTOPRIL, paracetamol: PARACETAMOL };

/** The molecules a page text talks about, if we have their structures. */
export function findMolecules(text: string): Molecule[] {
  return Object.values(MOLECULES).filter((m) => m.match.test(text));
}
