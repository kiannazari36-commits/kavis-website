import { useEffect, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import { useAsync } from '../hooks/useAsync';
import { addRecording, lessonsForRecording } from '../api/recording';
import { lessonStatus } from '../api/upload';
import { clock, decodeAudio, transcribe } from '../speech/transcribe';
import s from './Upload.module.css';

// Design: design/ScrUpload.dc.html, "Ders ses kaydı ekle": which lesson it belongs to, a recording file or a live
// recording in class, what we prepare, then "Metne çevir ve PDF ile eşleştir". The sound becomes text on this
// computer (Whisper in the browser); only the text goes to the server, which matches it to the PDF's pages.

type Stage = 'pick' | 'work';
type Step = 'model' | 'listen' | 'match' | 'ready' | 'failed';
const WHAT = ['rec_what0', 'rec_what1', 'rec_what2', 'rec_what3'];

export default function Record() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const lessons = useAsync(lessonsForRecording, []);
  const [lessonId, setLessonId] = useState(params.get('pdf') ?? '');
  const lesson = lessons?.find((l) => l.id === lessonId) ?? lessons?.[0];
  const fileInput = useRef<HTMLInputElement>(null);

  const [sound, setSound] = useState<Blob | null>(null);
  const [soundName, setSoundName] = useState('');
  // Live recording in class.
  const recorder = useRef<MediaRecorder | null>(null);
  const [recSecs, setRecSecs] = useState<number | null>(null);

  const [stage, setStage] = useState<Stage>('pick');
  const [step, setStep] = useState<Step>('model');
  const [pct, setPct] = useState(0);
  const [recId, setRecId] = useState<string | null>(null);

  useEffect(() => {
    if (recSecs === null) return;
    const id = setInterval(() => setRecSecs((n) => (n === null ? n : n + 1)), 1000);
    return () => clearInterval(id);
  }, [recSecs === null]); // eslint-disable-line react-hooks/exhaustive-deps

  // After sending: ask the server every 4 seconds until the recording is matched.
  useEffect(() => {
    if (step !== 'match' || !recId) return;
    const id = setInterval(async () => {
      const st = await lessonStatus(recId);
      if (st?.status === 'ready') setStep('ready');
      if (st?.status === 'failed') setStep('failed');
    }, 4000);
    return () => clearInterval(id);
  }, [step, recId]);

  const pickFile = (f: File | undefined) => {
    if (!f) return;
    if (!f.type.startsWith('audio/') && !/\.(m4a|mp3|wav|aac)$/i.test(f.name)) return toast(t('rec_notAudio'));
    setSound(f);
    setSoundName(f.name);
  };

  const startLive = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const type = MediaRecorder.isTypeSupported('audio/mp4') ? 'audio/mp4' : 'audio/webm';
      const r = new MediaRecorder(stream, { mimeType: type });
      const parts: Blob[] = [];
      r.ondataavailable = (e) => e.data.size && parts.push(e.data);
      r.onstop = () => {
        stream.getTracks().forEach((x) => x.stop());
        setSound(new Blob(parts, { type }));
        setSoundName(t('rec_liveName'));
        setRecSecs(null);
      };
      r.start(1000);
      recorder.current = r;
      setRecSecs(0);
      toast(t('rec_liveStarted'));
    } catch {
      toast(t('rec_noMic'));
    }
  };
  const stopLive = () => recorder.current?.state === 'recording' && recorder.current.stop();

  const go = async () => {
    if (!lesson) return toast(t('rec_needLesson'));
    if (!sound) return toast(t('rec_needSound'));
    setStage('work');
    setStep('model');
    setPct(0);
    try {
      const { samples, seconds } = await decodeAudio(sound);
      const segments = await transcribe(samples, lesson.language ?? lang, (st, p) => {
        setStep(st === 'download' ? 'model' : 'listen');
        setPct(p);
      });
      if (!segments.length) {
        setStage('pick');
        return toast(t('rec_noSpeech'));
      }
      setStep('match');
      const title = `${lesson.title} · ${t('rec_word')}`;
      setRecId(await addRecording(sound, lesson, title, segments, seconds));
    } catch (e) {
      console.error('recording', e);
      setStage('pick');
      toast(t('rec_failed'));
    }
  };

  const head = (
    <div className={s.head}>
      <button className={s.round} aria-label={t('back')} onClick={() => navigate(-1)}>
        <Icon name="back" size={20} width={1.8} className="flip-rtl" />
      </button>
      <h1>{t('rec_title')}</h1>
    </div>
  );

  if (stage === 'work') {
    const order: Step[] = ['model', 'listen', 'match'];
    const at = step === 'ready' ? 3 : order.indexOf(step);
    const label = ['rec_stepModel', 'rec_stepListen', 'rec_stepMatch'];
    return (
      <main className={s.main}>
        {head}
        <section className={s.proc}>
          <div className={s.fileRow}>
            <span className={`mono ${s.badge}`}>{t('rec_badge')}</span>
            <span className={s.fileText}>
              <b>{lesson?.title}</b>
              <span>{soundName}</span>
            </span>
          </div>
          <h2>{step === 'ready' ? t('rec_ready') : t('rec_working')}</h2>
          {step === 'failed' ? <p className={s.warn}>{t('rec_failed')}</p> : step !== 'ready' && <p>{t('rec_keepOpen')}</p>}
          <ol className={s.steps} aria-live="polite">
            {label.map((k, i) => {
              const state = i < at ? 'done' : i === at && step !== 'failed' ? 'active' : 'wait';
              const detail = state === 'active' && i < 2 ? `%${num(pct, lang)}` : '';
              return (
                <li key={k} className={s[state]}>
                  <span className={s.dot}>{state === 'done' && <Icon name="check" size={13} width={2.6} />}</span>
                  <span className={s.stepText}>
                    <b>{t(k)}</b>
                    <span>{[detail, state === 'done' ? t('up_done') : state === 'active' ? t('up_working') : t('up_wait')].filter(Boolean).join(' · ')}</span>
                  </span>
                </li>
              );
            })}
          </ol>
          <div className={s.bar}>
            <span style={{ width: `${step === 'ready' ? 100 : Math.round((at * 100 + (at < 2 ? pct : 50)) / 3)}%` }} />
          </div>
          {step === 'ready' && recId && (
            <button className={s.pri} onClick={() => navigate(`/recording?id=${recId}`)}>
              {t('rec_open')}
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
        <section className={s.drop}>
          <span className={s.dropIcon}>
            <Icon name="mic" size={28} />
          </span>
          <b>{t('rec_title')}</b>
          <span>{t('rec_s')}</span>
          <div className={s.recBtns}>
            <button className={s.pri} onClick={() => fileInput.current?.click()} disabled={recSecs !== null}>
              {t('rec_file')}
            </button>
            {recSecs === null ? (
              <button className={s.ghost} onClick={startLive}>
                {t('rec_live')}
              </button>
            ) : (
              <button className={s.ghost} onClick={stopLive}>
                <span className="mono">{clock(recSecs)}</span> · {t('rec_stop')}
              </button>
            )}
          </div>
          <input ref={fileInput} type="file" accept="audio/*,.m4a,.mp3,.wav,.aac" hidden onChange={(e) => (pickFile(e.target.files?.[0]), (e.target.value = ''))} />
          {sound && (
            <div className={s.fileRow}>
              <span className={`mono ${s.badge}`}>{t('rec_badge')}</span>
              <span className={s.fileText}>
                <b dir="ltr">{soundName}</b>
                <span>{num(Math.round((sound.size / 1048576) * 10) / 10, lang)} MB</span>
              </span>
            </div>
          )}
          <span className={`mono ${s.photoHead}`}>{t('rec_what')}</span>
          <ul className={s.recWhat}>
            {WHAT.map((k) => (
              <li key={k}>
                <Icon name="check" size={14} width={2.4} />
                {t(k)}
              </li>
            ))}
          </ul>
        </section>

        <section className={s.side}>
          <label className={s.field}>
            {t('rec_which')}
            <select value={lesson?.id ?? ''} onChange={(e) => setLessonId(e.target.value)}>
              {!lessons?.length && <option value="">{t('rec_noLessons')}</option>}
              {(lessons ?? []).map((l) => (
                <option key={l.id} value={l.id}>
                  {l.courseName ? `${l.title} · ${l.courseName}` : l.title}
                </option>
              ))}
            </select>
          </label>
          <p className={s.note}>{t('rec_privacy')}</p>
          <button className={sound && lesson ? s.pri : `${s.pri} ${s.off}`} aria-disabled={!sound || !lesson} onClick={go}>
            {t('rec_cta')}
          </button>
        </section>
      </div>
    </main>
  );
}
