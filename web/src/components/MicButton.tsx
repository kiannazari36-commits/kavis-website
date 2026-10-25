import { useI18n } from '../i18n/I18nProvider';
import Icon from './Icon';
import type { VoiceState } from '../speech/useVoice';
import s from './MicButton.module.css';

// The microphone button of the assistant (chat and reader panel): tap to speak, tap again to stop.

export default function MicButton({ state, onClick, className, size = 19 }: { state: VoiceState; onClick: () => void; className: string; size?: number }) {
  const { t } = useI18n();
  return (
    <button
      type="button"
      className={state.kind === 'rec' ? `${className} ${s.on}` : className}
      aria-label={t(state.kind === 'rec' ? 'voiceStop' : 'talk')}
      aria-pressed={state.kind === 'rec'}
      aria-busy={state.kind === 'busy'}
      disabled={state.kind === 'busy'}
      onClick={onClick}
    >
      <Icon name="mic" size={size} />
    </button>
  );
}
