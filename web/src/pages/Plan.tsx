import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { dateRange, dayDate, dayShort, duration, hoursLabel, num, weekdayName } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import { addDays, getWeekPlan, rescheduleMissed, setTaskDone, taskLink, type PlanTask } from '../api/plan';
import { isoToday, listCourses } from '../api/courses';
import { useAsync } from '../hooks/useAsync';
import { useSettings } from '../settings/SettingsProvider';
import { COURSE_COLOR } from '../components/courseColors';
import s from './Plan.module.css';

// Design: design/NewIPad.dc.html, screen "plan" ("Ders planım"): Kavis plan / own plan / no plan.
// The Kavis plan is made by the server; here the student ticks tasks off and moves missed ones.

const DAY_KEYS = ['dMon', 'dTue', 'dWed', 'dThu', 'dFri', 'dSat', 'dSun'];
const REASON_COLOR = { pri: 'var(--pri)', amb: 'var(--amb-t)', good: 'var(--good)' };

export default function Plan() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const { settings, patch } = useSettings();
  const [menu, setMenu] = useState(false);
  const [short, setShort] = useState(false);
  const [own, setOwn] = useState<Record<number, string[]>>({});
  const [reload, setReload] = useState(0);
  const plan = useAsync(getWeekPlan, [reload]);
  const courses = useAsync(listCourses, []) ?? [];
  // Ticks are shown at once and saved in the background.
  const [ticks, setTicks] = useState<Record<string, boolean>>({});

  const mode = settings.planMode;
  const nDays = Math.max(1, Math.min(7, settings.studyDays));
  const hLabel = hoursLabel(settings.studyHours, lang, t);
  const today = isoToday();
  const weekStart = plan?.weekStart ?? today;
  const days = DAY_KEYS.map((_, i) => addDays(weekStart, i));
  const isDone = (x: PlanTask) => ticks[x.id] ?? x.status === 'done';

  const setMode = (m: typeof mode) => {
    patch({ planMode: m });
    setMenu(false);
    toast(t(m === 'aim' ? 'toastAim' : m === 'own' ? 'toastOwn' : 'toastNone'));
  };

  // Color and label of a task: the course's, amber for review, bordo for exam prep.
  const look = (x: PlanTask): [string, string, string] => {
    if (x.kind === 'exam_prep') return ['var(--pri-t)', 'var(--pri-soft)', t('planLabelExam')];
    const c = courses.find((y) => y.id === x.courseId);
    if (x.kind === 'review' || x.kind === 'cards' || x.kind === 'mistakes' || !c) return ['var(--amb-t)', 'var(--amb-soft)', t('planLabelReview')];
    const col = COURSE_COLOR[c.color];
    return [col.fg, col.soft, c.short ?? c.name];
  };

  const card = (x: PlanTask) => {
    const [fg, bg, label] = look(x);
    return (
      <button
        key={x.id}
        className={s.task}
        style={{ borderInlineStartColor: fg, background: bg, opacity: isDone(x) ? 0.55 : 1 }}
        onClick={() => navigate(taskLink(x))}
      >
        <span style={{ color: fg }}>
          {label} · {duration(x.minutes, lang)}
        </span>
        <b>{x.title}</b>
        <span className={s.why}>{x.why}</span>
      </button>
    );
  };

  let todayTasks = plan?.tasks.filter((x) => x.day === today) ?? [];
  // "I have little time today": the two first tasks, half as long (shown only; the server's light-day plan comes later).
  if (short) todayTasks = todayTasks.slice(0, 2).map((x) => ({ ...x, minutes: Math.max(5, Math.round(x.minutes / 10) * 5) }));
  const todayMin = todayTasks.reduce((a, x) => a + x.minutes, 0);

  const tick = (x: PlanTask) => {
    const on = !isDone(x);
    setTicks({ ...ticks, [x.id]: on });
    setTaskDone(x.id, on);
    if (on) toast(t('wellDone') + x.title + t('completed'));
  };

  const missed = async () => {
    if (!plan) return;
    const moved = await rescheduleMissed(plan);
    if (!moved.length) return toast(t('noMissed'));
    const names = [...new Set(moved)].map((d) => weekdayName(d, lang)).join(', ');
    toast(t('toastMissedN').replace('{n}', num(moved.length, lang)).replace('{days}', names));
    setReload(reload + 1);
  };

  const factors: [string, string][] = [
    [t('perWeekA') + num(nDays, lang) + t('perWeekB') + hLabel + t('perWeekC'), 'var(--amb-t)'],
    ...(plan?.reasons ?? []).map((r): [string, string] => [r.text, REASON_COLOR[r.color] ?? 'var(--pri)']),
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
          <button className={s.school} onClick={() => navigate('/schedule')}>
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

      {mode === 'aim' && plan === null && (
        <section className={s.none}>
          <Icon name="calendar" size={40} width={1.5} />
          <p>{t('noPlan')}</p>
        </section>
      )}

      {mode === 'aim' && plan && (
        <>
          <div className={s.stages}>
            {(
              [
                ['basic', '1', 'stageBasic', 'stageBasicS'],
                ['smart', '2', 'stageSmart', 'stageSmartS'],
              ] as const
            ).map(([id, n, title, sub]) => (
              // The stage is the server's: the first 2 weeks are basic, then the plan becomes smart.
              <button key={id} aria-pressed={plan.stage === id} className={plan.stage === id ? `${s.stage} ${s.stageOn}` : s.stage} onClick={() => toast(t(sub))}>
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
                  {t('thisWeek')} <span>· {dateRange(days[0], days[6], lang)}</span>
                </h2>
                <span>{num(nDays, lang) + t('daysTimes') + hLabel}</span>
              </div>
              {days.map((d, i) => {
                const tasks = plan.tasks.filter((x) => x.day === d);
                return (
                  <div key={d} className={s.day}>
                    <span className={s.dayName}>
                      <b className={d === today ? s.todayName : ''}>{t(DAY_KEYS[i])}</b>
                      <span className="mono">{d === today ? t('today') : dayShort(d, lang)}</span>
                    </span>
                    {tasks.length ? <div className={s.tasks}>{tasks.map(card)}</div> : <span className={s.rest}>{t('restDay')}</span>}
                  </div>
                );
              })}
            </section>

            <div className={s.side}>
              <section className={s.today}>
                <div className={s.secHead}>
                  <h2>{t('todayPlan')}</h2>
                  <span>{`${dayDate(today, lang)} · ${duration(todayMin, lang)}`}</span>
                </div>
                {todayTasks.length === 0 && <span className={s.rest}>{t('restDay')}</span>}
                {todayTasks.map((x) => {
                  const [fg, , label] = look(x);
                  const done = isDone(x);
                  return (
                    <div key={x.id} className={s.todayRow}>
                      <button role="checkbox" aria-checked={done} aria-label={x.title} className={done ? `${s.chk} ${s.chkOn}` : s.chk} onClick={() => tick(x)}>
                        {done && <Icon name="check" size={14} width={2.6} />}
                      </button>
                      <span className={s.todayText} style={{ opacity: done ? 0.55 : 1 }}>
                        <b>{x.title}</b>
                        <span>
                          {label} · {duration(x.minutes, lang)} · <span style={{ color: fg }}>{x.why}</span>
                        </span>
                      </span>
                      <button className={s.go} onClick={() => navigate(taskLink(x))}>
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
                    toast(t(short ? 'toastShortOff' : 'toastShortOn'));
                  }}
                >
                  {t(short ? 'shortOff' : 'shortOn')}
                </button>
              </section>

              <section className={s.missed}>
                <b>{t('missedTitle')}</b>
                <span>{t('missedText')}</span>
                <button onClick={missed}>{t('missedBtn')}</button>
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
                    const c = courses.find((x) => x.id === id);
                    const col = COURSE_COLOR[c?.color ?? 'red'];
                    return (
                      <span key={j} className={s.ownItem} style={{ borderInlineStartColor: col.fg, background: col.soft }}>
                        {(c?.short ?? c?.name ?? '') + t('min45')}
                      </span>
                    );
                  })}
                  {/* Own plan: not saved yet (needs a place in the database). */}
                  <button
                    className={s.addOwn}
                    onClick={() => courses.length && setOwn({ ...own, [i]: [...(own[i] ?? []), courses[(own[i] ?? []).length % courses.length].id] })}
                  >
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
