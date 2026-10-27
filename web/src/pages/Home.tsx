import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import TopBar from '../components/TopBar';
import Icon, { type IconName } from '../components/Icon';
import { COURSE_COLOR } from '../components/courseColors';
import { listCourses, recentPdfs } from '../api/courses';
import { getProfile } from '../api/account';
import { useAsync } from '../hooks/useAsync';
import { courseCount, duration, num } from '../i18n/format';
import { daysUntil, isoToday } from '../api/courses';
import { ensureWeekPlan, getTodayReview, setReview, setTaskDone } from '../api/plan';
import { listOwnPlan } from '../api/ownPlan';
import { useSettings } from '../settings/SettingsProvider';
import { useTrial } from '../trial/TrialProvider';
import { usePanelPref } from '../hooks/usePanelPref';
import s from './Home.module.css';

// Design: design/DeskApp.dc.html, screen "home" (web).

// Level tag on a lesson card, from how much of it is read: Beginner / Good / Very good (k81 / k78 / k83).
const levelKey = (pct: number) => (pct < 30 ? 'k81' : pct < 80 ? 'k78' : 'k83');

/** "09:00" + minutes → "09:40". */
const addTime = (hm: string, minutes: number) => {
  const m = parseInt(hm, 10) * 60 + parseInt(hm.slice(3), 10) + minutes;
  return `${String(Math.floor(m / 60) % 24).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
};

export default function Home() {
  const { t, lang } = useI18n();
  const { guard } = useTrial();
  const profile = useAsync(getProfile, []);
  const courses = useAsync(listCourses, []);
  // "My Courses" cards on home: the lessons read most recently.
  const recent = useAsync(() => recentPdfs(3), []) ?? [];
  const firstName = profile?.name.split(' ')[0] ?? '';
  const navigate = useNavigate();
  // PDF, photos, recordings and question samples open their screens.
  const upload = (to: string) => (to === '/samples' ? navigate(to) : guard('pdf', () => navigate(to)));
  const { settings } = useSettings();
  const review = useAsync(getTodayReview, []);
  const [showReview, setShowReview] = useState(true);
  // Today's plan, one after the other from the reminder time, 10 minutes apart: the Kavis plan's tasks (made first
  // if the week's plan is missing or old), or with "Kendi planım" the student's own courses for this weekday.
  const mode = settings.planMode;
  const week = useAsync(() => (mode === 'aim' ? ensureWeekPlan(mode) : Promise.resolve(null)), [mode]);
  const own = useAsync(() => (mode === 'own' ? listOwnPlan() : Promise.resolve([])), [mode]);
  const loaded = mode === 'aim' ? week !== undefined : mode === 'own' ? own !== undefined : true;
  const weekdayNow = ((new Date().getDay() + 6) % 7) + 1;
  const todayTasks =
    mode === 'aim'
      ? (week?.tasks ?? []).filter((x) => x.day === isoToday()).map((x) => ({ ...x, own: false, link: '' }))
      : mode === 'own'
        ? (own ?? [])
            .filter((x) => x.weekday === weekdayNow)
            .map((x) => {
              const c = courses?.find((y) => y.id === x.courseId);
              return { id: x.id, title: c?.name ?? '', minutes: x.minutes, why: t('ownPlanWhy'), status: 'todo', own: true, link: `/courses/${x.courseId}` };
            })
        : [];
  const plan = todayTasks.map((x, i) => ({
    ...x,
    time: addTime(settings.notifyTime, todayTasks.slice(0, i).reduce((a, y) => a + y.minutes + 10, 0)),
  }));
  const [ticks, setTicks] = useState<Record<string, boolean>>({});
  const isDone = (id: string, status: string) => ticks[id] ?? status === 'done';
  const nextExam = [...(courses ?? [])].filter((c) => c.examDate).sort((a, b) => a.examDate!.localeCompare(b.examDate!))[0];
  // Right panel (today's plan): closed by default like the iPad design, opens wide screens only. Remembered.
  // The assistant is not in it (it opens from the star at the top).
  const [panelOpen, setPanelOpen] = usePanelPref('kavis.planOpen', 1440);

  const uploads: [IconName, string, string][] = [
    ['upload', 'k33', '/upload'],
    ['camera', 'k69', '/upload?mode=photo'],
    ['mic', 'k70', '/record'],
    ['help', 'k71', '/samples'],
  ];
  const tools: [IconName, string, string, string, string][] = [
    ['list', 'k72', 'var(--pri-soft)', 'var(--pri-t)', '/exam'],
    ['cards', 'k73', 'var(--amb-soft)', 'var(--amb-t)', '/cards'],
    ['book', 'k74', 'var(--good-soft)', 'var(--good)', '/reader'],
  ];

  return (
    <main className={panelOpen ? s.main : `${s.main} ${s.mainWide}`}>
      <div className={s.left}>
        <div className={s.head}>
          <TopBar />
          <h1 className={s.hello}>
            <span>{firstName ? t('helloName').replace('{name}', firstName) : t('k63').split(' ')[0]}</span> {t('k64')}
          </h1>
        </div>

        {showReview && review && (
          <section className={s.review}>
            <span className={s.reviewIcon}>
              <Icon name="refresh" size={26} />
            </span>
            <span className={s.reviewText}>
              <b>{t('k65')}</b>
              <span>
                {[review.title, t('reviewParts').replace('{c}', num(review.cards, lang)).replace('{q}', num(review.questions, lang)), duration(review.minutes, lang)].join(' · ')}
              </span>
            </span>
            <span className={s.reviewBtns}>
              <button className={s.reviewGo} onClick={() => navigate(`/review?id=${review.id}`)}>
                <Icon name="play" size={15} />
                {t('k67')}
              </button>
              <button className={s.reviewLater} onClick={() => (setReview(review.id, 'tomorrow'), setShowReview(false))}>
                {t('k68')}
              </button>
            </span>
          </section>
        )}

        <div className={s.uploads}>
          {uploads.map(([icon, key, to], i) => (
            <button key={key} className={i === 0 ? `${s.upload} ${s.uploadPri}` : s.upload} onClick={() => upload(to)}>
              <Icon name={icon} size={20} />
              {t(key)}
            </button>
          ))}
        </div>

        <div className={s.tools}>
          {tools.map(([icon, key, bg, fg, to]) => (
            <Link key={key} to={to} className={s.tool}>
              <span className={s.toolIcon} style={{ background: bg, color: fg }}>
                <Icon name={icon} size={19} />
              </span>
              {t(key)}
              <Icon name="chevron" size={16} className={`flip-rtl ${s.chev}`} />
            </Link>
          ))}
        </div>

        <div className={s.coursesHead}>
          <h2>{t('k48')}</h2>
          <span className={s.count}>{courses && `· ${courseCount(courses.length, lang)}`}</span>
          <Link to="/courses" className={s.folderLink}>
            {t('k76')}
          </Link>
        </div>
        <div className={s.recent}>
          {recent.map(({ course, pdf }) => {
            const col = COURSE_COLOR[course.color];
            return (
              <Link key={pdf.id} to={`/reader?course=${course.id}&pdf=${pdf.id}`} className={s.pdfCard}>
                <span className={`mono ${s.pdfBadge}`} style={{ background: col.soft, color: col.fg }}>
                  PDF
                </span>
                <b>{pdf.title}</b>
                <span className={s.pdfCourse}>{course.short ?? course.name}</span>
                <span className={s.bar}>
                  <span style={{ width: `${pdf.read}%`, background: col.main }} />
                </span>
                <span className={s.pdfFoot}>
                  <span className={s.level} style={{ background: col.soft, color: col.fg }}>
                    {t(levelKey(pdf.read))}
                  </span>
                  <span className={`mono ${s.device}`}>{t('k79')}</span>
                </span>
              </Link>
            );
          })}
        </div>
      </div>

      {!panelOpen && (
        <button className={s.planTab} aria-label={t('planOpen')} aria-expanded={false} onClick={() => setPanelOpen(true)}>
          <span className={s.tabCount}>{plan.length}</span>
          <span className={s.tabTitle}>{t('planTab')}</span>
          <span className={`mono ${s.tabTimes}`}>{plan.map((p) => p.time).join(' · ')}</span>
          <Icon name="chevron" size={16} width={2.2} className={s.tabChev} />
        </button>
      )}

      {panelOpen && (
        <aside className={s.right}>
          <section className={s.panel}>
            <div className={s.panelHead}>
              <h2>{t('k84')}</h2>
              <Link to="/plan" className={s.weekly}>
                {t('weeklyPlan')}
              </Link>
              <button className={s.panelClose} aria-label={t('planClose')} aria-expanded onClick={() => setPanelOpen(false)}>
                <Icon name="close" size={14} width={2.2} />
              </button>
            </div>
            {loaded && plan.length === 0 && (
              <Link to="/plan" className={s.planEmpty}>
                {t(mode === 'aim' ? 'planEmptyToday' : mode === 'own' ? 'planOwnEmpty' : 'planOffHome')}
              </Link>
            )}
            {plan.map((p) => {
              const done = isDone(p.id, p.status);
              return (
                <div key={p.id} className={s.planRow}>
                  <span className={`mono ${s.time}`}>{p.time}</span>
                  <span className={s.planText}>
                    <b>{p.title}</b>
                    <span>{`${duration(p.minutes, lang)} · ${p.why}`}</span>
                  </span>
                  {p.own ? (
                    <Link to={p.link} className={s.check} aria-label={p.title}>
                      <Icon name="chevron" size={13} width={2.4} className="flip-rtl" />
                    </Link>
                  ) : (
                    <button
                      role="checkbox"
                      aria-checked={done}
                      aria-label={p.title}
                      className={done ? `${s.check} ${s.checkOn}` : s.check}
                      onClick={() => {
                        setTicks({ ...ticks, [p.id]: !done });
                        setTaskDone(p.id, !done);
                      }}
                    >
                      {done && <Icon name="check" size={13} width={2.4} />}
                    </button>
                  )}
                </div>
              );
            })}
            {nextExam && (
              <Link to="/plan" className={s.countdown}>
                <b>{num(daysUntil(nextExam.examDate!), lang)}</b>
                {t('daysUntilExam').replace('{course}', nextExam.short ?? nextExam.name)}
              </Link>
            )}
          </section>

        </aside>
      )}
    </main>
  );
}
