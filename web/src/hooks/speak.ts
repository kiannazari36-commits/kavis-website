// Reading text aloud with the browser's own voice (Web Speech API): free, works offline, no server.

const VOICE_LANG: Record<string, string> = { tr: 'tr-TR', en: 'en-US', fa: 'fa-IR', ar: 'ar-SA' };

export const canSpeak = () => typeof window !== 'undefined' && 'speechSynthesis' in window;

/** Reads `text` aloud in `lang` (tr/en/fa/ar); stops anything read before. onEnd runs when it stops. */
export function speak(text: string, lang: string, onEnd?: () => void) {
  if (!canSpeak()) return false;
  const synth = window.speechSynthesis;
  synth.cancel();
  const u = new SpeechSynthesisUtterance(text);
  u.lang = VOICE_LANG[lang] ?? lang;
  const voice = synth.getVoices().find((v) => v.lang.toLowerCase().startsWith(lang.toLowerCase()));
  if (voice) u.voice = voice;
  u.rate = 0.95;
  u.onend = () => onEnd?.();
  u.onerror = () => onEnd?.();
  synth.speak(u);
  return true;
}

export function stopSpeaking() {
  if (canSpeak()) window.speechSynthesis.cancel();
}
