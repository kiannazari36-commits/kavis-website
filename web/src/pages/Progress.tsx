import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num, percent } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon, { type IconName } from '../components/Icon';
import { getProgress } from '../api/progress';
import { useAsync } from '../hooks/useAsync';
import type { CourseRank } from '../api/types';
import s from './Progress.module.css';

// Design: design/NewIPad.dc.html, screen "progress" ("İlerleme · bu hafta").

const MEDALS: [string, string, string, string][] = [
  ['#E9B949', '#F8DB82', '#7A4E06', 'gold'],
  ['#AEB4BE', '#E4E7EB', '#4E5563', 'silver'],
  ['#C4834F', '#EBBE96', '#5E3216', 'bronze'],
];
const LEVEL_ICON: Record<CourseRank['icon'], IconName> = { star: 'spark', trend: 'chart', alert: 'help' };
const DAY_KEYS = ['dMon', 'dTue', 'dWed', 'dThu', 'dFri', 'dSat', 'dSun'];
const TODAY = 3; // Thursday is highlighted in the design

export default function Progress() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const data = useAsync(getProgress, []);
  const [cheer, setCheer] = useState(true);

  if (!data) return <main className={s.main} />;

  const stats: [string, string, IconName, string][] = [
    [t('stWeekV'), t('stWeek'), 'calendar', 'low'],
    [num(84, lang), t('stScore'), 'check', 'good'],
    [t('stStreakV'), t('stStreak'), 'flame', 'mid'],
    [num(240, lang), t('stWords'), 'lines', 'low'],
  ];

  // Shows the congratulation as a real browser notification when allowed, otherwise as a toast.
  const showCheer = async () => {
    const title = t('cheerTitle');
    const body = t('cheerText');
    if ('Notification' in window) {
      const perm = Notification.permission === 'default' ? await Notification.requestPermission() : Notification.permission;
      if (perm === 'granted') {
        new Notification(title, { body, icon: '/icon_star.png' });
        return;
      }
    }
    toast(body);
  };

  const rankAction = (r: CourseRank) => {
    if (r.toast) toast(r.toast[lang]);
    else if (r.level === 'mid') navigate('/plan');
    else navigate('/quiz');
  };

  return (
    <main className={s.main}>
      <h1 className={s.title}>
        {t('progA')} <span>{t('progB')}</span>
      </h1>

      <div className={s.stats}>
        {stats.map(([v, label, icon, level]) => (
          <div key={label} className={s.stat}>
            <span className={`${s.statIcon} ${s[level]}`}>
              <Icon name={icon} size={18} />
            </span>
            <b>{v}</b>
            <span>{label}</span>
          </div>
        ))}
      </div>

      <section className={s.rankBox}>
        <div className={s.secHead}>
          <h2>
            {t('rankTitle')} <span>{t('rankSub')}</span>
          </h2>
          <span>{t('rankHint')}</span>
        </div>

        {cheer && (
          <div className={s.cheer} role="status">
            <span className={s.cheerIcon}>
              <Icon name="spark" size={20} />
            </span>
            <span className={s.cheerText}>
              <b>{t('cheerTitle')}</b>
              <span>{t('cheerText')}</span>
              <small>{t('cheerInfo')}</small>
            </span>
            <button onClick={showCheer}>{t('cheerShow')}</button>
            <button onClick={() => (setCheer(false), toast(t('cheerBye')))}>{t('cheerThanks')}</button>
          </div>
        )}

        <div className={s.ranks}>
          {data.ranking.map((r, i) => {
            const [m1, m2, m3, medal] = MEDALS[i];
            const gp = Math.round(((r.growth.to - r.growth.from) / r.growth.from) * 100);
            return (
              <button key={r.courseId} className={r.level === 'low' ? `${s.rank} ${s.rankLow}` : s.rank} onClick={() => rankAction(r)}>
                <div className={s.rankTop}>
                  <span className={s.medal} aria-label={num(i + 1, lang) + t('placeAria') + t(medal)}>
                    <svg aria-hidden="true" width="46" height="54" viewBox="0 0 48 56">
                      <path d="M13 0h9l6 19h-9z" fill="#9C2F3A" />
                      <path d="M35 0h-9l-6 19h9z" fill="#7A2430" />
                      <circle cx="24" cy="35" r="19" fill={m1} />
                      <circle cx="24" cy="35" r="14.5" fill={m2} stroke={m3} strokeOpacity=".35" strokeWidth="1.5" />
                    </svg>
                    <b style={{ color: m3 }}>{num(i + 1, lang)}</b>
                  </span>
                  <span className={s.rankName}>
                    <b>{r.name[lang]}</b>
                    <span className="mono">{num(i + 1, lang) + t('placeA') + t(medal).toLocaleUpperCase(lang)}</span>
                  </span>
                </div>
                <span className={`${s.badge} ${s[r.level]}`}>
                  <Icon name={LEVEL_ICON[r.icon]} size={12} width={2} />
                  {r.badge[lang]}
                </span>
                <div className={s.rankMid}>
                  <span className={s.avg}>
                    <b>{num(r.growth.to, lang)}</b>
                    <span>{t('avgLabel')}</span>
                  </span>
                  <span className={s.grow} />
                  <span className={s.bars} aria-label={t('scoresAria') + r.scores.join(', ')}>
                    {r.scores.map((v, j) => (
                      <span key={j} className={j === r.scores.length - 1 ? s[`bar_${r.level}`] : ''} style={{ height: Math.round(v * 0.44) }} />
                    ))}
                  </span>
                </div>
                <span className={gp >= 10 ? `${s.growth} ${s.growthHot}` : s.growth}>
                  <Icon name="chart" size={13} width={2} />
                  {num(r.growth.days, lang) + t('inDays') + num(r.growth.from, lang) + ' → ' + num(r.growth.to, lang)}
                  <b>+{percent(gp, lang)}</b>
                  {gp >= 10 && <span> {t('cheerTag')}</span>}
                </span>
                <span className={s.note}>{r.note[lang]}</span>
                <span className={`${s.cta} ${s[`cta_${r.level}`]}`}>{r.cta[lang]} ›</span>
              </button>
            );
          })}
        </div>
      </section>

      <div className={s.twoCol}>
        <section className={s.box}>
          <div className={s.secHead}>
            <h2>{t('weekTitle')}</h2>
            <span>{t('weekTotal')}</span>
          </div>
          <div className={s.chart}>
            {data.weekMinutes.map((m, i) => (
              <div key={i} className={s.col}>
                <span className="mono">{m ? num(m, lang) : '–'}</span>
                <span className={i === TODAY ? `${s.colBar} ${s.colToday}` : m ? `${s.colBar} ${s.colOn}` : s.colBar} style={{ height: m ? Math.round(m * 1.6) : 6 }} />
                <span>{t(DAY_KEYS[i])}</span>
              </div>
            ))}
          </div>
        </section>
        <div className={s.sideCol}>
          <section className={s.streak}>
            <span className="mono">{t('streakTitle')}</span>
            <b>{t('streakText')}</b>
            <span>{t('streakSub')}</span>
          </section>
          <section className={s.words}>
            <b>{t('wordsTitle')}</b>
            <span>{t('wordsText')}</span>
          </section>
        </div>
      </div>

      <section className={s.box}>
        <h2 className={s.h2}>{t('weakTitle')}</h2>
        {data.weak.map((w) => (
          <button key={w.title.en} className={s.weak} onClick={() => navigate('/reader')}>
            <span className={s.weakName}>{w.title[lang]}</span>
            <span className={s.weakPdf}>{w.pdf[lang]}</span>
            <span className={s.weakBar}>
              <span style={{ width: `${w.mastery}%`, background: w.color }} />
            </span>
            <span className={s.weakPct}>{percent(w.mastery, lang)}</span>
          </button>
        ))}
      </section>
    </main>
  );
}
