import { useRef, useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num, weekdayName } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon, { type IconName } from '../components/Icon';
import Switch from '../components/Switch';
import { addClass, deleteClass, listClasses, readTimetable, setClassRemind, type ClassEntry, type FoundClass } from '../api/timetable';
import Thinking from '../components/Thinking';
import { addDays } from '../api/plan';
import { isoToday, listCourses } from '../api/courses';
import { useAsync } from '../hooks/useAsync';
import { useSettings } from '../settings/SettingsProvider';
import { COURSE_COLOR } from '../components/courseColors';
import s from './Schedule.module.css';

// Design: design/NewSchedule.dc.html ("Okul ders programım"): empty state with 3 ways to add, day tabs with
// each day's classes and a reminder bell, reminder settings and a notification preview.
// A photo or PDF of the timetable is read by the server (Edge Function import-timetable); the student sees the
// classes it found, unticks wrong ones and adds the rest.

const DAY_KEYS = ['dMon', 'dTue', 'dWed', 'dThu', 'dFri', 'dSat', 'dSun'];
const TIMES = ['19:00', '20:00', '21:00', '22:00'];
// A known Monday, to get weekday names from the browser.
const MONDAY = '2026-10-19';
const weekdayOf = (iso: string) => ((new Date(`${iso}T12:00:00`).getDay() + 6) % 7) + 1;

