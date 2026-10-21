import { useI18n } from '../i18n/I18nProvider';
import { AppleLogo } from './Icon';
import StoreButton from './StoreButton';
import { APP_STORE_URL } from '../config';

// "Download on the App Store" (Premium page, share link page). "Yakında" until the iPhone app is live.
export default function AppStoreButton() {
  const { t } = useI18n();
  return <StoreButton url={APP_STORE_URL} logo={<AppleLogo size={24} />} small={t('k12')} name="App Store" />;
}
