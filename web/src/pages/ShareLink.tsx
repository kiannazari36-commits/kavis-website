import { useI18n } from '../i18n/I18nProvider';
import Wordmark from '../components/Wordmark';
import AppStoreButton from '../components/AppStoreButton';
import Icon from '../components/Icon';
import { currentUser } from '../api/auth';
import { useTrial } from '../trial/TrialProvider';
import { isAndroid } from '../config';
import s from './ShareLink.module.css';

// Page behind a share link (/s/:id). CLAUDE.md: no preview of the content, only "download the app".
// A signed-in student without Premium also sees that shared lessons need Premium.
export default function ShareLink() {
  const { t } = useI18n();
  const { trial } = useTrial();
  const signedInFree = !!currentUser() && !trial.premium;

  return (
    <div className={s.page}>
      <section className={s.card}>
        <img src="/icon_star.png" alt="" width={96} height={96} className={s.icon} />
        <Wordmark size={26} />
        <h1>{t('shareOpenTitle')}</h1>
        <p>{t('shareOpenSub')}</p>
        {isAndroid() ? <span className={s.android}>{t('androidNote')}</span> : <AppStoreButton />}
        {signedInFree && (
          <span className={s.premium}>
            <Icon name="lock" size={15} />
            {t('sharePremiumOnly')}
          </span>
        )}
      </section>
    </div>
  );
}
