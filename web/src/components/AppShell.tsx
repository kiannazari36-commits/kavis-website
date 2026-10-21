import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { useTheme } from '../theme/ThemeProvider';
import { useToast } from './Toast';
import { listCourses } from '../api/courses';
import { currentUser, logOut } from '../api/auth';
import { useAsync } from '../hooks/useAsync';
import { COURSE_COLOR } from './courseColors';
import Wordmark from './Wordmark';
import Icon, { type IconName } from './Icon';
import s from './AppShell.module.css';

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
  const toast = useToast();
  const navigate = useNavigate();
  const location = useLocation();
  const courses = useAsync(listCourses, []);
  const user = currentUser() ?? { name: 'Elif Yıldız' };
  const initials = user.name
    .split(' ')
    .map((w) => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();
  const [open, setOpen] = useState(false);

  // Close the mobile menu after navigating.
  useEffect(() => setOpen(false), [location.pathname, location.search]);

  return (
    <div className={s.shell}>
      <div className={s.mobileBar}>
        <button className={s.iconBtn} aria-label={t('menu')} aria-expanded={open} onClick={() => setOpen(true)}>
          <Icon name="menu" />
        </button>
        <Wordmark size={18} />
        <span className={s.grow} />
        <img src="/icon_star.png" alt="" width={34} height={34} />
      </div>
      {open && <div className={s.scrim} onClick={() => setOpen(false)} />}

      <aside className={open ? `${s.side} ${s.sideOpen}` : s.side}>
        <div className={s.logo}>
          <Wordmark size={24} />
          <button className={`${s.iconBtn} ${s.closeBtn}`} aria-label={t('menu')} onClick={() => setOpen(false)}>
            <Icon name="close" />
          </button>
        </div>
        <button className={s.upload} onClick={() => toast(t('k165'))}>
          <Icon name="upload" size={18} />
          {t('k33')}
        </button>
        {NAV.map(([to, icon, key]) => (
          <NavLink key={to} to={to} className={({ isActive }) => (isActive ? `${s.nav} ${s.navOn}` : s.nav)}>
            <Icon name={icon} size={19} />
            {t(key)}
          </NavLink>
        ))}
        <div className={`mono ${s.section}`}>{t('k52')}</div>
        {courses?.slice(0, 4).map((c) => (
          <NavLink key={c.id} to={`/courses/${c.id}`} className={({ isActive }) => (isActive ? `${s.course} ${s.courseOn}` : s.course)}>
            <span className={s.dot} style={{ background: COURSE_COLOR[c.color].main }} />
            <span className={s.ellipsis}>{(c.short ?? c.name)[lang]}</span>
          </NavLink>
        ))}
        <span className={s.grow} />
        <div className={s.premium}>
          <b>{t('k57')}</b>
          <span>{t('k58')}</span>
          <button onClick={() => navigate('/premium')}>{t('k59')}</button>
        </div>
        <div className={s.profile}>
          <button
            className={s.profileMain}
            title={t('logout')}
            onClick={async () => {
              await logOut();
              navigate('/');
            }}
          >
            <span className={s.avatar}>{initials}</span>
            <span className={s.profileText}>
              <b>{user.name}</b>
              <span>{t('k60')}</span>
            </span>
          </button>
          <button className={s.themeBtn} aria-label={t('theme')} onClick={toggle}>
            <Icon name="moon" size={18} />
          </button>
        </div>
      </aside>

      <div className={s.content}>
        <Outlet />
      </div>
    </div>
  );
}
