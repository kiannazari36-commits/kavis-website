import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { useToast } from '../components/Toast';
import Wordmark from '../components/Wordmark';
import LangThemeSwitch from '../components/LangThemeSwitch';
import Icon, { AppleLogo, PlayLogo, type IconName } from '../components/Icon';
import s from './Landing.module.css';

// Design: design/DeskApp.dc.html, screen "landing" (web).
const FEATURES: [IconName, string, string][] = [
  ['upload', 'k18', 'k19'],
  ['spark', 'k20', 'k21'],
  ['list', 'k22', 'k23'],
  ['cards', 'k24', 'k25'],
  ['mic', 'k26', 'k27'],
  ['globe', 'k28', 'k29'],
];

export default function Landing() {
  const { t } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const toSignup = () => navigate('/login');
  const toLogin = () => navigate('/login?mode=login');
  const store = () => toast(t('k166'));
  const soon = () => toast(t('k165'));
  const toFeatures = () => document.getElementById('features')?.scrollIntoView({ behavior: 'smooth' });

  return (
    <div className={s.page}>
      <header className={s.header}>
        <a href="/" className={s.brand} aria-label="Kavis Study">
          <img src="/icon_star.png" alt="" width={40} height={40} />
          <Wordmark size={24.2} />
        </a>
        <span className={s.grow} />
        <nav className={s.links}>
          <button onClick={toFeatures}>{t('k0')}</button>
          <button onClick={soon}>{t('k1')}</button>
          <button onClick={() => navigate('/premium')}>{t('k2')}</button>
          <button onClick={soon}>{t('k3')}</button>
        </nav>
        <LangThemeSwitch />
        <button className={s.loginBtn} onClick={toLogin}>
          {t('k5')}
        </button>
        <button className={s.startBtn} onClick={toSignup}>
          {t('k6')}
        </button>
      </header>

      <section className={s.hero}>
        <div className={s.heroText}>
          <span className={`mono ${s.badge}`}>{t('k7')}</span>
          <h1 className={s.title}>
            {t('k8')} <span className={s.accent}>{t('k9')}</span> {t('k10')}
          </h1>
          <p className={s.lead}>{t('k11')}</p>
          <div className={s.stores}>
            <button className={s.store} onClick={store}>
              <AppleLogo size={22} />
              <span className={s.storeText}>
                <small>{t('k12')}</small>
                <b>App Store</b>
              </span>
            </button>
            <button className={s.store} onClick={() => toast(t('androidSoon'))}>
              <PlayLogo size={20} />
              <span className={s.storeText}>
                <small>{t('k13')}</small>
                <b>Google Play</b>
              </span>
            </button>
            <button className={s.store} onClick={store}>
              <AppleLogo size={22} />
              <span className={s.storeText}>
                <small>{t('k14')}</small>
                <b>macOS</b>
              </span>
            </button>
            <button className={s.webBtn} onClick={toSignup}>
              <Icon name="globe" size={18} />
              {t('k15')}
            </button>
          </div>
          <span className={s.devices}>{t('k16')}</span>
        </div>

        <div className={s.art} aria-hidden="true">
          <div className={s.laptop}>
            <div className={s.laptopSide}>
              <Wordmark size={12} />
              <span className={s.dotOn} />
              <span className={s.dot} />
              <span className={s.dot} />
              <span className={s.dot} />
            </div>
            <div className={s.laptopMain}>
              <span className={s.laptopTitle}>{t('k17')}</span>
              <span className={s.laptopHero} />
              <span className={s.laptopTiles}>
                <span style={{ background: 'var(--pri-soft)' }} />
                <span style={{ background: 'var(--amb-soft)' }} />
                <span style={{ background: 'var(--good-soft)' }} />
              </span>
              <span className={s.line} style={{ width: '60%' }} />
              <span className={s.line} style={{ width: '40%' }} />
            </div>
          </div>
          <div className={s.phone}>
            <div className={s.phoneScreen}>
              <img src="/icon_star.png" alt="" width={62} height={62} />
              <Wordmark size={14} />
            </div>
          </div>
        </div>
      </section>

      <section id="features" className={s.features}>
        {FEATURES.map(([icon, title, text]) => (
          <div key={title} className={s.feature}>
            <span className={s.featureIcon}>
              <Icon name={icon} size={21} />
            </span>
            <span className={s.featureText}>
              <b>{t(title)}</b>
              <span>{t(text)}</span>
            </span>
          </div>
        ))}
      </section>
    </div>
  );
}
