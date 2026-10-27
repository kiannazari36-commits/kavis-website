import { lazy, Suspense, useEffect, useRef, useState, type FormEvent } from 'react';
import { Link, useNavigate, useOutletContext, useSearchParams } from 'react-router-dom';
import { LANG_NAMES, LANGS, useI18n, type Lang } from '../i18n/I18nProvider';
import { useTheme } from '../theme/ThemeProvider';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import Wordmark from '../components/Wordmark';
import { getPdf, recentPdfs } from '../api/courses';
import { addHighlight, getLesson, markRead, saveStudyTime, tapTerm, translate, type TranslationStyle } from '../api/reader';
import { askAssistant, latestThread, type ChatMessage, type SourceMode } from '../api/assistant';
import { findMolecules, type Molecule } from '../components/molecules';
import WebLinks from '../components/WebLinks';
import ActNotes from '../components/ActNotes';
import AnswerText from '../components/AnswerText';
import Thinking from '../components/Thinking';
import { useVoice, VOICE_FAIL, voicePlaceholder } from '../speech/useVoice';
import MicButton from '../components/MicButton';
import { sectionCheckCounter } from '../api/quiz';
import { addTermCard } from '../api/cards';
import { lectureMarks, recordingsOf, type LectureMark } from '../api/recording';
import { loadInk, saveInk, type PageInk, type Stroke } from '../api/ink';
import { clock } from '../speech/transcribe';
import { canSpeak, speak, speakAll, stopSpeaking } from '../hooks/speak';
import { num, percent } from '../i18n/format';
import { useAsync } from '../hooks/useAsync';
import { usePanelPref } from '../hooks/usePanelPref';
import { enterFullscreen, exitFullscreen, fullscreenElement, onFullscreenChange } from '../hooks/fullscreen';
import type { ShellContext } from '../components/AppShell';
import { dirOf, useSettings } from '../settings/SettingsProvider';
import ShareDialog from '../components/ShareDialog';
import type { ReaderBlock, ReaderDoc, ReaderTag, ReaderTerm, Segment } from '../api/types';
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
// Label (key in reader.json) and color of each block kind.
const TAGS: Record<ReaderTag, [string, 'vio' | 'red']> = {
  definition: ['s1tag', 'vio'],
  dose: ['tagDose', 'vio'],
  side_effect: ['tagSide', 'red'],
  special: ['s3tag', 'vio'],
  emergency: ['s4tag', 'red'],
  general: ['tagGeneral', 'vio'],
};
/** Pen colors: bordo, amber, green, blue. */
const PEN_COLORS = ['#9C2F3A', '#E0A12A', '#2F7D5B', '#2F5D9C'];

/** The study timer stops by itself after this long without any activity. */
const IDLE_MS = 5 * 60 * 1000;

