// Speech-to-text in the browser (CLAUDE.md: recordings are turned into text on the device; only the text goes to
// the server). With a graphics card (WebGPU): Whisper "small" (better with drug names; ~1 hour of lecture in ~6
// minutes on a Mac, a few hundred MB downloaded once). Without: Whisper "base", 8-bit (~80 MB) on the processor.
// Read in 30-second pieces so the page can show how far it is; the browser keeps the model after the first time.
import { pipeline, type AutomaticSpeechRecognitionPipeline } from '@huggingface/transformers';

const MODEL_GPU = 'onnx-community/whisper-small';
const MODEL_CPU = 'onnx-community/whisper-base';
const RATE = 16000;
const WINDOW_S = 30;

export type Segment = { start: number; end: number; text: string };
export type WorkerIn = { audio: Float32Array; language: string; model?: string };
export type WorkerOut =
  | { type: 'download'; progress: number }
  | { type: 'progress'; progress: number }
  | { type: 'done'; segments: Segment[] }
  | { type: 'error'; message: string };

let asr: Promise<AutomaticSpeechRecognitionPipeline> | null = null;
const post = (m: WorkerOut) => self.postMessage(m);

self.onmessage = async (e: MessageEvent<WorkerIn>) => {
  const { audio, language, model } = e.data;
  try {
    // The graphics card (WebGPU) is much faster where the browser has it; otherwise the processor (WASM).
    const gpu = 'gpu' in navigator && !!(await (navigator as unknown as { gpu: { requestAdapter(): Promise<unknown> } }).gpu.requestAdapter().catch(() => null));
    asr ??= pipeline('automatic-speech-recognition', model ?? (gpu ? MODEL_GPU : MODEL_CPU), {
      device: gpu ? 'webgpu' : 'wasm',
      dtype: gpu ? { encoder_model: 'fp32', decoder_model_merged: 'q4' } : 'q8',
      progress_callback: (p) => {
        if (p.status === 'progress_total') post({ type: 'download', progress: p.progress });
      },
    }) as Promise<AutomaticSpeechRecognitionPipeline>;
    const run = await asr;
    const pieces = Math.max(1, Math.ceil(audio.length / (RATE * WINDOW_S)));
    const segments: Segment[] = [];
    for (let i = 0; i < pieces; i++) {
      const piece = audio.subarray(i * RATE * WINDOW_S, (i + 1) * RATE * WINDOW_S);
      const out = await run(piece, { language, task: 'transcribe', return_timestamps: true });
      const result = Array.isArray(out) ? out[0] : out;
      for (const c of result.chunks ?? []) {
        const text = c.text.trim();
        if (!text) continue;
        const [from, to] = c.timestamp;
        segments.push({ start: i * WINDOW_S + (from ?? 0), end: i * WINDOW_S + (to ?? WINDOW_S), text });
      }
      post({ type: 'progress', progress: Math.round(((i + 1) / pieces) * 100) });
    }
    post({ type: 'done', segments });
  } catch (err) {
    post({ type: 'error', message: String((err as Error).message ?? err) });
  }
};
