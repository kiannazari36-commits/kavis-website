import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import Icon, { type IconName } from '../components/Icon';
import TopBar from '../components/TopBar';
import { listNotifications, markAllRead, type Notice } from '../api/notifications';
import { addDays } from '../api/plan';
import { isoToday } from '../api/courses';
import { useAsync } from '../hooks/useAsync';
import s from './Notifications.module.css';

// Design: design/ScrNotifications.dc.html: grouped by Today / Yesterday / This week (and Earlier), icon, title, text, time.
// Opening the page marks everything read.

const ICON: Record<string, IconName> = {
  study_1h_before: 'calendar',
  start_now: 'play',
  review_day: 'refresh',
  streak: 'flame',
  lesson_ready: 'book',
  exam_result: 'check',
  weekly_report: 'chart',
  class_tomorrow: 'calendar',
  cheer: 'spark',
  trial_ending: 'lock',
  share_received: 'share',
};
// Color of the round icon per kind.
const TONE: Record<string, string> = { exam_result: s.good, cheer: s.good, streak: s.amb, review_day: s.amb, weekly_report: s.blue, lesson_ready: s.blue, trial_ending: s.pri };

const localDay = (iso: string) => {
  const d = new Date(iso);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

export default function Notifications() {
  const { t, lang } = useI18n();
  const navigate = useNavigate();
  const list = useAsync(listNotifications, []);

  useEffect(() => {
    if (list?.some((n) => !n.read)) markAllRead();
  }, [list]);

  const today = isoToday();
  const yesterday = addDays(today, -1);
  const weekAgo = addDays(today, -7);
  const groups: [string, Notice[]][] = [
    [t('nToday'), []],
    [t('nYesterday'), []],
    [t('nThisWeek'), []],
    [t('nEarlier'), []],
  ];
  for (const n of list ?? []) {
    const d = localDay(n.at);
    groups[d === today ? 0 : d === yesterday ? 1 : d > weekAgo ? 2 : 3][1].push(n);
  }
  const time = (n: Notice) => {
    const d = new Date(n.at);
    const day = localDay(n.at);
    if (day === today || day === yesterday) return num(`${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`, lang);
    return new Intl.DateTimeFormat(lang === 'fa' ? 'fa-IR-u-ca-gregory' : lang, { weekday: 'short' }).format(d);
  };

  return (
    <main className={s.main}>
      <div className={s.head}>
        <TopBar />
        <h1>{t('notifs')}</h1>
      </div>
      {list && list.length === 0 && <p className={s.empty}>{t('noNotifs')}</p>}
      {groups
        .filter(([, items]) => items.length)
        .map(([label, items]) => (
          <section key={label} className={s.group}>
            <h2>{label}</h2>
            <div className={s.list}>
              {items.map((n) => (
                <button key={n.id} className={s.item} onClick={() => n.to && navigate(n.to)}>
                  <span className={`${s.icon} ${TONE[n.kind] ?? s.pri}`}>
                    <Icon name={ICON[n.kind] ?? 'bell'} size={18} />
                  </span>
                  <span className={s.text}>
                    <span className={s.top}>
                      <b>{n.title}</b>
                      <span className="mono">{time(n)}</span>
                    </span>
                    <span className={s.body}>{n.body}</span>
                  </span>
                  {!n.read && <span className={s.dot} aria-label={t('unread')} />}
                </button>
              ))}
            </div>
          </section>
        ))}
    </main>
  );
}
