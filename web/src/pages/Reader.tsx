import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useNavigate, useOutletContext, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { useTheme } from '../theme/ThemeProvider';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import Wordmark from '../components/Wordmark';
import { getPdf } from '../api/courses';
import { getReaderDoc, translate, type TranslationStyle } from '../api/reader';
import { useAsync } from '../hooks/useAsync';
import { usePanelPref } from '../hooks/usePanelPref';
import { enterFullscreen, exitFullscreen, fullscreenElement, onFullscreenChange } from '../hooks/fullscreen';
import type { ShellContext } from '../components/AppShell';
import { useSettings } from '../settings/SettingsProvider';
import ShareDialog from '../components/ShareDialog';
import type { ReaderBlock, ReaderDoc, Segment } from '../api/types';
import { useTrial } from '../trial/TrialProvider';
import s from './Reader.module.css';

// Design: design/NewIPad.dc.html, screen "reader" (also used by DeskApp for the web app).
// The teacher's text is shown exactly as in the PDF; only the app's labels follow the interface language.

type Paper = 'light' | 'sepia' | 'dark';
const PAPERS: [Paper, string, string][] = [
  ['light', 'paperLight', '#FFFCF6'],
  ['sepia', 'paperSepia', '#F4E6CC'],
  ['dark', 'paperDark', '#1D1915'],
];
const FONT_SIZES = [20, 23, 17];
const START_SECONDS = 1394; // study timer in the design starts at 23:14

type Msg = { from: 'me' | 'ai'; text: string };

