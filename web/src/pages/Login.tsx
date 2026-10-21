import { useEffect, useRef, useState, type FormEvent } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { useToast } from '../components/Toast';
import Wordmark from '../components/Wordmark';
import LangThemeSwitch from '../components/LangThemeSwitch';
import Icon, { AppleLogo, GoogleLogo } from '../components/Icon';
import { logIn, resendCode, signUp, socialLogIn, verifyEmail, type Provider } from '../api/auth';
import s from './Login.module.css';

// Design: design/DeskApp.dc.html screen "login" (layout) + design/NewSignup.dc.html (sign up / log in / verify flow).
type Mode = 'signup' | 'login' | 'verify';

const DEMO_CODE = '481920';
const RESEND_SECONDS = 42;

// 0–4 bars: length, mixed case, digit, symbol.
function passwordScore(pw: string) {
  if (!pw) return 0;
  let n = pw.length >= 8 ? 1 : 0;
  if (/[a-zğüşöçı]/.test(pw) && /[A-ZĞÜŞÖÇİ]/.test(pw)) n++;
  if (/\d/.test(pw)) n++;
  if (/[^A-Za-z0-9ğüşöçıĞÜŞÖÇİ]/.test(pw)) n++;
  return Math.max(n, 1);
}

export default function Login() {
  const { t } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const mode: Mode = params.get('mode') === 'login' ? 'login' : params.get('mode') === 'verify' ? 'verify' : 'signup';
  const setMode = (m: Mode) => setParams(m === 'signup' ? {} : { mode: m }, { replace: m !== 'verify' });

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPw, setShowPw] = useState(false);
  const [consent, setConsent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [pending, setPending] = useState({ email: 'elif@ogrenci.edu.tr', name: 'Elif Yıldız' });

  const signup = mode === 'signup';
  const blocked = signup && !consent;
  const score = passwordScore(password);

  const social = async (p: Provider) => {
    setBusy(true);
    await socialLogIn(p);
    navigate('/home');
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (busy) return;
    if (blocked) {
      toast(t('needConsent'));
      return;
    }
    setBusy(true);
    if (signup) {
      const r = await signUp(name, email, password);
      setPending({ email: r.pendingEmail, name: r.name });
      setBusy(false);
      setMode('verify');
    } else {
      await logIn(email, password);
      navigate('/home');
    }
  };

  return (
    <div className={s.page}>
      <aside className={s.brandSide}>
        <Link to="/" className={s.logo} aria-label="Kavis Study">
          <img src="/icon_star.png" alt="" width={150} height={150} />
        </Link>
        <Wordmark size={34} />
        <div className={s.claim}>
          {t('k30')}
          <br />
          {t('k31')}
        </div>
        <div className={s.claim2}>{t('k32')}</div>
        <div className={s.steps}>
          {['k33', 'k34', 'k35'].map((k) => (
            <span key={k}>
              <Icon name="check" size={16} width={2.2} />
              {t(k)}
            </span>
          ))}
        </div>
      </aside>

      <main className={s.formSide}>
        <div className={s.topBar}>
          <Link to="/" className={s.back} aria-label={t('back')}>
            <Icon name="back" size={20} width={1.8} className="flip-rtl" />
          </Link>
          <span className={s.grow} />
          <LangThemeSwitch />
        </div>

        {mode === 'verify' ? (
          <Verify email={pending.email} name={pending.name} onBack={() => setMode('signup')} />
        ) : (
          <form className={s.form} onSubmit={submit} noValidate>
            <div role="tablist" aria-label={t('account')} className={s.tabs}>
              {(['signup', 'login'] as const).map((m) => (
                <button
                  key={m}
                  type="button"
                  role="tab"
                  aria-selected={mode === m}
                  className={mode === m ? `${s.tab} ${s.tabOn}` : s.tab}
                  onClick={() => setMode(m)}
                >
                  {t(m)}
                </button>
              ))}
            </div>

            <h1 className={s.title}>
              {signup ? t('titleUp1') : t('titleIn1')} <span>{signup ? t('titleUp2') : t('titleIn2')}</span>
            </h1>

            <button type="button" className={s.apple} onClick={() => social('apple')} disabled={busy}>
              <AppleLogo size={18} />
              {signup ? t('k39') : t('appleIn')}
            </button>
            <button type="button" className={s.google} onClick={() => social('google')} disabled={busy}>
              <GoogleLogo size={18} />
              {signup ? t('k40') : t('googleIn')}
            </button>

            <div className={s.divider}>
              <span />
              {t('k41')}
              <span />
            </div>

            {signup && (
              <label className={s.field}>
                {t('k42')}
                <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Elif Yıldız" autoComplete="name" />
              </label>
            )}
            <label className={s.field}>
              {t('k43')}
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="elif@ogrenci.edu.tr"
                autoComplete="email"
                dir="ltr"
              />
            </label>
            <label className={s.field}>
              {t('k44')}
              <span className={s.pwBox}>
                <input
                  type={showPw ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••"
                  autoComplete={signup ? 'new-password' : 'current-password'}
                  dir="ltr"
                />
                <button
                  type="button"
                  className={s.eye}
                  aria-label={showPw ? t('hidePw') : t('showPw')}
                  onClick={() => setShowPw(!showPw)}
                >
                  <Icon name={showPw ? 'eye' : 'eyeOff'} size={20} width={1.6} />
                </button>
              </span>
            </label>

            {signup && password && (
              <div className={s.strength}>
                <span className={s.bars}>
                  {[1, 2, 3, 4].map((i) => (
                    <span key={i} style={{ background: i <= score ? (score >= 3 ? 'var(--good)' : 'var(--amb)') : 'var(--sub)' }} />
                  ))}
                </span>
                {score >= 3 && <span className={s.strong}>{t('strong')}</span>}
              </div>
            )}
            {!signup && (
              <button type="button" className={s.forgot} onClick={() => toast(t('k165'))}>
                {t('forgot')}
              </button>
            )}

            {signup && (
              <button type="button" role="checkbox" aria-checked={consent} className={s.consent} onClick={() => setConsent(!consent)}>
                <span className={consent ? `${s.box} ${s.boxOn}` : s.box}>{consent && <Icon name="check" size={13} width={3} />}</span>
                <span>
                  <b>{t('terms')}</b> {t('and')} <b>{t('kvkk')}</b> {t('consentEnd')}
                </span>
              </button>
            )}

            <button type="submit" className={blocked ? `${s.submit} ${s.submitOff}` : s.submit} aria-disabled={blocked || busy}>
              {signup ? t('k45') : t('login')}
            </button>

            <button type="button" className={s.switch} onClick={() => setMode(signup ? 'login' : 'signup')}>
              {signup ? t('haveAccount') : t('noAccount')} <b>{signup ? t('login') : t('signup')}</b>
            </button>
            {!signup && <span className={s.legal}>{t('k46')}</span>}
          </form>
        )}
      </main>
    </div>
  );
}

function Verify({ email, name, onBack }: { email: string; name: string; onBack: () => void }) {
  const { t } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [digits, setDigits] = useState<string[]>(Array(6).fill(''));
  const [left, setLeft] = useState(RESEND_SECONDS);
  const [busy, setBusy] = useState(false);
  const refs = useRef<(HTMLInputElement | null)[]>([]);
  const code = digits.join('');
  const filled = code.length === 6;

  useEffect(() => {
    refs.current[0]?.focus();
  }, []);

  useEffect(() => {
    if (left <= 0) return;
    const id = setTimeout(() => setLeft(left - 1), 1000);
    return () => clearTimeout(id);
  }, [left]);

  const setFrom = (start: number, text: string) => {
    const only = text.replace(/\D/g, '').slice(0, 6 - start).split('');
    if (!only.length) return;
    const next = [...digits];
    only.forEach((d, i) => (next[start + i] = d));
    setDigits(next);
    refs.current[Math.min(start + only.length, 5)]?.focus();
  };

  const go = async () => {
    if (!filled) {
      toast(t('needCode'));
      return;
    }
    setBusy(true);
    await verifyEmail(email, name, code);
    navigate('/home');
  };

  const resend = async () => {
    if (left > 0) return;
    await resendCode(email);
    setLeft(RESEND_SECONDS);
  };

  return (
    <div className={s.verify}>
      <button type="button" className={s.verifyBack} onClick={onBack}>
        <Icon name="back" size={16} width={1.8} className="flip-rtl" />
        {t('back')}
      </button>
      <span className={s.mailIcon} aria-hidden="true">
        <Icon name="mail" size={40} width={1.5} />
      </span>
      <h1 className={s.title}>
        {t('checkA')} <span>{t('checkB')}</span>
      </h1>
      <p className={s.verifyText}>
        {t('code6')} <b dir="ltr">{email}</b> {t('sentTo')}
      </p>
      <div className={s.code} dir="ltr">
        {digits.map((d, i) => (
          <input
            key={i}
            ref={(el) => {
              refs.current[i] = el;
            }}
            className={`mono ${d || i === code.length ? s.codeOn : ''}`}
            value={d}
            inputMode="numeric"
            autoComplete={i === 0 ? 'one-time-code' : 'off'}
            aria-label={`${i + 1}/6`}
            maxLength={6}
            onChange={(e) => {
              const v = e.target.value.replace(/\D/g, '');
              if (!v) {
                const next = [...digits];
                next[i] = '';
                setDigits(next);
              } else setFrom(i, v);
            }}
            onKeyDown={(e) => {
              if (e.key === 'Backspace' && !d && i > 0) refs.current[i - 1]?.focus();
              if (e.key === 'Enter') go();
            }}
            onPaste={(e) => {
              e.preventDefault();
              setFrom(i, e.clipboardData.getData('text'));
            }}
          />
        ))}
      </div>
      <button type="button" className={s.paste} onClick={() => setFrom(0, DEMO_CODE)}>
        {t('paste')}
      </button>
      <button type="button" className={s.resend} onClick={resend} disabled={left > 0}>
        {t('resend')}{' '}
        {left > 0 && <span className="mono">0:{String(left).padStart(2, '0')}</span>}
      </button>
      <button type="button" className={filled ? s.submit : `${s.submit} ${s.submitOff}`} aria-disabled={!filled || busy} onClick={go}>
        {t('verifyGo')}
      </button>
    </div>
  );
}
