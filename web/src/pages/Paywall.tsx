import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { useToast } from '../components/Toast';
import Wordmark from '../components/Wordmark';
import Icon from '../components/Icon';
import { getPremiumOffer, restorePurchases, startTrial } from '../api/premium';
import { useAsync } from '../hooks/useAsync';
import type { PremiumPlan } from '../api/types';
import s from './Paywall.module.css';

// Design: design/NewIPad.dc.html Premium sheet ("pw"), shown as its own page on the web.
// ?why=share|offline shows why Premium was opened.

export default function Paywall() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const why = params.get('why');
  const offer = useAsync(getPremiumOffer, []);
  const [plan, setPlan] = useState<PremiumPlan['id']>('year');
  const [busy, setBusy] = useState(false);

  const close = () => (window.history.length > 1 ? navigate(-1) : navigate('/home'));

  return (
    <div className={s.page}>
      <section role="dialog" aria-labelledby="pw-title" className={s.sheet}>
        <div className={s.head}>
          <img src="/icon_star.png" alt="" width={46} height={46} />
          <span className={s.headText}>
            <span id="pw-title" className={s.title}>
              <Wordmark size={20} />
              <span className={s.badge}>PREMIUM</span>
            </span>
            <span className={s.sub}>{t('pwSub')}</span>
            {why && (
              <span className={s.why}>
                <Icon name="lock" size={15} />
                {t(why === 'share' ? 'pwWhyShare' : 'pwWhyOffline')}
              </span>
            )}
          </span>
          <button className={s.x} aria-label={t('close')} onClick={close}>
            <Icon name="close" size={16} />
          </button>
        </div>

        {offer && (
          <>
            <div className={s.table} role="table">
              <div className={s.tHead} role="row">
                <span />
                <span>{t('pwFree')}</span>
                <span className={s.prem}>PREMIUM</span>
              </div>
              {offer.rows.map(([name, free, prem]) => (
                <div key={name.en} className={s.tRow} role="row">
                  <span>{name[lang]}</span>
                  <span className={s.free}>{free[lang]}</span>
                  <b>{prem[lang]}</b>
                </div>
              ))}
            </div>
            <span className={s.fair}>{t('pwFair')}</span>

            <div role="radiogroup" className={s.plans}>
              {offer.plans.map((p) => (
                <button key={p.id} role="radio" aria-checked={plan === p.id} className={plan === p.id ? `${s.plan} ${s.planOn}` : s.plan} onClick={() => setPlan(p.id)}>
                  {p.tag && <span className={p.id === 'year' ? `${s.tag} ${s.tagAmb}` : s.tag}>{p.tag[lang]}</span>}
                  <b>{p.title[lang]}</b>
                  <span className={s.prices}>
                    <span dir="ltr" className={s.price}>
                      {p.price}
                    </span>
                    {p.old && (
                      <span dir="ltr" className={s.old}>
                        {p.old}
                      </span>
                    )}
                  </span>
                  <span className={s.planSub}>{p.sub[lang]}</span>
                </button>
              ))}
            </div>
          </>
        )}

        <button
          className={s.start}
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            await startTrial(plan);
            toast(t('pwStarted'));
            navigate('/home');
          }}
        >
          {t('pwStart')}
        </button>
        <div className={s.links}>
          <button onClick={() => restorePurchases().then(() => toast(t('pwRestored')))}>{t('pwRestore')}</button>
          <button onClick={close}>{t('pwContinueFree')}</button>
        </div>
        <span className={s.note}>{t('pwNote')}</span>
      </section>
    </div>
  );
}
