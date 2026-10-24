import { useEffect, useRef, useState, type DragEvent } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import { inspectPdf, lessonStatus, MAX_MB, MAX_PAGES, uploadLesson, UploadFail, type LessonStatus, type PdfInfo } from '../api/upload';
import { listCourses } from '../api/courses';
import { useAsync } from '../hooks/useAsync';
import { useTrial } from '../trial/TrialProvider';
import { TRIAL_LIMITS } from '../api/trial';
import s from './Upload.module.css';

// Design: design/ScrUpload.dc.html — choose the PDF, name and course, "Dersi hazırla", then the preparing steps;
// scanned PDFs (no text) show the error card. Photos and recordings come later (toast).

type Stage = 'pick' | 'noText' | 'processing';
const STEPS = ['up_step0', 'up_step1', 'up_step2', 'up_step3', 'up_step4'];

export default function Upload() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const { trial, guard } = useTrial();
  const courses = useAsync(listCourses, []) ?? [];
  const input = useRef<HTMLInputElement>(null);

  const [stage, setStage] = useState<Stage>('pick');
  const [file, setFile] = useState<File | null>(null);
  const [info, setInfo] = useState<PdfInfo | null>(null);
  const [title, setTitle] = useState('');
  const [courseId, setCourseId] = useState(params.get('course') ?? '');
  const [busy, setBusy] = useState(false);
  const [over, setOver] = useState(false);
  const [lessonId, setLessonId] = useState<string | null>(null);
  const [status, setStatus] = useState<LessonStatus | null>(null);

  // While preparing: ask the server every 4 seconds.
  useEffect(() => {
    if (stage !== 'processing' || !lessonId) return;
    let alive = true;
    const tick = async () => {
      const st = await lessonStatus(lessonId);
      if (!alive || !st) return;
      setStatus(st);
      if (st.status === 'needs_ocr') setStage('noText');
    };
    tick();
    const id = setInterval(tick, 4000);
    return () => {
      alive = false;
      clearInterval(id);
    };
  }, [stage, lessonId]);

  const choose = async (f: File | undefined) => {
    if (!f) return;
    if (f.type !== 'application/pdf' && !f.name.toLowerCase().endsWith('.pdf')) return toast(t('up_notPdf'));
    if (f.size > MAX_MB * 1048576) return toast(t('up_tooBig').replace('{mb}', num(Math.round(f.size / 1048576), lang)));
    setFile(f);
    setInfo(null);
    if (!title) setTitle(f.name.replace(/\.pdf$/i, '').replace(/[_-]+/g, ' ').trim());
    try {
      const i = await inspectPdf(f);
      setInfo(i);
      if (!i.hasText) setStage('noText');
    } catch {
      toast(t('up_notPdf'));
      setFile(null);
    }
  };

  const prepare = () =>
    guard('pdf', async () => {
      if (!file || !info) return toast(t('up_needFile'));
      if (!title.trim()) return toast(t('up_needName'));
      if (info.pages > MAX_PAGES) return toast(t('up_tooLong').replace('{n}', num(info.pages, lang)));
      setBusy(true);
      try {
        const id = await uploadLesson(file, title, courseId || null);
        setLessonId(id);
        setStage('processing');
      } catch (e) {
        const reason = e instanceof UploadFail ? e.reason : 'network';
        toast(reason === 'trial' ? t('trialPdfFull') : reason === 'tooBig' ? t('up_tooBig').replace('{mb}', num(Math.round(file.size / 1048576), lang)) : t('up_failed'));
      }
      setBusy(false);
    });

  const onDrop = (e: DragEvent) => {
    e.preventDefault();
    setOver(false);
    choose(e.dataTransfer.files[0]);
  };

  const head = (
    <div className={s.head}>
      <button className={s.round} aria-label={t('back')} onClick={() => navigate(-1)}>
        <Icon name="back" size={20} width={1.8} className="flip-rtl" />
      </button>
      <h1>{t('up_title')}</h1>
    </div>
  );

  if (stage === 'noText') {
    return (
      <main className={s.main}>
        {head}
        <section className={s.error}>
          <span className={s.errIcon}>
            <Icon name="file" size={28} />
          </span>
          <h2>{t('up_errT')}</h2>
          <p>{t('up_errS')}</p>
          <div className={s.fileRow}>
            <span className={`mono ${s.badge}`}>PDF</span>
            <span className={s.fileText}>
              <b dir="ltr">{file?.name}</b>
              <span className="mono">{t('up_errTag')}</span>
            </span>
          </div>
          <button
            className={s.pri}
            onClick={() => {
              setStage('pick');
              setFile(null);
              setInfo(null);
              input.current?.click();
            }}
          >
            {t('up_other')}
          </button>
          <button className={s.ghost} onClick={() => toast(t('k165'))}>
            {t('up_ocr')}
          </button>
          <small>{t('up_errNote')}</small>
        </section>
      </main>
    );
  }

  if (stage === 'processing') {
    const st = status?.status ?? 'uploaded';
    const ready = st === 'ready';
    // Steps follow the server: uploaded = waiting, processing = working through, ready = all done.
    const done = ready ? STEPS.length : st === 'processing' ? 1 : 0;
    const pct = ready ? 100 : st === 'processing' ? 45 : 8;
    const detail = (i: number) => {
      const x = status?.stats ?? {};
      if (i === 0 && info) return t('up_pages').replace('{n}', num(info.pages, lang)).replace('{mb}', num(info.sizeMb, lang));
      if (i === 1 && x.terms) return num(x.terms, lang);
      if (i === 3 && x.questions) return num(x.questions, lang);
      if (i === 4 && x.cards) return num(x.cards, lang);
      return '';
    };
    return (
      <main className={s.main}>
        {head}
        <section className={s.proc}>
          <div className={s.fileRow}>
            <span className={`mono ${s.badge}`}>PDF</span>
            <span className={s.fileText}>
              <b>{title}</b>
              <span>{courses.find((c) => c.id === courseId)?.name ?? ''}</span>
            </span>
          </div>
          <h2>{ready ? t('up_ready') : t('up_procT')}</h2>
          {st === 'failed' ? <p className={s.warn}>{t('up_processFailed')}</p> : !ready && <p>{t('up_procS')}</p>}
          <ol className={s.steps} aria-live="polite">
            {STEPS.map((k, i) => {
              const state = i < done ? 'done' : i === done && !ready ? 'active' : 'wait';
              return (
                <li key={k} className={s[state]}>
                  <span className={s.dot}>{state === 'done' && <Icon name="check" size={13} width={2.6} />}</span>
                  <span className={s.stepText}>
                    <b>{t(k)}</b>
                    <span>{[detail(i), state === 'done' ? t('up_done') : state === 'active' ? t('up_working') : t('up_wait')].filter(Boolean).join(' · ')}</span>
                  </span>
                </li>
              );
            })}
          </ol>
          <div className={s.bar}>
            <span style={{ width: `${pct}%` }} />
          </div>
          {ready && lessonId && (
            <button className={s.pri} onClick={() => navigate(`/reader?course=${status?.courseId ?? ''}&pdf=${lessonId}`)}>
              {t('up_open')}
            </button>
          )}
        </section>
      </main>
    );
  }

  return (
    <main className={s.main}>
      {head}
      <div className={s.grid}>
        <section
          className={over ? `${s.drop} ${s.dropOn}` : s.drop}
          onDragOver={(e) => (e.preventDefault(), setOver(true))}
          onDragLeave={() => setOver(false)}
          onDrop={onDrop}
        >
          <span className={s.dropIcon}>
            <Icon name="upload" size={28} />
          </span>
          <b>{t('up_dropT')}</b>
          <span>{t('up_drop')}</span>
          <button className={s.pri} onClick={() => input.current?.click()}>
            {t('up_choose')}
          </button>
          <input ref={input} type="file" accept="application/pdf,.pdf" hidden onChange={(e) => choose(e.target.files?.[0])} />
          {file && (
            <div className={s.fileRow}>
              <span className={`mono ${s.badge}`}>PDF</span>
              <span className={s.fileText}>
                <b dir="ltr">{file.name}</b>
                <span>{info ? t('up_pages').replace('{n}', num(info.pages, lang)).replace('{mb}', num(info.sizeMb, lang)) : '…'}</span>
              </span>
            </div>
          )}
          {info && info.pages > MAX_PAGES && <p className={s.warn}>{t('up_tooLong').replace('{n}', num(info.pages, lang))}</p>}
        </section>

        <section className={s.side}>
          <label className={s.field}>
            {t('up_name')}
            <input value={title} onChange={(e) => setTitle(e.target.value)} />
          </label>
          <label className={s.field}>
            {t('up_course')}
            <select value={courseId} onChange={(e) => setCourseId(e.target.value)}>
              <option value="">{t('up_pickCourse')}</option>
              {courses.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          <p className={s.note}>{t('up_note')}</p>
          <button className={file && info && !busy ? s.pri : `${s.pri} ${s.off}`} aria-disabled={!file || !info || busy} onClick={prepare}>
            {busy ? t('up_uploading') : t('up_prepare')}
          </button>
          {!trial.premium && (
            <span className={`mono ${s.quota}`}>
              {t('up_trialLeft').replace('{used}', num(trial.pdfsUsed, lang)).replace('{max}', num(TRIAL_LIMITS.pdfs, lang))}
            </span>
          )}
          <button className={s.alt} onClick={() => toast(t('k165'))}>
            <Icon name="camera" size={18} />
            <span>
              <b>{t('up_noPdf')}</b>
              <small>{t('up_noPdfS')}</small>
            </span>
          </button>
        </section>
      </div>
    </main>
  );
}
