import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { dateRange, num, pdfCount, shortDate } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import Switch from '../components/Switch';
import { daysUntil, listCourses } from '../api/courses';
import type { QuestionKind } from '../api/types';
import { buildExam, EXAM_KINDS, examWeek, readyQuestions, saveExamDays, upcomingExams, type CourseExam, type ExamKindName } from '../api/exam';
import { useAsync } from '../hooks/useAsync';
import { useTrial } from '../trial/TrialProvider';
import type { Course } from '../api/types';
import s from './Exam.module.css';

// Design: design/ScrReview.dc.html, variants "exam" / "examAll" / "setWeek" ("Sınav merkezi"). The exam week from the
// courses' exam days (with "Değiştir" to set it), an exam of one course or of several, the number of questions and
// "Zayıf konulara ağırlık ver". The server puts the exam together from the questions already written for the student's
// lessons (Edge Function build-exam, no AI); it is played on the quiz page (/quiz?quiz=…) and graded like any quiz.
// The design's dark exam card is bordo in light mode (CLAUDE.md: no very dark boxes in light mode).

const COUNTS = [20, 40, 60];
const KIND_KEY: Record<ExamKindName, string> = {
  midterm: 'exMidterm',
  final: 'exFinal',
  makeup: 'exMakeup',
};

export default function Exam() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const { guard } = useTrial();
  const [version, setVersion] = useState(0);
  const courses = useAsync(listCourses, []);
  const exams = useAsync(upcomingExams, [version]);
  const ready = useAsync(readyQuestions, []);
  const [mode, setMode] = useState<'course' | 'all'>('course');
  const [picked, setPicked] = useState<string | null>(null);
  const [allPicked, setAllPicked] = useState<string[] | null>(null);
  const [count, setCount] = useState(40);
  const [weakFocus, setWeakFocus] = useState(true);
  // Which kinds of questions the exam has (the student's choice for this exam).
  const [kinds, setKinds] = useState<QuestionKind[]>(['multiple_choice']);
  const toggleKind = (k: QuestionKind) => {
    if (kinds.includes(k) && kinds.length === 1) return;
    setKinds(kinds.includes(k) ? kinds.filter((x) => x !== k) : [...kinds, k]);
  };
  const [building, setBuilding] = useState(false);
  const [weekOpen, setWeekOpen] = useState(false);

  if (!courses || !exams) return <main className={s.main} />;

  const week = examWeek(exams);
  const selected = picked ?? exams[0]?.courseId ?? courses[0]?.id ?? '';
  const selectedAll = allPicked ?? courses.map((c) => c.id);
  const chosen = mode === 'all' ? selectedAll : selected ? [selected] : [];
  const examDay = (c: Course) => {
    const mine = exams.filter((e) => e.courseId === c.id);
    return (mine.find((e) => e.kind === week?.kind) ?? mine[0])?.date;
  };
  const daysLeft = week ? Math.max(0, daysUntil(week.from)) : null;
  const startName = courses.find((c) => c.id === selected)?.name ?? '';

  const start = () =>
    guard('generate', async () => {
      if (building || !chosen.length) return;
      setBuilding(true);
      const r = await buildExam(chosen, count, weakFocus, kinds);
      setBuilding(false);
      if ('error' in r) return toast(t(r.error === 'empty' ? 'exNone' : 'exFailed'));
      navigate(`/quiz?quiz=${r.quizId}`);
    });

  return (
    <main className={s.main}>
      <div className={s.head}>
        <button className={s.round} aria-label={t('back')} onClick={() => navigate('/home')}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <span className={s.titleBox}>
          <h1>{t('exTitle')}</h1>
          <span className={`mono ${s.sub}`}>{t(week?.kind === 'midterm' || !week ? 'exPrep' : 'exWeekLabel')}</span>
        </span>
      </div>

      <section className={s.week}>
        <span className={s.weekNum}>
          <b>{daysLeft === null ? '–' : num(daysLeft, lang)}</b>
          <span className="mono">{t('exDaysLeft')}</span>
        </span>
        <span className={s.weekText}>
          <span className={`mono ${s.weekLabel}`}>{t('exWeekLabel')}</span>
          {week ? (
            <>
              <b>
                {t(KIND_KEY[week.kind])} · {dateRange(week.from, week.to, lang)}
              </b>
              <span>{t('exFromCal')}</span>
            </>
          ) : (
            <>
              <b>{t('exSetWeek')}</b>
              <span>{t('exSetWeekSub')}</span>
            </>
          )}
        </span>
        <button className={s.weekBtn} onClick={() => setWeekOpen(true)}>
          {t('change')}
        </button>
      </section>

      <div role="radiogroup" aria-label={t('exKind')} className={s.modes}>
        {(
          [
            ['course', 'book', 'exModeCourse', 'exModeCourseSub'],
            ['all', 'list', 'exModeAll', 'exModeAllSub'],
          ] as const
        ).map(([m, icon, title, sub]) => (
          <button
            key={m}
            role="radio"
            aria-checked={mode === m}
            className={mode === m ? `${s.mode} ${s.modeOn}` : s.mode}
            onClick={() => (setMode(m), setCount(m === 'all' ? 60 : 40))}
          >
            <span className={s.modeIcon}>
              <Icon name={icon} size={18} />
            </span>
            <b>{t(title)}</b>
            <span>{t(sub)}</span>
          </button>
        ))}
      </div>

      <section className={s.card}>
        <span className={`mono ${s.label}`}>{t(mode === 'all' ? 'exPickAll' : 'exPickOne')}</span>
        {courses.length === 0 && <p className={s.muted}>{t('exNoCourses')}</p>}
        {courses.map((c) => {
          const on = mode === 'all' ? selectedAll.includes(c.id) : selected === c.id;
          const day = examDay(c);
          return (
            <button
              key={c.id}
              role={mode === 'all' ? 'checkbox' : 'radio'}
              aria-checked={on}
              className={s.row}
              onClick={() => (mode === 'all' ? setAllPicked(on ? selectedAll.filter((x) => x !== c.id) : [...selectedAll, c.id]) : setPicked(c.id))}
            >
              <span className={`${s.mark} ${mode === 'all' ? s.markBox : ''} ${on ? s.markOn : ''}`}>
                {on && <Icon name="check" size={12} width={3} />}
              </span>
              <span className={s.rowText}>
                <b>{c.name}</b>
                <span className="mono">
                  {pdfCount(c.pdfs.length, lang)} · {num(ready?.[c.id] ?? 0, lang)} {t('exReady')}
                </span>
              </span>
              {day && <span className={`mono ${s.day} ${on ? s.dayOn : ''}`}>{shortDate(day, lang)}</span>}
            </button>
          );
        })}
      </section>

      <section className={s.card}>
        <div className={s.opt}>
          <span>{t('exCount')}</span>
          <div role="radiogroup" aria-label={t('exCount')} className={s.seg}>
            {COUNTS.map((n) => (
              <button key={n} role="radio" aria-checked={count === n} className={count === n ? s.segOn : ''} onClick={() => setCount(n)}>
                {num(n, lang)}
              </button>
            ))}
          </div>
        </div>
        <div className={s.opt}>
          <span>{t('pickKinds')}</span>
          <div role="group" aria-label={t('pickKinds')} className={s.seg}>
            {(['multiple_choice', 'fill_blank', 'written'] as const).map((k) => (
              <button key={k} aria-pressed={kinds.includes(k)} className={kinds.includes(k) ? s.segOn : ''} onClick={() => toggleKind(k)}>
                {t(`kind_${k}`)}
              </button>
            ))}
          </div>
        </div>
        <div className={s.opt}>
          <span className={s.optText}>
            {t('exWeak')}
            <small>{t('exWeakSub')}</small>
          </span>
          <Switch on={weakFocus} onChange={setWeakFocus} label={t('exWeak')} />
        </div>
      </section>

      <button className={s.start} aria-busy={building} disabled={building || !chosen.length} onClick={start}>
        {building ? t('exBuilding') : mode === 'all' ? t('exStartAll') : t('exStartOne').replace('{c}', startName)}
      </button>

      {weekOpen && (
        <WeekDialog
          courses={courses}
          exams={exams}
          initial={week?.kind ?? 'midterm'}
          onClose={(saved) => {
            setWeekOpen(false);
            if (saved) setVersion((v) => v + 1);
          }}
        />
      )}
    </main>
  );
}