export default function Reader() {
  const { t } = useI18n();
  const { theme } = useTheme();
  const toast = useToast();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const courseId = params.get('course') ?? 'pharmacotherapy';
  const pdfId = params.get('pdf') ?? 'hypertension';
  const doc = useAsync(() => getReaderDoc(courseId, pdfId), [courseId, pdfId]);
  const pdfInfo = useAsync(() => getPdf(courseId, pdfId), [courseId, pdfId]);

  const { settings } = useSettings();
  const [paper, setPaper] = useState<Paper | null>(null);
  // Default paper comes from Settings; in dark mode the dark paper is used.
  const paperNow: Paper = paper ?? (theme === 'dark' ? 'dark' : settings.readerPaper);
  const [sec, setSec] = useState(1);
  const [fontI, setFontI] = useState(0);
  // Assistant panel: remembered; without a saved choice open only on wide screens.
  const [panel, setPanel] = usePanelPref('kavis.readerPanel', 1200);
  const [term, setTerm] = useState<string | null>(null);
  const [selected, setSelected] = useState(false);
  const [highlighted, setHighlighted] = useState(false);
  const [trSource, setTrSource] = useState<string | null>(null);
  const [paused, setPaused] = useState(false);
  const [shareOpen, setShareOpen] = useState(false);
  const [seconds, setSeconds] = useState(START_SECONDS);
  const scroller = useRef<HTMLDivElement>(null);
  const { guard } = useTrial();
  const { focus, setFocus } = useOutletContext<ShellContext>();

  // Study timer
  useEffect(() => {
    if (paused) return;
    const id = setInterval(() => setSeconds((n) => n + 1), 1000);
    return () => clearInterval(id);
  }, [paused]);

  // Escape closes popups and leaves focus mode
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      setTerm(null);
      setSelected(false);
      setTrSource(null);
      setFocus(false);
      exitFullscreen();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [setFocus]);

  // Leaving browser fullscreen (Esc, browser button) also leaves focus mode.
  useEffect(
    () =>
      onFullscreenChange(() => {
        if (!fullscreenElement()) setFocus(false);
      }),
    [setFocus],
  );

  // Back to normal when leaving the reader.
  useEffect(
    () => () => {
      setFocus(false);
      exitFullscreen();
    },
    [setFocus],
  );

  if (!doc) return <main className={s.loading} />;

  const isSample = pdfInfo !== undefined && pdfInfo?.pdf.id !== doc.id;
  const title = isSample && pdfInfo ? pdfInfo.pdf.title : doc.title;
  const section = doc.sections[sec];
  const fontSize = fontI === 0 ? settings.readerFontSize : FONT_SIZES[fontI];
  const clock = `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;

  const goSection = (i: number) => {
    setSec(i);
    setTerm(null);
    setSelected(false);
    scroller.current?.scrollTo({ top: 0, behavior: 'smooth' });
  };
  const nextSection = () => {
    if (sec >= doc.sections.length - 1) {
      toast(t('k165'));
      return;
    }
    goSection(sec + 1);
    toast(t('sectionWord') + (sec + 2) + t('sectionOpened'));
  };
  const cycleFont = () => {
    const n = (fontI + 1) % FONT_SIZES.length;
    setFontI(n);
    toast(t('fontSizePrefix') + ['Normal', t('fontBig'), t('fontSmall')][n]);
  };
  const askAssistant = (q: string) => {
    setPanel(true);
    toast(t('askedPrefix') + q);
  };
  const toggleFocus = () => {
    if (focus) {
      setFocus(false);
      exitFullscreen();
    } else {
      setTerm(null);
      setSelected(false);
      setFocus(true);
      enterFullscreen();
    }
  };

  return (
    <div className={s.wrap} data-paper={paperNow} data-focus={focus || undefined}>
      <main className={s.main}>
        <header className={s.header}>
          <button className={s.round} aria-label={t('back')} onClick={() => navigate(`/courses/${courseId}`)}>
            <Icon name="back" size={20} width={1.8} className="flip-rtl" />
          </button>
          <div className={s.titleBox}>
            <h1 lang={doc.language}>{title}</h1>
            <span className="mono">{isSample && pdfInfo ? `${pdfInfo.course.name} · ${t('sampleNote')}` : t('pageInfo')}</span>
          </div>
          <div role="radiogroup" aria-label={t('readingTheme')} className={s.papers}>
            {PAPERS.map(([p, key, swatch]) => (
              <button key={p} role="radio" aria-checked={paperNow === p} className={paperNow === p ? `${s.paperBtn} ${s.paperOn}` : s.paperBtn} onClick={() => setPaper(p)}>
                <span style={{ background: swatch }} />
                {t(key)}
              </button>
            ))}
          </div>
          <button className={s.round} aria-label={t('share')} onClick={() => guard('share', () => setShareOpen(true))}>
            <Icon name="share" size={19} />
          </button>
          <button className={`${s.round} ${s.aa}`} aria-label={t('textSize')} onClick={cycleFont}>
            Aa
          </button>
          <button className={panel ? `${s.round} ${s.roundOn}` : s.round} aria-label={t('panelToggle')} aria-pressed={panel} onClick={() => setPanel(!panel)}>
            <Icon name="panel" size={19} className="flip-rtl" />
          </button>
        </header>

        <div role="tablist" aria-label={t('sections')} className={s.tabs} lang={doc.language}>
          {doc.sections.map((x, i) => (
            <button key={x.tab} dir="auto" role="tab" aria-selected={i === sec} className={i === sec ? `${s.tab} ${s.tabOn}` : s.tab} onClick={() => goSection(i)}>
              {x.tab}
            </button>
          ))}
        </div>

        <div className={s.scroll} ref={scroller}>
          <div className={s.column}>
            {section.blocks.map((b, i) => (
              <Block
                key={`${sec}-${i}`}
                doc={doc}
                block={b}
                fontSize={fontSize}
                term={term}
                onTerm={(id) => {
                  setTerm(term === id ? null : id);
                  setSelected(false);
                }}
                selected={selected}
                highlighted={highlighted}
                onSelect={() => {
                  setSelected(!selected);
                  setTerm(null);
                }}
                selActs={[
                  [t('actTranslate'), () => (setSelected(false), setTrSource(doc.sampleSentence))],
                  [
                    t('actCopy'),
                    () => {
                      setSelected(false);
                      const p = b.paragraphs.find((x) => !Array.isArray(x));
                      if (p && !Array.isArray(p)) navigator.clipboard?.writeText(p.text).catch(() => {});
                      toast(t('copied'));
                    },
                  ],
                  [t('actHighlight'), () => (setSelected(false), setHighlighted(true), toast(t('highlighted')))],
                  [t('actAsk'), () => (setSelected(false), guard('question', () => (setPanel(true), toast(t('askedExplain')))))],
                ]}
                onTranslate={() => setTrSource(sec === 1 ? doc.sampleSentence : flatText(b))}
              />
            ))}

            <section className={s.check}>
              <span className={s.checkIcon}>
                <Icon name="check" size={22} width={2} />
              </span>
              <span className={s.checkText}>
                <b>{t('checkTitle')}</b>
                <span>{t(section.end)}</span>
              </span>
              <button className={s.checkGo} onClick={() => navigate(`/quiz?from=reader&course=${courseId}`)}>
                {t('start')}
              </button>
              <button className={s.checkNext} onClick={nextSection}>
                {sec === doc.sections.length - 1 ? t('lessonSummary') : t('nextSection')}
              </button>
            </section>
          </div>
        </div>

        <div className={s.dock}>
          <button className={s.clock} aria-label={paused ? t('resume') : t('pause')} onClick={() => setPaused(!paused)}>
            <span className="mono">{clock}</span>
            <span className={s.clockIcon}>
              <Icon name={paused ? 'play' : 'pause'} size={14} width={2.2} />
            </span>
          </button>
          <button aria-label={t('pen')} title={t('pen')} onClick={() => toast(t('k165'))}>
            <Icon name="pen" size={20} />
          </button>
          <button aria-label={t('listen')} title={t('listen')} onClick={() => toast(t('pageAloud'))}>
            <Icon name="speaker" size={20} />
          </button>
          <button aria-label={t('cardsLabel')} title={t('cardsLabel')} onClick={() => navigate('/cards')}>
            <Icon name="cards" size={20} />
          </button>
          <button
            aria-label={focus ? t('exitFullScreen') : t('fullScreen')}
            title={focus ? t('exitFullScreen') : t('fullScreen')}
            aria-pressed={focus}
            className={focus ? s.dockOn : undefined}
            onClick={toggleFocus}
          >
            <Icon name={focus ? 'shrink' : 'expand'} size={20} />
          </button>
        </div>

        {term && (
          <TermCard
            id={term}
            doc={doc}
            onClose={() => setTerm(null)}
            onAsk={(name) => {
              setTerm(null);
              guard('question', () => askAssistant(name + t('askedSuffix')));
            }}
            onCard={(name) => toast(name + t('addedToCards'))}
            onListen={(name) => toast(t('readingAloud') + name)}
          />
        )}
      </main>

      {panel && !focus && <AssistantPanel onClose={() => setPanel(false)} />}

      {shareOpen && <ShareDialog pdfId={pdfId} onClose={() => setShareOpen(false)} />}

      {trSource && <TranslateDialog doc={doc} source={trSource} onClose={() => setTrSource(null)} />}
    </div>
  );
}

function flatText(b: ReaderBlock) {
  return b.paragraphs
    .map((p) => (Array.isArray(p) ? p.map((x) => (typeof x === 'string' ? x : x.text)).join('') : p.text))
    .join(' ');
}

type BlockProps = {
  doc: ReaderDoc;
  block: ReaderBlock;
  fontSize: number;
  term: string | null;
  onTerm: (id: string) => void;
  selected: boolean;
  highlighted: boolean;
  onSelect: () => void;
  selActs: [string, () => void][];
  onTranslate: () => void;
};

function Block({ doc, block, fontSize, term, onTerm, selected, highlighted, onSelect, selActs, onTranslate }: BlockProps) {
  const { t } = useI18n();
  const toast = useToast();

  const seg = (x: Segment, i: number) =>
    typeof x === 'string' ? (
      <span key={i}>{x}</span>
    ) : (
      <button key={i} className={term === x.term ? `${s.term} ${s.termOn}` : s.term} aria-expanded={term === x.term} onClick={() => onTerm(x.term)}>
        {x.text}
      </button>
    );

  return (
    <article className={s.page}>
      <div className={s.pageTop}>
        <span className="mono">{t(block.page)}</span>
        <span className={block.tagStyle === 'red' ? `${s.tag} ${s.tagRed}` : s.tag}>{t(block.tag)}</span>
        <span className={s.grow} />
        <button className={s.translate} onClick={onTranslate}>
          {t('translate')}
        </button>
      </div>
      {block.heading && (
        <h2 className={s.heading} lang={doc.language}>
          {block.heading}
        </h2>
      )}
      <div className={`reading ${s.text}`} style={{ fontSize }} lang={doc.language} dir="auto">
        {block.paragraphs.map((p, i) =>
          Array.isArray(p) ? (
            <p key={i}>{p.map(seg)}</p>
          ) : (
            <div key={i} className={s.selWrap}>
              <p
                role="button"
                tabIndex={0}
                title={t('selectSentence')}
                aria-pressed={selected}
                className={`${s.selectable} ${selected ? s.selOn : ''} ${highlighted ? s.highlight : ''}`}
                onClick={onSelect}
                onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && (e.preventDefault(), onSelect())}
              >
                {p.text}
              </p>
              {selected && (
                <div role="toolbar" aria-label={t('selectedSentence')} className={s.selBar}>
                  {selActs.map(([label, fn]) => (
                    <button key={label} onClick={fn}>
                      {label}
                    </button>
                  ))}
                </div>
              )}
            </div>
          ),
        )}
      </div>
      {block.molecule && (
        <button className={s.chipBtn} onClick={() => toast(t('k165'))}>
          <span className={s.chipIcon}>
            <Icon name="molecule" size={16} />
          </span>
          {t('molecule')}
        </button>
      )}
      {block.audio && (
        <>
          <button className={s.audio} onClick={() => toast(t('pageAloud'))}>
            <span>
              <Icon name="play" size={13} width={2.2} />
            </span>
            {t('teacherStopped')}
          </button>
          <button className={s.hint} onClick={() => toast(t('k165'))}>
            <Icon name="question" size={15} />
            {t('questionsFrom')}
          </button>
        </>
      )}
    </article>
  );
}

function TermCard({
  id,
  doc,
  onClose,
  onAsk,
  onCard,
  onListen,
}: {
  id: string;
  doc: ReaderDoc;
  onClose: () => void;
  onAsk: (name: string) => void;
  onCard: (name: string) => void;
  onListen: (name: string) => void;
}) {
  const { t } = useI18n();
  const info = doc.terms[id];
  const name = t(`${id}name`);
  return (
    <div role="dialog" aria-label={t('termExpl')} className={s.termCard}>
      <div className={s.termTop}>
        <span className="mono">
          {t('termPage')} {info?.page}
        </span>
        <span className={s.tag}>{t(`${id}kind`)}</span>
        <span className={s.grow} />
        <button className={s.close} aria-label={t('close')} onClick={onClose}>
          <Icon name="close" size={16} />
        </button>
      </div>
      <b className={s.termName}>{name}</b>
      <span className={s.termDef}>{t(`${id}def`)}</span>
      <span className={s.termEn}>English: {info?.en}</span>
      <div className={s.termActs}>
        <button className={s.termAsk} onClick={() => onAsk(name)}>
          {t('askAssistant')}
        </button>
        <button onClick={() => onCard(name)}>{t('addToCards')}</button>
        <button onClick={() => onListen(name)}>{t('listen')}</button>
      </div>
    </div>
  );
}

function TranslateDialog({ doc, source, onClose }: { doc: ReaderDoc; source: string; onClose: () => void }) {
  const { t, lang } = useI18n();
  const toast = useToast();
  const targets = Object.keys(doc.sampleTranslations);
  const [target, setTarget] = useState(targets.includes(lang) ? lang : targets[0]);
  const { settings } = useSettings();
  const [style, setStyle] = useState<TranslationStyle>(settings.translationStyle);
  const text = useAsync(() => translate(doc, source, target, style), [source, target, style]);
  const dir = doc.sampleTranslations[target]?.dir ?? 'ltr';

  return (
    <div className={s.modal}>
      <div className={s.scrim} onClick={onClose} />
      <section role="dialog" aria-modal="true" aria-label={t('translation')} className={s.dialog}>
        <div className={s.dialogTop}>
          <h2>{t('translation')}</h2>
          <button className={s.close} aria-label={t('close')} onClick={onClose}>
            <Icon name="close" size={16} />
          </button>
        </div>
        <div className={s.source}>
          <span className="mono">{t('sourceLabel')}</span>
          <span className="reading" lang={doc.language} dir="ltr">
            {source}
          </span>
        </div>
        <div role="tablist" aria-label={t('trLanguage')} className={s.seg}>
          {targets.map((k) => (
            <button key={k} role="tab" aria-selected={k === target} className={k === target ? s.segOn : ''} onClick={() => setTarget(k)}>
              {doc.sampleTranslations[k].l}
            </button>
          ))}
        </div>
        <div className={s.styleRow}>
          <span>{t('trStyle')}</span>
          <div role="radiogroup" aria-label={t('trStyle')} className={`${s.seg} ${s.segSmall}`}>
            {(['literal', 'natural'] as const).map((k) => (
              <button
                key={k}
                role="radio"
                aria-checked={k === style}
                className={k === style ? s.segOn : ''}
                onClick={() => {
                  setStyle(k);
                  toast(t(k === 'literal' ? 'toastLiteral' : 'toastNatural'));
                }}
              >
                {t(k)}
              </button>
            ))}
          </div>
        </div>
        <p className={`reading ${s.result}`} dir={text ? dir : undefined} lang={text ? target : undefined}>
          {text === undefined ? '…' : (text ?? t('demoTranslation'))}
        </p>
        <span className={s.trHint}>{t(style === 'literal' ? 'hintLiteral' : 'hintNatural')}</span>
      </section>
    </div>
  );
}

function AssistantPanel({ onClose }: { onClose: () => void }) {
  const { t } = useI18n();
  const toast = useToast();
  const [draft, setDraft] = useState('');
  const [mine, setMine] = useState<Msg[]>([]);
  const [quick, setQuick] = useState(false);
  const { guard } = useTrial();
  const end = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (mine.length) end.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }, [mine.length]);

  const send = (text: string) => {
    const q = text.trim();
    if (!q) {
      toast(t('writeFirst'));
      return;
    }
    guard('question', () => {
      setMine((m) => [...m, { from: 'me', text: q }]);
      setDraft('');
      setQuick(false);
      toast(t('writing'));
    });
  };
  const submit = (e: FormEvent) => {
    e.preventDefault();
    send(draft);
  };

  return (
    <aside className={s.panel} aria-label={t('assistant')}>
      <div className={s.panelTop}>
        <span className="star-btn" style={{ width: 40, height: 40 }} aria-hidden="true" />
        <Wordmark size={16} />
        <span className={s.grow} />
        <button className={s.close} aria-label={t('close')} onClick={onClose}>
          <Icon name="close" size={16} />
        </button>
      </div>
      <span className={s.only}>{t('onlyFrom')}</span>

      <div className={s.chat}>
        <div className={s.me}>{t('explainPage')}</div>
        <div className={s.ai}>
          <b>{t('pageGist')}</b>
          <span>{t('gist1')}</span>
          <span>{t('gist2')}</span>
          <span className={`mono ${s.src}`}>{t('source12')}</span>
        </div>
        <div className={s.me}>{t('teacherEmph')}</div>
        <div className={s.ai}>{t('teacherAnswer')}</div>
        {mine.map((m, i) => (
          <div key={i} className={s.me}>
            {m.text}
          </div>
        ))}
        <div ref={end} />
      </div>

      {quick && (
        <div role="menu" aria-label={t('quick')} className={s.quickMenu}>
          {['explainPage', 'teacherEmph', 'k98', 'k99'].map((k) => (
            <button key={k} role="menuitem" onClick={() => send(t(k))}>
              {t(k)}
            </button>
          ))}
        </div>
      )}
      <form className={s.ask} onSubmit={submit}>
        <button type="button" className={s.askIcon} aria-label={t('quick')} aria-haspopup="menu" aria-expanded={quick} onClick={() => setQuick(!quick)}>
          <Icon name="spark" size={18} />
        </button>
        <input value={draft} onChange={(e) => setDraft(e.target.value)} placeholder={t('askPlaceholder')} aria-label={t('question')} />
        <button type="button" className={s.askIcon} aria-label={t('talk')} onClick={() => toast(t('listening'))}>
          <Icon name="mic" size={18} />
        </button>
        <button type="submit" className={s.askSend} aria-label={t('send')}>
          <Icon name="send" size={16} className="flip-rtl" />
        </button>
      </form>
    </aside>
  );
}
