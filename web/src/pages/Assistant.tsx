import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { useToast } from '../components/Toast';
import Icon, { type IconName } from '../components/Icon';
import {
  askAssistant,
  latestThread,
  listAssistantTopics,
  photoForAssistant,
  weakTopicsOf,
  type AssistantTopic,
  type ChatMessage,
  type QuestionPhoto,
  type SourceMode,
} from '../api/assistant';
import { useAsync } from '../hooks/useAsync';
import { num } from '../i18n/format';
import { useVoice, VOICE_FAIL, voicePlaceholder } from '../speech/useVoice';
import MicButton from '../components/MicButton';
import { useTrial } from '../trial/TrialProvider';
import s from './Assistant.module.css';

// Design: design/NewIPad.dc.html, screens "ai" (start + message box) and "aichat" (answer view).
// The assistant answers only from the student's material unless "AI + research" is switched on.
// Answers are made by the server (Edge Function "assistant") and appear while they are written; the chat also
// shows the earlier conversation from the database. A question can be typed, spoken (turned into text on this
// computer) or a photo of an exam question, solved step by step.

type Panel = '' | 'menu' | 'add';
/** What opens the chat: a typed question, a photo to solve, or "Ben anlatayım" (the student explains, I check). */
type Start = { topic: string; q: string; photo?: QuestionPhoto; teach?: boolean };

