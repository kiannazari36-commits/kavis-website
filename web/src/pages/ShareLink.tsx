import { useI18n } from '../i18n/I18nProvider';
import Wordmark from '../components/Wordmark';
import AppStoreButton from '../components/AppStoreButton';
import Icon from '../components/Icon';
import { currentUser } from '../api/auth';
import { isPremium } from '../api/premium';
import s from './ShareLink.module.css';

// Page behind a share link (/s/:id). CLAUDE.md: no preview of the content, only "download the app".
// A signed-in student without Premium also sees that shared lessons need Premium.
export default function ShareLink() {
  const { t } = useI18n();
  const signedInFree = !!currentUser() && !isPremium();

  return (
    <div className={s.page}>
      <section className={s.card}>
        <img src="/icon_star.png" alt="" width={96} height={96} className={s.icon} />
        <Wordmark size={26} />
        <h1>{t('shareOpenTitle')}</h1>
        <p>{t('shareOpenSub')}</p>
        <AppStoreButton />
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
