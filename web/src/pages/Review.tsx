import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { duration, num, pagesShort } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import { useAsync } from '../hooks/useAsync';
import { dirOf } from '../settings/SettingsProvider';
import { rateCard } from '../api/cards';
import { saveAttempt } from '../api/quiz';
import { setReview } from '../api/plan';
import { getReview, reviewCards, reviewQuestions } from '../api/review';
import { lessonRecap, lessonSummaryData, type RecapPoint } from '../api/summary';
import type { FlashCard } from '../api/types';
import s from './Review.module.css';

// Design: design/NewRevise.dc.html ("Bugünün tekrarı"): 1 summary made for the student → 2 cards (Biliyorum / Tekrar sor)
// → 3 short questions → result. "Sonra devam et" leaves without finishing; "Bitir" closes today's review.

const LETTERS = ['A', 'B', 'C', 'D', 'E'];
type Step = 0 | 1 | 2 | 3;

export default function Review() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const id = params.get('id') ?? '';
  const review = useAsync(() => getReview(id), [id]);
  const materialId = review?.materialId ?? '';
  const data = useAsync(() => (materialId ? lessonSummaryData(materialId, lang) : Promise.resolve(null)), [materialId, lang]);
  const cards = useAsync(() => (review ? reviewCards(review) : Promise.resolve(null)), [review]);
  const qpack = useAsync(() => (review ? reviewQuestions(review) : Promise.resolve(null)), [review]);
  const [recap, setRecap] = useState<{ points: RecapPoint[]; lang: string } | { error: string } | null>(null);
  useEffect(() => {
    if (materialId) lessonRecap(materialId).then(setRecap);
  }, [materialId]);

  const [step, setStep] = useState<Step>(0);
  const [ci, setCi] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [known, setKnown] = useState<Record<number, 'y' | 'n'>>({});
  const [qi, setQi] = useState(0);
  const [ans, setAns] = useState<Record<number, number>>({});
  const [saved, setSaved] = useState(false);

  if (review === undefined || cards === undefined || qpack === undefined) return <main className={s.main} />;
  if (!review || review.status === 'done') {
    return (
      <main className={s.main}>
        <Header onBack={() => navigate('/home')} title={t('rvTitle')} sub="" back={t('rvBack')} later={t('rvLater')} />
        <p className={s.muted}>{t(review ? 'rvNoReview' : 'rvLoadFail')}</p>
      </main>
    );
  }

  const cardList: FlashCard[] = cards ?? [];
  const qs = qpack?.questions ?? [];
  const card = cardList[ci];
  const q = qs[qi];
  const cl = card?.lang ?? 'tr';
  const knownN = cardList.filter((_, i) => known[i] === 'y').length;
  const rightN = qs.filter((x, i) => ans[i] === x.answer).length;
  const weakTopics = data?.weak ?? [];
  const points = recap && 'points' in recap ? recap.points : [];
  const rlang = recap && 'lang' in recap ? (recap.lang as typeof lang) : lang;
  const sureN = weakTopics.filter((w) => w.sure).length;
  const sub = [review.title, `~${duration(review.minutes, lang)}`].filter(Boolean).join(' · ');
  const pg = (a: number, b: number) => pagesShort(a, b, rlang);

  const afterCards = () => (qs.length ? (setQi(0), setStep(2)) : setStep(3));
  const mark = (v: 'y' | 'n') => {
    if (!card) return;
    rateCard(card, v === 'y' ? 'good' : 'again');
    setKnown({ ...known, [ci]: v });
    setFlipped(false);
    if (ci >= cardList.length - 1) {
      toast(t('rvToQs'));
      afterCards();
    } else setCi(ci + 1);
  };
  const toCards = () => {
    if (cardList.length) {
      setCi(0);
      setFlipped(false);
      setStep(1);
    } else afterCards();
  };
  const answer = (i: number) => {
    if (ans[qi] !== undefined) return;
    setAns({ ...ans, [qi]: i });
  };
  const nextQ = () => {
    if (ans[qi] === undefined) return;
    if (qi < qs.length - 1) return setQi(qi + 1);
    // The answers are saved as a quiz try; the server grades it (grade-quiz).
    if (qpack && !saved) {
      setSaved(true);
      saveAttempt(
        qpack.quizId,
        qs.map((x, i) => ({
          questionId: x.id,
          chosen: ans[i] ?? null,
          hints: 0,
        })),
      );
    }
    setStep(3);
  };
  const finish = async () => {
    await setReview(review.id, 'done');
    toast(t('rvDone'));
    navigate('/home');
  };
  const again = () => {
    setKnown({});
    setAns({});
    setQi(0);
    setSaved(false);
    toCards();
  };

  const steps = [t('rvStepSum'), t('rvStepCards'), t('rvStepQs')];
  return (
    <main className={s.main}>
      <Header onBack={() => navigate('/home')} title={t('rvTitle')} sub={sub} back={t('rvBack')} later={t('rvLater')} />
      {step < 3 && (
        <div className={s.steps}>
          {steps.map((l, i) => (
            <button
              key={l}
              aria-current={i === step ? 'step' : undefined}
              className={i === step ? `${s.step} ${s.stepOn}` : i < step ? `${s.step} ${s.stepDone}` : s.step}
              onClick={() => (i === 1 ? toCards() : i === 2 ? afterCards() : setStep(0))}
            >
              <span />
              {num(i + 1, lang)} · {l}
            </button>
          ))}
        </div>
      )}

      {step === 0 && (
        <div className={s.col}>
          <section className={s.intro}>
            <b>{t('rvPrepared')}</b>
            <p>{t('rvIntro')}</p>
            <span className={s.chips}>
              {sureN > 0 && <span className={s.chip}>{t('rvChipSure').replace('{n}', num(sureN, lang))}</span>}
              {weakTopics.length > 0 && <span className={s.chip}>{t('rvChipWeak').replace('{n}', num(weakTopics.length, lang))}</span>}
              {points.length > 0 && <span className={s.chip}>{t('rvChipForget')}</span>}
            </span>
          </section>
          <span className={`mono ${s.label}`}>{t('rvSumHead').replace('{n}', num(points.length || weakTopics.length, lang))}</span>
          {points.map((p, i) => (
            <article key={i} className={s.sumCard}>
              <div className={s.sumTop}>
                <span className={s.no}>{num(i + 1, lang)}</span>
                <span className={s.sumText} lang={rlang} dir={dirOf(rlang)}>
                  {p.text}
                </span>
                <span className={`mono ${s.pg}`}>{pg(p.page_from, p.page_to)}</span>
              </div>
              <div className={p.weak ? `${s.why} ${s.whyWeak}` : s.why}>
                <b>{t('rvWhy')}</b> {t(p.weak ? 'rvWhyWeak' : 'rvWhyForget')}
              </div>
            </article>
          ))}
          {!points.length &&
            weakTopics.map((w, i) => (
              <article key={w.id} className={s.sumCard}>
                <div className={s.sumTop}>
                  <span className={s.no}>{num(i + 1, lang)}</span>
                  <span className={s.sumText} dir="auto">
                    {w.title}
                  </span>
                  {w.page && <span className={`mono ${s.pg}`}>{pg(w.page, w.page)}</span>}
                </div>
                <div className={`${s.why} ${s.whyWeak}`}>
                  <b>{t('rvWhy')}</b> {t(w.sure ? 'rvWhySure' : 'rvWhyWeak')}
                </div>
              </article>
            ))}
          {recap && 'error' in recap && !weakTopics.length && <p className={s.muted}>{t('rvNoSum')}</p>}
          <button className={s.pri} onClick={toCards}>
            {t('rvToCards')}
          </button>
        </div>
      )}

      {step === 1 && (
        <div className={s.col}>
          {!card ? (
            <>
              <p className={s.muted}>{t('rvNoCards')}</p>
              <button className={s.pri} onClick={afterCards}>
                {t('rvToQs')}
              </button>
            </>
          ) : (
            <>
              <div className={s.cardTop}>
                <span className="mono">
                  {t('rvCardOf')
                    .replace('{a}', num(ci + 1, lang))
                    .replace('{b}', num(cardList.length, lang))}
                </span>
                <span className={s.dots}>
                  {cardList.map((_, i) => (
                    <span key={i} className={known[i] === 'y' ? s.dotY : known[i] === 'n' ? s.dotN : i === ci ? s.dotNow : ''} />
                  ))}
                </span>
              </div>
              <button
                className={flipped ? `${s.flash} ${s.flashOn}` : s.flash}
                aria-label={t('rvFlip')}
                onClick={() => setFlipped(!flipped)}
                lang={cl}
                dir={dirOf(cl)}
              >
                <span className={s.front}>{card.q}</span>
                {flipped ? (
                  <>
                    <span className={s.rule} />
                    <span className={s.back}>{card.a}</span>
                    {card.page && (
                      <span className="mono">
                        {t('rvSource')} {pagesShort(card.page, card.page, cl)}
                      </span>
                    )}
                  </>
                ) : (
                  <span className={s.hint}>{t('rvThink')}</span>
                )}
              </button>
              {flipped ? (
                <div className={s.two}>
                  <button className={s.amb} onClick={() => mark('n')}>
                    {t('rvAskAgain')}
                  </button>
                  <button className={s.pri} onClick={() => mark('y')}>
                    {t('rvKnow')}
                  </button>
                </div>
              ) : (
                <button className={s.ghost} onClick={() => setFlipped(true)}>
                  {t('rvShowAnswer')}
                </button>
              )}
            </>
          )}
        </div>
      )}

      {step === 2 && q && (
        <div className={s.col}>
          <span className="mono">
            {t('rvQOf')
              .replace('{a}', num(qi + 1, lang))
              .replace('{b}', num(qs.length, lang))}
          </span>
          <p className={s.qText} lang={rlang} dir={dirOf(rlang)}>
            {q.text}
          </p>
          <div className={s.opts} lang={rlang} dir={dirOf(rlang)}>
            {q.options.map((o, i) => {
              const shown = ans[qi] !== undefined;
              const cls = shown && i === q.answer ? s.optRight : shown && ans[qi] === i ? s.optWrong : s.opt;
              return (
                <button key={i} className={cls} aria-disabled={shown} onClick={() => answer(i)}>
                  {LETTERS[i]}) {o}
                </button>
              );
            })}
          </div>
          {ans[qi] !== undefined && (
            <div className={ans[qi] === q.answer ? `${s.verdict} ${s.vOk}` : `${s.verdict} ${s.vBad}`} role="status">
              <b>{t(ans[qi] === q.answer ? 'rvCorrect' : 'rvNotQuite')}</b>
              {q.why && <span>{q.why}</span>}
              {q.page && (
                <span className="mono">
                  {t('rvSource')} {pagesShort(q.page, q.page, rlang)}
                </span>
              )}
            </div>
          )}
          {ans[qi] !== undefined && (
            <button className={s.pri} onClick={nextQ}>
              {qi >= qs.length - 1 ? t('rvFinish') : t('nextQ')}
            </button>
          )}
        </div>
      )}

      {step === 3 && (
        <div className={s.col}>
          <section className={s.hero}>
            <b>{t('rvDone')}</b>
            <div className={s.heroGrid}>
              <span>
                <b>
                  {num(rightN, lang)} / {num(qs.length, lang)}
                </b>
                {t('rvQsRight')}
              </span>
              <span>
                <b>
                  {num(knownN, lang)} / {num(cardList.length, lang)}
                </b>
                {t('rvCardsKnown')}
              </span>
            </div>
          </section>
          {cardList.some((_, i) => known[i] === 'n') && (
            <section className={s.next}>
              <b>{t('rvAskedFirst')}</b>
              {cardList.map((c, i) => known[i] === 'n' && <span key={c.id}>• {c.q}</span>)}
            </section>
          )}
          <button className={s.pri} onClick={finish}>
            {t('rvFinish')}
          </button>
          <button className={s.ghost} onClick={again}>
            {t('rvAgain')}
          </button>
        </div>
      )}
    </main>
  );
}

function Header({ onBack, title, sub, back, later }: { onBack: () => void; title: string; sub: string; back: string; later: string }) {
  return (
    <div className={s.head}>
      <button className={s.round} aria-label={back} onClick={onBack}>
        <Icon name="back" size={20} width={1.8} className="flip-rtl" />
      </button>
      <span className={s.titleBox}>
        <h1>{title}</h1>
        {sub && <span>{sub}</span>}
      </span>
      <button className={s.laterBtn} onClick={onBack}>
        {later}
      </button>
    </div>
  );
}