export default function Assistant() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const { guard } = useTrial();
  const topics = useAsync(() => listAssistantTopics(t('asAllName'), t('asAllSub')), [lang]);

  const [course, setCourse] = useState(params.get('q') ? 'all' : (params.get('course') ?? ''));
  const [mode, setMode] = useState<SourceMode>('pdf');
  const [panel, setPanel] = useState<Panel>('');
  const [editCourse, setEditCourse] = useState(false);
  const [draft, setDraft] = useState('');
  const photoIn = useRef<HTMLInputElement>(null);
  const voice = useVoice(lang, (text) => setDraft((d) => (d ? `${d} ${text}` : text)), (why) => toast(t(VOICE_FAIL[why])));
  // A question from another page (?q=…) opens the chat directly.
  const [chat, setChat] = useState<Start | null>(() => {
    const q = params.get('q');
    return q ? { topic: 'all', q } : null;
  });

  useEffect(() => {
    if (params.has('q')) setParams({}, { replace: true });
  }, [params, setParams]);

  if (!topics) return <main className={s.page} />;

  const byId = (id: string) => topics.find((x) => x.id === id);
  const sel = byId(course);
  const name = (x?: AssistantTopic) => (x ? x.name : '');

  const placeholder = voicePlaceholder(voice.state, t) ?? (!sel ? t('phPick') : sel.id === 'all' ? t('phAll') : name(sel) + t('phAbout'));

  const setSource = (m: SourceMode) => {
    setMode(m);
    toast(t(m === 'ai' ? 'toastSrcAi' : 'toastSrcPdf'));
  };
  const pickCourse = (id: string) => {
    setCourse(id);
    setEditCourse(false);
    toast(t('coursePrefix') + name(byId(id)));
  };
  /** Questions need a course (or "all"); without one the course list opens. */
  const needCourse = () => {
    if (sel) return false;
    setPanel('menu');
    setEditCourse(true);
    toast(t('needCourse'));
    return true;
  };
  const send = () => {
    if (needCourse()) return;
    if (!draft.trim()) return toast(t('writeQ'));
    guard('question', () => {
      setChat({ topic: sel!.id, q: draft.trim() });
      setDraft('');
      setPanel('');
    });
  };
  // "+" menu: a lesson, the lecturer's questions ("Soru örneklerim") and recordings go to their own screens;
  // "Soruyu çözdür" takes a photo of a question.
  const addFile = (kind: 'pdf' | 'photo' | 'audio' | 'solve') => {
    setPanel('');
    const where = sel?.courseId ? `course=${sel.courseId}` : '';
    if (kind === 'pdf') navigate(`/upload${where ? `?${where}` : ''}`);
    else if (kind === 'photo') navigate(`/samples${where ? `?${where}` : ''}`);
    else if (kind === 'audio') navigate('/record');
    else if (!needCourse()) photoIn.current?.click();
  };
  const solve = async (file?: File) => {
    if (!file || !sel) return;
    if (!file.type.startsWith('image/')) return toast(t('solveBadFile'));
    const photo = await photoForAssistant(file).catch(() => null);
    if (!photo) return toast(t('solveBadFile'));
    guard('question', () => setChat({ topic: sel.id, q: draft.trim(), photo }));
    setDraft('');
  };
  const explainWeak = async () => {
    if (needCourse()) return;
    const weak = await weakTopicsOf(sel!.courseId);
    const q = weak.length ? t('qkWeakQ').replace('{list}', weak.join(', ')) : t('qkWeakQNone');
    guard('question', () => setChat({ topic: sel!.id, q }));
  };
  const teach = () => {
    if (needCourse()) return;
    setChat({ topic: sel!.id, q: '', teach: true });
  };

  const quick: [IconName, string, () => void][] = [
    ['headphones', 'qkWeak', explainWeak],
    ['lines', 'qkSummary', () => (navigate('/reader'), toast(t('summarizing')))],
    ['checklist', 'qkFive', () => navigate('/quiz?tab=quiz')],
    ['target', 'qkWeakList', () => navigate('/quiz')],
    ['mic', 'qkTeach', teach],
  ];

  if (chat) {
    return <Chat topic={byId(chat.topic) ?? topics[0]} start={chat} mode={mode} onBack={() => setChat(null)} />;
  }

  const courseGrid = (onPick: (id: string) => void, isOn: (id: string) => boolean) => (
    <div role="radiogroup" aria-label={t('courseLabel')} className={s.courseGrid}>
      {topics.map((k) => (
        <button key={k.id} role="radio" aria-checked={isOn(k.id)} className={isOn(k.id) ? `${s.course} ${s.courseOn}` : s.course} onClick={() => onPick(k.id)}>
          <span className={s.dot} style={{ background: k.color }} />
          <b>{k.name}</b>
          <span>{k.sub}</span>
        </button>
      ))}
    </div>
  );

  return (
    <main className={s.page}>
      <div className={s.stage}>
        <span className={s.grow} />
        {panel !== 'menu' && (
          <>
            <span className={s.glow} aria-hidden="true" />
            <h1 className={s.hero}>
              {t('heroA')} <span>{t('heroB')}</span>
            </h1>
            <span className={s.heroSub}>{t(mode === 'ai' ? 'heroSubAi' : 'heroSubPdf')}</span>
          </>
        )}
        <span className={s.grow} />

        <div className={s.composerWrap}>
          {panel === 'menu' && (
            <section className={`${s.card} ${s.menu}`}>
              <span className={`mono ${s.label}`}>{t('courseLabel')}</span>
              {!sel || editCourse ? (
                courseGrid(pickCourse, (id) => id === course)
              ) : (
                <div className={s.selRow}>
                  <span className={s.dot} style={{ background: sel.color }} />
                  <b>{name(sel)}</b>
                  <button className={s.ghostBtn} onClick={() => setEditCourse(true)}>
                    {t('change')}
                  </button>
                </div>
              )}
              <span className={s.sep} />
              <span className={`mono ${s.label}`}>{t('sourceLabel2')}</span>
              <div role="radiogroup" aria-label={t('sourceLabel2')} className={s.seg}>
                {(['pdf', 'ai'] as const).map((m) => (
                  <button key={m} role="radio" aria-checked={mode === m} className={mode === m ? s.segOn : ''} onClick={() => setSource(m)}>
                    <Icon name={m === 'pdf' ? 'file' : 'globe'} size={16} />
                    {t(m === 'pdf' ? 'srcPdf' : 'srcAi')}
                  </button>
                ))}
              </div>
              <span className={s.sep} />
              <span className={`mono ${s.label}`}>{t('quickLabel')}</span>
              <div className={s.quick}>
                {quick.map(([icon, key, fn], i) => (
                  <button key={key} className={i === 0 ? s.quickHot : ''} onClick={() => (setPanel(''), fn())}>
                    <span>
                      <Icon name={icon} size={16} />
                    </span>
                    {t(key)}
                  </button>
                ))}
              </div>
            </section>
          )}

          {panel === 'add' && (
            <section className={`${s.card} ${s.addMenu}`}>
              {(
                [
                  ['pdf', 'upload', 'addPdfItem', 'addPdfS'],
                  ['photo', 'camera', 'addPhoto', 'addPhotoS'],
                  ['audio', 'mic', 'addAudio', 'addAudioS'],
                  ['solve', 'solve', 'addSolve', 'addSolveS'],
                ] as const
              ).map(([kind, icon, title, sub]) => (
                <button key={kind} onClick={() => addFile(kind)}>
                  <span className={s.addIcon}>
                    <Icon name={icon} size={17} />
                  </span>
                  <span className={s.addText}>
                    <span>{t(title)}</span>
                    <small>{t(sub)}</small>
                  </span>
                </button>
              ))}
            </section>
          )}

          <input ref={photoIn} type="file" accept="image/*" hidden onChange={(e) => (solve(e.target.files?.[0]), (e.target.value = ''))} />
          <form
            className={s.composer}
            onSubmit={(e: FormEvent) => {
              e.preventDefault();
              send();
            }}
          >
            {(sel || mode === 'ai') && (
              <div className={s.chips}>
                {sel && (
                  <span className={s.chip}>
                    <button type="button" onClick={() => (setPanel('menu'), setEditCourse(true))}>
                      <span className={s.dot} style={{ background: sel.color }} />
                      {name(sel)}
                    </button>
                    <button type="button" aria-label={t('close')} onClick={() => (setCourse(''), toast(t('courseCleared')))}>
                      <Icon name="close" size={12} />
                    </button>
                  </span>
                )}
                {mode === 'ai' && (
                  <span className={`${s.chip} ${s.chipAi}`}>
                    <button type="button" onClick={() => setPanel('menu')}>
                      <Icon name="globe" size={13} />
                      {t('aiChip')}
                    </button>
                    <button type="button" aria-label={t('close')} onClick={() => setSource('pdf')}>
                      <Icon name="close" size={12} />
                    </button>
                  </span>
                )}
              </div>
            )}
            <div className={s.row}>
              <button
                type="button"
                className={panel === 'add' ? `${s.round} ${s.roundOn}` : s.round}
                aria-label={t('addMenu')}
                aria-expanded={panel === 'add'}
                onClick={() => setPanel(panel === 'add' ? '' : 'add')}
              >
                <Icon name="plus" size={20} className={panel === 'add' ? s.turned : ''} />
              </button>
              <button
                type="button"
                className={panel === 'menu' ? `${s.round} ${s.roundAmb}` : s.round}
                aria-label={t('quickLabel')}
                aria-haspopup="true"
                aria-expanded={panel === 'menu'}
                onClick={() => (setPanel(panel === 'menu' ? '' : 'menu'), setEditCourse(false))}
              >
                <Icon name="sliders" size={19} />
                {!sel && panel !== 'menu' && <span className={s.needDot} />}
              </button>
              <input value={draft} onChange={(e) => setDraft(e.target.value)} placeholder={placeholder} aria-label={t('question')} />
              <MicButton state={voice.state} onClick={voice.toggle} className={s.round} />
              <button type="submit" className={s.send} aria-label={t('send')}>
                <Icon name="send" size={18} className="flip-rtl" />
              </button>
            </div>
          </form>
        </div>
      </div>
    </main>
  );
}

