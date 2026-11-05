import { useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon, { type IconName } from '../components/Icon';
import { useAsync } from '../hooks/useAsync';
import { listCourses } from '../api/courses';
import {
  addSampleFiles,
  addSampleText,
  analyzeStyle,
  deleteSample,
  generateExamPack,
  getStyle,
  listSamples,
  type ExamFormat,
  type StyleFormat,
  makeExamSummary,
  setStyleUse,
  type QuestionType,
  type TeacherStyle,
} from '../api/samples';
import { useTrial } from '../trial/TrialProvider';
import s from './Samples.module.css';

// Design: design/NewQuestions.dc.html, "Soru örneklerim": choose the course, add sample questions (photo, PDF or typed;
// optional), then the server finds their style (question types, topics asked most, patterns); a switch decides
// whether exam questions follow it; "Bu tarzda yeni sorular" makes the course's exam pack in that style.

const FORMATS: StyleFormat[] = ['multiple_choice', 'fill_blank', 'true_false', 'calculation', 'other'];
// Formats the student can ask for; none chosen = the lecturer's own formats.
const CHOICES: ExamFormat[] = ['multiple_choice', 'fill_blank', 'true_false', 'calculation'];
const TYPES: QuestionType[] = ['case', 'side_effects', 'dose', 'knowledge', 'structure'];
// The style is used only for exam questions (cards and summaries stay as the lesson text says).
const USES = [['use_in_quizzes', 'useInQuizzes', 'smp_useQuiz']] as const;

/** The page (/samples) with its course chips, or — with `courseId` — the course page's "Sınava hazırlık" tab. */
export default function Samples({ courseId: fixed }: { courseId?: string } = {}) {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const { guard } = useTrial();
  const [params] = useSearchParams();
  const courses = useAsync(listCourses, []) ?? [];
  const [picked, setPicked] = useState<string | null>(params.get('course'));
  // Opened without a course (e.g. from the home page): the student picks it first, so samples never land in a
  // course by chance (only one course: that one).
  const courseId = fixed ?? picked ?? (courses.length === 1 ? courses[0].id : '');
  const [reload, setReload] = useState(0);
  const samples = useAsync(() => (courseId ? listSamples(courseId) : Promise.resolve([])), [courseId, reload]) ?? [];
  const saved = useAsync(() => (courseId ? getStyle(courseId) : Promise.resolve(null)), [courseId, reload]);
  const [style, setStyle] = useState<{ course: string; v: TeacherStyle } | null>(null);
  const current = style?.course === courseId ? style.v : saved;
  const photoIn = useRef<HTMLInputElement>(null);
  const pdfIn = useRef<HTMLInputElement>(null);
  const [writing, setWriting] = useState(false);
  const [text, setText] = useState('');
  const [wanted, setWanted] = useState<ExamFormat[]>([]);
  const [busy, setBusy] = useState<'add' | 'analyze' | 'make' | 'summary' | 'brief' | null>(null);

  const addFiles = async (list: FileList | null) => {
    const files = [...(list ?? [])].filter((f) => f.size <= 15 * 1048576);
    if (!files.length) return toast(t('smp_badFile'));
    setBusy('add');
    const ok = await addSampleFiles(courseId, files);
    setBusy(null);
    toast(t(ok ? 'smp_added' : 'smp_failed'));
    setReload((n) => n + 1);
  };
  const addText = async () => {
    if (text.trim().length < 20) return toast(t('smp_tooShort'));
    setBusy('add');
    const ok = await addSampleText(courseId, t('smp_typed'), text);
    setBusy(null);
    if (ok) {
      setText('');
      setWriting(false);
    }
    toast(t(ok ? 'smp_added' : 'smp_failed'));
    setReload((n) => n + 1);
  };
  const analyze = () =>
    guard('generate', async () => {
      if (!samples.length) return toast(t('smp_needSample'));
      setBusy('analyze');
      const r = await analyzeStyle(courseId);
      setBusy(null);
      if ('error' in r) return toast(t(r.error === 'locked' ? 'trialQFull' : r.error === 'budget' ? 'askBudget' : 'smp_failed'));
      setStyle({ course: courseId, v: r });
      setReload((n) => n + 1);
    });
  const make = () =>
    guard('generate', async () => {
      setBusy('make');
      const r = await generateExamPack(courseId, [], wanted);
      setBusy(null);
      if ('error' in r) return toast(t(r.error === 'locked' ? 'trialQFull' : r.error === 'budget' ? 'askBudget' : 'smp_failed'));
      toast(t('smp_made').replace('{n}', num(r.questions, lang)));
      navigate(`/quiz?course=${courseId}&tab=quiz`);
    });
  const summary = courses.find((c) => c.id === courseId)?.summary;
  const brief = courses.find((c) => c.id === courseId)?.brief;
  const makeSummary = (mode: 'full' | 'brief' = 'full') =>
    guard('generate', async () => {
      if (!samples.length) return toast(t('smp_needSample'));
      setBusy(mode === 'brief' ? 'brief' : 'summary');
      const r = await makeExamSummary(courseId, mode);
      setBusy(null);
      if ('error' in r) return toast(t(r.error === 'mismatch' ? 'smp_sumMismatch' : r.error === 'locked' ? 'trialQFull' : r.error === 'budget' ? 'askBudget' : 'smp_failed'));
      navigate(`/reader?course=${courseId}&pdf=${r.materialId}`);
    });
  const toggle = (field: (typeof USES)[number][0], key: (typeof USES)[number][1]) => {
    if (!current) return;
    const v = { ...current, [key]: !current[key] };
    setStyle({ course: courseId, v });
    setStyleUse(courseId, field, v[key]);
  };

  const methods: [IconName, string, () => void][] = [
    ['camera', 'smp_photo', () => photoIn.current?.click()],
    ['file', 'smp_pdf', () => pdfIn.current?.click()],
    ['pen', 'smp_text', () => setWriting(!writing)],
  ];

  const addBlock = (
    <>
      <div className={s.methods}>
        {methods.map(([icon, key, go]) => (
          <button key={key} onClick={go} disabled={!courseId || busy === 'add'}>
            <span className={s.methodIcon}>
              <Icon name={icon} size={21} />
            </span>
            {t(key)}
          </button>
        ))}
      </div>
      <input ref={photoIn} type="file" accept="image/jpeg,image/png,image/webp" multiple hidden onChange={(e) => (addFiles(e.target.files), (e.target.value = ''))} />
      <input ref={pdfIn} type="file" accept="application/pdf,.pdf" multiple hidden onChange={(e) => (addFiles(e.target.files), (e.target.value = ''))} />
      {writing && (
        <div className={s.write}>
          <textarea value={text} onChange={(e) => setText(e.target.value)} placeholder={t('smp_textHint')} rows={7} />
          <button className={s.pri} onClick={addText} disabled={busy === 'add'}>
            {t('smp_save')}
          </button>
        </div>
      )}
    </>
  );

  const listBlock = (
    <>
      {samples.length === 0 && <span className={s.muted}>{t('smp_empty')}</span>}
      {samples.map((x) => (
        <div key={x.id} className={s.sample}>
          <span className={`mono ${s.badge}`}>{x.kind === 'photo' ? t('smp_kPhoto') : x.kind === 'pdf' ? 'PDF' : t('smp_kText')}</span>
          <span className={s.sampleText}>
            <b dir="auto">{x.title || t('smp_typed')}</b>
            <span>{x.questions !== null ? t('smp_count').replace('{n}', num(x.questions, lang)) : t('smp_notRead')}</span>
          </span>
          <button
            className={s.del}
            aria-label={t('lessonDelete')}
            onClick={async () => {
              await deleteSample(x.id);
              setReload((n) => n + 1);
            }}
          >
            <Icon name="trash" size={15} />
          </button>
        </div>
      ))}
    </>
  );

  const analyzeBtn = (
    <button className={samples.length ? s.pri : `${s.pri} ${s.off}`} aria-busy={busy === 'analyze'} onClick={analyze}>
      {busy === 'analyze' ? t('smp_analyzing') : t(current ? 'smp_reanalyze' : 'smp_analyze')}
    </button>
  );

  const styleBlock = !current ? (
    <span className={s.muted}>{t('smp_noStyle')}</span>
  ) : (
    <>
      <span className={s.muted}>{t('smp_from').replace('{n}', num(current.questions, lang))}</span>
      {TYPES.filter((k) => current.types[k] > 0)
        .sort((a, b) => current.types[b] - current.types[a])
        .map((k) => (
          <div key={k} className={s.type}>
            <span className={s.typeText}>
              <b>{t(`style_${k}`)}</b>
              <span className="mono">%{num(current.types[k], lang)}</span>
            </span>
            <span className={s.barBg}>
              <span className={s.bar} style={{ width: `${current.types[k]}%` }} />
            </span>
          </div>
        ))}
      {FORMATS.some((k) => (current.formats[k] ?? 0) > 0) && <span className={s.label}>{t('smp_formats')}</span>}
      {FORMATS.filter((k) => (current.formats[k] ?? 0) > 0)
        .sort((a, b) => (current.formats[b] ?? 0) - (current.formats[a] ?? 0))
        .map((k) => (
          <div key={k} className={s.type}>
            <span className={s.typeText}>
              <b>{t(`fmt_${k}`)}</b>
              <span className="mono">%{num(current.formats[k] ?? 0, lang)}</span>
            </span>
            <span className={s.barBg}>
              <span className={s.bar} style={{ width: `${current.formats[k] ?? 0}%` }} />
            </span>
          </div>
        ))}
      {current.topTopics.length > 0 && (
        <>
          <span className={s.label}>{t('smp_topics')}</span>
          <div className={s.tags}>
            {current.topTopics.map((x) => (
              <span key={x.title}>
                {x.title} · {num(x.count, lang)}
              </span>
            ))}
          </div>
        </>
      )}
      {current.patterns.length > 0 && (
        <ul className={s.patterns}>
          {current.patterns.map((p) => (
            <li key={p}>{p}</li>
          ))}
        </ul>
      )}
      <span className={s.label}>{t('smp_use')}</span>
      <div className={s.uses}>
        {USES.map(([field, key, label]) => (
          <button key={field} role="switch" aria-checked={current[key]} className={current[key] ? s.useOn : ''} onClick={() => toggle(field, key)}>
            <span className={s.knob} />
            {t(label)}
          </button>
        ))}
      </div>
    </>
  );

  const makeBlock = (
    <>
      <span className={s.label}>{t('smp_formatLabel')}</span>
      <div className={s.chips} role="group" aria-label={t('smp_formatLabel')}>
        {CHOICES.map((k) => (
          <button
            key={k}
            aria-pressed={wanted.includes(k)}
            className={wanted.includes(k) ? s.chipOn : ''}
            onClick={() => setWanted(wanted.includes(k) ? wanted.filter((x) => x !== k) : [...wanted, k])}
          >
            {t(`fmt_${k}`)}
          </button>
        ))}
      </div>
      <span className={s.small}>{t(wanted.length ? 'smp_formatChosen' : 'smp_formatAuto')}</span>
      <button className={s.make} aria-busy={busy === 'make'} onClick={make} disabled={!courseId || busy === 'make'}>
        <Icon name="spark" size={16} />
        {busy === 'make' ? t('smp_making') : t('smp_makeBtn')}
      </button>
      <span className={s.small}>{t('smp_makeNote')}</span>
    </>
  );

  const summaryBlock = (
    <>
      <button className={s.makeAlt} aria-busy={busy === 'summary'} onClick={() => makeSummary()} disabled={!courseId || !!busy}>
        <Icon name="file" size={16} />
        {busy === 'summary' ? t('smp_sumMaking') : t(summary ? 'smp_sumRedo' : 'smp_sumBtn')}
      </button>
      {summary && (
        <button className={s.openSum} onClick={() => navigate(`/reader?course=${courseId}&pdf=${summary.id}`)}>
          {t('smp_sumOpen')}
        </button>
      )}
      <span className={s.small}>{t('smp_sumNote')}</span>
      <button className={s.makeAlt} aria-busy={busy === 'brief'} onClick={() => makeSummary('brief')} disabled={!courseId || !!busy}>
        <Icon name="file" size={16} />
        {busy === 'brief' ? t('smp_briefMaking') : t(brief ? 'smp_briefRedo' : 'smp_briefBtn')}
      </button>
      {brief && (
        <button className={s.openSum} onClick={() => navigate(`/reader?course=${courseId}&pdf=${brief.id}`)}>
          {t('smp_briefOpen')}
        </button>
      )}
      <span className={s.small}>{t('smp_briefNote')}</span>
    </>
  );

  // Course page tab: the same parts as four numbered steps.
  if (fixed)
    return (
      <div className={s.steps}>
        <p className={s.lead}>{t('smp_lead')}</p>
        <div className={s.grid}>
          <section className={s.card}>
            <span className={s.step}>1 · {t('prep_samples')}</span>
            {addBlock}
            {listBlock}
          </section>
          <section className={s.card}>
            <span className={s.step}>2 · {t('prep_style')}</span>
            {styleBlock}
            {analyzeBtn}
          </section>
          <section className={s.card}>
            <span className={s.step}>3 · {t('smp_sumFolder')}</span>
            {summary ? (
              <button className={s.pri} onClick={() => navigate(`/reader?course=${courseId}&pdf=${summary.id}`)}>
                {t('smp_sumOpen')}
              </button>
            ) : null}
            <button className={s.makeAlt} aria-busy={busy === 'summary'} onClick={() => makeSummary()} disabled={!!busy}>
              <Icon name="file" size={16} />
              {busy === 'summary' ? t('smp_sumMaking') : t(summary ? 'smp_sumRedo' : 'smp_sumBtn')}
            </button>
            <span className={s.small}>{t('smp_sumNote')}</span>
            <span className={s.step}>{t('smp_briefFolder')}</span>
            {brief ? (
              <button className={s.pri} onClick={() => navigate(`/reader?course=${courseId}&pdf=${brief.id}`)}>
                {t('smp_briefOpen')}
              </button>
            ) : null}
            <button className={s.makeAlt} aria-busy={busy === 'brief'} onClick={() => makeSummary('brief')} disabled={!!busy}>
              <Icon name="file" size={16} />
              {busy === 'brief' ? t('smp_briefMaking') : t(brief ? 'smp_briefRedo' : 'smp_briefBtn')}
            </button>
            <span className={s.small}>{t('smp_briefNote')}</span>
          </section>
          <section className={s.card}>
            <span className={s.step}>4 · {t('prep_questions')}</span>
            {makeBlock}
            <div className={s.links}>
              <button className={s.makeAlt} onClick={() => navigate(`/quiz?course=${courseId}&tab=quiz`)}>
                {t('prep_solve')}
              </button>
              <button className={s.makeAlt} onClick={() => navigate('/exam')}>
                {t('prep_examCenter')}
              </button>
            </div>
          </section>
        </div>
      </div>
    );

  return (
    <main className={s.main}>
      <div className={s.head}>
        <button className={s.round} aria-label={t('back')} onClick={() => navigate(-1)}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <h1>
          {t('smp_titleA')} <span>{t('smp_titleB')}</span>
        </h1>
      </div>
      <p className={s.lead}>{t('smp_lead')}</p>

      <div className={s.grid}>
        <div className={s.col}>
          <section className={s.card}>
            <span className={s.label}>{t('smp_which')}</span>
            <div className={s.chips}>
              {courses.map((c) => (
                <button key={c.id} aria-pressed={c.id === courseId} className={c.id === courseId ? s.chipOn : ''} onClick={() => setPicked(c.id)}>
                  {c.short ?? c.name}
                </button>
              ))}
            </div>
            {courseId ? addBlock : <span className={s.muted}>{t('smp_pickFirst')}</span>}
          </section>

          {courseId && (
            <section className={s.card}>
              <span className={s.label}>{t('smp_list')}</span>
              {listBlock}
              {analyzeBtn}
            </section>
          )}
        </div>

        {courseId && (
          <section className={`${s.card} ${s.style}`}>
            <h2>{t('smp_style')}</h2>
            {styleBlock}
            {makeBlock}
            {summaryBlock}
          </section>
        )}
      </div>
    </main>
  );
}
