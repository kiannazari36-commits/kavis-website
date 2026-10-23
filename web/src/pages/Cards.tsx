import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import Icon from '../components/Icon';
import { dueCards, goodInterval, rateCard } from '../api/cards';
import { useAsync } from '../hooks/useAsync';
import { dirOf } from '../settings/SettingsProvider';
import type { CardRating, FlashCard } from '../api/types';
import s from './Cards.module.css';

// Design: design/NewIPad.dc.html, screen "cards": flip a card, then rate it (next review time).
// Keyboard: Space flips, 1 / 2 / 3 rate. Card text is in its deck's language (the content language, CLAUDE.md).
// The cards due now form today's round; "Didn't know" and "Hard" come back at the end of the round.
const RATES: [CardRating, string, string][] = [
  ['again', 'rateNo', 'rateNoT'],
  ['hard', 'rateHard', 'rateHardT'],
  ['good', 'rateYes', 'rateYesT'],
];

export default function Cards() {
  const { t, lang } = useI18n();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const courseId = params.get('course') ?? undefined;
  const loaded = useAsync(() => dueCards(courseId), [courseId]);
  const [queue, setQueue] = useState<FlashCard[] | null>(null);
  const [total, setTotal] = useState(0);
  const [done, setDone] = useState(0);
  const [back, setBack] = useState(false);
  const [stats, setStats] = useState([0, 0, 0]);

  useEffect(() => {
    if (!loaded) return;
    setQueue(loaded);
    setTotal(loaded.length);
    setDone(0);
  }, [loaded]);

  const rate = (k: number) => {
    if (!queue?.length) return;
    const [card, ...rest] = queue;
    const rating = RATES[k][0];
    rateCard(card, rating);
    setStats(stats.map((n, j) => (j === k ? n + 1 : n)));
    if (rating === 'good') {
      setQueue(rest);
      setDone(done + 1);
    } else setQueue([...rest, { ...card, reps: 0, intervalDays: rating === 'again' ? 0 : card.intervalDays }]);
    setBack(false);
  };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement).closest('input, textarea')) return;
      if (e.key === ' ') {
        e.preventDefault();
        setBack((b) => !b);
      } else if (back && ['1', '2', '3'].includes(e.key)) rate(+e.key - 1);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  if (!queue) return <main className={s.main} />;

  const card = queue[0];
  const pos = Math.min(done + 1, total);
  const cl = card?.lang ?? 'tr';
  const nextLabel = (id: CardRating, key: string) =>
    id === 'good' && card ? t('daysN').replace('{n}', num(goodInterval(card), lang)) : t(key);

  return (
    <main className={s.main}>
      <div className={s.head}>
        <button className={s.round} aria-label={t('back')} onClick={() => navigate('/home')}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <h1>
          {t('cardsTitle')} {card?.deck && <span>· {card.deck}</span>}
        </h1>
        <span className={s.styleBadge}>
          <Icon name="spark" size={11} width={2} />
          {t('teacherStyle')}
        </span>
        <span className={s.count}>
          {num(pos, lang)} / {num(total, lang)}
        </span>
      </div>
      <span className={s.bar} aria-hidden="true">
        <span style={{ width: `${total ? Math.round((done / total) * 100) : 100}%` }} />
      </span>

      {!card ? (
        <div className={s.stage}>
          <div className={s.card}>
            <span className={s.main2}>{t('cardsDone')}</span>
          </div>
          <button className={s.show} onClick={() => navigate('/home')}>
            {t('k47')}
          </button>
          <span className={s.stats}>
            {t('statsA') + num(stats[0], lang) + t('statsB') + num(stats[1], lang) + t('statsC') + num(stats[2], lang)}
          </span>
        </div>
      ) : (
        <div className={s.stage}>
          <button className={back ? `${s.card} ${s.cardBack}` : s.card} onClick={() => setBack(!back)} aria-live="polite">
            <span className={`mono ${s.side}`}>
              {t(back ? 'sideA' : 'sideQ')} {card.page !== null && `${t('pageShort')} ${num(card.page, lang)}`}
            </span>
            <span className={back ? `${s.main2} ${s.answer}` : s.main2} lang={cl} dir={dirOf(cl)}>
              {back ? card.a : card.q}
            </span>
            {back ? (
              <span className={s.sub} lang={cl} dir={dirOf(cl)}>
                {card.note}
              </span>
            ) : (
              <span className={s.sub}>{t('tapToSee')}</span>
            )}
          </button>

          {back ? (
            <div className={s.rates}>
              {RATES.map(([id, label, next], k) => (
                <button key={id} className={s[id]} onClick={() => rate(k)}>
                  {t(label)}
                  <span>
                    {nextLabel(id, next)} {t('later')}
                  </span>
                </button>
              ))}
            </div>
          ) : (
            <button className={s.show} onClick={() => setBack(true)}>
              {t('showAnswer')}
            </button>
          )}
          <span className={s.stats}>
            {t('statsA') + num(stats[0], lang) + t('statsB') + num(stats[1], lang) + t('statsC') + num(stats[2], lang)}
          </span>
        </div>
      )}
    </main>
  );
}
