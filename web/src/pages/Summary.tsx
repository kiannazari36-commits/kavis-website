import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import Icon from '../components/Icon';
import { useAsync } from '../hooks/useAsync';
import { dirOf } from '../settings/SettingsProvider';
import { lessonRecap, lessonSummaryData, type RecapPoint } from '../api/summary';
import s from './Summary.module.css';

// Design: design/ScrReview.dc.html, tab "Bu ders" (Ders özeti), opened after the last section of a lesson:
// the lesson's weak topics, the words the student tapped, a short review summary from the PDF (with its pages),
// and the way on: cards, the lesson's questions, back to the pages.
export default function Summary() {
  const { t, lang } = useI18n();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const pdfId = params.get('pdf') ?? '';
  const courseId = params.get('course') ?? '';
  const data = useAsync(() => lessonSummaryData(pdfId, lang), [pdfId, lang]);
  const [recap, setRecap] = useState<{ points: RecapPoint[]; lang: string } | { error: string } | null>(null);
  useEffect(() => {
    if (pdfId) lessonRecap(pdfId).then(setRecap);
  }, [pdfId]);

  const reader = (page?: number | null) => navigate(`/reader?course=${courseId}&pdf=${pdfId}${page ? `&page=${page}` : ''}`);
  const pg = (a: number, b?: number) => (b && b !== a ? `${t('pageAbbr')} ${num(a, lang)}–${num(b, lang)}` : `${t('pageAbbr')} ${num(a, lang)}`);
  const date = data?.scoredOn ? new Date(data.scoredOn).toLocaleDateString(lang === 'tr' ? 'tr-TR' : lang, { day: 'numeric', month: 'long' }) : '';
  const sub = [data?.title, data?.score != null ? `${t('lsExam')} ${num(data.score, lang)}/100` : '', date].filter(Boolean).join(' · ');

  return (
    <main className={s.main}>
      <div className={s.head}>
        <button className={s.round} aria-label={t('back')} onClick={() => navigate(-1)}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <div className={s.titles}>
          <h1>{t('lessonSummary')}</h1>
          <span className="mono">{sub.toLocaleUpperCase(lang)}</span>
        </div>
      </div>

      <div className={s.grid}>
        <section className={s.card}>
          <h2>
            <span className={s.chip}>
              <Icon name="target" size={16} />
            </span>
            {t('lsWeak')}
            {data && data.weak.length > 0 && <span className={s.count}>{num(data.weak.length, lang)}</span>}
          </h2>
          {data && !data.weak.length && <p className={s.muted}>{t('lsNoWeak')}</p>}
          {data?.weak.map((w) => (
            <button key={w.id} className={s.weak} onClick={() => reader(w.page)}>
              <span className={s.weakText}>
                <b dir="auto">{w.title}</b>
                {w.page && <span className="mono">{pg(w.page)}</span>}
              </span>
              <span className={s.weakMeta}>
                <span className={w.sure ? `${s.tag} ${s.tagBad}` : s.tag}>{t(w.sure ? 'lsSure' : 'lsWrongTag')}</span>
                <span className={s.meter}>
                  <span style={{ width: `${w.mastery}%` }} />
                </span>
                <span className="mono">%{num(w.mastery, lang)}</span>
              </span>
            </button>
          ))}
        </section>

        <section className={s.card}>
          <h2>
            <span className={s.chip}>
              <Icon name="book" size={16} />
            </span>
            {t('lsWords')}
          </h2>
          {data && !data.words.length && <p className={s.muted}>{t('lsNoWords')}</p>}
          {data?.words.map((w) => (
            <div key={w.word} className={s.word} dir="auto">
              <b>{w.word}</b>
              <span>{w.text}</span>
              <span className="mono">×{num(w.taps, lang)}</span>
            </div>
          ))}
        </section>

        <section className={`${s.card} ${s.recap}`}>
          <span className={`mono ${s.recapT}`}>{t('lsRecap')}</span>
          {!recap && <p className={s.muted}>{t('lsMaking')}</p>}
          {recap && 'error' in recap && (
            <p className={s.muted}>{t(recap.error === 'locked' ? 'trialLocked' : recap.error === 'budget' ? 'askBudget' : 'askFailed')}</p>
          )}
          {recap && 'points' in recap && (
            <ul lang={recap.lang} dir={dirOf(recap.lang as never)}>
              {recap.points.map((p, i) => (
                <li key={i} className={p.weak ? s.weakPoint : undefined}>
                  {p.weak && <span className={s.weakMark}>{t('lsWeakMark')}</span>}
                  {p.text}{' '}
                  <button className={`mono ${s.pageLink}`} onClick={() => reader(p.page_from)}>
                    {pg(p.page_from, p.page_to)}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>

      <div className={s.actions}>
        <button className={s.pri} onClick={() => navigate(`/quiz?from=reader&course=${courseId}&pdf=${pdfId}&pf=1&pt=${data?.pages ?? 9999}`)}>
          {t('lsQuiz')}
        </button>
        <button className={s.ghost} onClick={() => navigate(`/cards?pdf=${pdfId}`)}>
          {t('cardsTitle')}
        </button>
        <button className={s.ghost} onClick={() => reader()}>
          {t('lsRead')}
        </button>
      </div>
    </main>
  );
}
