import { useState, type FormEvent } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import { LANG_NAMES, LANGS, useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import Wordmark from '../components/Wordmark';
import { currentUser } from '../api/auth';
import { useSettings } from '../settings/SettingsProvider';
import { createCourses, DEPARTMENTS, finishOnboarding, SUGGESTIONS, termName } from '../api/onboarding';
import s from './Welcome.module.css';

// Design: design/ScrOnboarding.dc.html (language, weekly plan, department) and design/NewCourses.dc.html "setup"
// (this term's courses), on one web page in 4 steps. School and class year are asked with the department.
// The app opens this page after sign-up until it is finished.

type Step = 0 | 1 | 2 | 3;
const STEPS = 4;
const YEARS = [1, 2, 3, 4, 5, 6];

export default function Welcome() {
  const { t, lang, setLang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const { settings, patch } = useSettings();
  const [step, setStep] = useState<Step>(0);
  const [school, setSchool] = useState('');
  const [dept, setDept] = useState<string>('');
  const [year, setYear] = useState<number | null>(null);
  const [days, setDays] = useState(settings.studyDays || 4);
  const [hours, setHours] = useState(settings.studyHours || 1.5);
  const [extra, setExtra] = useState<string[]>([]);
  const [chosen, setChosen] = useState<string[]>([]);
  const [typed, setTyped] = useState('');
  const [started, setStarted] = useState(false);
  const [done, setDone] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);

  if (!currentUser()) return <Navigate to="/login?mode=login" replace />;

  const all = [...(SUGGESTIONS[dept] ?? []), ...extra.filter((x) => !(SUGGESTIONS[dept] ?? []).includes(x))];
  // Decimal comma in Turkish ("1,5 sa").
  const dec = (x: number) => num(lang === 'tr' ? String(x).replace('.', ',') : x, lang);
  const hoursText = (h: number) => t('wel_hours').replace('{h}', dec(h));
  const toggle = (name: string) => {
    if (chosen.includes(name)) {
      setChosen(chosen.filter((x) => x !== name));
      setDone(done.filter((x) => x !== name));
    } else setChosen([...chosen, name]);
  };
  const add = (e?: FormEvent) => {
    e?.preventDefault();
    const name = typed.trim();
    if (!name) return;
    if (!all.includes(name)) setExtra([...extra, name]);
    if (!chosen.includes(name)) setChosen([...chosen, name]);
    setTyped('');
  };

  const next = async () => {
    if (step === 1 && !dept) return toast(t('wel_needDept'));
    if (step < 3) return setStep((step + 1) as Step);
    setBusy(true);
    patch({ studyDays: days, studyHours: hours });
    await createCourses(chosen, started ? done : []);
    const ok = await finishOnboarding({ school, department: dept, classYear: year });
    setBusy(false);
    if (!ok) return toast(t('wel_failed'));
    navigate('/home', { replace: true });
  };

  return (
    <main className={s.page}>
      <div className={s.box}>
        <div className={s.top}>
          <Wordmark size={18} />
          <span className={`mono ${s.count}`}>
            {num(step + 1, lang)} / {num(STEPS, lang)}
          </span>
        </div>

        {step === 0 && (
          <section className={s.step}>
            <span className={`mono ${s.eyebrow}`}>{t('wel_eyebrow')}</span>
            <h1>{t('wel_langT')}</h1>
            <p>{t('wel_langS')}</p>
            <div className={s.list} role="radiogroup" aria-label={t('wel_langT')}>
              {LANGS.map((l) => (
                <button key={l} role="radio" aria-checked={l === lang} className={l === lang ? s.on : ''} onClick={() => setLang(l)}>
                  <span className={`mono ${s.code}`}>{l.toUpperCase()}</span>
                  <b lang={l}>{LANG_NAMES[l]}</b>
                  <span className={s.radio} />
                </button>
              ))}
            </div>
          </section>
        )}

        {step === 1 && (
          <section className={s.step}>
            <span className={`mono ${s.eyebrow}`}>{t('wel_aboutE')}</span>
            <h1>{t('wel_deptT')}</h1>
            <p>{t('wel_deptS')}</p>
            <label className={s.field}>
              {t('wel_school')}
              <input value={school} onChange={(e) => setSchool(e.target.value)} placeholder={t('wel_schoolPh')} autoComplete="organization" />
            </label>
            <span className={s.label}>{t('wel_dept')}</span>
            <div className={s.grid} role="radiogroup" aria-label={t('wel_dept')}>
              {DEPARTMENTS.map((d) => (
                <button key={d} role="radio" aria-checked={d === dept} className={d === dept ? s.on : ''} onClick={() => setDept(d)}>
                  {t(`dept_${DEPARTMENTS.indexOf(d)}`)}
                </button>
              ))}
            </div>
            <span className={s.label}>{t('wel_year')}</span>
            <div className={s.chips} role="radiogroup" aria-label={t('wel_year')}>
              {YEARS.map((y) => (
                <button key={y} role="radio" aria-checked={y === year} className={y === year ? s.chipOn : ''} onClick={() => setYear(y)}>
                  {t('wel_yearN').replace('{n}', num(y, lang))}
                </button>
              ))}
            </div>
          </section>
        )}

        {step === 2 && (
          <section className={s.step}>
            <span className={`mono ${s.eyebrow}`}>{t('wel_planE')}</span>
            <h1>{t('wel_planT')}</h1>
            <p>{t('wel_planS')}</p>
            <div className={s.card}>
              <b>{t('wel_days')}</b>
              <div className={s.days} role="radiogroup" aria-label={t('wel_days')}>
                {[1, 2, 3, 4, 5, 6, 7].map((n) => (
                  <button key={n} role="radio" aria-checked={n === days} className={n === days ? s.chipOn : ''} onClick={() => setDays(n)}>
                    {num(n, lang)}
                  </button>
                ))}
              </div>
            </div>
            <div className={s.card}>
              <b>{t('wel_perDay')}</b>
              <div className={s.stepper}>
                <button aria-label={t('wel_less')} onClick={() => setHours(Math.max(0.5, hours - 0.5))}>
                  −
                </button>
                <span aria-live="polite">{hoursText(hours)}</span>
                <button className={s.plus} aria-label={t('wel_more')} onClick={() => setHours(Math.min(8, hours + 0.5))}>
                  +
                </button>
              </div>
            </div>
            <div className={s.sum}>
              <Icon name="calendar" size={17} />
              <span>
                <b>{t('wel_sum').replace('{d}', num(days, lang)).replace('{h}', hoursText(hours)).replace('{t}', dec(Math.round(days * hours * 10) / 10))}</b>
                <small>{t('wel_sumS')}</small>
              </span>
            </div>
          </section>
        )}

        {step === 3 && (
          <section className={s.step}>
            <span className={`mono ${s.term}`}>{termName()}</span>
            <h1>
              {t('wel_coursesA')} <span>{t('wel_coursesB')}</span>
            </h1>
            <p>{t('wel_coursesS')}</p>
            <form className={s.addRow} onSubmit={add}>
              <input value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('wel_coursePh')} aria-label={t('wel_courseName')} />
              <button type="submit" aria-label={t('wel_addCourse')}>
                <Icon name="plus" size={18} />
              </button>
            </form>
            {all.length > 0 && (
              <>
                <span className={s.label}>{t('wel_suggest')}</span>
                <div className={s.chips}>
                  {all.map((name) => (
                    <button key={name} aria-pressed={chosen.includes(name)} className={chosen.includes(name) ? s.chipOn : ''} onClick={() => toggle(name)}>
                      <Icon name={chosen.includes(name) ? 'check' : 'plus'} size={13} />
                      {name}
                    </button>
                  ))}
                </div>
              </>
            )}
            <div className={s.card}>
              <b>{t('wel_started')}</b>
              <div className={s.seg}>
                <button aria-pressed={!started} className={!started ? s.segOn : ''} onClick={() => setStarted(false)}>
                  {t('wel_new')}
                </button>
                <button aria-pressed={started} className={started ? s.segOn : ''} onClick={() => setStarted(true)}>
                  {t('wel_some')}
                </button>
              </div>
              {started && chosen.length > 0 && (
                <>
                  <small>{t('wel_which')}</small>
                  <div className={s.chips}>
                    {chosen.map((name) => (
                      <button
                        key={name}
                        aria-pressed={done.includes(name)}
                        className={done.includes(name) ? s.chipOn : ''}
                        onClick={() => setDone(done.includes(name) ? done.filter((x) => x !== name) : [...done, name])}
                      >
                        {name}
                      </button>
                    ))}
                  </div>
                </>
              )}
            </div>
          </section>
        )}

        <div className={s.foot}>
          <div className={s.dots} aria-hidden="true">
            {Array.from({ length: STEPS }, (_, i) => (
              <span key={i} className={i === step ? s.dotOn : ''} />
            ))}
          </div>
          <button className={s.pri} aria-busy={busy} disabled={busy} onClick={next}>
            {step < 3 ? t('wel_next') : chosen.length ? t('wel_create').replace('{n}', num(chosen.length, lang)) : t('wel_later')}
          </button>
          {step > 0 && (
            <button className={s.back} onClick={() => setStep((step - 1) as Step)}>
              {t('back')}
            </button>
          )}
          {step === 3 && <small>{t('wel_changeLater')}</small>}
        </div>
      </div>
    </main>
  );
}
