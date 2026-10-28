import { useState } from 'react';
import { useI18n } from '../i18n/I18nProvider';
import { useTrial } from '../trial/TrialProvider';
import { redeemCode, type RedeemError } from '../api/promo';
import s from './RedeemCode.module.css';

/** "Davet kodum var": an invite code gives free Premium for a few weeks. Never shows a price or a buy button. */
export default function RedeemCode() {
  const { t, lang } = useI18n();
  const { trial, refresh } = useTrial();
  const [open, setOpen] = useState(false);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<RedeemError | null>(null);
  const date = (iso: string) => new Date(iso).toLocaleDateString(lang, { day: 'numeric', month: 'long', year: 'numeric' });

  const promoUntil = trial.premium && trial.premiumSource === 'promo' && trial.premiumUntil ? trial.premiumUntil : null;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!code.trim() || busy) return;
    setBusy(true);
    setError(null);
    const r = await redeemCode(code);
    setBusy(false);
    if (r.ok) {
      setCode('');
      await refresh();
    } else setError(r.error);
  }

  return (
    <div className={s.box}>
      {promoUntil && (
        <span className={s.ok} role="status">
          {t('codeOk').replace('{date}', date(promoUntil))}
        </span>
      )}
      {!promoUntil && !open && (
        <button className={s.link} onClick={() => setOpen(true)}>
          {t('codeHave')}
        </button>
      )}
      {!promoUntil && open && (
        <form className={s.form} onSubmit={submit}>
          <span className={s.hint}>{t('codeHint')}</span>
          <span className={s.line}>
            <input
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              placeholder={t('codePlace')}
              aria-label={t('codeHave')}
              dir="ltr"
              autoCapitalize="characters"
              autoComplete="off"
              spellCheck={false}
              maxLength={24}
            />
            <button className={s.pri} type="submit" disabled={busy || !code.trim()}>
              {t('codeApply')}
            </button>
          </span>
          {error && (
            <span className={s.err} role="alert">
              {t(`codeErr_${error}`)}
            </span>
          )}
        </form>
      )}
    </div>
  );
}
