import { Link } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { LEGAL_CHROME } from '../i18n/legal';
import s from './LegalLinks.module.css';

// Footer row: terms of use + privacy policy (draft pages, see pages/Legal.tsx).
export default function LegalLinks() {
  const { lang } = useI18n();
  const c = LEGAL_CHROME[lang];
  return (
    <nav className={s.row} aria-label="Legal">
      <Link to="/terms">{c.terms}</Link>
      <Link to="/privacy">{c.privacy}</Link>
      <Link to="/">{c.back}</Link>
    </nav>
  );
}
