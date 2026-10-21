import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import Wordmark from '../components/Wordmark';
import Icon from '../components/Icon';
import AppStoreButton from '../components/AppStoreButton';
import { getPremiumOffer } from '../api/premium';
import { useAsync } from '../hooks/useAsync';
import s from './Paywall.module.css';

// Design: design/NewIPad.dc.html Premium sheet ("pw"), shown as its own page on the web.
// Rule (CLAUDE.md): the web never sells Premium and shows no prices — it points to the iPhone app.
// ?why=share|offline shows why Premium was opened.

export default function Paywall() {
  const { t, lang } = useI18n();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const why = params.get('why');
  const offer = useAsync(getPremiumOffer, []);

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

            <div className={s.plans}>
              {offer.plans.map((p) => (
                <div key={p.id} className={s.plan}>
                  {p.tag && <span className={p.id === 'year' ? `${s.tag} ${s.tagAmb}` : s.tag}>{p.tag[lang]}</span>}
                  <b>{p.title[lang]}</b>
                  <span className={s.planSub}>{t('pwPriceStore')}</span>
                </div>
              ))}
            </div>
          </>
        )}

        <div className={s.iphone}>
          <b>{t('pwIphone')}</b>
          <span>{t('pwIphoneSub')}</span>
          <AppStoreButton />
        </div>
        <div className={s.links}>
          <button onClick={close}>{t('back')}</button>
        </div>
      </section>
    </div>
  );
}
