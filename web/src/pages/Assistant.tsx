import { useEffect, useState, type FormEvent } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { useToast } from '../components/Toast';
import Icon, { type IconName } from '../components/Icon';
import { askAssistant, listAssistantTopics, uploadForAssistant, type SourceMode } from '../api/assistant';
import { useAsync } from '../hooks/useAsync';
import type { AssistantTopic, Attachment, AttachmentKind } from '../api/types';
import s from './Assistant.module.css';

// Design: design/NewIPad.dc.html, screens "ai" (start + message box) and "aichat" (answer view).
// The assistant answers only from the student's material unless "AI + research" is switched on.

type Panel = '' | 'menu' | 'add' | 'courses';
type Upload = { kind: AttachmentKind; data: Attachment; topic: string; chosen: boolean; done: boolean };

export default function Assistant() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const topics = useAsync(listAssistantTopics, []);

  const [course, setCourse] = useState(params.get('q') ? 'hypertension' : '');
  const [mode, setMode] = useState<SourceMode>('pdf');
  const [panel, setPanel] = useState<Panel>('');
  const [editCourse, setEditCourse] = useState(false);
  const [upload, setUpload] = useState<Upload | null>(null);
  const [draft, setDraft] = useState('');
  // A question from another page (?q=…) opens the chat directly.
  const [chat, setChat] = useState<{ topic: string; q: string } | null>(() => {
    const q = params.get('q');
    return q ? { topic: 'hypertension', q } : null;
  });

  useEffect(() => {
    if (params.has('q')) setParams({}, { replace: true });
  }, [params, setParams]);

  if (!topics) return <main className={s.page} />;

  const byId = (id: string) => topics.find((x) => x.id === id);
  const sel = byId(course);
  const name = (x?: AssistantTopic) => (x ? x.name[lang] : '');

  const placeholder = !sel ? t('phPick') : sel.id === 'all' ? t('phAll') : name(sel) + t('phAbout');

  const setSource = (m: SourceMode) => {
    setMode(m);
    toast(t(m === 'ai' ? 'toastSrcAi' : 'toastSrcPdf'));
  };
  const pickCourse = (id: string) => {
    setCourse(id);
    setEditCourse(false);
    toast(t('coursePrefix') + name(byId(id)));
  };
  const send = () => {
    if (!sel) {
      setPanel('menu');
      setEditCourse(true);
      toast(t('needCourse'));
      return;
    }
    setChat({ topic: sel.id, q: draft.trim() });
    setDraft('');
    setPanel('');
  };
  const addFile = async (kind: AttachmentKind | 'solve') => {
    setPanel('');
    if (kind === 'solve') {
      toast(t('k165'));
      return;
    }
    const data = await uploadForAssistant(kind);
    setUpload({ kind, data, topic: data.topic, chosen: false, done: false });
    toast(data.name[lang] + t('attUploaded'));
  };

  const quick: [IconName, string, () => void][] = [
    ['headphones', 'qkWeak', () => toast(t('k165'))],
    ['lines', 'qkSummary', () => (navigate('/reader'), toast(t('summarizing')))],
    ['checklist', 'qkFive', () => navigate('/quiz?tab=quiz')],
    ['target', 'qkWeakList', () => navigate('/quiz')],
    ['mic', 'qkTeach', () => toast(t('k165'))],
  ];

  if (chat) {
    return <Chat topic={byId(chat.topic) ?? topics[0]} question={chat.q} mode={mode} onBack={() => setChat(null)} />;
  }

  const courseGrid = (onPick: (id: string) => void, isOn: (id: string) => boolean, list = topics) => (
    <div role="radiogroup" aria-label={t('courseLabel')} className={s.courseGrid}>
      {list.map((k) => (
        <button key={k.id} role="radio" aria-checked={isOn(k.id)} className={isOn(k.id) ? `${s.course} ${s.courseOn}` : s.course} onClick={() => onPick(k.id)}>
          <span className={s.dot} style={{ background: k.color }} />
          <b>{k.name[lang]}</b>
          <span>{k.sub[lang]}</span>
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
          {upload && (
            <section className={s.card}>
              <div className={s.attTop}>
                <span className={`mono ${s.attTag}`}>{upload.data.tag[lang]}</span>
                <span className={s.attName}>
                  <b>{upload.data.name[lang]}</b>
                  <span>{upload.data.meta[lang]}</span>
                </span>
                <button className={s.x} aria-label={t('close')} onClick={() => setUpload(null)}>
                  <Icon name="close" size={16} />
                </button>
              </div>
              {!upload.done ? (
                <div className={s.attDetect}>
                  <span>
                    {t('attThinks')} <b>{name(byId(upload.topic))}</b> {t('attBelongs')}{' '}
                    <span className={s.muted}>· {upload.chosen ? t('youChose') : upload.data.why[lang]}</span>
                  </span>
                  <button
                    className={s.priBtn}
                    onClick={() => {
                      const n = name(byId(upload.topic));
                      setUpload({ ...upload, done: true });
                      setCourse(upload.topic);
                      toast(upload.kind === 'photo' ? `${n} ·${t('attQAdded')}` : n + t('attFolderAdded'));
                    }}
                  >
                    {t(upload.kind === 'photo' ? 'attAddQ' : 'attAddCourse')}
                  </button>
                  <button className={s.ghostBtn} onClick={() => setPanel('courses')}>
                    {t('attOther')}
                  </button>
                </div>
              ) : (
                <span className={s.attDone}>
                  {name(byId(upload.topic)) + t(upload.kind === 'photo' ? 'attQAdded' : 'attFolderAdded') + t('attUses')}
                </span>
              )}
            </section>
          )}

          {panel === 'courses' && upload && (
            <section className={s.card}>
              <span className={s.cardTitle}>{t('assignTitle')}</span>
              {courseGrid(
                (id) => (setUpload({ ...upload, topic: id, chosen: true }), setPanel('')),
                (id) => id === upload.topic,
                topics.filter((x) => x.id !== 'all'),
              )}
            </section>
          )}

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
              <button type="button" className={s.round} aria-label={t('talk')} onClick={() => toast(t('listening'))}>
                <Icon name="mic" size={19} />
              </button>
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

function Chat({ topic, question, mode, onBack }: { topic: AssistantTopic; question: string; mode: SourceMode; onBack: () => void }) {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [draft, setDraft] = useState('');
  const answer = useAsync(() => askAssistant(topic.id, question, mode), [topic.id, question, mode]);
  const all = topic.id === 'all';
  const name = topic.name[lang];
  const tag = all ? t('tagAll') : t('tagCourse') + name.toLocaleUpperCase(lang === 'tr' ? 'tr' : 'en');
  const hello = all ? t('helloAll') : t('helloA') + name + t('helloB') + (mode === 'ai' ? t('helloAi') : '');

  const follow: [string, string][] = [
    ['followEasy', t('followEasyT')],
    ['followQuiz', name + t('followQuizT')],
    ['followCard', t('followCardA') + name + t('followCardB')],
  ];

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
        {topic.folder && (
          <button className={s.folderBtn} onClick={() => navigate(topic.folder === 'all' ? '/courses' : `/courses/${topic.folder}`)}>
            <Icon name="folder" size={17} />
            {t(all ? 'folderAll' : 'folderOpen')}
          </button>
        )}
      </div>

      <div className={s.thread}>
        <div className={s.column}>
          <div className={s.ai}>{hello}</div>
          <div className={s.me}>{question || topic.sample.q[lang]}</div>
          {answer ? (
            <>
              <div className={s.answer}>
                <span className={`mono ${s.answerTag}`}>{tag}</span>
                <span>{answer.a[lang]}</span>
                <span className={`mono ${s.answerSrc}`}>
                  {t('sourcePrefix')} {answer.src[lang]}
                </span>
              </div>
              {question && <span className={s.protoNote}>{t('protoNote')}</span>}
              <div className={s.follow}>
                {follow.map(([k, msg]) => (
                  <button key={k} onClick={() => toast(msg)}>
                    {t(k)}
                  </button>
                ))}
              </div>
            </>
          ) : (
            <div className={s.typing} aria-label="…">
              <span />
              <span />
              <span />
            </div>
          )}
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
          setDraft('');
          toast(t('searchingA') + name + t('searchingB'));
        }}
      >
        <div className={s.row}>
          <input
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder={all ? t('phAll') : name + t('phAbout')}
            aria-label={t('question')}
          />
          <button type="button" className={s.round} aria-label={t('talk')} onClick={() => toast(t('listening'))}>
            <Icon name="mic" size={19} />
          </button>
          <button type="submit" className={s.send} aria-label={t('send')}>
            <Icon name="send" size={18} className="flip-rtl" />
          </button>
        </div>
      </form>
    </main>
  );
}
