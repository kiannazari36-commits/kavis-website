import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { duration, hoursLabel, num } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import { getWeekPlan, rescheduleMissed, type PlanStage } from '../api/plan';
import { useAsync } from '../hooks/useAsync';
import { useSettings } from '../settings/SettingsProvider';
import type { PlanItem } from '../api/types';
import s from './Plan.module.css';

// Design: design/NewIPad.dc.html, screen "plan" ("Ders planım"): Kavis plan / own plan / no plan.

const DAY_KEYS = ['dMon', 'dTue', 'dWed', 'dThu', 'dFri', 'dSat', 'dSun'];
const FIRST_DATE = 12; // Monday 12 October in the mock
// Which weekdays get study first when the student studies fewer than 7 days.
const ORDER = [0, 1, 3, 5, 2, 6, 4];
// Task colors: course color, amber for review, bordo for exam prep.
const KIND_COLOR: Record<string, [string, string]> = {
  pharmacotherapy: ['var(--pri-t)', 'var(--pri-soft)'],
  toxicology: ['var(--good)', 'var(--good-soft)'],
  'pharm-tech-3': ['var(--vio)', 'var(--vio-soft)'],
  review: ['var(--amb-t)', 'var(--amb-soft)'],
  exam: ['var(--pri-t)', 'var(--pri-soft)'],
};
const OWN_COURSES = ['pharmacotherapy', 'toxicology', 'pharm-tech-3'];

