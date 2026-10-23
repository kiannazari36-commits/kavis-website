import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { duration, num, percent } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon, { type IconName } from '../components/Icon';
import { getProgress, type CourseRank } from '../api/progress';
import { getProfile } from '../api/account';
import { isoToday } from '../api/courses';
import { useAsync } from '../hooks/useAsync';
import { useSettings } from '../settings/SettingsProvider';
import s from './Progress.module.css';

// Design: design/NewIPad.dc.html, screen "progress" ("İlerleme · bu hafta"). All numbers come from the student's rows.

const MEDALS: [string, string, string, string][] = [
  ['#E9B949', '#F8DB82', '#7A4E06', 'gold'],
  ['#AEB4BE', '#E4E7EB', '#4E5563', 'silver'],
  ['#C4834F', '#EBBE96', '#5E3216', 'bronze'],
];
const BADGE_ICON: Record<CourseRank['badge'], IconName> = { strong: 'spark', rising: 'chart', steady: 'chart', weak: 'help' };
const DAY_KEYS = ['dMon', 'dTue', 'dWed', 'dThu', 'dFri', 'dSat', 'dSun'];
const growthPct = (r: CourseRank) => (r.from ? Math.round(((r.current - r.from) / r.from) * 100) : 0);
const signed = (n: number, lang: Parameters<typeof num>[1]) => (n > 0 ? '+' : n < 0 ? '−' : '') + num(Math.abs(n), lang);
const hm = (h: number) => `${String(h).padStart(2, '0')}:00`;

