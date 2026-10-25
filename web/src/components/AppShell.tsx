import { useEffect, useState } from 'react';
import { Navigate, NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { useTheme } from '../theme/ThemeProvider';
import { listCourses } from '../api/courses';
import { currentUser, logOut } from '../api/auth';
import { cancelDeletion, clearProfile, DELETION_EVENT, deletionDate, getProfile } from '../api/account';
import { useToast } from './Toast';
import { checkThisDevice, signOutThisDevice } from '../api/devices';
import { studyLine } from '../i18n/format';
import { useAsync } from '../hooks/useAsync';
import { usePanelPref } from '../hooks/usePanelPref';
import { COURSE_COLOR } from './courseColors';
import Wordmark from './Wordmark';
import TrialCard from '../trial/TrialCard';
import Icon, { type IconName } from './Icon';
import s from './AppShell.module.css';

/** Shared with pages inside the shell (read with useOutletContext). */
export type ShellContext = {
  /** Focus mode: hides the menu and top bar, e.g. for full-screen reading. */
  focus: boolean;
  setFocus: (on: boolean) => void;
};

// Sidebar from design/DeskApp.dc.html (home / courses / settings screens).
const NAV: [string, IconName, string][] = [
  ['/home', 'home', 'k47'],
  ['/courses', 'book', 'k48'],
  ['/plan', 'calendar', 'k49'],
  ['/progress', 'chart', 'k50'],
  ['/settings', 'sliders', 'k51'],
];

export default function AppShell() {
  const { t, lang } = useI18n();
  const { toggle } = useTheme();
  const navigate = useNavigate();
  const location = useLocation();
  const courses = useAsync(listCourses, []);
  const user = currentUser();
  const profile = useAsync(getProfile, []);
  const initials = (profile?.name || user?.name || user?.email || '?')
    .split(' ')
    .map((w) => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();
  const [open, setOpen] = useState(false);
  const [focus, setFocus] = useState(false);
  const toast = useToast();
  // "Hesabın … tarihinde silinecek · Vazgeç" while a deletion waits its 30 days.
  const [delCheck, setDelCheck] = useState(0);
  const deleteOn = useAsync(deletionDate, [delCheck]);
  useEffect(() => {
    const again = () => setDelCheck((n) => n + 1);
    window.addEventListener(DELETION_EVENT, again);
    return () => window.removeEventListener(DELETION_EVENT, again);
  }, []);
  // Desktop: wide menu (open) or the narrow icon rail of the iPad design (closed). Remembered.
  const [wide, setWide] = usePanelPref('kavis.sideOpen', 1280);

  // Close the mobile menu after navigating.
  useEffect(() => setOpen(false), [location.pathname, location.search]);

  // Once per visit: signed out from another device → back to login; account full → choose a device.
  useEffect(() => {
    if (!currentUser()) return;
    checkThisDevice().then(({ signedOut, full }) => {
      if (signedOut) {
        clearProfile();
        navigate('/login?mode=login', { replace: true });
      } else if (full) navigate('/devices', { replace: true });
    });
  }, [navigate]);

  // App pages need a signed-in student.
  if (!user) return <Navigate to="/login?mode=login" replace />;

  return (
    <div className={focus ? `${s.shell} ${s.focus}` : s.shell}>
      <div className={s.mobileBar}>
        <button className={s.iconBtn} aria-label={t('menu')} aria-expanded={open} onClick={() => setOpen(true)}>
          <Icon name="menu" />
        </button>
        <Wordmark size={18} />
        <span className={s.grow} />
        <img src="/icon_star.png" alt="" width={34} height={34} />
      </div>
      {open && <div className={s.scrim} onClick={() => setOpen(false)} />}

      <aside aria-label={t('mainNav')} className={[s.side, open ? s.sideOpen : '', wide ? '' : s.rail].join(' ')}>
        <div className={s.logo}>
          <span className={s.logoWide}>
            <Wordmark size={24} />
          </span>
          <span className={s.logoRail}>
            <Wordmark size={18} />
          </span>
          <button
            className={s.toggle}
            aria-label={t(wide ? 'sideCollapse' : 'sideExpand')}
            title={t(wide ? 'sideCollapse' : 'sideExpand')}
            aria-expanded={wide}
            onClick={() => setWide(!wide)}
          >
            <Icon name="panel" size={18} className={wide ? '' : 'flip-rtl'} />
          </button>
          <button className={`${s.iconBtn} ${s.closeBtn}`} aria-label={t('menu')} onClick={() => setOpen(false)}>
            <Icon name="close" />
          </button>
        </div>
        {NAV.map(([to, icon, key]) => (
          <NavLink key={to} to={to} title={t(key)} className={({ isActive }) => (isActive ? `${s.nav} ${s.navOn}` : s.nav)}>
            <Icon name={icon} size={19} />
            <span className={s.label}>{t(key)}</span>
          </NavLink>
        ))}
        <div className={`mono ${s.section} ${s.wideOnly}`}>{t('k52')}</div>
        {courses?.slice(0, 4).map((c) => (
          <NavLink key={c.id} to={`/courses/${c.id}`} className={({ isActive }) => `${s.course} ${s.wideOnly} ${isActive ? s.courseOn : ''}`}>
            <span className={s.dot} style={{ background: COURSE_COLOR[c.color].main }} />
            <span className={s.ellipsis}>{c.short ?? c.name}</span>
          </NavLink>
        ))}
        <span className={s.grow} />
        <div className={s.wideOnly}>
          <TrialCard />
        </div>
        <div className={s.profile}>
          <button
            className={s.profileMain}
            title={t('logout')}
            onClick={async () => {
              await signOutThisDevice();
              await logOut();
              clearProfile();
              navigate('/');
            }}
          >
            <span className={s.avatar}>{initials}</span>
            <span className={`${s.profileText} ${s.label}`}>
              <b>{profile?.name || user.name || user.email}</b>
              <span>{profile && studyLine(profile.department, profile.classYear, lang)}</span>
            </span>
          </button>
          <button className={s.themeBtn} aria-label={t('theme')} onClick={toggle}>
            <Icon name="moon" size={18} />
          </button>
        </div>
      </aside>

      <div className={s.content}>
        <Outlet context={{ focus, setFocus } satisfies ShellContext} />
      </div>

      {deleteOn && !focus && (
        <div className={s.delBanner} role="status">
          <Icon name="trash" size={16} />
          <span>{t('delBanner').replace('{date}', new Date(deleteOn).toLocaleDateString(lang, { day: 'numeric', month: 'long' }))}</span>
          <button onClick={async () => toast(t((await cancelDeletion()) ? 'delUndone' : 'delFailed'))}>{t('delUndo')}</button>
        </div>
      )}
    </div>
  );
}
