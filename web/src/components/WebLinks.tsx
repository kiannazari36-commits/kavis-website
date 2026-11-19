import { useI18n } from '../i18n/I18nProvider';
import type { ChatMessage } from '../api/assistant';

/** Only real web addresses are links (a javascript: or data: address from the AI is never shown). */
const safe = (url: string) => {
  try {
    return ['https:', 'http:'].includes(new URL(url).protocol);
  } catch {
    return false;
  }
};

/** The web pages an "AI + research" answer used, opened in a new tab (assistant chat and reader panel). */
export default function WebLinks({ links, className }: { links: ChatMessage['links']; className: string }) {
  const { t } = useI18n();
  links = links.filter((l) => safe(l.url));
  if (!links.length) return null;
  return (
    <span className={className}>
      <span className="mono">{t('webSources')}</span>
      {links.map((l) => (
        <a key={l.url} href={l.url} target="_blank" rel="noreferrer noopener" dir="auto">
          {l.title}
        </a>
      ))}
    </span>
  );
}
