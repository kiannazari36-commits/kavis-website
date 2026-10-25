import { useRef, useState } from 'react';
import { decodeAudio, transcribe } from './transcribe';

// Asking by voice: the microphone records until the student taps again, then Whisper turns it into text on this
// computer (the same model as lecture recordings, downloaded once). Only the text is sent as the question.

export type VoiceState = { kind: 'idle' } | { kind: 'rec' } | { kind: 'busy'; download: number | null };

export function useVoice(lang: string, onText: (text: string) => void, onFail: (why: 'mic' | 'empty' | 'failed') => void) {
  const [state, setState] = useState<VoiceState>({ kind: 'idle' });
  const recorder = useRef<MediaRecorder | null>(null);

  const start = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const type = MediaRecorder.isTypeSupported('audio/mp4') ? 'audio/mp4' : 'audio/webm';
      const r = new MediaRecorder(stream, { mimeType: type });
      const parts: Blob[] = [];
      r.ondataavailable = (e) => e.data.size && parts.push(e.data);
      r.onstop = async () => {
        stream.getTracks().forEach((x) => x.stop());
        setState({ kind: 'busy', download: null });
        try {
          const { samples } = await decodeAudio(new Blob(parts, { type }));
          const segments = await transcribe(samples, lang, (step, pct) => setState({ kind: 'busy', download: step === 'download' ? pct : null }));
          const text = segments.map((x) => x.text).join(' ').trim();
          if (text) onText(text);
          else onFail('empty');
        } catch (e) {
          console.error('voice', e);
          onFail('failed');
        }
        setState({ kind: 'idle' });
      };
      r.start();
      recorder.current = r;
      setState({ kind: 'rec' });
    } catch {
      onFail('mic');
    }
  };

  /** Tap: start listening; tap again: stop and write the question. */
  const toggle = () => {
    if (state.kind === 'rec') recorder.current?.stop();
    else if (state.kind === 'idle') start();
  };
  return { state, toggle };
}

/** The question box tells what the microphone is doing. */
export function voicePlaceholder(v: VoiceState, t: (k: string) => string) {
  if (v.kind === 'rec') return t('voiceRec');
  if (v.kind === 'busy') return v.download !== null ? t('voiceDownload').replace('{n}', String(v.download)) : t('voiceBusy');
  return null;
}

export const VOICE_FAIL = { mic: 'voiceNoMic', empty: 'voiceEmpty', failed: 'voiceFailed' } as const;
