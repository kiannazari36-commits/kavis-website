import { useState } from 'react';
import { useI18n, type Lang } from '../i18n/I18nProvider';
import { dirOf } from '../settings/SettingsProvider';
import Icon from './Icon';
import s from './MolViewer.module.css';

// Port of design/MolViewer.dc.html (captopril). Coordinates are in a 300×300 box.
// The design has Turkish labels only; the other languages were added for the web.
type L = Record<Lang, string>;
type Group = { id: string; name: L; atoms: string[]; bonds: [string, string][]; note: L };

const CAPTOPRIL = {
  name: { tr: 'Kaptopril', en: 'Captopril', fa: 'کاپتوپریل', ar: 'كابتوبريل' } as L,
  formula: 'C9H15NO3S',
  mw: { tr: '217,3 g/mol', en: '217.3 g/mol', fa: '217.3 g/mol', ar: '217.3 g/mol' } as L,
  cls: { tr: 'ACE inhibitörü', en: 'ACE inhibitor', fa: 'مهارکنندهٔ ACE', ar: 'مثبط ACE' } as L,
  atoms: {
    S: [34, 160, 'S', 'HS'], C1: [72, 138, 'C'], C2: [110, 160, 'C'], Me: [110, 204, 'C'], C3: [148, 138, 'C'], O3: [148, 94, 'O', 'O'],
    N: [186, 160, 'N', 'N'], Ca: [218, 138, 'C'], Cb: [250, 162, 'C'], Cc: [238, 198, 'C'], Cd: [198, 198, 'C'], Cx: [218, 96, 'C'],
    Ox1: [254, 78, 'O', 'O'], Ox2: [184, 78, 'O', 'OH'],
  } as Record<string, [number, number, string, string?]>,
  // [from, to, double?, side of the second line]
  bonds: [
    ['S', 'C1'], ['C1', 'C2'], ['C2', 'Me'], ['C2', 'C3'], ['C3', 'O3', 2, 1], ['C3', 'N'], ['N', 'Ca'], ['Ca', 'Cb'], ['Cb', 'Cc'],
    ['Cc', 'Cd'], ['Cd', 'N'], ['Ca', 'Cx'], ['Cx', 'Ox1', 2, -1], ['Cx', 'Ox2'],
  ] as [string, string, number?, number?][],
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
  ] as Group[],
};

const EL: Record<string, string> = { O: '#C0352B', N: '#2F5E9C', S: '#C99A12', C: '#6E645A' };
const f = (n: number) => n.toFixed(1);

