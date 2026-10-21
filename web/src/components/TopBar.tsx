import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { useToast } from './Toast';
import Icon from './Icon';
import s from './TopBar.module.css';

// Search + streak + notifications + assistant star (design/DeskApp.dc.html, top of home/courses).
export default function TopBar() {
  const { t } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
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
        {t('k62')}
      </button>
      <button className={s.bell} aria-label={t('notifs')} onClick={() => toast(t('k165'))}>
        <Icon name="bell" size={19} />
        <span />
      </button>
      <button className="star-btn" aria-label={t('k92')} onClick={() => navigate('/assistant')} />
    </div>
  );
}
