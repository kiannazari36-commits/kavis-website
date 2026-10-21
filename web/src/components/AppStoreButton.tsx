import { useI18n } from '../i18n/I18nProvider';
import { useToast } from './Toast';
import { AppleLogo } from './Icon';
import { APP_STORE_URL } from '../config';
import s from './AppStoreButton.module.css';

// Black "Download on the App Store" button (design: landing store buttons).
// Until the app is published (APP_STORE_URL empty) it shows a short message.
export default function AppStoreButton() {
  const { t } = useI18n();
  const toast = useToast();
  const inner = (
    <>
      <AppleLogo size={24} />
      <span className={s.text}>
        <small>{t('k12')}</small>
        <b>App Store</b>
      </span>
    </>
  );
  return APP_STORE_URL ? (
    <a className={s.btn} href={APP_STORE_URL} target="_blank" rel="noreferrer">
      {inner}
    </a>
  ) : (
    <button className={s.btn} onClick={() => toast(t('k166'))}>
      {inner}
    </button>
  );
}