type Shown = ChatMessage & { photo?: string };

function Chat({ topic, start, mode, onBack }: { topic: AssistantTopic; start: Start; mode: SourceMode; onBack: () => void }) {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [draft, setDraft] = useState('');
  const { guard } = useTrial();
  const voice = useVoice(lang, (text) => setDraft((d) => (d ? `${d} ${text}` : text)), (why) => toast(t(VOICE_FAIL[why])));
  const thread = useAsync(() => latestThread(topic.courseId), [topic.courseId]);
  // Messages of this visit (the earlier ones come from the database) and the thread they continue.
  const [extra, setExtra] = useState<Shown[]>([]);
  const [threadId, setThreadId] = useState<string | null>(null);
  const [waiting, setWaiting] = useState(false);
  // The answer while it is being written.
  const [live, setLive] = useState('');
  const writing = live.length > 0;
  const askedFirst = useRef(false);
  const end = useRef<HTMLDivElement>(null);
  const all = topic.id === 'all';
  const name = topic.name;
  const tag = all ? t('tagAll') : t('tagCourse') + name.toLocaleUpperCase(lang === 'tr' ? 'tr' : 'en');
  const hello = start.teach ? t('teachHello') : all ? t('helloAll') : t('helloA') + name + t('helloB') + (mode === 'ai' ? t('helloAi') : '');
  const messages: Shown[] = [...(thread?.messages ?? []), ...extra];

  const follow: [string, string, 'question' | 'generate'][] = [
    ['followEasy', t('followEasyT'), 'question'],
    ['followQuiz', name + t('followQuizT'), 'generate'],
    ['followCard', t('followCardA') + name + t('followCardB'), 'generate'],
  ];
  const sourceLine = (m: ChatMessage) =>
    m.sources
      .filter((x) => x.lesson)
      .map((x) => (x.page !== null ? `${x.lesson} · ${t('pageAbbr')} ${num(x.page, lang)}` : x.lesson))
      .join(' · ');

  // In "Ben anlatayım" the student's text goes with a request to check it against the lessons.
  const ask = async (q: string, photo?: QuestionPhoto) => {
    const shown = q || t('solveLabel');
    setExtra((e) => [...e, { id: crypto.randomUUID(), role: 'user', text: shown, mode, sources: [], outsidePdf: false, photo: photo && `data:image/jpeg;base64,${photo.data}` }]);
    setWaiting(true);
    setLive('');
    const sent = start.teach && !photo ? t('teachPrefix') + q : q;
    const r = await askAssistant(sent, { courseId: topic.courseId, threadId: threadId ?? thread?.id ?? null, mode, lang, photo }, setLive);
    setWaiting(false);
    setLive('');
    if ('error' in r) {
      toast(t({ locked: 'trialQFull', budget: 'askBudget', declined: 'askDeclined', other: 'askFailed' }[r.error]));
      return;
    }
    setThreadId(r.threadId);
    setExtra((e) => [...e, r.message]);
  };

  // A question (or photo) from the start screen is asked once the earlier chat is loaded.
  useEffect(() => {
    if ((!start.q && !start.photo) || askedFirst.current || thread === undefined) return;
    askedFirst.current = true;
    ask(start.q, start.photo);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [thread]);

  useEffect(() => {
    end.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }, [messages.length, waiting, writing]);

  return (
    <main className={s.chatPage}>
      <div className={s.chatTop}>
        <button className={s.round} aria-label={t('back')} onClick={onBack}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <span className="star-btn" style={{ width: 40, height: 40 }} aria-hidden="true" />
        <span className={s.chatTitle}>
          <h1>{t('assistantTitle')}</h1>
          <span className={s.chips}>
            <span className={s.chipStatic}>
              <span className={s.dot} style={{ background: topic.color }} />
              {name}
            </span>
            <span className={mode === 'ai' ? `${s.chipStatic} ${s.chipAi}` : s.chipStatic}>{t(mode === 'ai' ? 'srcAi' : 'srcPdf')}</span>
          </span>
        </span>
        <button className={s.folderBtn} onClick={() => navigate(all ? '/courses' : `/courses/${topic.courseId}`)}>
          <Icon name="folder" size={17} />
          {t(all ? 'folderAll' : 'folderOpen')}
        </button>
      </div>

      <div className={s.thread}>
        <div className={s.column}>
          <div className={s.ai}>{hello}</div>
          {thread !== undefined && messages.length === 0 && !waiting && !start.teach && <span className={s.protoNote}>{t('noThread')}</span>}
          {messages.map((m) =>
            m.role === 'user' ? (
              <div key={m.id} className={s.me}>
                {m.photo && <img className={s.mePhoto} src={m.photo} alt={t('solveLabel')} />}
                {m.text}
              </div>
            ) : (
              <div key={m.id} className={s.answer}>
                <span className={`mono ${s.answerTag}`}>{m.outsidePdf ? t('outsidePdf') : tag}</span>
                <span>{m.text}</span>
                {sourceLine(m) && (
                  <span className={`mono ${s.answerSrc}`}>
                    {t('sourcePrefix')} {sourceLine(m)}
                  </span>
                )}
              </div>
            ),
          )}
          {waiting && live && (
            <div className={s.answer} aria-live="polite">
              <span className={`mono ${s.answerTag}`}>{tag}</span>
              <span>{live}</span>
            </div>
          )}
          {((waiting && !live) || thread === undefined) && (
            <div className={s.typing} aria-label="…">
              <span />
              <span />
              <span />
            </div>
          )}
          {messages.length > 0 && !waiting && !start.teach && (
            <div className={s.follow}>
              {follow.map(([k, msg, action]) => (
                <button key={k} onClick={() => guard(action, () => (k === 'followEasy' ? ask(t('followEasyQ')) : toast(msg)))}>
                  {t(k)}
                </button>
              ))}
            </div>
          )}
          <div ref={end} />
        </div>
      </div>

      <form
        className={`${s.composer} ${s.chatComposer}`}
        onSubmit={(e) => {
          e.preventDefault();
          if (!draft.trim()) {
            toast(t('writeQ'));
            return;
          }
          if (waiting) return;
          guard('question', () => {
            const q = draft.trim();
            setDraft('');
            ask(q);
          });
        }}
      >
        <div className={s.row}>
          <input
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder={voicePlaceholder(voice.state, t) ?? (start.teach ? t('teachPh') : all ? t('phAll') : name + t('phAbout'))}
            aria-label={t('question')}
          />
          <MicButton state={voice.state} onClick={voice.toggle} className={s.round} />
          <button type="submit" className={s.send} aria-label={t('send')}>
            <Icon name="send" size={18} className="flip-rtl" />
          </button>
        </div>
      </form>
    </main>
  );
}
