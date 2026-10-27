import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import Wordmark from '../components/Wordmark';
import LangThemeSwitch from '../components/LangThemeSwitch';
import Icon, { AppleLogo, PlayLogo, type IconName } from '../components/Icon';
import StoreButton from '../components/StoreButton';
import { APP_STORE_URL, MAC_STORE_URL, PLAY_STORE_URL } from '../config';
import LegalLinks from '../components/LegalLinks';
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
// "Nasıl çalışır": three steps; "SSS": common questions (answers follow CLAUDE.md product rules).
const HOW: [IconName, string, string][] = [
  ['upload', 'how1T', 'how1S'],
  ['book', 'how2T', 'how2S'],
  ['checklist', 'how3T', 'how3S'],
];
const FAQ = ['faq1', 'faq2', 'faq3', 'faq4', 'faq5', 'faq6'];

export default function Landing() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const toSignup = () => navigate('/login');
  const toLogin = () => navigate('/login?mode=login');
  const scrollTo = (id: string) => () => document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' });
  const toFeatures = scrollTo('features');

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
          <button onClick={scrollTo('how')}>{t('k1')}</button>
          <button onClick={() => navigate('/premium')}>{t('k2')}</button>
          <button onClick={scrollTo('faq')}>{t('k3')}</button>
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
            <StoreButton url={APP_STORE_URL} logo={<AppleLogo size={22} />} small={t('k12')} name="App Store" />
            <StoreButton url={PLAY_STORE_URL} logo={<PlayLogo size={20} />} small={t('k13')} name="Google Play" />
            <StoreButton url={MAC_STORE_URL} logo={<AppleLogo size={22} />} small={t('k14')} name="macOS" />
            <button className={s.webBtn} onClick={toSignup}>
              <Icon name="globe" size={18} />
              {t('k15')}
            </button>
          </div>
          <span className={s.devices}>{t('storesSoon')}</span>
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

      <section id="how" className={s.how}>
        <h2>{t('k1')}</h2>
        <ol>
          {HOW.map(([icon, title, text], i) => (
            <li key={title} className={s.feature}>
              <span className={s.featureIcon}>
                <Icon name={icon} size={21} />
              </span>
              <span className={s.featureText}>
                <b>
                  {i + 1}. {t(title)}
                </b>
                <span>{t(text)}</span>
              </span>
            </li>
          ))}
        </ol>
      </section>

      <section id="faq" className={s.faq}>
        <h2>{t('k3')}</h2>
        {FAQ.map((k) => (
          <details key={k}>
            <summary>{t(`${k}Q`)}</summary>
            <p>{t(`${k}A`)}</p>
          </details>
        ))}
      </section>
      <LegalLinks />
    </div>
  );
}