/** "Sınav haftanı gir" (design "setWeek"): the exam kind and each course's day. */
function WeekDialog({
  courses,
  exams,
  initial,
  onClose,
}: {
  courses: Course[];
  exams: CourseExam[];
  initial: ExamKindName;
  onClose: (saved: boolean) => void;
}) {
  const { t } = useI18n();
  const toast = useToast();
  const [kind, setKind] = useState<ExamKindName>(initial);
  const [days, setDays] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  // Each course starts with its upcoming exam of this kind.
  useEffect(() => {
    setDays(Object.fromEntries(exams.filter((e) => e.kind === kind).map((e) => [e.courseId, e.date])));
  }, [kind, exams]);
  const save = async () => {
    setSaving(true);
    const ok = await saveExamDays(kind, days, exams);
    setSaving(false);
    toast(t(ok ? 'exSaved' : 'exSaveFailed'));
    if (ok) onClose(true);
  };
  return (
    <div className={s.modal}>
      <div className={s.scrim} onClick={() => onClose(false)} />
      <section role="dialog" aria-modal="true" aria-labelledby="week-title" className={s.dialog}>
        <div className={s.dialogHead}>
          <span>
            <b id="week-title">{t('exSetWeek')}</b>
            <small>{t('exSetWeekSub')}</small>
          </span>
          <button className={s.round} aria-label={t('exCloseBtn')} onClick={() => onClose(false)}>
            <Icon name="close" size={18} />
          </button>
        </div>
        <div role="radiogroup" aria-label={t('exKind')} className={s.seg}>
          {EXAM_KINDS.map((k) => (
            <button key={k} role="radio" aria-checked={kind === k} className={kind === k ? s.segOn : ''} onClick={() => setKind(k)}>
              {t(KIND_KEY[k])}
            </button>
          ))}
        </div>
        <span className={`mono ${s.label}`}>{t('exPerCourse')}</span>
        <div className={s.dayList}>
          {courses.map((c) => (
            <label key={c.id} className={s.dayRow}>
              <span>{c.name}</span>
              <input type="date" value={days[c.id] ?? ''} onChange={(e) => setDays({ ...days, [c.id]: e.target.value })} />
            </label>
          ))}
        </div>
        <button className={s.start} aria-busy={saving} disabled={saving} onClick={save}>
          {t('exSave')}
        </button>
      </section>
    </div>
  );
}
