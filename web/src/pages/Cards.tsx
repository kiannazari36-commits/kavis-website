import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import Icon from '../components/Icon';
import { DECK_SIZE, getDeck, rateCard } from '../api/cards';
import { useAsync } from '../hooks/useAsync';
import { listCourses } from '../api/courses';
import { dirOf, useContentLang } from '../settings/SettingsProvider';
import type { CardRating } from '../api/types';
import s from './Cards.module.css';

// Design: design/NewIPad.dc.html, screen "cards": flip a card, then rate it (next review time).
// Keyboard: Space flips, 1 / 2 / 3 rate. Card text uses the content language (CLAUDE.md).
const RATES: [CardRating, string, string][] = [
  ['again', 'rateNo', 'rateNoT'],
  ['hard', 'rateHard', 'rateHardT'],
  ['good', 'rateYes', 'rateYesT'],
];

export default function Cards() {
  const { t, lang } = useI18n();
  const navigate = useNavigate();
  const deck = useAsync(() => getDeck('pharmacotherapy', 'hypertension'), []);
  const courses = useAsync(listCourses, []);
  const cl = useContentLang(courses?.find((c) => c.id === 'pharmacotherapy'));
  const [i, setI] = useState(0);
  const [back, setBack] = useState(false);
  const [stats, setStats] = useState([0, 0, 0]);

  const rate = (k: number) => {
    rateCard(i, RATES[k][0]);
    setStats(stats.map((n, j) => (j === k ? n + 1 : n)));
    setI(i + 1);
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

  if (!deck) return <main className={s.main} />;

  const card = deck[i % deck.length];
  const pos = (i % DECK_SIZE) + 1;

  return (
    <main className={s.main}>
      <div className={s.head}>
        <button className={s.round} aria-label={t('back')} onClick={() => navigate('/home')}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <h1>
          {t('cardsTitle')} <span>{t('cardsSub')}</span>
        </h1>
        <span className={s.styleBadge}>
          <Icon name="spark" size={11} width={2} />
          {t('teacherStyle')}
        </span>
        <span className={s.count}>
          {num(pos, lang)} / {num(DECK_SIZE, lang)}
        </span>
      </div>
      <span className={s.bar} aria-hidden="true">
        <span style={{ width: `${Math.round((pos / DECK_SIZE) * 100)}%` }} />
      </span>

      <div className={s.stage}>
        <button className={back ? `${s.card} ${s.cardBack}` : s.card} onClick={() => setBack(!back)} aria-live="polite">
          <span className={`mono ${s.side}`}>
            {t(back ? 'sideA' : 'sideQ')} {t('pageShort')} {num(card.page, lang)}
          </span>
          <span className={back ? `${s.main2} ${s.answer}` : s.main2} lang={cl} dir={dirOf(cl)}>
            {back ? card.a[cl] : card.q[cl]}
          </span>
          {back ? (
            <span className={s.sub} lang={cl} dir={dirOf(cl)}>
              {card.note[cl]}
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
                  {t(next)} {t('later')}
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
    </main>
  );
}