export default function Schedule() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const { settings, patch } = useSettings();
  const [reload, setReload] = useState(0);
  const loaded = useAsync(listClasses, [reload]);
  const courses = useAsync(listCourses, []) ?? [];
  const [bells, setBells] = useState<Record<string, boolean>>({});
  const [adding, setAdding] = useState(false);
  const [manual, setManual] = useState(false);
  // Reading a photo / PDF: the classes found, and which of them stay ticked.
  const photoIn = useRef<HTMLInputElement>(null);
  const fileIn = useRef<HTMLInputElement>(null);
  const [reading, setReading] = useState(false);
  const [found, setFound] = useState<(FoundClass & { on: boolean })[] | null>(null);
  const [saving, setSaving] = useState(false);

  const today = weekdayOf(isoToday());
  const tomorrow = (today % 7) + 1;
  const [day, setDay] = useState(tomorrow);

  if (!loaded) return <main className={s.main} />;

  const classes = loaded.map((c) => ({ ...c, remind: bells[c.id] ?? c.remind }));
  const dayName = (wd: number) => weekdayName(addDays(MONDAY, wd - 1), lang);
  // Monday–Friday always; the weekend only when it has classes.
  const days = [1, 2, 3, 4, 5, 6, 7].filter((wd) => wd <= 5 || classes.some((c) => c.weekday === wd));
  const ofDay = (wd: number) => classes.filter((c) => c.weekday === wd);
  const tmr = ofDay(tomorrow).filter((c) => c.remind);
  const colorOf = (c: ClassEntry) => {
    const course = courses.find((x) => x.id === c.courseId) ?? courses.find((x) => c.title.startsWith(x.name));
    return course ? COURSE_COLOR[course.color] : { soft: 'var(--sub)', fg: 'var(--text2)', main: 'var(--text2)' };
  };
  const notifTitle = tmr.length ? t('schNotifN').replace('{n}', num(tmr.length, lang)) : t('schNotifNone');

  const toggleBell = (c: ClassEntry) => {
    setBells({ ...bells, [c.id]: !c.remind });
    setClassRemind(c.id, !c.remind);
    toast(c.title + t(c.remind ? 'schOff' : 'schOn'));
  };
  const toggle = (key: 'classRemindDayBefore' | 'classRemindFirst' | 'classPrepTip', label: string) => {
    patch({ [key]: !settings[key] });
    toast(label + t(settings[key] ? 'schClosed' : 'schOpened'));
  };
  // "Send a sample notification": a real browser notification when allowed, otherwise a toast.
  const test = async () => {
    if (!settings.classRemindDayBefore) return toast(t('schNeedOn'));
    const body = tmr.map((c) => `${c.start} ${c.title}${c.room ? ` · ${c.room}` : ''}`).join('\n');
    if ('Notification' in window) {
      const perm = Notification.permission === 'default' ? await Notification.requestPermission() : Notification.permission;
      if (perm === 'granted') {
        new Notification(notifTitle, { body, icon: '/icon_star.png' });
        return;
      }
    }
    toast(`${notifTitle}${body ? ' · ' + body.replace(/\n/g, ' · ') : ''}`);
  };

  const read = async (file?: File) => {
    if (!file) return;
    setReading(true);
    setFound(null);
    const r = await readTimetable(file);
    setReading(false);
    if ('error' in r) return toast(t(r.error === 'file' ? 'schBadFile' : r.error === 'budget' ? 'askBudget' : 'schReadFailed'));
    if (!r.length) return toast(t('schNoneFound'));
    setFound(r.map((c) => ({ ...c, on: true })));
  };
  // The course a class belongs to: a course whose name is in the class title.
  const courseFor = (title: string) => {
    const x = title.toLocaleLowerCase(lang);
    return courses.find((c) => x.includes(c.name.toLocaleLowerCase(lang)) || (c.short && x.includes(c.short.toLocaleLowerCase(lang))))?.id ?? null;
  };
  const addFound = async () => {
    const chosen = (found ?? []).filter((c) => c.on);
    if (!chosen.length) return toast(t('schPickOne'));
    setSaving(true);
    for (const c of chosen) await addClass({ ...c, courseId: courseFor(c.title) });
    setSaving(false);
    setFound(null);
    setReload((n) => n + 1);
    toast(t('schAddedN').replace('{n}', num(chosen.length, lang)));
  };

  const ways: [IconName, string, string, () => void][] = [
    ['camera', 'schPhoto', 'schPhotoS', () => photoIn.current?.click()],
    ['file', 'schFile', 'schFileS', () => fileIn.current?.click()],
    ['pen', 'schHand', 'schHandS', () => (setManual(true), setAdding(true), setDay(today <= 5 ? today : 1))],
  ];

  return (
    <main className={s.main}>
      <div className={s.head}>
        <button className={s.round} aria-label={t('back')} onClick={() => navigate('/plan')}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <span className={s.titleBox}>
          <h1>{t('schTitle')}</h1>
          <span>{t('schRemind')}</span>
        </span>
      </div>
      <input ref={photoIn} type="file" accept="image/*" hidden onChange={(e) => (read(e.target.files?.[0]), (e.target.value = ''))} />
      <input ref={fileIn} type="file" accept="application/pdf,.pdf,image/*" hidden onChange={(e) => (read(e.target.files?.[0]), (e.target.value = ''))} />

      {reading && (
        <section className={s.found}>
          <h2>{t('schReading')}</h2>
          <Thinking />
        </section>
      )}
      {found && (
        <section className={s.found}>
          <h2>{t('schFoundN').replace('{n}', num(found.length, lang))}</h2>
          <p>{t('schFoundS')}</p>
          <ul>
            {found.map((c, i) => (
              <li key={`${c.weekday}-${c.start}-${i}`}>
                <label>
                  <input type="checkbox" checked={c.on} onChange={() => setFound(found.map((x, j) => (j === i ? { ...x, on: !x.on } : x)))} />
                  <span className={`mono ${s.foundTime}`}>
                    {dayName(c.weekday)} · {c.start}
                    {c.end ? `–${c.end}` : ''}
                  </span>
                  <b dir="auto">{c.title}</b>
                  <span className={s.foundMeta} dir="auto">
                    {[c.room, c.teacher].filter(Boolean).join(' · ')}
                  </span>
                </label>
              </li>
            ))}
          </ul>
          <div className={s.foundBtns}>
            <button className={s.pri} aria-busy={saving} disabled={saving} onClick={addFound}>
              {t('schAddChosen')}
            </button>
            <button className={s.ghost} onClick={() => setFound(null)}>
              {t('schCancel')}
            </button>
          </div>
        </section>
      )}

      {classes.length === 0 && !manual ? (
        <section className={s.empty}>
          <span className={s.emptyIcon}>
            <Icon name="calendar" size={30} />
          </span>
          <h2>{t('schEmptyT')}</h2>
          <p>{t('schEmptyS')}</p>
          <span className={s.how}>{t('schHow')}</span>
          {ways.map(([icon, title, sub, fn], i) => (
            <button key={title} className={i === 0 ? `${s.way} ${s.wayPri}` : s.way} onClick={fn}>
              <span className={s.wayIcon}>
                <Icon name={icon} size={20} />
              </span>
              <span className={s.wayText}>
                <b>{t(title)}</b>
                <span>{t(sub)}</span>
              </span>
            </button>
          ))}
          <small>{t('schPrivate')}</small>
        </section>
      ) : (
        <div className={s.grid}>
          <div className={s.col}>
            <section className={s.hero}>
              <span className={s.heroIcon}>
                <Icon name="bell" size={22} />
              </span>
              <span className={s.heroText}>
                <span className="mono">{`${t('schTmr')} · ${dayName(tomorrow).toLocaleUpperCase(lang)} · ${num(tmr.length, lang)} ${t('schLesson')}`}</span>
                <b>{tmr.length ? `${t('schFirst')} ${tmr[0].start} · ${tmr[0].title}` : t('schNoRemind')}</b>
                <span>{settings.classRemindDayBefore ? t('schTonightA') + settings.classRemindTime + t('schTonightB') : t('schRemindOff')}</span>
              </span>
            </section>

            <div role="tablist" aria-label={t('schDay')} className={s.days}>
              {days.map((wd) => (
                <button key={wd} role="tab" aria-selected={wd === day} className={wd === day ? `${s.dayBtn} ${s.dayOn}` : s.dayBtn} onClick={() => setDay(wd)}>
                  <b>{t(DAY_KEYS[wd - 1])}</b>
                  <span>{num(ofDay(wd).length, lang) + t('schClasses')}</span>
                  <small>{wd === today ? t('schToday') : wd === tomorrow ? t('schTomorrow') : ''}</small>
                </button>
              ))}
            </div>

            <section className={s.card}>
              <h2 className={s.dayTitle}>
                {dayName(day)}
                {day === today ? ` · ${t('schToday')}` : day === tomorrow ? ` · ${t('schTomorrow')}` : ''}
              </h2>
              {ofDay(day).length === 0 && <p className={s.muted}>{t('schNoClasses')}</p>}
              {ofDay(day).map((c) => {
                const col = colorOf(c);
                return (
                  <div key={c.id} className={s.row} style={{ background: col.soft }}>
                    <span className={`mono ${s.time}`} style={{ color: col.fg }}>
                      <b>{c.start}</b>
                      <span>{c.end}</span>
                    </span>
                    <span className={s.rowText}>
                      <b>{c.title}</b>
                      <span>{[c.room, c.teacher].filter(Boolean).join(' · ')}</span>
                    </span>
                    <button
                      className={c.remind ? `${s.bell} ${s.bellOn}` : s.bell}
                      aria-pressed={c.remind}
                      aria-label={c.title}
                      onClick={() => toggleBell(c)}
                    >
                      <Icon name="bell" size={17} />
                    </button>
                    <button
                      className={s.del}
                      aria-label={t('schDelete')}
                      onClick={() => deleteClass(c.id).then(() => (toast(c.title + t('schDeleted')), setReload(reload + 1)))}
                    >
                      <Icon name="trash" size={16} />
                    </button>
                  </div>
                );
              })}
              {adding ? (
                <AddForm
                  day={day}
                  courses={courses.map((c) => ({ id: c.id, name: c.name }))}
                  onCancel={() => setAdding(false)}
                  onSaved={(title, wd) => {
                    setAdding(false);
                    setDay(wd);
                    setReload(reload + 1);
                    toast(title + t('schAdded'));
                  }}
                />
              ) : (
                <button className={s.add} onClick={() => setAdding(true)}>
                  <Icon name="plus" size={17} />
                  {t('schAdd')}
                </button>
              )}
            </section>
          </div>

          <div className={s.col}>
            <section className={s.card}>
              <h2 className={s.cardTitle}>{t('schRemind')}</h2>
              {(
                [
                  ['classRemindDayBefore', 'schDayBefore', 'schDayBeforeS'],
                  ['classRemindFirst', 'schMorning', 'schMorningS'],
                  ['classPrepTip', 'schPrep', 'schPrepS'],
                ] as const
              ).map(([key, title, sub]) => (
                <div key={key} className={s.switchRow}>
                  <span className={s.rowText}>
                    <b>{t(title)}</b>
                    <span>{t(sub)}</span>
                  </span>
                  <Switch on={settings[key]} label={t(title)} onChange={() => toggle(key, t(title))} />
                </div>
              ))}
              <span className={s.when}>{t('schWhen')}</span>
              <div role="radiogroup" aria-label={t('schWhen')} className={s.seg}>
                {TIMES.map((x) => (
                  <button
                    key={x}
                    role="radio"
                    aria-checked={settings.classRemindTime === x}
                    className={settings.classRemindTime === x ? s.segOn : ''}
                    onClick={() => (patch({ classRemindTime: x }), toast(t('schTimeToast') + x))}
                  >
                    {x}
                  </button>
                ))}
              </div>
            </section>

            <section className={s.card}>
              <h2 className={s.cardTitle}>{t('schPreview')}</h2>
              <div className={s.notif}>
                <img src="/icon_star.png" alt="" width={36} height={36} />
                <span className={s.notifText}>
                  <span className="mono">
                    <span>KAVIS STUDY</span>
                    <span>{settings.classRemindTime}</span>
                  </span>
                  <b>{notifTitle}</b>
                  {tmr.map((c) => (
                    <span key={c.id}>
                      <span className="mono">{c.start}</span> {c.title}
                      {c.room ? ` · ${c.room}` : ''}
                    </span>
                  ))}
                  {settings.classPrepTip && tmr.length > 0 && <em>{t('schPrepLine').replace('{x}', tmr[0].title)}</em>}
                </span>
              </div>
              <button className={s.ghost} onClick={test}>
                {t('schTest')}
              </button>
            </section>

            <button className={s.redo} onClick={() => photoIn.current?.click()}>
              {t('schNew')}
            </button>
          </div>
        </div>
      )}
    </main>
  );
}

