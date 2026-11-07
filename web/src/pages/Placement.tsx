import { useEffect, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import { useAsync } from '../hooks/useAsync';
import { dirOf } from '../settings/SettingsProvider';
import { keepTest, placementLesson, placementQuiz, questionCount, savedTest, startPlacement, type PlacementQuiz, type PlacementTopic } from '../api/placement';
import { saveAttempt } from '../api/quiz';
import { runPlanner } from '../api/plan';
import s from './Placement.module.css';

// Design: design/NewPlacement.dc.html ("Seviye tespiti"), opened when an upload is ready: "Have you studied this
// before?" → no (open the PDF) / a short test / only some topics; then the topic map (known / weak / to study).
// The test is made by the server from the lesson's own questions (no AI); grade-quiz writes the topic states.

type Stage = 'ask' | 'partial' | 'quiz' | 'result';
type Answer = number | 'x';
type Status = 'know' | 'weak' | 'new' | 'todo';

const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F'];
const ICON = {
  no: 'M4 5h6a2 2 0 0 1 2 2v12a2 2 0 0 0-2-2H4z M20 5h-6a2 2 0 0 0-2 2v12a2 2 0 0 1 2-2h6z',
  yes: 'M9 11l2 2 4-4 M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z',
  part: 'M9 6h11 M9 12h11 M9 18h11 M4 6l1 1 2-2 M4 12l1 1 2-2 M4 18h2',
};
const MARK: Record<Status, string> = { know: 'M5 12l5 5 9-10', weak: 'M12 8v5 M12 16h.01', new: 'M6 6l12 12 M18 6L6 18', todo: 'M6 6l12 12 M18 6L6 18' };
const Path = ({ d, size = 21, width = 1.7 }: { d: string; size?: number; width?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={width} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d={d} />
  </svg>
);

/** Reading time of a topic: about 5 minutes a page, at least 5. */
const minutesOf = (t: PlacementTopic) => (t.pageFrom ? Math.max(5, ((t.pageTo ?? t.pageFrom) - t.pageFrom + 1) * 5) : 10);

export default function Placement() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const pdfId = params.get('pdf') ?? '';
  const courseId = params.get('course') ?? '';
  const lesson = useAsync(() => placementLesson(pdfId), [pdfId]);

  const [stage, setStage] = useState<Stage>('ask');
  const [sel, setSel] = useState<Record<string, boolean> | null>(null);
  const [quiz, setQuiz] = useState<PlacementQuiz | null>(null);
  const [topicIds, setTopicIds] = useState<string[] | null>(null);
  const [qi, setQi] = useState(0);
  const [answers, setAnswers] = useState<Record<string, Answer>>({});
  const [busy, setBusy] = useState(false);
  // The grading request: the plan waits for it, so the new topic states are in before the plan is made again.
  const grading = useRef<Promise<unknown> | null>(null);

  // A test left with "Sonra devam et" goes on from the same question.
  useEffect(() => {
    const kept = pdfId ? savedTest(pdfId) : null;
    if (!kept) return;
    placementQuiz(kept.quizId).then((q) => {
      if (!q) return keepTest(pdfId, null);
      setQuiz(q);
      setTopicIds(kept.topicIds);
      setAnswers(kept.answers);
      setQi(Math.min(kept.index, q.questions.length - 1));
      setStage('quiz');
    });
  }, [pdfId]);

  const topics = lesson?.topics ?? [];
  const picked = sel ?? Object.fromEntries(topics.map((x) => [x.id, true]));
  const pg = (x: PlacementTopic) =>
    !x.pageFrom ? '' : x.pageTo && x.pageTo !== x.pageFrom ? `${t('pageAbbr')} ${num(x.pageFrom, lang)}–${num(x.pageTo, lang)}` : `${t('pageAbbr')} ${num(x.pageFrom, lang)}`;
  const mins = (m: number) => (m >= 60 ? t('ptHM').replace('{h}', num(Math.floor(m / 60), lang)).replace('{m}', num(m % 60, lang)) : t('ptM').replace('{m}', num(m, lang)));
  const reader = (page?: number | null) => navigate(`/reader?course=${courseId}&pdf=${pdfId}${page ? `&page=${page}` : ''}`);

  const begin = async (ids: string[] | null) => {
    if (busy) return;
    setBusy(true);
    const q = await startPlacement(pdfId, ids ?? undefined);
    setBusy(false);
    if (q === 'none') {
      toast(t('ptNoQ'));
      return reader();
    }
    if (!q) return toast(t('ptFailed'));
    setQuiz(q);
    setTopicIds(ids);
    setAnswers({});
    setQi(0);
    setStage('quiz');
  };

  const questions = quiz?.questions ?? [];
  const cur = questions[qi];
  const answer = (v: Answer) => {
    if (!quiz || !cur) return;
    const next = { ...answers, [cur.id]: v };
    setAnswers(next);
    if (qi < questions.length - 1) return setQi(qi + 1);
    keepTest(pdfId, null);
    grading.current = saveAttempt(
      quiz.quizId,
      questions.map((q) => ({ questionId: q.id, chosen: next[q.id] === 'x' ? null : (next[q.id] as number), hints: 0, dontKnow: next[q.id] === 'x' })),
    );
    setStage('result');
    toast(t('ptDone'));
  };

  // The topic map: every topic of the lesson, from this test's answers (same rules as the server).
  const res = topics.map((x) => {
    const asked = questions.filter((q) => quiz?.topicOf[q.id] === x.id);
    const right = asked.filter((q) => answers[q.id] === q.answer).length;
    const st: Status = !asked.length ? 'todo' : right === asked.length ? 'know' : right === 0 ? 'new' : 'weak';
    const m = minutesOf(x);
    const act =
      st === 'know' ? t('ptActKnow') : st === 'weak' ? t('ptActWeak') : t(st === 'new' ? 'ptActNew' : 'ptActTodo').replace('{pg}', pg(x)).replace('{m}', num(m, lang));
    return { x, st, min: st === 'know' ? 0 : st === 'weak' ? 10 : m, act };
  });
  const cnt = (...k: Status[]) => res.filter((r) => k.includes(r.st)).length;
  const total = topics.reduce((a, x) => a + minutesOf(x), 0);
  const mine = res.reduce((a, r) => a + r.min, 0);

  const allN = questionCount(topics);
  const partN = questionCount(topics.filter((x) => picked[x.id]));
  const cl = quiz?.lang ?? lang;

  const back = () => (stage === 'ask' ? reader() : setStage('ask'));
  const later = () => {
    if (quiz) keepTest(pdfId, { quizId: quiz.quizId, topicIds, index: qi, answers });
    toast(t('ptSaved'));
    reader();
  };
  const updatePlan = async () => {
    if (busy) return;
    setBusy(true);
    await grading.current;
    await runPlanner('build');
    setBusy(false);
    toast(t('ptPlanned'));
    navigate('/plan');
  };
  const startRed = () => {
    const first = res.find((r) => r.st === 'new' || r.st === 'todo') ?? res.find((r) => r.st === 'weak') ?? res[0];
    if (first) toast(t('ptStartT').replace('{t}', first.x.title));
    reader(first?.x.pageFrom);
  };
  const again = () => {
    setStage('ask');
    setAnswers({});
    setQi(0);
    setQuiz(null);
  };

  const sub = lesson ? `${lesson.title} · ${t('ptFileSub').replace('{t}', num(topics.length, lang)).replace('{p}', num(lesson.pages, lang))}` : '';
  const opts = [
    { k: 'no', title: t('ptNoT'), sub: t('ptNoS'), tap: () => (toast(t('ptOpening')), reader()) },
    {
      k: 'yes',
      title: t('ptYesT'),
      sub: t('ptYesS').replace('{n}', num(allN, lang)).replace('{m}', num(Math.max(1, Math.ceil(allN * 0.6)), lang)),
      tap: () => begin(null),
    },
    { k: 'part', title: t('ptPartT'), sub: t('ptPartS'), tap: () => setStage('partial') },
  ] as const;

  return (
    <main className={s.main}>
      <div className={s.head}>
        <button className={s.round} aria-label={t('back')} onClick={back}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <span className={s.titles}>
          <h1>{t('ptTitle')}</h1>
          <span dir="auto">{sub}</span>
        </span>
        {stage === 'quiz' && (
          <button className={s.later} onClick={later}>
            {t('ptLater')}
          </button>
        )}
      </div>

      {stage === 'ask' && (
        <div className={s.body}>
          <section className={s.hero}>
            <span className={s.star} aria-hidden="true" />
            <h2>{t('ptAskT')}</h2>
            <span>{t('ptAskS')}</span>
          </section>
          {opts.map((o) => (
            <button key={o.k} className={o.k === 'yes' ? `${s.opt} ${s.optPri}` : s.opt} aria-busy={o.k === 'yes' && busy} onClick={o.tap}>
              <span className={s.optIcon}>
                <Path d={ICON[o.k]} />
              </span>
              <span className={s.optText}>
                <b>{o.title}</b>
                <span>{o.sub}</span>
              </span>
            </button>
          ))}
          <span className={s.note}>
            <Icon name="lock" size={14} width={1.8} />
            {t('ptPrivate')}
          </span>
        </div>
      )}

      {stage === 'partial' && (
        <>
          <div className={s.body}>
            <h2 className={s.h2}>{t('ptPickT')}</h2>
            <span className={s.lead}>{t('ptPickS')}</span>
            <div className={s.list}>
              {topics.map((x) => {
                const on = !!picked[x.id];
                return (
                  <button key={x.id} role="checkbox" aria-checked={on} className={s.topic} onClick={() => setSel({ ...picked, [x.id]: !on })}>
                    <span className={on ? `${s.box} ${s.boxOn}` : s.box}>{on && <Path d="M5 12l5 5 9-10" size={15} width={3} />}</span>
                    <span className={s.topicT} dir="auto">
                      {x.title}
                    </span>
                    <span className="mono">{pg(x)}</span>
                  </button>
                );
              })}
            </div>
          </div>
          <div className={s.foot}>
            <button
              className={s.pri}
              aria-busy={busy}
              onClick={() => {
                const ids = topics.filter((x) => picked[x.id]).map((x) => x.id);
                if (!ids.length) return toast(t('ptPickOne'));
                begin(ids);
              }}
            >
              {t('ptPickGo').replace('{n}', num(partN, lang))}
            </button>
          </div>
        </>
      )}

      {stage === 'quiz' && cur && (
        <div className={s.body}>
          <div className={s.progress}>
            <div className="mono">
              <span>{t('ptQ').replace('{i}', num(qi + 1, lang)).replace('{n}', num(questions.length, lang))}</span>
              <span>{t('ptLeft').replace('{m}', num(Math.max(1, Math.ceil((questions.length - qi) * 0.6)), lang))}</span>
            </div>
            <span className={s.track}>
              <span style={{ width: `${Math.round((qi / questions.length) * 100)}%` }} />
            </span>
          </div>
          <span className={s.qTopic} dir={dirOf(cl)}>
            {[cur.topic, cur.page ? `${t('pageAbbr')} ${num(cur.page, lang)}` : ''].filter(Boolean).join(' · ')}
          </span>
          <h2 className={s.qText} dir={dirOf(cl)}>
            {cur.text}
          </h2>
          {cur.options.map((o, i) => (
            <button key={`${cur.id}-${i}`} className={s.qOpt} dir={dirOf(cl)} onClick={() => answer(i)}>
              {LETTERS[i]}) {o}
            </button>
          ))}
          <button className={s.idk} onClick={() => answer('x')}>
            {t('ptIdk')}
          </button>
          <span className={s.hint}>{t('ptDontGuess')}</span>
        </div>
      )}

      {stage === 'result' && (
        <>
          <div className={s.body}>
            <section className={s.hero}>
              <span className={s.mapLabel}>{t('ptMap')}</span>
              <div className={s.counts}>
                <span>
                  <b className={s.good}>{num(cnt('know'), lang)}</b>
                  <span>{t('ptKnowL')}</span>
                </span>
                <span>
                  <b className={s.amb}>{num(cnt('weak'), lang)}</b>
                  <span>{t('ptWeakL')}</span>
                </span>
                <span>
                  <b className={s.bad}>{num(cnt('new', 'todo'), lang)}</b>
                  <span>{t('ptTodoL')}</span>
                </span>
              </div>
              <span className={s.time}>{t('ptTime').replace('{a}', mins(total)).replace('{b}', mins(mine))}</span>
            </section>
            {res.map((r) => (
              <div key={r.x.id} className={`${s.res} ${s[`st_${r.st}`]}`}>
                <span className={s.mark}>
                  <Path d={MARK[r.st]} size={17} width={2.4} />
                </span>
                <span className={s.resText}>
                  <span>
                    <b dir="auto">{r.x.title}</b>
                    <span className={s.stLabel}>{t(r.st === 'know' ? 'ptStKnow' : r.st === 'weak' ? 'ptStWeak' : r.st === 'new' ? 'ptStNew' : 'ptStTodo')}</span>
                  </span>
                  <span>{r.act}</span>
                </span>
              </div>
            ))}
            <span className={s.marked}>
              <Path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z M14 3v5h5" size={14} width={1.8} />
              {t('ptMarked')}
            </span>
            <button className={s.again} onClick={again}>
              {t('ptAgain')}
            </button>
          </div>
          <div className={s.foot}>
            <button className={s.pri} aria-busy={busy} onClick={updatePlan}>
              {t('ptPlan')}
            </button>
            <button className={s.sec} onClick={startRed}>
              {t('ptStart')}
            </button>
          </div>
        </>
      )}
    </main>
  );
}
