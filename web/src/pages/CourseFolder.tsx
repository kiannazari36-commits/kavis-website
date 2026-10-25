import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useI18n, type Lang } from '../i18n/I18nProvider';
import { duration, examLabel, num, percent } from '../i18n/format';
import Icon from '../components/Icon';
import { COURSE_COLOR } from '../components/courseColors';
import { courseStats, getCourse } from '../api/courses';
import { useAsync } from '../hooks/useAsync';
import { deleteLesson } from '../api/upload';
import { recordingsOfCourse } from '../api/recording';
import { clock } from '../speech/transcribe';
import { useToast } from '../components/Toast';
import type { Pdf } from '../api/types';
import ContentLangPicker from '../components/ContentLangPicker';
import { useContentLang, useSettings } from '../settings/SettingsProvider';
import { useTrial } from '../trial/TrialProvider';
import s from './CourseFolder.module.css';

// Design: design/NewCourses.dc.html, variant "detail" (one course folder with its PDFs), laid out for the web.
function pdfStatus(p: Pdf, lang: Lang, t: (k: string) => string) {
  const pages = num(p.pages, lang) + t('pagesSep');
  if (p.read === 100) return pages + t('done');
  if (p.read === 0) return pages + t('notStarted');
  return pages + num(Math.round((p.pages * (100 - p.read)) / 100), lang) + t('pagesLeft');
}

export default function CourseFolder() {
  const { courseId = '' } = useParams();
  const { t, lang } = useI18n();
  const { guard } = useTrial();
  const navigate = useNavigate();
  const toast = useToast();
  // "Delete lesson": asked once more before it happens (it cannot be undone).
  const [asking, setAsking] = useState<string | null>(null);
  const [reload, setReload] = useState(0);
  const course = useAsync(() => getCourse(courseId), [courseId, reload]);
  const recordings = useAsync(() => recordingsOfCourse(courseId), [courseId]) ?? [];
  const remove = async (p: Pdf) => {
    setAsking(null);
    const ok = await deleteLesson(p.id);
    toast(ok ? p.title + t('lessonDeleted') : t('lessonDeleteFailed'));
    if (ok) setReload((n) => n + 1);
  };
  const { settings, setCourseContentLang } = useSettings();
  const contentLang = useContentLang(course ?? undefined);

  if (course === undefined) return <main className={s.main} />;
  if (course === null)
    return (
      <main className={s.main}>
        <p className={s.missing}>{t('noResults')}</p>
        <Link to="/courses" className="btn btn-ghost">
          {t('k48')}
        </Link>
      </main>
    );

  const col = COURSE_COLOR[course.color];
  const st = courseStats(course);
  const maxMin = Math.max(1, ...course.pdfs.map((p) => p.minutes));
  const addPdf = () => guard('pdf', () => navigate(`/upload?course=${course.id}`));

  return (
    <main className={s.main}>
      <div className={s.top}>
        <button className={s.back} aria-label={t('back')} onClick={() => navigate('/courses')}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <span className={s.crumb}>
          <Link to="/courses">{t('k48')}</Link>
          <Icon name="chevron" size={14} className="flip-rtl" />
          <span>{t('courseFolder')}</span>
        </span>
        <span className={s.grow} />
        <button className={s.addTop} onClick={addPdf}>
          <Icon name="plus" size={18} />
          {t('addPdfShort')}
        </button>
      </div>

      <section className={s.hero} style={{ background: col.soft }}>
        <div className={s.heroText}>
          <span style={{ color: col.fg }}>{examLabel(course.examKind, course.examDate, lang)}</span>
          <h1>{course.name}</h1>
        </div>
        <div className={s.stats}>
          <span>
            <b>{num(course.pdfs.length, lang)}</b>
            <small>PDF</small>
          </span>
          <span>
            <b>{percent(st.pct, lang)}</b>
            <small>{t('read')}</small>
          </span>
          <span>
            <b className={s.hours}>{duration(st.minutes, lang)}</b>
            <small>{t('study')}</small>
          </span>
        </div>
      </section>

      <section className={s.langBox}>
        <span className={s.langTitle}>
          <b>{t('contentLang')}</b>
          <span>{t('clCourseHint')}</span>
        </span>
        <ContentLangPicker
          withDefault
          value={settings.courseContentLang[course.id] ?? null}
          resolved={contentLang}
          onChange={(v) => setCourseContentLang(course.id, v)}
        />
      </section>

      {course.pdfs.length > 0 ? (
        <>
          <div className={s.listHead}>
            <h2>{t('pdfs')}</h2>
            <span>{t('ringHint')}</span>
          </div>
          <div className={s.list}>
            {course.pdfs.map((p) => (
              <div key={p.id} className={s.pdfRow}>
                <Link to={`/reader?course=${course.id}&pdf=${p.id}`} className={s.pdf}>
                  <span
                    className={s.ring}
                    role="img"
                    aria-label={`${percent(p.read, lang)} ${t('read')}`}
                    style={{ background: `conic-gradient(${col.fg} ${Math.round(p.read * 3.6)}deg, var(--sub) 0)` }}
                  >
                    <span className="mono">{num(p.read, lang)}</span>
                  </span>
                  <span className={s.pdfBody}>
                    <b>{p.title}</b>
                    <span className={s.timeRow}>
                      <span className={s.timeBar}>
                        <span style={{ width: `${Math.round((p.minutes / maxMin) * 100)}%` }} />
                      </span>
                      <span className="mono">{duration(p.minutes, lang)}</span>
                    </span>
                    <span className={s.status}>
                      {pdfStatus(p, lang, t)}
                      {p.read > 0 && <span className={`mono ${s.device}`}>{t('onDevice')}</span>}
                    </span>
                  </span>
                  <Icon name="chevron" size={18} className={`flip-rtl ${s.chev}`} />
                </Link>
                {asking === p.id ? (
                  <div className={s.ask} role="group" aria-label={t('lessonDeleteAsk')}>
                    <span>{t('lessonDeleteAsk')}</span>
                    <button className={s.askYes} onClick={() => remove(p)}>
                      {t('lessonDeleteYes')}
                    </button>
                    <button className={s.askNo} onClick={() => setAsking(null)}>
                      {t('lessonDeleteNo')}
                    </button>
                  </div>
                ) : (
                  <button className={s.del} aria-label={t('lessonDelete')} title={t('lessonDelete')} onClick={() => setAsking(p.id)}>
                    <Icon name="trash" size={16} />
                  </button>
                )}
              </div>
            ))}
          </div>
        </>
      ) : (
        <div className={s.emptyBox}>
          <b>{t('emptyFolder')}</b>
          <span>{t('emptyHint')}</span>
        </div>
      )}

      {recordings.length > 0 && (
        <>
          <div className={s.listHead}>
            <h2>{t('recList')}</h2>
          </div>
          <div className={s.list}>
            {recordings.map((r) => (
              <Link key={r.id} to={`/recording?id=${r.id}`} className={s.pdf}>
                <span className={s.recIcon}>
                  <Icon name="mic" size={22} />
                </span>
                <span className={s.pdfBody}>
                  <b>{r.title}</b>
                  <span className={s.status}>
                    {r.status === 'ready' ? clock(r.seconds) : r.status === 'failed' ? t('recFailedShort') : t('recWorkingShort')} · {r.day}
                  </span>
                </span>
                <Icon name="chevron" size={18} className={`flip-rtl ${s.chev}`} />
              </Link>
            ))}
          </div>
        </>
      )}

      <button className={s.addBottom} onClick={addPdf}>
        <Icon name="plus" size={18} />
        {t('addPdf')}
      </button>
    </main>
  );
}
