import { useState } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num, shortDate } from '../i18n/format';
import Icon from '../components/Icon';
import { useAsync } from '../hooks/useAsync';
import { getAdminStats } from '../api/admin';
import s from './Admin.module.css';

// The owner's page: not in any menu, opened at /admin. Everyone else is sent home (the server refuses them too).

export default function Admin() {
  const { t, lang } = useI18n();
  const navigate = useNavigate();
  const [reload, setReload] = useState(0);
  const [query, setQuery] = useState('');
  const stats = useAsync(getAdminStats, [reload]);

  if (stats === undefined) return <main className={s.main} />;
  if (stats === 'notAdmin') return <Navigate to="/home" replace />;
  if (stats === 'failed')
    return (
      <main className={s.main}>
        <h1>{t('adm_title')}</h1>
        <p className={s.lead}>{t('adm_failed')}</p>
        <div>
          <button className={s.ghost} onClick={() => setReload((n) => n + 1)}>
            {t('adm_refresh')}
          </button>
        </div>
      </main>
    );

  const { totals, users } = stats;
  const q = query.trim().toLocaleLowerCase(lang);
  const shown = q ? users.filter((u) => u.email.toLocaleLowerCase(lang).includes(q) || u.name.toLocaleLowerCase(lang).includes(q)) : users;
  const day = (iso: string | null) => (iso ? shortDate(iso.slice(0, 10), lang) : '—');
  const tiles: [string, number | string][] = [
    ['adm_users', num(totals.users, lang)],
    ['adm_new7', num(totals.new7, lang)],
    ['adm_active7', num(totals.active7, lang)],
    ['adm_premium', num(totals.premium, lang)],
    ['adm_trial', num(totals.trial, lang)],
    ['adm_ended', num(totals.ended, lang)],
    ['adm_lessons', num(totals.lessons, lang)],
    ['adm_cost', `$${totals.costMonth.toFixed(2)}`],
  ];

  return (
    <main className={s.main}>
      <div className={s.head}>
        <button className={s.round} aria-label={t('back')} onClick={() => navigate('/home')}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <h1>{t('adm_title')}</h1>
        <span className={s.grow} />
        <button className={s.ghost} onClick={() => setReload((n) => n + 1)}>
          {t('adm_refresh')}
        </button>
      </div>
      <p className={s.lead}>{t('adm_lead')}</p>

      <div className={s.tiles}>
        {tiles.map(([k, v]) => (
          <div key={k} className={s.tile}>
            <span className="mono">{v}</span>
            <small>{t(k)}</small>
          </div>
        ))}
      </div>

      <section className={s.card}>
        <div className={s.listHead}>
          <h2>{t('adm_list')}</h2>
          <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t('adm_search')} aria-label={t('adm_search')} />
        </div>
        <div className={s.tableWrap}>
          <table>
            <thead>
              <tr>
                <th>{t('adm_email')}</th>
                <th>{t('adm_joined')}</th>
                <th>{t('adm_last')}</th>
                <th>{t('adm_status')}</th>
                <th>{t('adm_lessonsCol')}</th>
                <th>{t('adm_questions')}</th>
                <th>{t('adm_costCol')}</th>
              </tr>
            </thead>
            <tbody>
              {shown.map((u) => (
                <tr key={u.email + u.joined}>
                  <td>
                    <b dir="ltr">{u.email}</b>
                    {u.name && <span dir="auto">{u.name}</span>}
                    {!u.confirmed && <em>{t('adm_unconfirmed')}</em>}
                  </td>
                  <td className="mono">{day(u.joined)}</td>
                  <td className="mono">{day(u.lastLogin)}</td>
                  <td>
                    <span className={`${s.badge} ${s[u.status]}`}>{t(`adm_st_${u.status}`)}</span>
                  </td>
                  <td className="mono">{num(u.lessons, lang)}</td>
                  <td className="mono">{num(u.questions, lang)}</td>
                  <td className="mono">${u.cost.toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <small className={s.note}>{t('adm_privacy')}</small>
      </section>
    </main>
  );
}
