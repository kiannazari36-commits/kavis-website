import { useI18n } from '../i18n/I18nProvider';
import { useToast } from './Toast';
import Icon from './Icon';
import { signOutDevice, type Device } from '../api/devices';
import { lastSeen } from '../i18n/format';
import s from './DeviceList.module.css';

// Devices signed in to the account, each with a sign-out button (not for this device).
export default function DeviceList({ devices, onSignedOut }: { devices: Device[]; onSignedOut: (id: string) => void }) {
  const { t, lang } = useI18n();
  const toast = useToast();

  return (
    <ul className={s.list}>
      {devices.map((d) => (
        <li key={d.id} className={s.item}>
          <span className={s.icon}>
            <Icon name={d.kind === 'iphone' ? 'phone' : d.kind === 'ipad' ? 'tablet' : 'globe'} size={20} />
          </span>
          <span className={s.text}>
            <b dir="ltr">{d.name}</b>
            <span>{d.current ? t('devThis') + ' · ' + t('devActiveNow') : d.lastUsed ? t('devLastUsed').replace('{t}', lastSeen(d.lastUsed, lang)) : ''}</span>
          </span>
          {!d.current && (
            <button
              className={s.out}
              onClick={async () => {
                await signOutDevice(d.id);
                toast(t('devSignedOut').replace('{name}', d.name));
                onSignedOut(d.id);
              }}
            >
              {t('devSignOut')}
            </button>
          )}
        </li>
      ))}
    </ul>
  );
}
