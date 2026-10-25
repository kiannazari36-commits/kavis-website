import { useI18n } from '../i18n/I18nProvider';
import s from './Thinking.module.css';

// While the assistant thinks (before the first words arrive): three dots that bounce and a short word, so the
// student sees it is working (assistant chat and reader panel).
export default function Thinking({ className }: { className?: string }) {
  const { t } = useI18n();
  return (
    <div className={className ? `${s.box} ${className}` : s.box} role="status" aria-live="polite">
      <span className={s.dots} aria-hidden="true">
        <span />
        <span />
        <span />
      </span>
      <span className={s.word}>{t('thinking')}</span>
    </div>
  );
}
