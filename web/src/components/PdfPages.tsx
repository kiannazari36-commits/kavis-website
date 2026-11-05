import { useEffect, useRef, useState, type ReactNode } from 'react';
import { getDocument, GlobalWorkerOptions, TextLayer, type PDFDocumentProxy } from 'pdfjs-dist';
import workerUrl from 'pdfjs-dist/build/pdf.worker.min.mjs?url';
import { fold, termHits } from '../api/terms';
import s from './PdfPages.module.css';

// The reader's "Orijinal PDF": the teacher's pages exactly as they are (figures, tables, slides), drawn with pdf.js.
// Pages stand one under the other; a page is only drawn when it comes near the screen and let go again when it is
// far away, so a long PDF opens fast and does not fill the memory. Over each page lies pdf.js's invisible text
// layer: the student can select text, the lesson's hard words are underlined and highlights are marked on it.
// Loaded lazily by the reader (pdf.js is big).

GlobalWorkerOptions.workerSrc = workerUrl;

export type PdfSelection = { text: string; page: number };

type Props = {
  data: ArrayBuffer;
  /** Page size (Aa: 1 normal, bigger, smaller); a bigger page than the screen scrolls sideways. */
  zoom: number;
  /** Hard words: term key → the word as it is written in the PDF. */
  terms: { key: string; surface: string }[];
  highlights: string[];
  /** The page to show first. */
  startPage: number;
  /** The pen is on: the text layer lets the drawing through. */
  pen: boolean;
  /** Drawn over each page (the pen's lines). */
  overlay: (page: number) => ReactNode;
  /** Shown under a page (the section check at the end of a section; `last` = the PDF's last page). */
  after: (page: number, last: boolean) => ReactNode;
  onTerm: (key: string) => void;
  onSelect: (sel: PdfSelection | null) => void;
  onFail: () => void;
};

export default function PdfPages({ data, zoom, terms, highlights, startPage, pen, overlay, after, onTerm, onSelect, onFail }: Props) {
  const [pdf, setPdf] = useState<PDFDocumentProxy | null>(null);
  // Each page's size in PDF points (width, height), read once.
  const [sizes, setSizes] = useState<[number, number][]>([]);
  const box = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);

  useEffect(() => {
    let alive = true;
    // pdf.js takes the buffer over; a copy keeps the reader's one usable.
    const task = getDocument({ data: new Uint8Array(data.slice(0)) });
    task.promise.then(
      async (d) => {
        const all: [number, number][] = [];
        for (let n = 1; n <= d.numPages; n++) {
          const v = (await d.getPage(n)).getViewport({ scale: 1 });
          all.push([v.width, v.height]);
        }
        if (!alive) return;
        setSizes(all);
        setPdf(d);
      },
      (e) => {
        if (!alive) return;
        console.error('pdf', e);
        onFail();
      },
    );
    return () => {
      alive = false;
      task.destroy();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data]);

  // The column's width follows the window.
  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setWidth(el.clientWidth));
    ro.observe(el);
    setWidth(el.clientWidth);
    return () => ro.disconnect();
  }, []);

  // Once laid out: open at the start page.
  const started = useRef(false);
  useEffect(() => {
    if (!sizes.length || !width || started.current) return;
    started.current = true;
    if (startPage > 1) box.current?.querySelector(`[data-from="${startPage}"]`)?.scrollIntoView({ block: 'start' });
  }, [sizes, width, startPage]);

  // Selecting text on a page: the reader shows its menu (highlight, translate, copy, ask). On a touch screen
  // (iPad) the selection is made with a long press and its handles, so changes of the selection count too.
  useEffect(() => {
    let wait: ReturnType<typeof setTimeout> | undefined;
    const done = () => {
      clearTimeout(wait);
      wait = setTimeout(() => {
        const sel = window.getSelection();
        const text = sel?.toString().replace(/\s+/g, ' ').trim() ?? '';
        const node = sel?.anchorNode;
        const page = node && box.current?.contains(node) ? (node instanceof Element ? node : node.parentElement)?.closest<HTMLElement>('[data-from]') : null;
        onSelect(text.length > 1 && page ? { text, page: Number(page.dataset.from) } : null);
      }, 250);
    };
    const el = box.current;
    el?.addEventListener('pointerup', done);
    el?.addEventListener('keyup', done);
    document.addEventListener('selectionchange', done);
    return () => {
      clearTimeout(wait);
      el?.removeEventListener('pointerup', done);
      el?.removeEventListener('keyup', done);
      document.removeEventListener('selectionchange', done);
    };
  }, [onSelect]);

  const pageWidth = Math.round(Math.min(width, 860) * zoom);
  return (
    <div ref={box} className={pen ? `${s.pages} ${s.penOn}` : s.pages}>
      {pdf &&
        pageWidth > 0 &&
        sizes.map(([w, h], i) => (
          <div key={i + 1} className={s.slot}>
            <Page pdf={pdf} n={i + 1} width={pageWidth} height={Math.round((pageWidth * h) / w)} terms={terms} highlights={highlights} onTerm={onTerm}>
              {overlay(i + 1)}
            </Page>
            <span className={`mono ${s.no}`}>S. {i + 1}</span>
            {after(i + 1, i === sizes.length - 1)}
          </div>
        ))}
    </div>
  );
}

type PageProps = {
  pdf: PDFDocumentProxy;
  n: number;
  width: number;
  height: number;
  terms: Props['terms'];
  highlights: string[];
  onTerm: (key: string) => void;
  children: ReactNode;
};

