import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import Icon from '../components/Icon';
import DeviceList from '../components/DeviceList';
import { checkDeviceLimit } from '../api/devices';
import { useAsync } from '../hooks/useAsync';
import s from './DeviceLimit.module.css';

// Shown after login on a 3rd device (CLAUDE.md: max 2 devices, the web counts as one).
// Signing out one device lets the student continue here.
export default function DeviceLimit() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const devices = useAsync(checkDeviceLimit, []);

  return (
    <div className={s.page}>
      <section className={s.card} role="dialog" aria-labelledby="dev-title">
        <span className={s.icon}>
          <Icon name="phone" size={26} />
        </span>
        <h1 id="dev-title">{t('devFullTitle')}</h1>
        <p>{t('devFullSub')}</p>
        {devices && <DeviceList
            devices={devices}
            onSignedOut={async () => {
              // A slot is free now: register this browser, then continue.
              await checkDeviceLimit();
              navigate('/home', { replace: true });
            }}
          />}
        {devices === null && (
          <button className={s.go} onClick={() => navigate('/home', { replace: true })}>
            {t('k47')}
          </button>
        )}
        <span className={s.hint}>{t('devHint')}</span>
      </section>
    </div>
  );
}
