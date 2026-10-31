import type { ReaderDoc } from './types';

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

/**
 * "PDF olarak kaydet": the reading page of the exam summary as a clean printable page in a hidden frame, then the
 * browser's print dialog opens (Save as PDF). Works for every script, because the browser draws the text.
 */
export function printDoc(title: string, doc: ReaderDoc) {
  const rtl = doc.language === 'fa' || doc.language === 'ar';
  const body = doc.sections
    .map((sec) => {
      const blocks = sec.blocks
        .map((b) => {
          const table = b.table
            ? `<table><thead><tr>${b.table.head.map((h) => `<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>${b.table.rows
                .map((r) => `<tr>${r.map((c) => `<td>${esc(c)}</td>`).join('')}</tr>`)
                .join('')}</tbody></table>`
            : '';
          const paras = b.table
            ? ''
            : b.paragraphs.map((p) => `<p>${esc(Array.isArray(p) ? p.map((x) => (typeof x === 'string' ? x : x.text)).join('') : p.text)}</p>`).join('');
          return `<section>${b.heading && b.heading !== sec.title ? `<h3>${esc(b.heading)}</h3>` : ''}${table}${paras}</section>`;
        })
        .join('');
      return `<div class="topic"><h2>${esc(sec.title)}</h2>${blocks}</div>`;
    })
    .join('');
  const html = `<!doctype html><html lang="${doc.language}" dir="${rtl ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><title>${esc(title)}</title>
<style>
body{font-family:Georgia,'Times New Roman',serif;color:#2A2420;line-height:1.6;margin:0;padding:0 4px}
h1{font-size:24px;margin:0 0 18px;color:#9C2F3A}
h2{font-size:19px;margin:0 0 8px;border-bottom:1px solid #E0D4BE;padding-bottom:4px}
h3{font-size:15px;margin:14px 0 4px}
p{font-size:13.5px;margin:0 0 8px}
table{width:100%;border-collapse:collapse;font-size:12.5px;margin-top:6px}
th,td{text-align:start;padding:6px 8px;border-bottom:1px solid #E0D4BE;vertical-align:top}
th{color:#6E645A}
.topic{margin-bottom:22px;break-inside:auto}
.topic:not(:first-of-type){break-before:page}
@page{margin:16mm}
</style></head><body><h1>${esc(title)}</h1>${body}</body></html>`;

  const frame = document.createElement('iframe');
  frame.style.cssText = 'position:fixed;width:0;height:0;border:0;visibility:hidden';
  document.body.appendChild(frame);
  const w = frame.contentWindow;
  if (!w) return frame.remove();
  w.document.open();
  w.document.write(html);
  w.document.close();
  const run = () => {
    w.focus();
    w.print();
    setTimeout(() => frame.remove(), 60_000);
  };
  // Fonts and layout need a moment before the print preview is made.
  setTimeout(run, 300);
}
