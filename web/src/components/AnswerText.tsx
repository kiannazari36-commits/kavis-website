import s from './AnswerText.module.css';

type Part = { kind: 'text'; text: string } | { kind: 'table'; head: string[]; rows: string[][] };

const cells = (line: string) =>
  line
    .trim()
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .split('|')
    .map((c) => c.trim());

/**
 * The assistant's answer: plain text, and markdown tables ("| a | b |" lines) the assistant writes when the student
 * asks for a table or "cetvel". A table is shown as a real table; the |---| line is dropped.
 */
export function splitAnswer(text: string): Part[] {
  const parts: Part[] = [];
  const lines = text.split('\n');
  let i = 0;
  while (i < lines.length) {
    if (lines[i].trim().startsWith('|')) {
      const block: string[] = [];
      while (i < lines.length && lines[i].trim().startsWith('|')) block.push(lines[i++]);
      const rows = block.filter((l) => !/^\s*\|?\s*:?-{2,}/.test(l)).map(cells);
      if (rows.length >= 2) {
        parts.push({ kind: 'table', head: rows[0], rows: rows.slice(1) });
        continue;
      }
      parts.push({ kind: 'text', text: block.join('\n') });
      continue;
    }
    const block: string[] = [];
    while (i < lines.length && !lines[i].trim().startsWith('|')) block.push(lines[i++]);
    const t = block.join('\n').trim();
    if (t) parts.push({ kind: 'text', text: t });
  }
  return parts;
}

export default function AnswerText({ text }: { text: string }) {
  const parts = splitAnswer(text);
  return (
    <>
      {parts.map((p, i) =>
        p.kind === 'text' ? (
          <span key={i}>{p.text}</span>
        ) : (
          <div key={i} className={s.scroll}>
            <table className={s.table}>
              <thead>
                <tr>
                  {p.head.map((h, j) => (
                    <th key={j}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {p.rows.map((r, j) => (
                  <tr key={j}>
                    {p.head.map((_, k) => (
                      <td key={k}>{r[k] ?? ''}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ),
      )}
    </>
  );
}
