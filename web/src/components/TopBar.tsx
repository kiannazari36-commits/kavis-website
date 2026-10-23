import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import Icon from './Icon';
import { hasUnread } from '../api/notifications';
import { getStreak } from '../api/progress';
import { useAsync } from '../hooks/useAsync';
import { num } from '../i18n/format';
import s from './TopBar.module.css';

// Search + streak + notifications + assistant star (design/DeskApp.dc.html, top of home/courses).
export default function TopBar() {
  const { t, lang } = useI18n();
  const navigate = useNavigate();
  const streak = useAsync(getStreak, []);
  const unread = useAsync(hasUnread, []);
  const [params] = useSearchParams();
  const [q, setQ] = useState(params.get('q') ?? '');
  const input = useRef<HTMLInputElement>(null);
  const isMac = /Mac|iPhone|iPad/.test(navigator.platform);

  // Ctrl K / ⌘K focuses search.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        input.current?.focus();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    navigate(q.trim() ? `/courses?q=${encodeURIComponent(q.trim())}` : '/courses');
  };

  return (
    <div className={s.bar}>
      <form className={s.search} onSubmit={submit} role="search">
        <Icon name="search" size={17} />
        <input ref={input} value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('k61')} aria-label={t('k61')} />
        <kbd className="mono">{isMac ? '⌘K' : 'Ctrl K'}</kbd>
      </form>
      <span className={s.grow} />
      <button className={s.streak} onClick={() => navigate('/progress')}>
        <Icon name="flame" size={16} />
        {streak !== undefined && t('daysN').replace('{n}', num(streak, lang))}
      </button>
      <button className={s.bell} aria-label={t('notifs')} onClick={() => navigate('/notifications')}>
        <Icon name="bell" size={19} />
        {unread && <span />}
      </button>
      <button className="star-btn" aria-label={t('k92')} onClick={() => navigate('/assistant')} />
    </div>
  );
}
