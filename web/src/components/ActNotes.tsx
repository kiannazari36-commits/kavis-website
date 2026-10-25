import { useI18n } from '../i18n/I18nProvider';
import Icon from './Icon';
import type { ChatMessage } from '../api/assistant';

/** What the assistant did when the student asked (assistant chat and reader panel), e.g. "Zayıf konularına eklendi". */
export default function ActNotes({ acts, className }: { acts: ChatMessage['acts']; className: string }) {
  const { t } = useI18n();
  if (!acts.length) return null;
  return (
    <span className={className}>
      {acts.map((a) => (
        <span key={a.kind + a.title}>
          <Icon name={a.kind === 'weak' ? 'target' : 'cards'} size={13} />
          {t(a.kind === 'weak' ? 'actWeak' : 'actCard')}
          <b dir="auto">{a.title}</b>
        </span>
      ))}
    </span>
  );
}
