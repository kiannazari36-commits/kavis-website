import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import Wordmark from '../components/Wordmark';
import Icon from '../components/Icon';
import { confirmDeletion } from '../api/account';
import s from './ConfirmDelete.module.css';

// Page behind the link in the "Hesabı sil" email (/account/delete#t=<token>). Nothing happens on open (some mail
// apps open links by themselves); the deletion starts only with the button. No login needed: the token is the proof.
export default function ConfirmDelete() {
  const { t, lang } = useI18n();
  const navigate = useNavigate();
  const token = new URLSearchParams(window.location.hash.slice(1)).get('t') ?? '';
  const [busy, setBusy] = useState(false);
  const [state, setState] = useState<{ date: string } | { error: string } | null>(token ? null : { error: 'delLinkBad' });

  async function confirm() {
    if (busy) return;
    setBusy(true);
    const r = await confirmDeletion(token);
    setBusy(false);
    // The token is used up either way: take it out of the address bar.
    window.history.replaceState(null, '', window.location.pathname);
    if ('error' in r) return setState({ error: r.error === 'other' ? 'delFailed' : 'delLinkBad' });
    setState({ date: new Date(r.scheduledFor).toLocaleDateString(lang, { day: 'numeric', month: 'long', year: 'numeric' }) });
  }

  return (
    <div className={s.page}>
      <section className={s.card}>
        <Wordmark size={24} />
        <span className={s.icon}>
          <Icon name="trash" size={26} />
        </span>
        {state === null && (
          <>
            <h1>{t('delTitle')}</h1>
            <p>{t('delText')}</p>
            <p className={s.sub}>{t('delSub')}</p>
            <div className={s.btns}>
              <button className={s.ghost} onClick={() => navigate('/')}>
                {t('delCancel')}
              </button>
              <button className={s.danger} aria-busy={busy} onClick={confirm}>
                {t('k161')}
              </button>
            </div>
          </>
        )}
        {state && 'date' in state && (
          <>
            <h1>{t('delBanner').replace('{date}', state.date)}</h1>
            <p>{t('delDoneSub')}</p>
          </>
        )}
        {state && 'error' in state && <p className={s.err}>{t(state.error)}</p>}
      </section>
    </div>
  );
}
