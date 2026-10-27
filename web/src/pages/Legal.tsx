import { Link } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { LEGAL_CHROME, PRIVACY, TERMS } from '../i18n/legal';
import Wordmark from '../components/Wordmark';
import LangThemeSwitch from '../components/LangThemeSwitch';
import LegalLinks from '../components/LegalLinks';
import s from './Legal.module.css';

// Public pages /terms and /privacy. DRAFT texts (src/i18n/legal.ts), not yet checked by a lawyer.
export default function Legal({ kind }: { kind: 'terms' | 'privacy' }) {
  const { lang } = useI18n();
  const chrome = LEGAL_CHROME[lang];
  const doc = (kind === 'terms' ? TERMS : PRIVACY)[lang];

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
        <p className={s.draft} role="note">
          {chrome.draft}
        </p>
        <h1>{doc.title}</h1>
        <p className={s.updated}>{chrome.updated}</p>
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
