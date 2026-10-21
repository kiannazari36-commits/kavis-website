import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import { TRIAL_LIMITS } from '../api/trial';
import { useTrial } from './TrialProvider';
import s from './TrialCard.module.css';

// Remaining trial limits (CLAUDE.md). Shown in the sidebar instead of the "Go Premium" card.
export default function TrialCard() {
  const { t, lang } = useI18n();
  const navigate = useNavigate();
  const { trial } = useTrial();

  if (trial.premium) return null;

  const meter = (label: string, used: number, max: number) => (
    <span className={s.meter}>
      <span className={s.meterTop}>
        <span>{label}</span>
        <b className="mono">
          {num(used, lang)}/{num(max, lang)}
        </b>
      </span>
      <span className={s.bar}>
        <span className={used >= max ? s.full : ''} style={{ width: `${Math.min(100, (used / max) * 100)}%` }} />
      </span>
    </span>
  );

  return (
    <div className={trial.ended ? `${s.card} ${s.ended}` : s.card}>
      <span className={s.head}>
        <b>{trial.ended ? t('trialEnded') : t('trialTitle')}</b>
        {!trial.ended && <span>{t('trialDaysLeft').replace('{n}', num(trial.daysLeft, lang))}</span>}
      </span>
      {trial.ended ? (
        <span className={s.text}>{t('trialKeep')}</span>
      ) : (
        <>
          {meter('PDF', trial.pdfsUsed, TRIAL_LIMITS.pdfs)}
          {meter(t('trialQuestions'), trial.questionsUsed, TRIAL_LIMITS.questions)}
          <span className={s.text}>{t('trialPages')}</span>
        </>
      )}
      <button onClick={() => navigate('/premium')}>{t('goPremium')}</button>
    </div>
  );
}
