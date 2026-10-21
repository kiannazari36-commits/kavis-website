import { Link } from 'react-router-dom';
import { LANGS, useI18n } from '../i18n/I18nProvider';
import { useTheme } from '../theme/ThemeProvider';
import { useToast } from '../components/Toast';
import { ROUTES } from '../routes';

// Temporary page used until each screen is built in step 3.
export default function Placeholder({ name }: { name: string }) {
  const { lang, setLang, t } = useI18n();
  const { theme, toggle } = useTheme();
  const toast = useToast();

  return (
    <main style={{ maxWidth: 760, margin: '0 auto', padding: '48px 16px', display: 'grid', gap: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <img src={theme === 'dark' ? '/icon_star_dark.png' : '/icon_star.png'} alt="" width={44} height={44} style={{ borderRadius: 12 }} />
        <strong style={{ fontSize: 22 }}>Kavis Study</strong>
      </div>
      <section className="card" style={{ padding: 24, display: 'grid', gap: 14 }}>
        <span className="mono" style={{ color: 'var(--text3)', fontSize: 12 }}>{name}</span>
        <h1 style={{ margin: 0, fontSize: 26 }}>{t('k17')}</h1>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
          {LANGS.map((l) => (
            <button key={l} className={l === lang ? 'btn btn-sm btn-pri' : 'btn btn-sm btn-ghost'} onClick={() => setLang(l)}>
              {l.toUpperCase()}
            </button>
          ))}
          <button className="btn btn-sm btn-amb" onClick={toggle}>
            {theme === 'dark' ? 'Light' : 'Dark'}
          </button>
          <button className="btn btn-sm btn-ghost" onClick={() => toast(t('k33'))}>
            Toast
          </button>
        </div>
      </section>
      <nav style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {ROUTES.map((r) => (
          <Link key={r.path} to={r.path} className="btn btn-sm btn-ghost">
            {r.name}
          </Link>
        ))}
      </nav>
    </main>
  );
}
