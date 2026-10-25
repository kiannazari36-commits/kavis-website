import type { Segment, WorkerIn, WorkerOut } from './whisper.worker';

export type { Segment };

/** 754 → "12:34" (recording times). */
export const clock = (sec: number) => `${String(Math.floor(sec / 60)).padStart(2, '0')}:${String(Math.floor(sec % 60)).padStart(2, '0')}`;

const LANG: Record<string, string> = { tr: 'turkish', en: 'english', fa: 'persian', ar: 'arabic' };

/** The recording as 16 kHz mono samples, which Whisper reads. */
export async function decodeAudio(file: Blob): Promise<{ samples: Float32Array; seconds: number }> {
  const ctx = new AudioContext();
  try {
    const decoded = await ctx.decodeAudioData(await file.arrayBuffer());
    const off = new OfflineAudioContext(1, Math.ceil(decoded.duration * 16000), 16000);
    const src = off.createBufferSource();
    src.buffer = decoded;
    src.connect(off.destination);
    src.start();
    const out = await off.startRendering();
    // A copy with its own memory, so it can be handed to the worker.
    return { samples: new Float32Array(out.getChannelData(0)), seconds: Math.round(decoded.duration) };
  } finally {
    ctx.close();
  }
}

/**
 * Turns the recording into timestamped text on this computer (a background worker, so the page stays usable).
 * onStep: 'download' while the model is fetched the first time, 'listen' while the recording is read (0–100).
 */
export function transcribe(
  samples: Float32Array,
  lang: string,
  onStep: (step: 'download' | 'listen', pct: number) => void,
  model?: string,
): Promise<Segment[]> {
  const worker = new Worker(new URL('./whisper.worker.ts', import.meta.url), { type: 'module' });
  return new Promise((resolve, reject) => {
    worker.onmessage = (e: MessageEvent<WorkerOut>) => {
      const m = e.data;
      if (m.type === 'download') onStep('download', Math.round(m.progress));
      else if (m.type === 'progress') onStep('listen', m.progress);
      else {
        worker.terminate();
        if (m.type === 'done') resolve(m.segments);
        else reject(new Error(m.message));
      }
    };
    worker.onerror = (e) => (worker.terminate(), reject(new Error(e.message)));
    const msg: WorkerIn = { audio: samples, language: LANG[lang] ?? 'turkish', model };
    worker.postMessage(msg, [samples.buffer]);
  });
}
