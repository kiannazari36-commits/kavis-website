import { Link } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { LEGAL_CHROME, PRIVACY, TERMS } from '../i18n/legal';
import { cleanUpdated, visibleDoc } from '../i18n/legalView';
import { LEGAL_DRAFT_VISIBLE } from '../config';
import Wordmark from '../components/Wordmark';
import LangThemeSwitch from '../components/LangThemeSwitch';
import LegalLinks from '../components/LegalLinks';
import s from './Legal.module.css';

// Public pages /terms and /privacy. DRAFT texts (src/i18n/legal.ts), not yet checked by a lawyer.
// LEGAL_DRAFT_VISIBLE (config.ts) = false hides the draft banner and the lawyer notes.
export default function Legal({ kind }: { kind: 'terms' | 'privacy' }) {
  const { lang } = useI18n();
  const chrome = LEGAL_CHROME[lang];
  const doc = visibleDoc((kind === 'terms' ? TERMS : PRIVACY)[lang], LEGAL_DRAFT_VISIBLE);

  return (
    <div className={s.page}>
      <header className={s.header}>
        <Link to="/" className={s.brand} aria-label="Kavis Study">
          <img src="/icon_star.png" alt="" width={36} height={36} />
          <Wordmark size={22} />
        </Link>
        <span className={s.grow} />
        <LangThemeSwitch />
      </header>
      <main className={s.card}>
        {LEGAL_DRAFT_VISIBLE && (
          <p className={s.draft} role="note">
            {chrome.draft}
          </p>
        )}
        <h1>{doc.title}</h1>
        <p className={s.updated}>{LEGAL_DRAFT_VISIBLE ? chrome.updated : cleanUpdated(chrome.updated)}</p>
        {doc.sections.map((sec) => (
          <section key={sec.h}>
            <h2>{sec.h}</h2>
            {sec.p.map((p) => (
              <p key={p}>{p}</p>
            ))}
          </section>
        ))}
        <LegalLinks />
      </main>
    </div>
  );
}