export default function Plan() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const { settings, patch } = useSettings();
  const [stage, setStage] = useState<PlanStage>('smart');
  const [menu, setMenu] = useState(false);
  const [done, setDone] = useState<Record<number, boolean>>({});
  const [short, setShort] = useState(false);
  const [own, setOwn] = useState<Record<number, string[]>>({});
  const week = useAsync(() => getWeekPlan(stage), [stage]);

  const mode = settings.planMode;
  const nDays = Math.max(1, Math.min(7, settings.studyDays));
  const studyIdx = ORDER.slice(0, nDays);
  const scale = settings.studyHours / 1.5;
  const mins = (m: number) => Math.max(5, Math.round((m * scale) / 5) * 5);
  const hLabel = hoursLabel(settings.studyHours, lang, t);

  const setMode = (m: typeof mode) => {
    patch({ planMode: m });
    setMenu(false);
    toast(t(m === 'aim' ? 'toastAim' : m === 'own' ? 'toastOwn' : 'toastNone'));
  };

  const card = (it: PlanItem, key: string | number) => {
    const [fg, bg] = KIND_COLOR[it.kind] ?? KIND_COLOR.review;
    return (
      <button key={key} className={s.task} style={{ borderInlineStartColor: fg, background: bg }} onClick={() => navigate(it.to === 'quiz' ? '/quiz' : '/reader')}>
        <span style={{ color: fg }}>
          {it.label[lang]} · {duration(mins(it.minutes), lang)}
        </span>
        <b>{it.title[lang]}</b>
        <span className={s.why}>{it.why[lang]}</span>
      </button>
    );
  };

  let todayRaw = week ? (studyIdx.includes(0) ? week[0] : week[studyIdx[0]]) : [];
  if (short) todayRaw = todayRaw.slice(0, 2).map((x) => ({ ...x, minutes: Math.round(x.minutes / 2) }));
  const todayMin = todayRaw.reduce((a, x) => a + mins(x.minutes), 0);

  const factors: [string, string][] =
    stage === 'basic'
      ? [
          [t('perWeekA') + num(nDays, lang) + t('perWeekB') + hLabel + t('perWeekC'), 'var(--amb-t)'],
          [t('fEqual'), 'var(--pri)'],
          [t('fNew'), 'var(--amb-t)'],
          [t('fLater'), 'var(--good)'],
        ]
      : [
          [t('perWeekA') + num(nDays, lang) + t('perWeekB') + hLabel + t('perWeekC'), 'var(--amb-t)'],
          [t('fExam'), 'var(--pri)'],
          [t('fWeak'), 'var(--pri)'],
          [t('fTeacher'), 'var(--amb-t)'],
          [t('fRepeat'), 'var(--good)'],
        ];

  return (
    <main className={s.main}>
      <div className={s.head}>
        <h1>
          {t('planA')} <span>{t('planB')}</span>
        </h1>
        <div className={s.headBtns}>
          <button className={s.modeBtn} aria-haspopup="menu" aria-expanded={menu} onClick={() => setMenu(!menu)}>
            {t(mode === 'own' ? 'modeOwn' : mode === 'none' ? 'modeNone' : 'modeAim')}
            <span className={menu ? `${s.chev} ${s.chevUp}` : s.chev}>
              <Icon name="chevron" size={16} />
            </span>
          </button>
          <button className={s.school} onClick={() => toast(t('k165'))}>
            <Icon name="calendar" size={18} />
            {t('schoolSchedule')}
          </button>
          {menu && (
            <div role="menu" className={s.menu}>
              {(['aim', 'own', 'none'] as const).map((m) => {
                const key = m === 'aim' ? 'modeAim' : m === 'own' ? 'modeOwn' : 'modeNone';
                return (
                  <button key={m} role="menuitemradio" aria-checked={mode === m} className={mode === m ? s.menuOn : ''} onClick={() => setMode(m)}>
                    <span className={s.menuText}>
                      <b>{t(key)}</b>
                      <span>{t(key + 'S')}</span>
                    </span>
                    <span className={s.menuChk}>{mode === m && <Icon name="check" size={13} width={2.6} />}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {mode === 'aim' && (
        <>
          <div className={s.stages}>
            {(
              [
                ['basic', '1', 'stageBasic', 'stageBasicS'],
                ['smart', '2', 'stageSmart', 'stageSmartS'],
              ] as const
            ).map(([id, n, title, sub]) => (
              <button
                key={id}
                aria-pressed={stage === id}
                className={stage === id ? `${s.stage} ${s.stageOn}` : s.stage}
                onClick={() => (setStage(id), setDone({}), setShort(false))}
              >
                <span className={s.stageNo}>{num(n, lang)}</span>
                <span className={s.stageText}>
                  <b>{t(title)}</b>
                  <span>{t(sub)}</span>
                </span>
              </button>
            ))}
          </div>

          <div className={s.grid}>
            <section className={s.week}>
              <div className={s.secHead}>
                <h2>
                  {t('thisWeek')} <span>{t('weekSub')}</span>
                </h2>
                <span>{num(nDays, lang) + t('daysTimes') + hLabel}</span>
              </div>
              {DAY_KEYS.map((d, i) => {
                const on = studyIdx.includes(i);
                return (
                  <div key={d} className={s.day}>
                    <span className={s.dayName}>
                      <b className={i === 0 ? s.todayName : ''}>{t(d)}</b>
                      <span className="mono">{i === 0 ? t('today') : num(FIRST_DATE + i, lang) + t('oct')}</span>
                    </span>
                    {on ? <div className={s.tasks}>{week?.[i].map(card)}</div> : <span className={s.rest}>{t('restDay')}</span>}
                  </div>
                );
              })}
            </section>

            <div className={s.side}>
              <section className={s.today}>
                <div className={s.secHead}>
                  <h2>{t('todayPlan')}</h2>
                  <span>{t('todayDate') + duration(todayMin, lang)}</span>
                </div>
                {todayRaw.map((it, i) => {
                  const [fg] = KIND_COLOR[it.kind] ?? KIND_COLOR.review;
                  return (
                    <div key={i} className={s.todayRow}>
                      <button
                        role="checkbox"
                        aria-checked={!!done[i]}
                        aria-label={it.title[lang]}
                        className={done[i] ? `${s.chk} ${s.chkOn}` : s.chk}
                        onClick={() => {
                          setDone({ ...done, [i]: !done[i] });
                          if (!done[i]) toast(t('wellDone') + it.title[lang] + t('completed'));
                        }}
                      >
                        {done[i] && <Icon name="check" size={14} width={2.6} />}
                      </button>
                      <span className={s.todayText} style={{ opacity: done[i] ? 0.55 : 1 }}>
                        <b>{it.title[lang]}</b>
                        <span>
                          {it.label[lang]} · {duration(mins(it.minutes), lang)} · <span style={{ color: fg }}>{it.why[lang]}</span>
                        </span>
                      </span>
                      <button className={s.go} onClick={() => navigate(it.to === 'quiz' ? '/quiz' : '/reader')}>
                        {t('start')}
                      </button>
                    </div>
                  );
                })}
                <button
                  aria-pressed={short}
                  className={short ? `${s.short} ${s.shortOn}` : s.short}
                  onClick={() => {
                    setShort(!short);
                    setDone({});
                    toast(t(short ? 'toastShortOff' : 'toastShortOn'));
                  }}
                >
                  {t(short ? 'shortOff' : 'shortOn')}
                </button>
              </section>

              <section className={s.missed}>
                <b>{t('missedTitle')}</b>
                <span>{t('missedText')}</span>
                <button onClick={() => rescheduleMissed().then(() => toast(t('toastMissed')))}>{t('missedBtn')}</button>
              </section>

              <section className={s.factors}>
                <b>{t('planWhy')}</b>
                {factors.map(([text, color]) => (
                  <span key={text}>
                    <span className={s.dot} style={{ background: color }} />
                    {text}
                  </span>
                ))}
              </section>
            </div>
          </div>
        </>
      )}

      {mode === 'own' && (
        <>
          <section className={s.week}>
            <div className={s.secHead}>
              <h2>
                {t('ownTitle')} <span>{t('weekSub')}</span>
              </h2>
              <span>{t('ownHint')}</span>
            </div>
            {DAY_KEYS.map((d, i) => (
              <div key={d} className={s.day}>
                <span className={s.dayName}>
                  <b>{t(d)}</b>
                </span>
                <div className={s.tasks}>
                  {(own[i] ?? []).map((id, j) => {
                    const [fg, bg] = KIND_COLOR[id];
                    const label = { pharmacotherapy: 'k53', toxicology: 'k54', 'pharm-tech-3': 'k55' }[id] ?? id;
                    return (
                      <span key={j} className={s.ownItem} style={{ borderInlineStartColor: fg, background: bg }}>
                        {t(label) + t('min45')}
                      </span>
                    );
                  })}
                  <button className={s.addOwn} onClick={() => setOwn({ ...own, [i]: [...(own[i] ?? []), OWN_COURSES[(own[i] ?? []).length % 3]] })}>
                    {t('addCourseShort')}
                  </button>
                </div>
              </div>
            ))}
          </section>
          <button className={s.toAim} onClick={() => setMode('aim')}>
            {t('backToAim')}
          </button>
        </>
      )}

      {mode === 'none' && (
        <section className={s.none}>
          <Icon name="calendar" size={40} width={1.5} />
          <h2>{t('noneTitle')}</h2>
          <p>{t('noneText')}</p>
          <button onClick={() => setMode('aim')}>{t('noneBtn')}</button>
        </section>
      )}
    </main>
  );
}
