import { useEffect } from 'react';
import { useI18n } from '../i18n/I18nProvider';
import Icon from './Icon';
import s from './KeysDialog.module.css';

// Settings › Computer › Keyboard shortcuts: what each key does (the keys work in AppShell, TopBar, Cards, Reader).
export default function KeysDialog({ onClose }: { onClose: () => void }) {
  const { t } = useI18n();
  const mac = /Mac|iPhone|iPad/.test(navigator.platform);
  const mod = mac ? '⌘' : 'Ctrl';
  const rows: [string, string][] = [
    [`${mod} K`, 'keySearch'],
    [`${mod} U`, 'keyUpload'],
    [`${mod} J`, 'keyAssistant'],
    [mac ? '⌃ ⌘ F' : 'F11', 'keyFull'],
    ['Esc', 'keyEsc'],
    [t('keySpace'), 'keyFlip'],
    ['1 · 2 · 3', 'keyRate'],
  ];

  useEffect(() => {
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [onClose]);

  return (
    <div className={s.modal}>
      <div className={s.scrim} onClick={onClose} />
      <section role="dialog" aria-modal="true" aria-labelledby="keys-title" className={s.dialog}>
        <div className={s.top}>
          <b id="keys-title">{t('k151')}</b>
          <button className={s.x} aria-label={t('close')} onClick={onClose}>
            <Icon name="close" size={16} />
          </button>
        </div>
        <dl>
          {rows.map(([k, label]) => (
            <div key={label}>
              <dt>
                <kbd>{k}</kbd>
              </dt>
              <dd>{t(label)}</dd>
            </div>
          ))}
        </dl>
      </section>
    </div>
  );
}
