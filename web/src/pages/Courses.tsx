import { useState, type DragEvent } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { duration, examLabel, pdfCount, percent, rank, termSummary } from '../i18n/format';
import { useToast } from '../components/Toast';
import TopBar from '../components/TopBar';
import Icon from '../components/Icon';
import { COURSE_COLOR } from '../components/courseColors';
import { courseStats, daysUntil, listCourses } from '../api/courses';
import { useAsync } from '../hooks/useAsync';
import type { Course } from '../api/types';
import { useTrial } from '../trial/TrialProvider';
import s from './Courses.module.css';

// Design: design/DeskApp.dc.html, screen "courses" (web) — the "My Courses" folder.
type Filter = 'all' | 'soon' | 'weak' | 'done';
const FILTERS: [Filter, string][] = [
  ['all', 'k103'],
  ['soon', 'k104'],
  ['weak', 'k105'],
  ['done', 'k106'],
];

const matches: Record<Filter, (c: Course) => boolean> = {
  all: () => true,
  soon: (c) => !!c.examDate && daysUntil(c.examDate) <= 9,
  weak: (c) => courseStats(c).pct < 55,
  done: (c) => courseStats(c).pct === 100,
};

export default function Courses() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const { guard } = useTrial();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const q = (params.get('q') ?? '').toLocaleLowerCase(lang);
  const [filter, setFilter] = useState<Filter>('all');
  const [dragOver, setDragOver] = useState(false);
  const courses = useAsync(listCourses, []);

  const all = courses ?? [];
  const shown = all.filter(matches[filter]).filter(
    (c) => !q || c.name.toLocaleLowerCase(lang).includes(q) || c.pdfs.some((p) => p.title.toLocaleLowerCase(lang).includes(q)),
  );
  const totalPdfs = all.reduce((a, c) => a + c.pdfs.length, 0);
  const totalHours = Math.round(all.reduce((a, c) => a + courseStats(c).minutes, 0) / 60);

  const addCourse = () => toast(t('k165'));
  const onDrop = (e: DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    guard('pdf', () => toast(t('k165')));
  };

  return (
    <main className={s.main}>
      <div className={s.head}>
        <TopBar />
        <span className={s.titleBox}>
          <h1 className={s.title}>
            {t('k48')} <span>{t('k101')}</span>
          </h1>
          <span className={s.summary}>{courses && termSummary(all.length, totalPdfs, totalHours, lang)}</span>
        </span>
      </div>

      <div className={s.filters}>
        {FILTERS.map(([f, key]) => (
          <button key={f} aria-pressed={filter === f} className={filter === f ? `${s.chip} ${s.chipOn}` : s.chip} onClick={() => setFilter(f)}>
            {t(key)}
          </button>
        ))}
        <span className={s.grow} />
        <button className={s.add} onClick={addCourse}>
          <Icon name="plus" size={18} />
          {t('k107')}
        </button>
      </div>

      <div className={s.grid}>
        {shown.map((c) => {
          const col = COURSE_COLOR[c.color];
          const st = courseStats(c);
          const next = c.pdfs.find((p) => p.read < 100) ?? c.pdfs[0];
          return (
            <div key={c.id} className={s.card}>
              <span className={s.stripe} style={{ background: col.main }} />
              <Link to={`/courses/${c.id}`} className={s.cardHead}>
                <span className={s.folder} style={{ background: col.soft, color: col.main }}>
                  <Icon name="folder" size={24} />
                </span>
                <span className={s.cardTitle}>
                  <b>{c.name}</b>
                  <span className="mono">
                    {pdfCount(c.pdfs.length, lang)} · {duration(st.minutes, lang)}
                  </span>
                </span>
              </Link>
              <div className={s.progress}>
                <span className={s.bar}>
                  <span style={{ width: `${st.pct}%`, background: col.main }} />
                </span>
                <b>{percent(st.pct, lang)}</b>
              </div>
              <div className={s.tags}>
                {c.examDate && <span>{examLabel(c.examKind, c.examDate, lang)}</span>}
                {c.rank !== undefined && <span>{rank(c.rank, lang)}</span>}
              </div>
              <div className={s.actions}>
                <button className={s.continue} onClick={() => navigate(next ? `/reader?course=${c.id}&pdf=${next.id}` : `/courses/${c.id}`)}>
                  {t('k111')}
                </button>
                <button className={s.prep} onClick={() => navigate(`/quiz?course=${c.id}`)}>
                  {t('k112')}
                </button>
              </div>
            </div>
          );
        })}

        {courses && shown.length === 0 && <div className={s.empty}>{t('noResults')}</div>}

        <button
          className={dragOver ? `${s.drop} ${s.dropOn}` : s.drop}
          onClick={addCourse}
          onDragOver={(e) => {
            e.preventDefault();
            setDragOver(true);
          }}
          onDragLeave={() => setDragOver(false)}
          onDrop={onDrop}
        >
          <span className={s.dropIcon}>
            <Icon name="plus" size={22} />
          </span>
          {t('k127')}
          <small>{t('k128')}</small>
        </button>
      </div>
    </main>
  );
}
