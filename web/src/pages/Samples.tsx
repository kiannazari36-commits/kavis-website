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
  setStyleUse,
  type QuestionType,
  type TeacherStyle,
} from '../api/samples';
import { useTrial } from '../trial/TrialProvider';
import s from './Samples.module.css';

// Design: design/NewQuestions.dc.html, "Soru örneklerim": choose the course, add sample questions (photo, PDF or typed;
// optional), then the server finds their style (question types, topics asked most, patterns); a switch decides
// whether exam questions follow it; "Bu tarzda yeni sorular" makes the course's exam pack in that style.

const TYPES: QuestionType[] = ['case', 'side_effects', 'dose', 'knowledge', 'structure'];
// The style is used only for exam questions (cards and summaries stay as the lesson text says).
const USES = [['use_in_quizzes', 'useInQuizzes', 'smp_useQuiz']] as const;

export default function Samples() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const { guard } = useTrial();
  const [params] = useSearchParams();
  const courses = useAsync(listCourses, []) ?? [];
  const [picked, setPicked] = useState<string | null>(params.get('course'));
  const courseId = picked ?? courses[0]?.id ?? '';
  const [reload, setReload] = useState(0);
  const samples = useAsync(() => (courseId ? listSamples(courseId) : Promise.resolve([])), [courseId, reload]) ?? [];
  const saved = useAsync(() => (courseId ? getStyle(courseId) : Promise.resolve(null)), [courseId, reload]);
  const [style, setStyle] = useState<{ course: string; v: TeacherStyle } | null>(null);
  const current = style?.course === courseId ? style.v : saved;
  const photoIn = useRef<HTMLInputElement>(null);
  const pdfIn = useRef<HTMLInputElement>(null);
  const [writing, setWriting] = useState(false);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState<'add' | 'analyze' | 'make' | null>(null);

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
      const r = await generateExamPack(courseId);
      setBusy(null);
      if ('error' in r) return toast(t(r.error === 'locked' ? 'trialQFull' : r.error === 'budget' ? 'askBudget' : 'smp_failed'));
      toast(t('smp_made').replace('{n}', num(r.questions, lang)));
      navigate(`/quiz?course=${courseId}&tab=quiz`);
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
          </section>

          <section className={s.card}>
            <span className={s.label}>{t('smp_list')}</span>
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
            <button className={samples.length ? s.pri : `${s.pri} ${s.off}`} aria-busy={busy === 'analyze'} onClick={analyze}>
              {busy === 'analyze' ? t('smp_analyzing') : t(current ? 'smp_reanalyze' : 'smp_analyze')}
            </button>
          </section>
        </div>

        <section className={`${s.card} ${s.style}`}>
          <h2>{t('smp_style')}</h2>
          {!current ? (
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
          )}
          <button className={s.make} aria-busy={busy === 'make'} onClick={make} disabled={!courseId || busy === 'make'}>
            <Icon name="spark" size={16} />
            {busy === 'make' ? t('smp_making') : t('smp_makeBtn')}
          </button>
          <span className={s.small}>{t('smp_makeNote')}</span>
        </section>
      </div>
    </main>
  );
}
