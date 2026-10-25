import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import { getRecording, type Recording as Rec } from '../api/recording';
import { clock } from '../speech/transcribe';
import s from './Recording.module.css';

// Design: design/ScrAudio.dc.html, "Ders ses kaydı": the player, what the lecturer stressed (time per topic, repeats,
// "sınavda çıkar" moments) and the full text with times, each part linked to its PDF page.

export default function Recording() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const id = params.get('id') ?? '';
  const [rec, setRec] = useState<Rec | null | undefined>(undefined);
  const audio = useRef<HTMLAudioElement>(null);
  const [now, setNow] = useState(0);
  const [speed, setSpeed] = useState(1);

  // Load, and again every 4 seconds while the server is still matching.
  useEffect(() => {
    let alive = true;
    let timer: ReturnType<typeof setTimeout>;
    const load = async () => {
      const r = await getRecording(id);
      if (!alive) return;
      setRec(r);
      if (r && (r.status === 'processing' || r.status === 'uploaded')) timer = setTimeout(load, 4000);
    };
    load();
    return () => {
      alive = false;
      clearTimeout(timer);
    };
  }, [id]);

  const seek = (sec: number) => {
    if (!audio.current) return toast(t('rec_noSound'));
    audio.current.currentTime = sec;
    audio.current.play().catch(() => {});
  };
  const pageAt = (sec: number) => rec?.parts.find((p) => sec >= p.start && sec < p.end)?.page ?? 0;
  const readerLink = (page: number) => (rec?.pdf ? `/reader?course=${rec.pdf.courseId ?? ''}&pdf=${rec.pdf.id}${page ? `&page=${page}` : ''}` : '/courses');

  if (rec === undefined) return <main className={s.main} />;
  if (rec === null)
    return (
      <main className={s.main}>
        <p className={s.muted}>{t('noResults')}</p>
      </main>
    );

  const working = rec.status === 'processing' || rec.status === 'uploaded';
  const maxMin = Math.max(1, ...rec.topics.map((x) => x.minutes));
  return (
    <main className={s.main}>
      <div className={s.head}>
        <button className={s.round} aria-label={t('back')} onClick={() => navigate(-1)}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <span className={s.headText}>
          <h1>{t('rec_page')}</h1>
          <span>{rec.pdf ? `${rec.pdf.title} · ${clock(rec.seconds)}` : clock(rec.seconds)}</span>
        </span>
      </div>

      {working && <p className={s.note}>{t('rec_matching')}</p>}
      {rec.status === 'failed' && <p className={s.warn}>{t('rec_failed')}</p>}

      <div className={s.grid}>
        <div className={s.left}>
          <section className={s.card}>
            {rec.audioUrl ? (
              <>
                <audio
                  ref={audio}
                  src={rec.audioUrl}
                  controls
                  preload="metadata"
                  className={s.audio}
                  onTimeUpdate={(e) => setNow(e.currentTarget.currentTime)}
                />
                <div className={s.speeds}>
                  {[1, 1.25, 1.5, 2].map((x) => (
                    <button
                      key={x}
                      aria-pressed={speed === x}
                      className={speed === x ? s.on : ''}
                      onClick={() => {
                        setSpeed(x);
                        if (audio.current) audio.current.playbackRate = x;
                      }}
                    >
                      {num(x, lang)}×
                    </button>
                  ))}
                </div>
              </>
            ) : (
              <span className={s.muted}>{t('rec_textOnly')}</span>
            )}
            <span className={s.small}>{t('rec_note')}</span>
          </section>

          {rec.quotes.length > 0 && (
            <section className={s.card}>
              <h2>{t('rec_stress')}</h2>
              {rec.quotes.map((q, i) => (
                <button key={i} className={s.quote} onClick={() => seek(q.at)}>
                  <span className={q.kind === 'exam' ? s.tagExam : s.tagStress}>{t(q.kind === 'exam' ? 'rec_saidExam' : 'rec_stressed')}</span>
                  <span className={s.quoteText}>“{q.text}”</span>
                  <span className={`mono ${s.time}`}>{clock(q.at)}</span>
                </button>
              ))}
            </section>
          )}

          {rec.topics.length > 0 && (
            <section className={s.card}>
              <h2>{t('rec_time')}</h2>
              {rec.topics.map((x) => (
                <div key={x.topic_id} className={s.topic}>
                  <span className={s.topicText}>
                    <b>{x.title}</b>
                    <span>
                      {num(Math.round(x.minutes), lang)}
                      {t('rec_min')}
                      {x.repeats > 1 ? ` · ${num(x.repeats, lang)}${t('rec_repeats')}` : ''}
                      {x.said_exam ? ` · ${t('rec_saidExam')}` : ''}
                    </span>
                  </span>
                  <span className={s.barBg}>
                    <span className={x.said_exam ? s.barExam : s.bar} style={{ width: `${Math.round((x.minutes / maxMin) * 100)}%` }} />
                  </span>
                </div>
              ))}
              {rec.pdf?.courseId && (
                <Link to={`/quiz?course=${rec.pdf.courseId}&tab=quiz`} className={s.examBtn}>
                  {t('rec_examBtn')}
                </Link>
              )}
            </section>
          )}
        </div>

        <section className={`${s.card} ${s.textCard}`}>
          <h2>{t('rec_text')}</h2>
          {rec.segments.map((x, i) => {
            const page = pageAt(x.start);
            const newPage = page && page !== pageAt(rec.segments[i - 1]?.start ?? -1);
            const on = now >= x.start && now < x.end;
            return (
              <div key={i}>
                {newPage ? (
                  <Link to={readerLink(page)} className={`mono ${s.pageTag}`}>
                    {t('rec_pdfPage').replace('{n}', num(page, lang))}
                  </Link>
                ) : null}
                <button className={on ? `${s.line} ${s.lineOn}` : s.line} onClick={() => seek(x.start)}>
                  <span className={`mono ${s.time}`}>{clock(x.start)}</span>
                  <span>{x.text}</span>
                </button>
              </div>
            );
          })}
        </section>
      </div>
    </main>
  );
}
