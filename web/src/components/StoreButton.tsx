import type { ReactNode } from 'react';
import { useI18n } from '../i18n/I18nProvider';
import s from './StoreButton.module.css';

// Black store button (design: landing). Without a link the app is not published yet:
// the button is greyed out, cannot be clicked and shows "Yakında" / "Coming soon".
export default function StoreButton({ url, logo, small, name }: { url: string; logo: ReactNode; small: string; name: string }) {
  const { t } = useI18n();
  const inner = (
    <>
      {logo}
      <span className={s.text}>
        <small>{small}</small>
        <b>{name}</b>
      </span>
    </>
  );
  if (url)
    return (
      <a className={s.btn} href={url} target="_blank" rel="noreferrer">
        {inner}
      </a>
    );
  return (
    <span className={`${s.btn} ${s.soon}`} aria-disabled="true" aria-label={`${name} · ${t('comingSoon')}`}>
      {inner}
      <span className={s.badge}>{t('comingSoon')}</span>
    </span>
  );
}