function AddForm({
  day,
  courses,
  onCancel,
  onSaved,
}: {
  day: number;
  courses: { id: string; name: string }[];
  onCancel: () => void;
  onSaved: (title: string, weekday: number) => void;
}) {
  const { t } = useI18n();
  const toast = useToast();
  const [f, setF] = useState({ weekday: day, start: '09:00', end: '10:50', title: '', room: '', teacher: '', courseId: '' });
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!f.title.trim()) return toast(t('schNeedName'));
    setBusy(true);
    await addClass({ ...f, courseId: f.courseId || null });
    onSaved(f.title.trim(), f.weekday);
  };

  return (
    <form className={s.form} onSubmit={submit}>
      <label>
        {t('schName')}
        <input
          list="sch-courses"
          value={f.title}
          onChange={(e) => {
            const title = e.target.value;
            setF({ ...f, title, courseId: courses.find((c) => c.name === title)?.id ?? '' });
          }}
          autoFocus
        />
        <datalist id="sch-courses">
          {courses.map((c) => (
            <option key={c.id} value={c.name} />
          ))}
        </datalist>
      </label>
      <div className={s.formRow}>
        <label>
          {t('schDay')}
          <select value={f.weekday} onChange={(e) => setF({ ...f, weekday: Number(e.target.value) })}>
            {DAY_KEYS.map((k, i) => (
              <option key={k} value={i + 1}>
                {t(k)}
              </option>
            ))}
          </select>
        </label>
        <label>
          {t('schStart')}
          <input type="time" value={f.start} onChange={(e) => setF({ ...f, start: e.target.value })} required />
        </label>
        <label>
          {t('schEnd')}
          <input type="time" value={f.end} onChange={(e) => setF({ ...f, end: e.target.value })} />
        </label>
      </div>
      <div className={s.formRow}>
        <label>
          {t('schRoom')}
          <input value={f.room} onChange={(e) => setF({ ...f, room: e.target.value })} />
        </label>
        <label>
          {t('schTeacher')}
          <input value={f.teacher} onChange={(e) => setF({ ...f, teacher: e.target.value })} />
        </label>
      </div>
      <div className={s.formBtns}>
        <button type="button" className={s.ghost} onClick={onCancel}>
          {t('delCancel')}
        </button>
        <button type="submit" className={s.pri} disabled={busy}>
          {t('save')}
        </button>
      </div>
    </form>
  );
}
