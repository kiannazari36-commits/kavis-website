import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import Icon from '../components/Icon';
import { getTrial, TRIAL_LIMITS, TRIAL_START, type TrialStatus } from '../api/trial';
import { onSignedIn } from '../api/auth';
import s from './TrialProvider.module.css';

/**
 * What a button wants to do (CLAUDE.md trial rules):
 * pdf = upload a new PDF, question = new assistant question, generate = new quiz / cards, share = share (Premium only).
 * Reading old PDFs, notes, highlights, existing cards/summaries and offline use are always allowed.
 */
export type Action = 'pdf' | 'question' | 'generate' | 'share';

type Ctx = {
  trial: TrialStatus;
  /** Asks the server again (after redeeming an invite code). */
  refresh: () => Promise<void>;
  /** Runs `fn` if allowed, otherwise shows why it is locked. */
  guard: (action: Action, fn: () => void) => void;
};

const TrialContext = createContext<Ctx | null>(null);

export function TrialProvider({ children }: { children: ReactNode }) {
  const { t } = useI18n();
  const navigate = useNavigate();
  const [trial, setTrial] = useState<TrialStatus>(TRIAL_START);

  // From the server at start and after every sign-in.
  const refresh = useCallback(() => getTrial().then((s) => void (s && setTrial(s))), []);
  useEffect(() => {
    void refresh();
    return onSignedIn(() => void refresh());
  }, [refresh]);
  const [locked, setLocked] = useState<string | null>(null);

  const guard = useCallback(
    (action: Action, fn: () => void) => {
      if (trial.premium) return fn();
      if (action === 'share') return navigate('/premium?why=share');
      if (trial.ended) return setLocked(t('trialLocked'));
      if (action === 'pdf' && trial.pdfsUsed >= TRIAL_LIMITS.pdfs) return setLocked(t('trialPdfFull'));
      if (action === 'question' && trial.questionsUsed >= TRIAL_LIMITS.questions) return setLocked(t('trialQFull'));
      fn();
    },
    [trial, navigate, t],
  );

  return (
    <TrialContext.Provider value={{ trial, guard, refresh }}>
      {children}
      {locked && (
        <div className={s.modal}>
          <div className={s.scrim} onClick={() => setLocked(null)} />
          <section role="alertdialog" aria-modal="true" aria-labelledby="locked-title" className={s.dialog}>
            <span className={s.icon}>
              <Icon name="lock" size={24} />
            </span>
            <b id="locked-title">{t('premiumOnly')}</b>
            <p>{locked}</p>
            {trial.ended && <span className={s.keep}>{t('trialKeep')}</span>}
            <div className={s.btns}>
              <button className={s.ghost} onClick={() => setLocked(null)}>
                {t('delCancel')}
              </button>
              <button
                className={s.pri}
                onClick={() => {
                  setLocked(null);
                  navigate('/premium');
                }}
              >
                {t('goPremium')}
              </button>
            </div>
          </section>
        </div>
      )}
    </TrialContext.Provider>
  );
}

export function useTrial() {
  const ctx = useContext(TrialContext);
  if (!ctx) throw new Error('useTrial must be used inside TrialProvider');
  return ctx;
}
