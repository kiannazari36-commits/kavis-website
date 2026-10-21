import { useEffect, useRef, useState } from 'react';
import { LANGS, LANG_NAMES, useI18n } from '../i18n/I18nProvider';
import { useTheme } from '../theme/ThemeProvider';
import Icon from './Icon';
import s from './LangThemeSwitch.module.css';

// Globe + language code (as in the design header) opening a small menu, plus a light/dark button.
export default function LangThemeSwitch() {
  const { lang, setLang, t } = useI18n();
  const { theme, toggle } = useTheme();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const close = (e: MouseEvent) => {
      if (!ref.current?.contains(e.target as Node)) setOpen(false);
    };
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('mousedown', close);
    document.addEventListener('keydown', esc);
    return () => {
      document.removeEventListener('mousedown', close);
      document.removeEventListener('keydown', esc);
    };
  }, [open]);

  return (
    <div className={s.wrap} ref={ref}>
      <button className={s.lang} aria-haspopup="menu" aria-expanded={open} aria-label={t('language')} onClick={() => setOpen(!open)}>
        <Icon name="globe" size={16} />
        {lang.toUpperCase()}
      </button>
      {open && (
        <div className={s.menu} role="menu">
          {LANGS.map((l) => (
            <button
              key={l}
              role="menuitemradio"
              aria-checked={l === lang}
              className={l === lang ? `${s.item} ${s.on}` : s.item}
              onClick={() => {
                setLang(l);
                setOpen(false);
              }}
            >
              <span className="mono">{l.toUpperCase()}</span>
              {LANG_NAMES[l]}
            </button>
          ))}
        </div>
      )}
      <button className={s.theme} aria-label={t('theme')} onClick={toggle}>
        <Icon name={theme === 'dark' ? 'sun' : 'moon'} size={17} />
      </button>
    </div>
  );
}