export default function Reader() {
  const { t, lang } = useI18n();
  const { theme } = useTheme();
  const toast = useToast();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const courseId = params.get('course') ?? '';
  const pdfId = params.get('pdf') ?? '';
  const lesson = useAsync(() => (pdfId ? getLesson(pdfId) : Promise.resolve(null)), [pdfId]);
  const pdfInfo = useAsync(() => getPdf(courseId, pdfId), [courseId, pdfId]);
  // The lecture recording of this lesson, if there is one (button "Ses kaydı" in the header).
  const recordings = useAsync(() => (pdfId ? recordingsOf(pdfId) : Promise.resolve([])), [pdfId]);
  const recording = recordings?.find((r) => r.status === 'ready') ?? recordings?.[0];
  // What the lecturer said about each page in the recording ("Hoca burada sınavda çıkar dedi").
  const marks = useAsync(() => (pdfId ? lectureMarks(pdfId) : Promise.resolve([])), [pdfId]) ?? [];
  const checkCount = useAsync(() => (pdfId ? sectionCheckCounter(pdfId) : Promise.resolve({ count: () => 0 })), [pdfId]);
  const doc = lesson?.doc;
  const [pagesRead, setPagesRead] = useState<number[] | null>(null);
  const [pct, setPct] = useState<number | null>(null);
  const [highlights, setHighlights] = useState<string[]>([]);

  // "/reader" without a lesson: open the lesson read most recently.
  useEffect(() => {
    if (pdfId) return;
    recentPdfs(1).then(([r]) => r && navigate(`/reader?course=${r.course.id}&pdf=${r.pdf.id}`, { replace: true }));
  }, [pdfId, navigate]);

  useEffect(() => {
    if (lesson) setHighlights(lesson.highlights);
  }, [lesson]);

  const { settings } = useSettings();
  const [paper, setPaper] = useState<Paper | null>(null);
  // Default paper comes from Settings; in dark mode the dark paper is used.
  const paperNow: Paper = paper ?? (theme === 'dark' ? 'dark' : settings.readerPaper);
  // ?sec= opens a section (coming back from the section check); otherwise the first one.
  const [sec, setSec] = useState(() => Math.max(0, Number(params.get('sec')) || 0));
  const [fontI, setFontI] = useState(0);
  // Assistant panel: remembered; without a saved choice open only on wide screens.
  const [panel, setPanel] = usePanelPref('kavis.readerPanel', 1200);
  const [term, setTerm] = useState<string | null>(null);
  const [selected, setSelected] = useState(false);
  // The section list (one button that opens the others) and the page search box.
  const [secMenu, setSecMenu] = useState(false);
  const [pageQuery, setPageQuery] = useState('');
  const [trSource, setTrSource] = useState<{ text: string; page: number } | null>(null);
  const [paused, setPaused] = useState(() => loadClock(pdfId).paused);
  const [shareOpen, setShareOpen] = useState(false);
  const [asked, setAsked] = useState<{ text: string; n: number } | null>(null);
  // The pen: drawing over the pages, saved per page (annotations, kind 'ink').
  const [pen, setPen] = useState(false);
  const [penColor, setPenColor] = useState(PEN_COLORS[0]);
  const savedInk = useAsync(() => (pdfId ? loadInk(pdfId) : Promise.resolve({} as Record<number, PageInk>)), [pdfId]);
  const [inkEdits, setInkEdits] = useState<Record<number, PageInk>>({});
  const [lastInkPage, setLastInkPage] = useState<number | null>(null);
  const inkOf = (page: number): PageInk => inkEdits[page] ?? savedInk?.[page] ?? { id: null, strokes: [] };
  const setInk = async (page: number, strokes: Stroke[]) => {
    const now = { id: inkOf(page).id, strokes };
    setInkEdits((x) => ({ ...x, [page]: now }));
    setLastInkPage(page);
    const id = await saveInk(pdfId, page, now);
    setInkEdits((x) => ({ ...x, [page]: { ...x[page], id } }));
  };
  // The speaker in the dock reads the open section aloud (the browser's voice, free).
  const [reading, setReading] = useState(false);
  // Another section or leaving the page stops the reading.
  useEffect(
    () => () => {
      stopSpeaking();
      setReading(false);
    },
    [sec, pdfId],
  );
  const [seconds, setSeconds] = useState(() => loadClock(pdfId).seconds);
  const secondsRef = useRef(seconds);
  secondsRef.current = seconds;
  const pausedRef = useRef(paused);
  pausedRef.current = paused;
  const scroller = useRef<HTMLDivElement>(null);
  const { guard } = useTrial();
  const { focus, setFocus } = useOutletContext<ShellContext>();

  // Study timer. It counts real time (not timer ticks, which browsers slow down), and only while the student is
  // studying: it stops by itself when the tab is hidden, and after 5 minutes without any touch, key or scroll
  // (reading aloud counts as studying); any activity starts it again.
  const [hidden, setHidden] = useState(() => document.visibilityState === 'hidden');
  const [idle, setIdle] = useState(false);
  const lastActive = useRef(Date.now());
  const counted = useRef(seconds * 1000);
  const lastTick = useRef(Date.now());
  const running = !paused && !hidden && !idle;
  useEffect(() => {
    const onVisible = () => setHidden(document.visibilityState === 'hidden');
    const onActive = () => {
      lastActive.current = Date.now();
      setIdle(false);
    };
    const events = ['pointermove', 'pointerdown', 'keydown', 'wheel', 'touchstart', 'scroll'] as const;
    document.addEventListener('visibilitychange', onVisible);
    events.forEach((e) => window.addEventListener(e, onActive, { capture: true, passive: true }));
    return () => {
      document.removeEventListener('visibilitychange', onVisible);
      events.forEach((e) => window.removeEventListener(e, onActive, { capture: true }));
    };
  }, []);
  useEffect(() => {
    lastTick.current = Date.now();
    const id = setInterval(() => {
      const now = Date.now();
      // At most 5 s at once: a computer waking from sleep must not add the time it slept.
      const step = Math.min(now - lastTick.current, 5000);
      lastTick.current = now;
      if (!window.speechSynthesis?.speaking && now - lastActive.current > IDLE_MS) {
        setIdle(true);
        return;
      }
      if (!running) return;
      counted.current += step;
      setSeconds(Math.floor(counted.current / 1000));
    }, 500);
    return () => clearInterval(id);
  }, [running]);
  // Coming back after being away: tell once why the clock stood still.
  const wasIdle = useRef(false);
  useEffect(() => {
    if (idle && !wasIdle.current) toast(t('clockIdle'));
    wasIdle.current = idle;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [idle]);

  // The clock shows today's time on this lesson: leaving and coming back goes on from where it was (also paused).
  // Leaving saves the new study time; less than a minute waits until the next visit.
  useEffect(() => {
    const saved = loadClock(pdfId);
    setSeconds(saved.seconds);
    counted.current = saved.seconds * 1000;
    setPaused(saved.paused);
    let start = saved.seconds;
    let pending = saved.pending;
    const leave = () => {
      if (!pdfId) return;
      const fresh = secondsRef.current - start + pending;
      const sent = Boolean(courseId) && fresh >= 60;
      if (sent) saveStudyTime(courseId, pdfId, fresh);
      start = secondsRef.current;
      pending = sent ? 0 : fresh;
      saveClock(pdfId, { seconds: secondsRef.current, paused: pausedRef.current, pending });
    };
    // Closing the tab or the browser counts as leaving too.
    window.addEventListener('pagehide', leave);
    return () => {
      window.removeEventListener('pagehide', leave);
      leave();
    };
  }, [courseId, pdfId]);

  // Where the student is: the page at the top of the screen. Pages that came on screen count as read; both are
  // saved a moment after scrolling stops, so the lesson opens at the same page next time.
  const [atPage, setAtPage] = useState<number | null>(null);
  const seen = useRef<Set<number>>(new Set());
  const trackPage = () => {
    const box = scroller.current;
    if (!box) return;
    const top = box.getBoundingClientRect().top + 80;
    const bottom = box.getBoundingClientRect().bottom;
    let here: number | null = null;
    for (const el of box.querySelectorAll<HTMLElement>('[data-from]')) {
      const r = el.getBoundingClientRect();
      if (r.top < bottom && r.bottom > top) {
        here ??= Number(el.dataset.from);
        for (let p = Number(el.dataset.from); p <= Number(el.dataset.to); p++) seen.current.add(p);
      }
    }
    if (here !== null) setAtPage(here);
  };
  useEffect(() => {
    if (!lesson?.doc || atPage === null) return;
    // Page count from the lesson list; a lesson outside any course counts its own pages.
    const pageCount = pdfInfo?.pdf.pages ?? new Set(lesson.doc.sections.flatMap((x) => x.blocks.map((b) => b.pageFrom))).size;
    const timer = setTimeout(() => {
      markRead(pdfId, pagesRead ?? lesson.pagesRead, [...seen.current], pageCount, atPage).then((r) => {
        if (r) {
          setPagesRead(r.pagesRead);
          setPct(r.percent);
        }
      });
    }, 1500);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [atPage, sec]);
  // A newly opened section: what is on screen counts before any scrolling.
  useEffect(() => {
    const timer = setTimeout(trackPage, 400);
    return () => clearTimeout(timer);
  }, [lesson, sec]);

  // Coming back to a lesson (no ?sec=): open the section and page where the student stopped.
  const restored = useRef(false);
  useEffect(() => {
    if (!lesson?.doc || restored.current) return;
    restored.current = true;
    // Back from the check of the last section ("Sonraki bölüme geç" with ?sec past the end): the lesson summary.
    if (Number(params.get('sec')) >= lesson.doc.sections.length) {
      navigate(`/summary?course=${courseId}&pdf=${pdfId}`, { replace: true });
      return;
    }
    // ?page=N (from the lesson summary) opens that page; otherwise the page where the student stopped.
    const asked = Number(params.get('page')) || 0;
    const last = asked || lesson.lastPage;
    if (params.get('sec') || last <= 1) return;
    const i = lesson.doc.sections.findIndex((x) => x.blocks.some((b) => last >= b.pageFrom && last <= b.pageTo));
    if (i < 0) return;
    setSec(i);
    setTimeout(() => {
      const el = [...(scroller.current?.querySelectorAll<HTMLElement>('[data-from]') ?? [])].find((x) => last >= Number(x.dataset.from) && last <= Number(x.dataset.to));
      el?.scrollIntoView({ block: 'start' });
    }, 150);
    if (!asked) toast(t('resumeAt').replace('{p}', num(last, lang)));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lesson]);

  // Escape closes popups and leaves focus mode
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      setSecMenu(false);
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

  if (!lesson || pdfInfo === undefined) return <main className={s.loading} />;
  if (!doc || !doc.sections.length) {
    return (
      <main className={s.loading}>
        <div className={s.empty}>
          <b>{pdfInfo?.pdf.title}</b>
          <span>{t('noReaderDoc')}</span>
          <button className={s.checkNext} onClick={() => navigate(courseId ? `/courses/${courseId}` : '/courses')}>
            {t('back')}
          </button>
        </div>
      </main>
    );
  }

  const title = pdfInfo?.pdf.title ?? '';
  const sec_ = Math.min(sec, doc.sections.length - 1);
  const section = doc.sections[sec_];
  const lastPage = atPage ?? lesson.lastPage;
  const pageInfo = pdfInfo
    ? `${pdfInfo.course.name.toLocaleUpperCase(lang)} · ${t('pageOf').replace('{p}', num(lastPage, lang)).replace('{n}', num(pdfInfo.pdf.pages, lang))} · ${percent(pct ?? lesson.percent, lang)}`
    : '';
  const pageFrom = Math.min(...section.blocks.map((b) => b.pageFrom));
  const pageTo = Math.max(...section.blocks.map((b) => b.pageTo));
  // The section check only where this section's pages have questions.
  const checkN = checkCount ? checkCount.count(pageFrom, pageTo) : 0;
  const sectionEnd = sec_ === doc.sections.length - 1 ? t('s4end') : t('secEnd').replace('{n}', num(sec_ + 1, lang));
  const fontSize = fontI === 0 ? settings.readerFontSize : FONT_SIZES[fontI];
  const clock = `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;

  const goSection = (i: number) => {
    setSec(i);
    setTerm(null);
    setSelected(false);
    scroller.current?.scrollTo({ top: 0, behavior: 'smooth' });
  };
  // Page search: open the section with that page and scroll to it.
  const jumpToPage = (e: FormEvent) => {
    e.preventDefault();
    const p = Number(pageQuery);
    const i = doc.sections.findIndex((x) => x.blocks.some((b) => p >= b.pageFrom && p <= b.pageTo));
    if (!Number.isInteger(p) || i < 0) return toast(t('pageNotFound'));
    setPageQuery('');
    goSection(i);
    setTimeout(() => {
      const pages = scroller.current?.querySelectorAll<HTMLElement>('[data-from]') ?? [];
      const el = [...pages].find((x) => p >= Number(x.dataset.from) && p <= Number(x.dataset.to));
      el?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 80);
  };
  const nextSection = () => {
    // After the last section: this lesson's summary ("Ders özeti").
    if (sec >= doc.sections.length - 1) {
      navigate(`/summary?course=${courseId}&pdf=${pdfId}`);
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
  // A question from the reader (a hard word, a sentence): the panel opens and sends it.
  const askAssistant = (q: string) => {
    setPanel(true);
    setAsked({ text: q, n: Date.now() });
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
            <span className="mono">{pageInfo}</span>
          </div>
          <div role="radiogroup" aria-label={t('readingTheme')} className={s.papers}>
            {PAPERS.map(([p, key, swatch]) => (
              <button key={p} role="radio" aria-checked={paperNow === p} className={paperNow === p ? `${s.paperBtn} ${s.paperOn}` : s.paperBtn} onClick={() => setPaper(p)}>
                <span style={{ background: swatch }} />
                {t(key)}
              </button>
            ))}
          </div>
          <button
            className={s.round}
            aria-label={t(recording ? 'recAudio' : 'rec_title')}
            title={t(recording ? 'recAudio' : 'rec_title')}
            onClick={() => navigate(recording ? `/recording?id=${recording.id}` : `/record?pdf=${pdfId}`)}
          >
            <Icon name="mic" size={20} />
          </button>
          <button className={s.round} aria-label={t('share')} onClick={() => guard('share', () => setShareOpen(true))}>
            <Icon name="share" size={19} />
          </button>
          <button className={`${s.round} ${s.aa}`} aria-label={t('textSize')} onClick={cycleFont}>
            Aa
          </button>
          {/* The assistant opens beside the page: our round star, like everywhere else. */}
          <button
            className={panel ? `star-btn ${s.starOn}` : 'star-btn'}
            style={{ width: 46, height: 46 }}
            aria-label={t('panelToggle')}
            title={t('panelToggle')}
            aria-pressed={panel}
            onClick={() => setPanel(!panel)}
          />
        </header>

        {/* One button with the open section (tap: the list of all sections) and a small page search; in full
            screen (no header) also the page and the assistant star, top right. */}
        <div className={s.tabsRow}>
          <div className={s.secPick} lang={doc.language}>
            <button className={s.secBtn} aria-haspopup="listbox" aria-expanded={secMenu} aria-label={t('sections')} onClick={() => setSecMenu(!secMenu)}>
              <span className="mono">
                {num(sec_ + 1, lang)}/{num(doc.sections.length, lang)}
              </span>
              <b dir="auto">{section.title}</b>
              <Icon name="chevron" size={16} className={secMenu ? s.chevUp : s.chevDown} />
            </button>
            {secMenu && (
              <>
                <button className={s.secShade} aria-label={t('close')} onClick={() => setSecMenu(false)} />
                <div role="listbox" aria-label={t('sections')} className={s.secMenu}>
                  {doc.sections.map((x, i) => {
                    const from = Math.min(...x.blocks.map((b) => b.pageFrom));
                    const to = Math.max(...x.blocks.map((b) => b.pageTo));
                    return (
                      <button
                        key={`${i}-${x.title}`}
                        role="option"
                        aria-selected={i === sec_}
                        className={i === sec_ ? s.secOn : ''}
                        onClick={() => (goSection(i), setSecMenu(false))}
                      >
                        <span className="mono">{num(i + 1, lang)}</span>
                        <b dir="auto">{x.title}</b>
                        <span className="mono">
                          {t('pageAbbr')} {num(from, lang)}
                          {to !== from && `–${num(to, lang)}`}
                        </span>
                      </button>
                    );
                  })}
                </div>
              </>
            )}
          </div>
          <span className={s.grow} />
          <form className={s.pageFind} onSubmit={jumpToPage} role="search">
            <Icon name="search" size={15} />
            <input value={pageQuery} onChange={(e) => setPageQuery(e.target.value.replace(/\D/g, ''))} inputMode="numeric" placeholder={t('pageFind')} aria-label={t('pageFind')} />
          </form>
          {focus && (
            <>
              <span className={`mono ${s.focusPage}`}>{pageInfo}</span>
              <button
                className={panel ? `star-btn ${s.starOn}` : 'star-btn'}
                style={{ width: 42, height: 42 }}
                aria-label={t('panelToggle')}
                title={t('panelToggle')}
                aria-pressed={panel}
                onClick={() => setPanel(!panel)}
              />
            </>
          )}
        </div>

        <div className={s.scroll} ref={scroller} onScroll={trackPage}>
          <div className={s.column}>
            {section.blocks.map((b, i) => (
              <Block
                marks={marks.filter((m) => m.page >= b.pageFrom && m.page <= b.pageTo)}
                ink={inkOf(b.pageFrom).strokes}
                pen={pen ? penColor : null}
                onInk={(strokes) => setInk(b.pageFrom, strokes)}
                key={`${sec_}-${i}`}
                doc={doc}
                block={b}
                terms={lesson.terms}
                fontSize={fontSize}
                term={term}
                onTerm={(id) => {
                  setTerm(term === id ? null : id);
                  setSelected(false);
                }}
                selected={selected}
                highlights={highlights}
                onSelect={() => {
                  setSelected(!selected);
                  setTerm(null);
                }}
                selActs={[
                  [t('actTranslate'), () => (setSelected(false), setTrSource({ text: sentenceOf(b), page: b.pageFrom }))],
                  [
                    t('actCopy'),
                    () => {
                      setSelected(false);
                      const p = b.paragraphs.find((x) => !Array.isArray(x));
                      if (p && !Array.isArray(p)) navigator.clipboard?.writeText(p.text).catch(() => {});
                      toast(t('copied'));
                    },
                  ],
                  [
                    t('actHighlight'),
                    () => {
                      setSelected(false);
                      const text = sentenceOf(b);
                      if (text && !highlights.includes(text)) {
                        setHighlights([...highlights, text]);
                        addHighlight(pdfId, b.pageFrom, text);
                      }
                      toast(t('highlighted'));
                    },
                  ],
                  [t('actAsk'), () => (setSelected(false), askAssistant(t('askSentence') + sentenceOf(b)))],
                ]}
                onTranslate={() => setTrSource({ text: blockText(b), page: b.pageFrom })}
              />
            ))}

            {checkN > 0 ? (
              <section className={s.check}>
                <span className={s.checkIcon}>
                  <Icon name="check" size={22} width={2} />
                </span>
                <span className={s.checkText}>
                  <b>{t('checkTitle').replace('{n}', num(checkN, lang))}</b>
                  <span>{sectionEnd}</span>
                </span>
                <button className={s.checkGo} onClick={() => navigate(`/quiz?from=reader&course=${courseId}&pdf=${pdfId}&pf=${pageFrom}&pt=${pageTo}&next=${sec_ + 1}`)}>
                  {t('start')}
                </button>
                <button className={s.checkNext} onClick={nextSection}>
                  {sec_ === doc.sections.length - 1 ? t('lessonSummary') : t('nextSection')}
                </button>
              </section>
            ) : (
              <div className={s.nextOnly}>
                <button className={s.checkNext} onClick={nextSection}>
                  {sec_ === doc.sections.length - 1 ? t('lessonSummary') : t('nextSection')}
                </button>
              </div>
            )}
          </div>
        </div>

        {pen && (
          <div className={s.penBar} role="toolbar" aria-label={t('pen')}>
            {PEN_COLORS.map((c) => (
              <button
                key={c}
                aria-label={c}
                aria-pressed={penColor === c}
                className={penColor === c ? `${s.penColor} ${s.penColorOn}` : s.penColor}
                style={{ background: c }}
                onClick={() => setPenColor(c)}
              />
            ))}
            <button
              className={s.penText}
              onClick={() => {
                if (lastInkPage === null || !inkOf(lastInkPage).strokes.length) return toast(t('penNothing'));
                setInk(lastInkPage, inkOf(lastInkPage).strokes.slice(0, -1));
              }}
            >
              {t('penUndo')}
            </button>
            <button className={s.penText} onClick={() => setPen(false)}>
              {t('penDone')}
            </button>
          </div>
        )}
        <div className={s.dock}>
          <button
            className={running ? s.clock : `${s.clock} ${s.clockStill}`}
            aria-label={paused ? t('resume') : t('pause')}
            title={paused ? t('resume') : idle ? t('clockIdle') : t('pause')}
            onClick={() => setPaused(!paused)}
          >
            <span className="mono">{clock}</span>
            <span className={s.clockIcon}>
              <Icon name={paused ? 'play' : 'pause'} size={14} width={2.2} />
            </span>
          </button>
          <button
            aria-label={t('pen')}
            title={t('pen')}
            aria-pressed={pen}
            className={pen ? s.dockOn : undefined}
            onClick={() => {
              setPen(!pen);
              if (!pen) toast(t('penOn'));
            }}
          >
            <Icon name="pen" size={20} />
          </button>
          <button
            aria-label={t(reading ? 'stopListen' : 'listen')}
            title={t(reading ? 'stopListen' : 'listen')}
            aria-pressed={reading}
            className={reading ? s.dockOn : undefined}
            onClick={() => {
              if (reading) return (stopSpeaking(), setReading(false));
              if (!canSpeak()) return toast(t('noVoice'));
              const ok = speakAll(section.blocks.map(blockText).join('\n'), doc.language, () => setReading(false));
              setReading(ok);
              if (ok) toast(t('pageAloud'));
            }}
          >
            <Icon name="speaker" size={20} />
          </button>
          <button aria-label={t('cardsLabel')} title={t('cardsLabel')} onClick={() => navigate(`/cards?pdf=${pdfId}`)}>
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

        {term && lesson.terms[term] && (
          <TermCard
            term={lesson.terms[term]}
            onClose={() => setTerm(null)}
            onAsk={(name) => {
              setTerm(null);
              askAssistant(name + t('askedSuffix'));
            }}
            onCard={async (name) => {
              const r = await addTermCard(lesson.terms[term].id);
              toast(r === 'added' ? name + t('addedToCards') : r === 'already' ? name + t('cardAlready') : t('cardFailed'));
            }}
            onNoVoice={() => toast(t('noVoice'))}
          />
        )}
      </main>

      {panel && (
        <AssistantPanel materialId={pdfId} title={title} pages={[pageFrom, pageTo]} asked={asked} onClose={() => setPanel(false)} />
      )}

      {shareOpen && <ShareDialog pdfId={pdfId} onClose={() => setShareOpen(false)} />}

      {trSource && <TranslateDialog doc={doc} materialId={pdfId} source={trSource.text} page={trSource.page} onClose={() => setTrSource(null)} />}
    </div>
  );
}

/** The selectable sentence of a block, if it has one. */
/** The first paragraph of a page (the selection menu works on it). */
function sentenceOf(b: ReaderBlock) {
  const p = b.paragraphs.find((x) => !Array.isArray(x));
  return p && !Array.isArray(p) ? p.text : b.paragraphs[0] ? paraText(b.paragraphs[0]) : (b.heading ?? '');
}
/** The whole text of a page: heading and paragraphs, one per line ("Çevir", reading aloud). */
function blockText(b: ReaderBlock) {
  return [b.heading, ...b.paragraphs.map(paraText)].filter(Boolean).join('\n');
}

/** Plain text of one paragraph (hard words included). */
function paraText(p: ReaderBlock['paragraphs'][number]) {
  return Array.isArray(p) ? p.map((x) => (typeof x === 'string' ? x : x.text)).join('') : p.text;
}

type BlockProps = {
  /** Lines drawn over this page, and the pen's color while drawing (null = pen off). */
  ink: Stroke[];
  pen: string | null;
  onInk: (strokes: Stroke[]) => void;
  /** Notes from the lecture recording on this page. */
  marks: LectureMark[];
  doc: ReaderDoc;
  block: ReaderBlock;
  terms: Record<string, ReaderTerm>;
  fontSize: number;
  term: string | null;
  onTerm: (id: string) => void;
  selected: boolean;
  highlights: string[];
  onSelect: () => void;
  selActs: [string, () => void][];
  onTranslate: () => void;
};

const MolViewer = lazy(() => import('../components/MolViewer'));

/** Plain text of a block (heading + paragraphs), to find the drug it talks about. */
const blockPlain = (b: ReaderBlock) =>
  [b.heading ?? '', ...b.paragraphs.map((p) => (Array.isArray(p) ? p.map((x) => (typeof x === 'string' ? x : x.text)).join('') : p.text))].join(' ');

function Block({ doc, block, terms, fontSize, term, onTerm, selected, highlights, onSelect, selActs, onTranslate, marks, ink, pen, onInk }: BlockProps) {
  const { t, lang } = useI18n();
  const toast = useToast();
  const [molOpen, setMolOpen] = useState<Molecule | null>(null);
  // Chip only when we have the structure of a drug named in this block.
  const mols = findMolecules(blockPlain(block));
  const [tagKey, tagStyle] = TAGS[block.tag] ?? TAGS.definition;
  const pageLabel =
    block.pageFrom === block.pageTo
      ? t('pageLabel').replace('{n}', num(block.pageFrom, lang))
      : t('pagesLabel').replace('{a}', num(block.pageFrom, lang)).replace('{b}', num(block.pageTo, lang));

  const seg = (x: Segment, i: number) =>
    typeof x === 'string' ? (
      <span key={i}>{x}</span>
    ) : (
      <button
        key={i}
        className={term === x.term ? `${s.term} ${s.termOn}` : s.term}
        aria-expanded={term === x.term}
        onClick={() => {
          if (term !== x.term && terms[x.term]) tapTerm(terms[x.term].id);
          onTerm(x.term);
        }}
      >
        {x.text}
      </button>
    );

  return (
    <article className={s.page} data-from={block.pageFrom} data-to={block.pageTo}>
      <InkLayer strokes={ink} pen={pen} onDone={(st) => onInk([...ink, st])} />
      <div className={s.pageTop}>
        <span className="mono">{pageLabel}</span>
        <span className={tagStyle === 'red' ? `${s.tag} ${s.tagRed}` : s.tag}>{t(tagKey)}</span>
        <span className={s.grow} />
        <button className={s.translate} onClick={onTranslate}>
          {t('translate')}
        </button>
      </div>
      {marks.map((m, i) => (
        <Link key={i} to={`/recording?id=${m.recordingId}&t=${Math.floor(m.at)}`} className={m.kind === 'exam' ? `${s.lectureMark} ${s.lectureExam}` : s.lectureMark}>
          <Icon name="mic" size={15} />
          <span className={s.lectureText}>
            <b>{m.kind === 'exam' ? t('markExam') : m.kind === 'stress' ? t('markStress') : t('markTime').replace('{n}', num(m.minutes, lang))}</b>
            {m.text && <span>“{m.text}”</span>}
          </span>
          <span className="mono">{clock(m.at)}</span>
        </Link>
      ))}
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
                className={`${s.selectable} ${selected ? s.selOn : ''} ${highlights.includes(p.text) ? s.highlight : ''}`}
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
      {mols.map((m) => (
        <button key={m.id} className={s.chipBtn} onClick={() => setMolOpen(m)}>
          <span className={s.chipIcon}>
            <Icon name="molecule" size={16} />
          </span>
          {t('molecule')} · {m.name[lang]}
        </button>
      ))}
      {molOpen && <MoleculeDialog mol={molOpen} page={block.pageFrom} contentLang={doc.language as Lang} onClose={() => setMolOpen(null)} />}
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

type Clock = { day: string; seconds: number; paused: boolean; pending: number };
const clockKey = (pdfId: string) => `kavis.readerClock.${pdfId}`;
const today = () => new Date().toDateString();

/** The reader clock of one lesson, kept in this browser for today (a new day starts at 00:00). */
function loadClock(pdfId: string): Clock {
  const fresh = { day: today(), seconds: 0, paused: false, pending: 0 };
  try {
    const c = JSON.parse(localStorage.getItem(clockKey(pdfId)) ?? 'null') as Clock | null;
    if (!c) return fresh;
    return c.day === today() ? c : { ...fresh, pending: c.pending ?? 0 };
  } catch {
    return fresh;
  }
}

function saveClock(pdfId: string, c: Omit<Clock, 'day'>) {
  try {
    localStorage.setItem(clockKey(pdfId), JSON.stringify({ ...c, day: today() }));
  } catch {
    // private window: the clock simply starts again next time
  }
}

function TermCard({
  term,
  onClose,
  onAsk,
  onCard,
  onNoVoice,
}: {
  term: ReaderTerm;
  onClose: () => void;
  onAsk: (name: string) => void;
  onCard: (name: string) => void;
  onNoVoice: () => void;
}) {
  const { t, lang } = useI18n();
  // Explanation in the app language; a missing language is made later by the Edge Function "explain-term".
  const exLang = term.explanation[lang] ? lang : term.explanation.en ? 'en' : 'tr';
  const ex = term.explanation[exLang];
  const name = ex?.name ?? term.surface;
  // "Dinle": the browser reads the word and its explanation aloud; pressing again stops it.
  const [speaking, setSpeaking] = useState(false);
  useEffect(() => stopSpeaking, [term.id]);
  const listen = () => {
    if (speaking) {
      stopSpeaking();
      setSpeaking(false);
      return;
    }
    if (!canSpeak()) return onNoVoice();
    setSpeaking(speak(`${name}. ${ex?.text ?? ''}`, exLang, () => setSpeaking(false)));
  };
  return (
    <div role="dialog" aria-label={t('termExpl')} className={s.termCard}>
      <div className={s.termTop}>
        <span className="mono">
          {t('termPage')} {term.page}
        </span>
        {ex?.kind && <span className={s.tag}>{ex.kind}</span>}
        <span className={s.grow} />
        <button className={s.close} aria-label={t('close')} onClick={onClose}>
          <Icon name="close" size={16} />
        </button>
      </div>
      <b className={s.termName}>{name}</b>
      <span className={s.termDef}>{ex?.text}</span>
      {term.explanation.en && <span className={s.termEn}>English: {term.explanation.en.name}</span>}
      <div className={s.termActs}>
        <button className={s.termAsk} onClick={() => onAsk(name)}>
          {t('askAssistant')}
        </button>
        <button onClick={() => onCard(name)}>{t('addToCards')}</button>
        <button onClick={listen} aria-pressed={speaking}>
          {speaking ? t('stopListen') : t('listen')}
        </button>
      </div>
    </div>
  );
}

function TranslateDialog({ doc, materialId, source, page, onClose }: { doc: ReaderDoc; materialId: string; source: string; page: number; onClose: () => void }) {
  const { t, lang } = useI18n();
  const toast = useToast();
  // Every app language except the PDF's own.
  const targets = LANGS.filter((l) => l !== doc.language);
  const [target, setTarget] = useState<Lang>(targets.includes(lang) ? lang : targets[0]);
  const { settings } = useSettings();
  const [style, setStyle] = useState<TranslationStyle>(settings.translationStyle);
  // The translation of the chosen language and style; a new choice shows "Çevriliyor…" until its own text comes
  // (a new one is made by the AI and takes a few seconds), never the previous language's text.
  const key = `${target}|${style}|${source}`;
  const [done, setDone] = useState<{ key: string; text: Awaited<ReturnType<typeof translate>> } | null>(null);
  useEffect(() => {
    let alive = true;
    translate(materialId, source, target, style).then((r) => alive && setDone({ key, text: r }));
    return () => {
      alive = false;
    };
  }, [materialId, source, target, style, key]);
  const text = done?.key === key ? done.text : undefined;
  const dir = dirOf(target);

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
          <span className="mono">
            {t('sourceLabelN')
              .replace('{lang}', (LANG_NAMES[doc.language as Lang] ?? doc.language).toLocaleUpperCase(lang))
              .replace('{page}', num(page, lang))}
          </span>
          <span className={`reading ${s.sourceText}`} lang={doc.language} dir="auto">
            {source}
          </span>
        </div>
        <div role="tablist" aria-label={t('trLanguage')} className={s.seg}>
          {targets.map((k) => (
            <button key={k} role="tab" aria-selected={k === target} className={k === target ? s.segOn : ''} onClick={() => setTarget(k)}>
              {LANG_NAMES[k]}
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
        <p className={`reading ${s.result}`} dir={typeof text === 'string' ? dir : undefined} lang={typeof text === 'string' ? target : undefined}>
          {text === undefined ? t('translating') : typeof text === 'string' ? text : t(text.error === 'locked' ? 'trLocked' : 'trFailed')}
        </p>
        <span className={s.trHint}>{t(style === 'literal' ? 'hintLiteral' : 'hintNatural')}</span>
      </section>
    </div>
  );
}

function MoleculeDialog({ mol, page, contentLang, onClose }: { mol: Molecule; page: number; contentLang: Lang; onClose: () => void }) {
  const { t, lang } = useI18n();
  const cl = (LANGS as readonly string[]).includes(contentLang) ? contentLang : lang;
  useEffect(() => {
    const k = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', k);
    return () => window.removeEventListener('keydown', k);
  }, [onClose]);
  return (
    <div className={s.modal}>
      <div className={s.scrim} onClick={onClose} />
      <section role="dialog" aria-modal="true" aria-label={t('molecule')} className={s.dialog}>
        <div className={s.dialogTop}>
          <h2 className="mono" style={{ fontSize: 11, letterSpacing: '0.08em', color: 'var(--text2)', fontWeight: 400 }}>
            {t('molDrugPage').replace('{n}', num(page, lang))}
          </h2>
          <button className={s.close} aria-label={t('close')} onClick={onClose}>
            <Icon name="close" size={16} />
          </button>
        </div>
        <Suspense fallback={null}>
          <MolViewer mol={mol.id} size="full" contentLang={cl} />
        </Suspense>
      </section>
    </div>
  );
}

type PanelProps = {
  materialId: string;
  title: string;
  /** The pages the student is reading now, so "this page" means something to the assistant. */
  pages: [number, number];
  asked: { text: string; n: number } | null;
  onClose: () => void;
};

function AssistantPanel({ materialId, title, pages, asked, onClose }: PanelProps) {
  const { t, lang } = useI18n();
  // The earlier chat about this lesson (answers are made by the server, Edge Function "assistant").
  const thread = useAsync(() => latestThread(null, materialId), [materialId]);
  const toast = useToast();
  const [draft, setDraft] = useState('');
  const [mine, setMine] = useState<ChatMessage[]>([]);
  const [threadId, setThreadId] = useState<string | null>(null);
  const [waiting, setWaiting] = useState(false);
  // The answer while it is being written.
  const [live, setLive] = useState('');
  const writing = live.length > 0;
  const [quick, setQuick] = useState(false);
  // "Sadece PDF'lerim" or "Yapay zekâ + araştırma" (the lesson first, then the web).
  const [mode, setMode] = useState<SourceMode>('pdf');
  const { guard } = useTrial();
  const voice = useVoice(lang, (text) => setDraft((d) => (d ? `${d} ${text}` : text)), (why) => toast(t(VOICE_FAIL[why])));
  const end = useRef<HTMLDivElement>(null);
  const history = [...(thread?.messages ?? []), ...mine];

  useEffect(() => {
    if (mine.length) end.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }, [mine.length, waiting, writing]);

  // Questions in the reader are about this lesson only.
  const send = (text: string) => {
    const q = text.trim();
    if (!q) {
      toast(t('writeFirst'));
      return;
    }
    if (waiting) return;
    guard('question', async () => {
      setMine((m) => [...m, { id: crypto.randomUUID(), role: 'user', text: q, mode, sources: [], links: [], acts: [], outsidePdf: false }]);
      setDraft('');
      setQuick(false);
      setWaiting(true);
      setLive('');
      const r = await askAssistant(q, { materialId, threadId: threadId ?? thread?.id ?? null, mode, lang, pages }, setLive);
      setWaiting(false);
      setLive('');
      if ('error' in r) return toast(t({ locked: 'trialQFull', budget: 'askBudget', declined: 'askDeclined', other: 'askFailed' }[r.error]));
      setThreadId(r.threadId);
      setMine((m) => [...m, r.message]);
    });
  };
  const submit = (e: FormEvent) => {
    e.preventDefault();
    send(draft);
  };
  // Send a question asked from the page (once per ask).
  const sent = useRef(0);
  useEffect(() => {
    if (asked && asked.n !== sent.current) {
      sent.current = asked.n;
      send(asked.text);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [asked]);

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
      <span className={s.only}>{t(mode === 'ai' ? 'onlyFromAi' : 'onlyFrom').replace('{lesson}', title)}</span>
      <div role="radiogroup" aria-label={t('sourceLabel2')} className={s.srcSeg}>
        {(['pdf', 'ai'] as const).map((m) => (
          <button key={m} role="radio" aria-checked={mode === m} className={mode === m ? s.srcOn : ''} onClick={() => setMode(m)}>
            <Icon name={m === 'pdf' ? 'file' : 'globe'} size={14} />
            {t(m === 'pdf' ? 'srcPdf' : 'srcAi')}
          </button>
        ))}
      </div>

      <div className={s.chat}>
        {history.map((m) =>
          m.role === 'user' ? (
            <div key={m.id} className={s.me}>
              {m.text}
            </div>
          ) : (
            <div key={m.id} className={s.ai}>
              <AnswerText text={m.text} />
              {m.sources.some((x) => x.page !== null) && (
                <span className={`mono ${s.src}`}>
                  {t('sourcePrefix')}{' '}
                  {m.sources
                    .filter((x) => x.page !== null)
                    .map((x) => `${t('pageAbbr')} ${num(x.page!, lang)}`)
                    .join(', ')}
                </span>
              )}
              <ActNotes acts={m.acts} className={s.acts} />
              <WebLinks links={m.links} className={s.links} />
            </div>
          ),
        )}
        {waiting &&
          (live ? (
            <div className={s.ai} aria-live="polite">
              <AnswerText text={live} />
            </div>
          ) : (
            <Thinking />
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
        <input value={draft} onChange={(e) => setDraft(e.target.value)} placeholder={voicePlaceholder(voice.state, t) ?? t('askPlaceholder')} aria-label={t('question')} />
        <MicButton state={voice.state} onClick={voice.toggle} className={s.askIcon} size={18} />
        <button type="submit" className={s.askSend} aria-label={t('send')}>
          <Icon name="send" size={16} className="flip-rtl" />
        </button>
      </form>
      <span className={s.aiNote}>{t('aiNote')}</span>
    </aside>
  );
}

/**
 * Lines drawn over a page. With the pen on, the page catches the mouse / finger / Apple Pencil and draws;
 * a finished line is given back to be saved. Points are parts of the page's width and height (0–1).
 */
function InkLayer({ strokes, pen, onDone }: { strokes: Stroke[]; pen: string | null; onDone: (s: Stroke) => void }) {
  const box = useRef<SVGSVGElement>(null);
  // The line being drawn: kept in a ref too, so fast pointer events never see an old value.
  const [live, setLive] = useState<Stroke | null>(null);
  const drawing = useRef<Stroke | null>(null);
  const draw = (st: Stroke | null) => {
    drawing.current = st;
    setLive(st);
  };
  const at = (e: { clientX: number; clientY: number }): [number, number] => {
    const r = box.current!.getBoundingClientRect();
    return [(e.clientX - r.left) / r.width, (e.clientY - r.top) / r.height];
  };
  const line = (st: Stroke, i: number | string) => (
    <polyline
      key={i}
      points={st.points.map(([x, y]) => `${x},${y}`).join(' ')}
      fill="none"
      stroke={st.color}
      strokeWidth={3}
      strokeLinecap="round"
      strokeLinejoin="round"
      vectorEffect="non-scaling-stroke"
    />
  );
  if (!strokes.length && !pen) return null;
  return (
    <svg
      ref={box}
      className={pen ? `${s.ink} ${s.inkOn}` : s.ink}
      viewBox="0 0 1 1"
      preserveAspectRatio="none"
      onPointerDown={(e) => {
        if (!pen) return;
        e.currentTarget.setPointerCapture?.(e.pointerId);
        draw({ color: pen, points: [at(e)] });
      }}
      onPointerMove={(e) => drawing.current && draw({ ...drawing.current, points: [...drawing.current.points, at(e)] })}
      onPointerUp={() => {
        const st = drawing.current;
        if (st && st.points.length > 1) onDone(st);
        draw(null);
      }}
    >
      {strokes.map(line)}
      {live && line(live, 'live')}
    </svg>
  );
}