// Names and notes follow `contentLang` (the course content language); buttons follow the app language.
export default function MolViewer({ size = 'full', mark = '', contentLang }: { size?: 'full' | 'mini'; mark?: string; contentLang?: Lang }) {
  const { t, lang: appLang } = useI18n();
  const lang = contentLang ?? appLang;
  const m = CAPTOPRIL;
  const full = size === 'full';
  const [deg, setDeg] = useState(0);
  const [ball, setBall] = useState(false);
  const [sel, setSel] = useState(mark);

  const rad = (deg * Math.PI) / 180;
  const cs = Math.cos(rad);
  const sn = Math.sin(rad);
  const P: Record<string, [number, number]> = {};
  for (const [k, a] of Object.entries(m.atoms)) {
    const x = a[0] - 150;
    const y = a[1] - 150;
    P[k] = [150 + x * cs - y * sn, 150 + x * sn + y * cs];
  }

  let bonds = '';
  for (const [a0, z0, dbl, side] of m.bonds) {
    const a = P[a0];
    const z = P[z0];
    bonds += `M${f(a[0])} ${f(a[1])} L${f(z[0])} ${f(z[1])} `;
    if (dbl === 2 && !ball) {
      const dx = z[0] - a[0];
      const dy = z[1] - a[1];
      const len = Math.hypot(dx, dy);
      const o = 7 * (side || 1);
      const nx = (-dy / len) * o;
      const ny = (dx / len) * o;
      bonds += `M${f(a[0] + nx)} ${f(a[1] + ny)} L${f(z[0] + nx)} ${f(z[1] + ny)} `;
    }
  }

  const grp = m.groups.find((g) => g.id === sel);
  const hl = grp ? grp.bonds.map(([a0, z0]) => `M${f(P[a0][0])} ${f(P[a0][1])} L${f(P[z0][0])} ${f(P[z0][1])}`).join(' ') : '';
  const S = full ? 240 : 170;
  const k = S / 300;

  return (
    <div className={s.wrap}>
      {full && (
        <div className={s.head}>
          <b>{m.name[lang]}</b>
          <span className="mono">
            {m.formula} · {m.mw[lang]}
          </span>
          <span>{m.cls[lang]}</span>
        </div>
      )}
      <div className={s.body}>
        <div role="img" aria-label={m.name[lang] + t('molAria') + (grp ? ` · ${grp.name[lang]}` : '')} className={s.canvas} style={{ width: S, height: S }}>
          <svg aria-hidden="true" width={S} height={S} viewBox="0 0 300 300">
            {hl && <path d={hl} stroke="#F2B33D" strokeWidth={16} strokeLinecap="round" strokeLinejoin="round" fill="none" strokeOpacity={0.55} />}
            <path d={bonds} className={s.bond} strokeWidth={ball ? 7 : 3} strokeLinecap="round" fill="none" />
          </svg>
          {Object.entries(m.atoms).map(([key, a]) => {
            const [x, y] = P[key];
            const inG = !!grp?.atoms.includes(key);
            if (ball) {
              const r = a[2] === 'C' ? 16 : 22;
              const d = Math.round(r * k * 1.4);
              return (
                <span
                  key={key}
                  className={s.ball}
                  style={{
                    left: x * k,
                    top: y * k,
                    width: d,
                    height: d,
                    background: `radial-gradient(circle at 35% 30%, rgba(255,255,255,.55), ${EL[a[2]]} 60%)`,
                    border: inG ? '2px solid #F2B33D' : 0,
                    fontSize: Math.max(8, Math.round(11 * k * 1.3)),
                    color: a[2] === 'S' ? '#2A2420' : '#FFFCF6',
                  }}
                >
                  {a[2] === 'C' ? '' : a[2]}
                </span>
              );
            }
            if (!a[3]) return null;
            return (
              <span
                key={key}
                className={inG ? `${s.label} ${s.labelOn}` : s.label}
                style={{
                  left: x * k,
                  top: y * k,
                  height: Math.round(26 * k * 1.25),
                  minWidth: Math.round(26 * k * 1.25),
                  fontSize: Math.max(9, Math.round(19 * k * 1.15)),
                  color: a[2] === 'S' ? 'var(--mol-s)' : EL[a[2]],
                }}
              >
                {a[3]}
              </span>
            );
          })}
        </div>
        {full && (
          <div className={s.tools}>
            <div role="radiogroup" className={s.seg}>
              <button role="radio" aria-checked={!ball} className={!ball ? s.segOn : ''} onClick={() => setBall(false)}>
                {t('molLine')}
              </button>
              <button role="radio" aria-checked={ball} className={ball ? s.segOn : ''} onClick={() => setBall(true)}>
                {t('molBall')}
              </button>
            </div>
            <button className={s.rotate} onClick={() => setDeg((deg + 90) % 360)}>
              <Icon name="rotate" size={14} width={2} />
              {t('molRotate')} · {deg}°
            </button>
            <span className={s.hint}>{t('molTap')}</span>
            <div className={s.groups} lang={lang} dir={dirOf(lang)}>
              {m.groups.map((g) => (
                <button key={g.id} aria-pressed={g.id === sel} className={g.id === sel ? s.groupOn : ''} onClick={() => setSel(g.id === sel ? '' : g.id)}>
                  {g.name[lang]}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
      {full && grp && (
        <div className={s.note} lang={lang} dir={dirOf(lang)}>
          <b>{grp.name[lang]}:</b> {grp.note[lang]}
        </div>
      )}
    </div>
  );
}