function Page({ pdf, n, width, height, terms, highlights, onTerm, children }: PageProps) {
  const el = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const text = useRef<HTMLDivElement>(null);
  const [near, setNear] = useState(false);
  const [drawn, setDrawn] = useState(0);

  // Near the screen (about two pages ahead): draw; far away: let go.
  useEffect(() => {
    const io = new IntersectionObserver(([e]) => setNear(e.isIntersecting), { rootMargin: '1200px 0px' });
    if (el.current) io.observe(el.current);
    return () => io.disconnect();
  }, []);

  useEffect(() => {
    const c = canvas.current;
    const layer = text.current;
    if (!c || !layer) return;
    if (!near) {
      c.width = c.height = 0;
      layer.replaceChildren();
      return;
    }
    let alive = true;
    let cancel = () => {};
    (async () => {
      const page = await pdf.getPage(n);
      if (!alive) return;
      const scale = width / page.getViewport({ scale: 1 }).width;
      const viewport = page.getViewport({ scale });
      // Sharp on retina screens, but at most twice the size (memory).
      const ratio = Math.min(window.devicePixelRatio || 1, 2);
      c.width = Math.floor(viewport.width * ratio);
      c.height = Math.floor(viewport.height * ratio);
      const task = page.render({ canvas: c, viewport, transform: ratio === 1 ? undefined : [ratio, 0, 0, ratio, 0, 0] });
      cancel = () => task.cancel();
      await task.promise.catch(() => {});
      if (!alive) return;
      layer.replaceChildren();
      layer.style.setProperty('--total-scale-factor', String(scale));
      const tl = new TextLayer({ textContentSource: await page.getTextContent(), container: layer, viewport });
      await tl.render();
      if (alive) setDrawn((d) => d + 1);
    })();
    return () => {
      alive = false;
      cancel();
    };
  }, [near, pdf, n, width]);

  // Hard words and highlights on the text layer (again when they change).
  useEffect(() => {
    if (text.current && drawn) decorate(text.current, terms, highlights);
  }, [drawn, terms, highlights]);

  return (
    <div
      ref={el}
      className={s.page}
      style={{ width, height }}
      data-from={n}
      data-to={n}
      onClick={(e) => {
        const word = (e.target as HTMLElement).closest<HTMLElement>('mark[data-term]');
        if (word && !window.getSelection()?.toString()) onTerm(word.dataset.term!);
      }}
    >
      <canvas ref={canvas} className={s.canvas} />
      <div ref={text} className={`textLayer ${s.text}`} />
      {children}
    </div>
  );
}

const norm = (x: string) => fold(x).replace(/\s+/g, ' ').trim();

/**
 * Marks hard words (underlined, tap = explanation) and highlighted sentences on a page's text layer. pdf.js puts
 * the text as runs (spans); a sentence can go over several runs, so the page's text is joined with spaces and the
 * found places are mapped back to each run.
 */
function decorate(layer: HTMLElement, terms: Props['terms'], highlights: string[]) {
  const runs = [...layer.querySelectorAll<HTMLElement>('span:not(.markedContent)')].filter((r) => !r.querySelector('span'));
  // Each run's own text (first time: remember it, later the marks are rebuilt from it).
  const texts = runs.map((r) => (r.dataset.raw ??= r.textContent ?? ''));
  // The page's text, lower case, spaces collapsed; where each character came from.
  let page = '';
  const from: [number, number][] = [];
  texts.forEach((t, ri) => {
    for (let ci = 0; ci < t.length; ci++) {
      const ch = /\s/.test(t[ci]) ? ' ' : fold(t[ci]);
      if (ch === ' ' && (page.endsWith(' ') || !page)) continue;
      page += ch;
      from.push([ri, ci]);
    }
    if (!page.endsWith(' ')) {
      page += ' ';
      from.push([ri, t.length]);
    }
  });
  const marks: { run: number; a: number; b: number; cls: 'hl' | 'term'; key?: string }[] = [];
  const add = (start: number, end: number, cls: 'hl' | 'term', key?: string) => {
    for (let i = start; i < end; i++) {
      const [ri, ci] = from[i];
      const last = marks[marks.length - 1];
      if (last && last.run === ri && last.cls === cls && last.b === ci && last.key === key) last.b = ci + 1;
      else marks.push({ run: ri, a: ci, b: ci + 1, cls, key });
    }
  };
  for (const h of highlights) {
    const q = norm(h);
    if (q.length < 2) continue;
    for (let i = page.indexOf(q); i >= 0; i = page.indexOf(q, i + q.length)) add(i, i + q.length, 'hl');
  }
  // Whole words with their Turkish endings ("kaptoprilin"), not inside other words ("ace" not in "surface").
  for (const t of terms) for (const [a, b] of termHits(page, t.surface)) add(a, b, 'term', t.key);
  runs.forEach((r, ri) => {
    const raw = texts[ri];
    const mine = marks.filter((m) => m.run === ri && m.a < raw.length).sort((x, y) => x.a - y.a);
    if (!mine.length) {
      if (r.childElementCount) r.textContent = raw;
      return;
    }
    // Cut the run at every mark's edge; each piece gets the marks that cover it.
    const cuts = [...new Set([0, raw.length, ...mine.flatMap((m) => [m.a, Math.min(m.b, raw.length)])])].sort((x, y) => x - y);
    const nodes: Node[] = [];
    for (let k = 0; k < cuts.length - 1; k++) {
      const piece = raw.slice(cuts[k], cuts[k + 1]);
      const on = mine.filter((m) => m.a <= cuts[k] && m.b >= cuts[k + 1]);
      if (!on.length) {
        nodes.push(document.createTextNode(piece));
        continue;
      }
      const m = document.createElement('mark');
      m.textContent = piece;
      for (const x of on) {
        m.classList.add(x.cls === 'hl' ? s.hl : s.term);
        if (x.key) m.dataset.term = x.key;
      }
      nodes.push(m);
    }
    r.replaceChildren(...nodes);
  });
}
