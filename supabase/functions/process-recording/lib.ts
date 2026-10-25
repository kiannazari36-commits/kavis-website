// Pure helpers of process-recording (no database, no AI).

export type Segment = { start: number; end: number; text: string };

/** Transcript pieces checked and cleaned: numbers in order, text trimmed and not too long, empty ones dropped. */
export function cleanSegments(input: unknown, maxSegments = 20000): Segment[] | null {
  if (!Array.isArray(input) || !input.length || input.length > maxSegments) return null;
  const out: Segment[] = [];
  for (const s of input) {
    const start = Number((s as Segment)?.start);
    const end = Number((s as Segment)?.end);
    const text = String((s as Segment)?.text ?? '').trim().slice(0, 600);
    if (!Number.isFinite(start) || !Number.isFinite(end) || start < 0 || !text) continue;
    out.push({ start: Math.round(start * 10) / 10, end: Math.round(Math.max(start, end) * 10) / 10, text });
  }
  out.sort((a, b) => a.start - b.start);
  return out.length ? out : null;
}

/** Joins short pieces into lines of about 20 seconds for the AI (fewer tokens): "[125] text …". */
export function transcriptLines(segments: Segment[], seconds = 20): string[] {
  const lines: string[] = [];
  let start = -1;
  let buf: string[] = [];
  for (const s of segments) {
    if (start < 0) start = s.start;
    buf.push(s.text);
    if (s.end - start >= seconds) {
      lines.push(`[${Math.floor(start)}] ${buf.join(' ')}`);
      start = -1;
      buf = [];
    }
  }
  if (buf.length) lines.push(`[${Math.floor(start)}] ${buf.join(' ')}`);
  return lines;
}

/** Claude Sonnet 5.5 list price in US dollars (input $2, output $10 per million tokens). */
export const costUsd = (input: number, output: number) => Math.round(((input * 2 + output * 10) / 1_000_000) * 10000) / 10000;
