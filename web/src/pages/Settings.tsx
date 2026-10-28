import { useEffect, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { LANGS, LANG_NAMES, useI18n } from '../i18n/I18nProvider';
import { hoursLabel, num, studyLine } from '../i18n/format';
import { useTheme, type ThemePref } from '../theme/ThemeProvider';
import { useToast } from '../components/Toast';
import TopBar from '../components/TopBar';
import Switch from '../components/Switch';
import Icon from '../components/Icon';
import ContentLangPicker from '../components/ContentLangPicker';
import { useContentLang, useSettings } from '../settings/SettingsProvider';
import { currentUser, logOut } from '../api/auth';
import { clearProfile, deleteAccount, getProfile, requestMyData, saveProfile, type Profile } from '../api/account';
import { useTrial } from '../trial/TrialProvider';
import RedeemCode from '../components/RedeemCode';
import DeviceList from '../components/DeviceList';
import { listDevices, signOutThisDevice, type Device } from '../api/devices';
import { useAsync } from '../hooks/useAsync';
import KeysDialog from '../components/KeysDialog';
import { SUPPORT_EMAIL } from '../config';
import s from './Settings.module.css';

/** Where students write for help (Settings › Help and support). */

// Design: design/DeskApp.dc.html screen "settings" (web layout: section menu + cards),
// section contents from design/NewIPad.dc.html "Profil ve ayarlar". "Content language" is new (CLAUDE.md).

const SECTIONS = ['account', 'devices', 'plan', 'look', 'lang', 'notif', 'offline', 'privacy', 'help'] as const;
type Section = (typeof SECTIONS)[number];
const SECTION_KEY: Record<Section, string> = {
  account: 'k129',
  devices: 'devTitle',
  plan: 'k130',
  look: 'k131',
  lang: 'k132',
  notif: 'k133',
  offline: 'k134',
  privacy: 'k135',
  help: 'k136',
};

function Row({ title, sub, children }: { title: string; sub?: string; children: ReactNode }) {
  return (
    <div className={s.row}>
      <span className={s.rowText}>
        <b>{title}</b>
        {sub && <span>{sub}</span>}
      </span>
      <span className={s.rowCtl}>{children}</span>
    </div>
  );
}

function Seg<T extends string>({ value, options, onChange, label }: { value: T; options: [T, string][]; onChange: (v: T) => void; label: string }) {
  return (
    <span role="radiogroup" aria-label={label} className={s.seg}>
      {options.map(([v, l]) => (
        <button key={v} role="radio" aria-checked={value === v} className={value === v ? s.segOn : ''} onClick={() => onChange(v)}>
          {l}
        </button>
      ))}
    </span>
  );
}

export default function Settings() {
  const { t, lang, setLang } = useI18n();
  const { pref, setPref } = useTheme();
  const toast = useToast();
  const navigate = useNavigate();
  const [keysOpen, setKeysOpen] = useState(false);
  const { settings, patch, setContentLang } = useSettings();
  const { trial } = useTrial();
  const loaded = useAsync(listDevices, []);
  const [removed, setRemoved] = useState<string[]>([]);
  const devices: Device[] = (loaded ?? []).filter((d) => !removed.includes(d.id));
  const contentLang = useContentLang({ id: '', language: 'tr' });
  const user = currentUser();
  const [active, setActive] = useState<Section>('look');
  const [editing, setEditing] = useState(false);
  const [profile, setProfile] = useState<Profile>({ name: user?.name ?? '', email: user?.email ?? '', school: '', department: '', classYear: null });
  useEffect(() => {
    getProfile().then((p) => p && setProfile(p));
  }, []);
  const [delOpen, setDelOpen] = useState(false);
  const [delPass, setDelPass] = useState('');
  const [delErr, setDelErr] = useState('');
  const [delBusy, setDelBusy] = useState(false);
  const isMac = /Mac|iPhone|iPad/.test(navigator.platform);

  const go = (id: Section) => {
    setActive(id);
    document.getElementById(`set-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  // Asks the browser for notification permission when switched on.
  const setBrowserNotif = async (on: boolean) => {
    if (on && 'Notification' in window && Notification.permission === 'default') await Notification.requestPermission();
    patch({ browserNotifications: on });
  };

  const initials = profile.name
    .split(' ')
    .map((w) => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();

  return (
    <main className={s.main}>
      <div className={s.head}>
        <TopBar />
        <h1>{t('k51')}</h1>
      </div>

      <div className={s.layout}>
        <nav className={s.nav}>
          {SECTIONS.map((id) => (
            <button key={id} aria-current={active === id} className={active === id ? s.navOn : ''} onClick={() => go(id)}>
              {t(SECTION_KEY[id])}
            </button>
          ))}
        </nav>

        <div className={s.sections}>
          {/* Account */}
          <section id="set-account" className={s.profile}>
            <span className={s.avatar}>{initials}</span>
            <span className={s.profileText}>
              <b>{profile.name}</b>
              <span>{[profile.email, profile.school, studyLine(profile.department, profile.classYear, lang)].filter(Boolean).join(' · ')}</span>
              <span className={s.planTag}>
                {trial.premium
                  ? trial.premiumUntil
                    ? t('codeActive').replace('{date}', new Date(trial.premiumUntil).toLocaleDateString(lang, { day: 'numeric', month: 'long', year: 'numeric' }))
                    : 'Premium'
                  : trial.ended
                    ? t('trialEnded')
                    : `${t('trialTitle')} · ${t('trialDaysLeft').replace('{n}', num(trial.daysLeft, lang))}`}
              </span>
            </span>
            <button className={s.ghost} onClick={() => setEditing(!editing)}>
              {t('edit')}
            </button>
            <button className={s.amb} onClick={() => navigate('/premium')}>
              {t('goPremium')}
            </button>
          </section>
          <section className={s.card}>
            <Row title={t('codeHave')}>
              <RedeemCode />
            </Row>
          </section>
          {editing && (
            <form
              className={`${s.card} ${s.editForm}`}
              onSubmit={async (e) => {
                e.preventDefault();
                try {
                  setProfile({ ...profile, ...(await saveProfile(profile)) });
                  setEditing(false);
                  toast(t('saved'));
                } catch {
                  toast(t('errOther'));
                }
              }}
            >
              <label>
                {t('fullName')}
                <input value={profile.name} onChange={(e) => setProfile({ ...profile, name: e.target.value })} autoComplete="name" />
              </label>
              <label>
                {t('email')}
                <input type="email" dir="ltr" value={profile.email} onChange={(e) => setProfile({ ...profile, email: e.target.value })} autoComplete="email" />
              </label>
              <label>
                {t('school')}
                <input value={profile.school} onChange={(e) => setProfile({ ...profile, school: e.target.value })} />
              </label>
              <button type="submit" className={s.pri}>
                {t('save')}
              </button>
            </form>
          )}

          {/* My devices (CLAUDE.md: max 2, the web counts as one) */}
          <section id="set-devices" className={s.card}>
            <h2>{t('devTitle')}</h2>
            <p className={s.cardHint}>{t('devHint')}</p>
            <DeviceList devices={devices} onSignedOut={(id) => setRemoved([...removed, id])} />
          </section>

          {/* Study plan */}
          <section id="set-plan" className={s.card}>
            <h2>{t('k130')}</h2>
            <Row title={t('studyDays')} sub={t('studyDaysHint')}>
              <span className={s.days}>
                {[1, 2, 3, 4, 5, 6, 7].map((n) => (
                  <button key={n} aria-pressed={settings.studyDays === n} className={settings.studyDays === n ? s.dayOn : ''} onClick={() => patch({ studyDays: n })}>
                    {num(n, lang)}
                  </button>
                ))}
              </span>
            </Row>
            <Row title={t('hoursPerDay')}>
              <span className={s.stepper}>
                <button aria-label="−" onClick={() => patch({ studyHours: Math.max(0.5, settings.studyHours - 0.5) })}>
                  −
                </button>
                <b>{hoursLabel(settings.studyHours, lang, t)}</b>
                <button aria-label="+" onClick={() => patch({ studyHours: Math.min(8, settings.studyHours + 0.5) })}>
                  +
                </button>
              </span>
            </Row>
          </section>

          {/* Appearance (DeskApp design) */}
          <section id="set-look" className={s.card}>
            <h2>{t('k131')}</h2>
            <Row title={t('k137')} sub={t('k138')}>
              <Seg<ThemePref>
                label={t('k137')}
                value={pref}
                onChange={setPref}
                options={[
                  ['light', t('k139')],
                  ['dark', t('k140')],
                  ['system', t('k141')],
                ]}
              />
            </Row>
            <Row title={t('k142')} sub={t('k143')}>
              <Seg
                label={t('k142')}
                value={settings.readerPaper}
                onChange={(v) => patch({ readerPaper: v })}
                options={[
                  ['light', t('k139')],
                  ['sepia', t('k144')],
                  ['dark', t('k140')],
                ]}
              />
            </Row>
            <Row title={t('k145')} sub={t('k146')}>
              <span className={s.size}>
                A
                <input
                  type="range"
                  min={15}
                  max={26}
                  value={settings.readerFontSize}
                  aria-label={t('k145')}
                  onChange={(e) => patch({ readerFontSize: +e.target.value })}
                />
                <span>A</span>
              </span>
            </Row>
            <Row title={t('k147')} sub={t('k148')}>
              <button
                className={s.ghost}
                onClick={() => {
                  try {
                    localStorage.removeItem('kavis.pdfPos');
                  } catch {
                    /* ignore */
                  }
                  toast(t('resetDone'));
                }}
              >
                <Icon name="refresh" size={15} />
                {t('k149')}
              </button>
            </Row>
          </section>

          <section className={s.card}>
            <h2>{t('k150')}</h2>
            <Row title={t('k151')} sub={t(isMac ? 'k162' : 'k152')}>
              <button className={s.link} onClick={() => setKeysOpen(true)}>
                {t('k153')}
              </button>
            </Row>
            <Row title={t('k154')} sub={t('k155')}>
              <Switch label={t('k154')} on={settings.browserNotifications} onChange={setBrowserNotif} />
            </Row>
            <Row title={t('k156')} sub={t('k157')}>
              <Switch label={t('k156')} on={settings.sync} onChange={(v) => patch({ sync: v })} />
            </Row>
          </section>

          {/* Language and translation */}
          <section id="set-lang" className={s.card}>
            <h2>{t('k132')}</h2>
            <Row title={t('appLanguage')}>
              <span className={s.chips}>
                {LANGS.map((l) => (
                  <button key={l} aria-pressed={lang === l} className={lang === l ? s.chipOn : ''} onClick={() => setLang(l)}>
                    {LANG_NAMES[l]}
                  </button>
                ))}
              </span>
            </Row>
            <Row title={t('trStyle')} sub={t(settings.translationStyle === 'literal' ? 'hintLiteral' : 'hintNatural')}>
              <Seg
                label={t('trStyle')}
                value={settings.translationStyle}
                onChange={(v) => patch({ translationStyle: v })}
                options={[
                  ['literal', t('literal')],
                  ['natural', t('natural')],
                ]}
              />
            </Row>
            <div className={s.block}>
              <span className={s.rowText}>
                <b>{t('contentLang')}</b>
                <span>{t('contentLangHint')}</span>
              </span>
              <ContentLangPicker value={settings.contentLang} resolved={contentLang} onChange={(v) => v && setContentLang(v)} />
            </div>
          </section>

          {/* Notifications */}
          <section id="set-notif" className={s.card}>
            <h2>{t('k133')}</h2>
            <Row title={t('reminderTime')} sub={t('reminderVal')}>
              <button className={s.ghost} onClick={() => navigate('/plan')}>
                <Icon name="calendar" size={15} />
                {t('k49')}
              </button>
            </Row>
            <Row title={t('cheerNotif')} sub={t('cheerNotifS')}>
              <Switch
                label={t('cheerNotif')}
                on={settings.cheerNotifications}
                onChange={(v) => (patch({ cheerNotifications: v }), toast(t(v ? 'cheerOn' : 'cheerOff')))}
              />
            </Row>
            <Row title={t('scheduleT')} sub={t('scheduleS')}>
              <button className={s.ghost} onClick={() => navigate('/schedule')}>
                {t('scheduleBtn')}
              </button>
            </Row>
          </section>

          {/* Offline (every plan, CLAUDE.md) */}
          <section id="set-offline" className={s.card}>
            <h2>{t('offTitle')}</h2>
            <Row title={t('offModeT')} sub={t('offModeS')}>
              <Switch label={t('offModeT')} on={settings.offlineMode} onChange={(v) => (patch({ offlineMode: v }), toast(t(v ? 'offOn' : 'offOff')))} />
            </Row>
            <Row title={t('autoDlT')} sub={t('autoDlS')}>
              <Switch label={t('autoDlT')} on={settings.autoDownload} onChange={(v) => (patch({ autoDownload: v }), toast(t(v ? 'dlOn' : 'dlOff')))} />
            </Row>
            <div className={s.block}>
              <span className={s.storageHead}>
                <b>{t('storageT')}</b>
                <span>{t('storageS')}</span>
              </span>
              <span className={s.storageBar}>
                <span />
              </span>
              <span className={s.note}>
                <Icon name="check" size={14} width={2.2} />
                {t('storageNote')}
              </span>
              <button className={s.ghost} onClick={() => toast(t('manageToast'))}>
                {t('storageBtn')}
              </button>
            </div>
          </section>

          {/* Privacy */}
          <section id="set-privacy" className={s.privacy}>
            <span className={s.privacyIcon}>
              <Icon name="lock" size={22} />
            </span>
            <span className={s.rowText}>
              <b>{t('k158')}</b>
              <span>{t('k159')}</span>
            </span>
            <button
              className={s.ghost}
              onClick={async () => {
                toast(t('expMaking'));
                toast(t((await requestMyData()) ? 'expReady' : 'expFailed'));
              }}
            >
              {t('k160')}
            </button>
            <button
              className={s.ghost}
              onClick={async () => {
                await signOutThisDevice();
                await logOut();
                clearProfile();
                navigate('/');
              }}
            >
              {t('logout')}
            </button>
            <button className={s.danger} onClick={() => setDelOpen(true)}>
              {t('k161')}
            </button>
          </section>

          {/* Help */}
          <section id="set-help" className={s.privacy}>
            <span className={`${s.privacyIcon} ${s.helpIcon}`}>
              <Icon name="help" size={22} />
            </span>
            <span className={s.rowText}>
              <b>{t('helpT')}</b>
              <span>{t('helpS')}</span>
            </span>
            <button className={s.ghost} onClick={() => navigate('/help')}>
              {t('hpOpen')}
            </button>
            <button className={s.ghost} onClick={() => navigate('/notifications')}>
              {t('notifsBtn')}
            </button>
            {/* Support by e-mail: opens the mail app with the address and a subject. */}
            <a className={s.ghost} href={`mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(t('supportSubject'))}`}>
              {t('supportBtn')}
            </a>
          </section>
        </div>
      </div>

      {delOpen && (
        <div className={s.modal}>
          <div className={s.scrim} onClick={() => setDelOpen(false)} />
          <section role="dialog" aria-modal="true" aria-label={t('delTitle')} className={s.dialog}>
            <span className={s.delIcon}>
              <Icon name="trash" size={26} />
            </span>
            <b className={s.delTitle}>{t('delTitle')}</b>
            <span className={s.delText}>{t('delText')}</span>
            <span className={s.delSub}>{t('delSub')}</span>
            <span className={s.delMail}>{t('delWait')}</span>
            {/* The password once more, so nobody deletes the account from a computer left open. */}
            <input
              className={s.delPass}
              type="password"
              autoComplete="current-password"
              value={delPass}
              onChange={(e) => (setDelPass(e.target.value), setDelErr(''))}
              placeholder={t('delPassHint')}
              aria-label={t('delPassHint')}
            />
            {delErr && <span className={s.delErr}>{delErr}</span>}
            <div className={s.delBtns}>
              <button className={s.ghostBig} onClick={() => (setDelOpen(false), setDelPass(''), setDelErr(''))}>
                {t('delCancel')}
              </button>
              <button
                className={s.dangerBig}
                aria-busy={delBusy}
                onClick={async () => {
                  if (!delPass) return setDelErr(t('delPassHint'));
                  if (delBusy) return;
                  setDelBusy(true);
                  const r = await deleteAccount(delPass);
                  setDelBusy(false);
                  if ('error' in r) return setDelErr(t(r.error === 'password' ? 'delPassWrong' : 'delFailed'));
                  setDelOpen(false);
                  setDelPass('');
                  toast(t('delScheduled').replace('{date}', new Date(r.scheduledFor).toLocaleDateString(lang, { day: 'numeric', month: 'long' })));
                }}
              >
                {t('k161')}
              </button>
            </div>
          </section>
        </div>
      )}
    {keysOpen && <KeysDialog onClose={() => setKeysOpen(false)} />}
    </main>
  );
}