export default function Progress() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const { settings } = useSettings();
  const data = useAsync(getProgress, []);
  const profile = useAsync(getProfile, []);
  const [cheer, setCheer] = useState(true);

  if (!data) return <main className={s.main} />;

  const weekTotal = data.weekMinutes.reduce((a, m) => a + m, 0);
  const todayIdx = (new Date(`${isoToday()}T12:00:00`).getDay() + 6) % 7;
  const stats: [string, string, IconName, string][] = [
    [duration(weekTotal, lang), t('stWeek'), 'calendar', 'low'],
    [data.lastScore === null ? '–' : num(data.lastScore, lang), t('stScore'), 'check', 'good'],
    [t('daysN').replace('{n}', num(data.streak, lang)), t('stStreak'), 'flame', 'mid'],
    [num(data.termsTapped, lang), t('stWords'), 'lines', 'low'],
  ];

  // Congratulate when a course average rose more than 10% (CLAUDE.md: also sent as a notification).
  const best = [...data.ranking].sort((a, b) => growthPct(b) - growthPct(a))[0];
  const cheerOn = cheer && best && growthPct(best) > 10;
  const firstName = profile?.name.split(' ')[0] ?? '';
  const cheerTitle = t('cheerTitleN').replace('{name}', firstName);
  const cheerText = best
    ? t('cheerTextN')
        .replace('{course}', best.name)
        .replace('{days}', num(best.days, lang))
        .replace('{from}', num(best.from, lang))
        .replace('{to}', num(best.current, lang))
        .replace('{pct}', percent(growthPct(best), lang))
    : '';

  // Shows the congratulation as a real browser notification when allowed, otherwise as a toast.
  const showCheer = async () => {
    if ('Notification' in window) {
      const perm = Notification.permission === 'default' ? await Notification.requestPermission() : Notification.permission;
      if (perm === 'granted') {
        new Notification(cheerTitle, { body: cheerText, icon: '/icon_star.png' });
        return;
      }
    }
    toast(cheerText);
  };

  const rankAction = (r: CourseRank) => navigate(r.level === 'good' ? `/cards?course=${r.courseId}` : r.level === 'mid' ? '/plan' : `/quiz?course=${r.courseId}`);
  const note = (r: CourseRank) => {
    const parts = [t('noteExams').replace('{n}', num(r.scores.length, lang))];
    if (r.level === 'good' && r.bestLesson) parts.push(t('noteBest').replace('{x}', r.bestLesson));
    if (r.level === 'mid' && r.scores.length > 1) parts.push(t('noteLast').replace('{d}', signed(r.scores[r.scores.length - 1] - r.scores[r.scores.length - 2], lang)));
    if (r.level === 'low' && r.hardest) parts.push(t('noteHard').replace('{x}', r.hardest.title).replace('{p}', percent(r.hardest.mastery, lang)));
    return parts.join(' · ');
  };
  const goal = Math.round(settings.studyDays * settings.studyHours * 60);

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

        {cheerOn && (
          <div className={s.cheer} role="status">
            <span className={s.cheerIcon}>
              <Icon name="spark" size={20} />
            </span>
            <span className={s.cheerText}>
              <b>{cheerTitle}</b>
              <span>{cheerText}</span>
              <small>{t('cheerInfo')}</small>
            </span>
            <button onClick={showCheer}>{t('cheerShow')}</button>
            <button onClick={() => (setCheer(false), toast(t('cheerBye')))}>{t('cheerThanks')}</button>
          </div>
        )}

        {data.ranking.length === 0 && <p className={s.note}>{t('noRanking')}</p>}
        <div className={s.ranks}>
          {data.ranking.map((r, i) => {
            const [m1, m2, m3, medal] = MEDALS[Math.min(i, MEDALS.length - 1)];
            const gp = growthPct(r);
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
                    <b>{r.name}</b>
                    <span className="mono">{num(i + 1, lang) + t('placeA') + t(medal).toLocaleUpperCase(lang)}</span>
                  </span>
                </div>
                <span className={`${s.badge} ${s[r.level]}`}>
                  <Icon name={BADGE_ICON[r.badge]} size={12} width={2} />
                  {t(`badge_${r.badge}`)}
                </span>
                <div className={s.rankMid}>
                  <span className={s.avg}>
                    <b>{num(r.current, lang)}</b>
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
                  {num(r.days, lang) + t('inDays') + num(r.from, lang) + ' → ' + num(r.current, lang)}
                  <b>{gp >= 0 ? '+' : '−'}{percent(Math.abs(gp), lang)}</b>
                  {gp >= 10 && <span> {t('cheerTag')}</span>}
                </span>
                <span className={s.note}>{note(r)}</span>
                <span className={`${s.cta} ${s[`cta_${r.level}`]}`}>{t(`cta_${r.level}`)} ›</span>
              </button>
            );
          })}
        </div>
      </section>

      <div className={s.twoCol}>
        <section className={s.box}>
          <div className={s.secHead}>
            <h2>{t('weekTitle')}</h2>
            <span>{t('weekGoal').replace('{a}', duration(weekTotal, lang)).replace('{b}', duration(goal, lang))}</span>
          </div>
          <div className={s.chart}>
            {data.weekMinutes.map((m, i) => (
              <div key={i} className={s.col}>
                <span className="mono">{m ? num(m, lang) : '–'}</span>
                <span
                  className={i === todayIdx ? `${s.colBar} ${s.colToday}` : m ? `${s.colBar} ${s.colOn}` : s.colBar}
                  style={{ height: m ? Math.min(150, Math.round(m * 1.6)) : 6 }}
                />
                <span>{t(DAY_KEYS[i])}</span>
              </div>
            ))}
          </div>
        </section>
        <div className={s.sideCol}>
          <section className={s.streak}>
            <span className="mono">{t('streakTitle')}</span>
            <b>{data.level ? `★ ${t(`level_${data.level}`)}` : '–'}</b>
            {data.lastScore !== null && (
              <span>{t('levelSub').replace('{s}', num(data.lastScore, lang)).replace('{d}', data.lastDiff === null ? '–' : signed(data.lastDiff, lang))}</span>
            )}
          </section>
          {data.bestHours && (
            <section className={s.words}>
              <b>{t('tipTitle').replace('{h}', `${hm(data.bestHours.from)}–${hm(data.bestHours.to)}`)}</b>
              <span>
                {t('tipText').replace('{p}', percent(data.bestHours.rate, lang)) +
                  (data.bestHours.late !== null && data.bestHours.late < data.bestHours.rate ? t('tipLate').replace('{p}', percent(data.bestHours.late, lang)) : '')}
              </span>
            </section>
          )}
        </div>
      </div>

      <section className={s.box}>
        <h2 className={s.h2}>{t('weakTitle')}</h2>
        {data.weak.length === 0 && <p className={s.note}>{t('noWeak')}</p>}
        {data.weak.map((w) => (
          <button key={w.title + w.materialId} className={s.weak} onClick={() => navigate(`/reader?course=${w.courseId ?? ''}&pdf=${w.materialId}`)}>
            <span className={s.weakName}>{w.title}</span>
            <span className={s.weakPdf}>{w.lesson}</span>
            <span className={s.weakBar}>
              <span style={{ width: `${w.mastery}%`, background: w.mastery < 45 ? '#9C2F3A' : w.mastery < 60 ? '#E8925A' : '#F2B33D' }} />
            </span>
            <span className={s.weakPct}>{percent(w.mastery, lang)}</span>
          </button>
        ))}
      </section>
    </main>
  );
}
