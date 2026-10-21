import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { num } from '../i18n/format';
import { useToast } from '../components/Toast';
import Icon from '../components/Icon';
import MolViewer from '../components/MolViewer';
import { addWrongsToPlan, getExamPack, setStudyReminder } from '../api/quiz';
import { listCourses } from '../api/courses';
import { useAsync } from '../hooks/useAsync';
import { dirOf, useContentLang } from '../settings/SettingsProvider';
import type { Lang } from '../i18n/I18nProvider';
import type { QuizQuestion } from '../api/types';
import s from './Quiz.module.css';

// Design: design/NewIPad.dc.html, screen "exam" ("Sınava özel"): summary by importance,
// questions in the lecturer's style with hints and confidence, then results with wrong answers.
// Summary, questions and explanations use the content language (CLAUDE.md); labels use the app language.

type Tab = 'sum' | 'quiz' | 'res';
type Confidence = 'sure' | 'unsure' | 'guess';
type Find = { mode: 'choose' | 'find' | 'show' | 'solved'; hints: number; bad: number };

const LETTERS = ['A', 'B', 'C', 'D', 'E'];
const TIMES = ['08:00', '09:00', '14:00', '19:00', '21:00'];
// Questions used for the 2-question section check started from the reader (as in the design).
const SECTION_CHECK = [1, 2];
// Courses shown as chips; only the first has its exam pack ready in the design.
const EXAM_COURSES = ['pharmacotherapy', 'toxicology', 'pharm-tech-3'];

export default function Quiz() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const fromReader = params.get('from') === 'reader';
  const pack = useAsync(() => getExamPack('pharmacotherapy'), []);
  const courses = useAsync(listCourses, []);
  const cl = useContentLang(courses?.find((c) => c.id === 'pharmacotherapy'));
  const cdir = dirOf(cl);

  const [tab, setTab] = useState<Tab>(params.get('tab') === 'quiz' || fromReader ? 'quiz' : 'sum');
  const [topic, setTopic] = useState(0);
  const [list, setList] = useState<number[] | null>(fromReader ? SECTION_CHECK : null);
  const [qi, setQi] = useState(0);
  const [answers, setAnswers] = useState<Record<number, number>>({});
  const [conf, setConf] = useState<Record<number, Confidence>>({});
  const [hints, setHints] = useState<Record<number, number>>({});
  const [finds, setFinds] = useState<Record<number, Find>>({});
  const [time, setTime] = useState('09:00');

  if (!pack || !courses) return <main className={s.main} />;

  const qs = pack.questions;
  const qList = list ?? qs.map((_, i) => i);
  const qIdx = qList[Math.min(qi, qList.length - 1)];
  const Q = qs[qIdx];
  const sel = answers[qIdx];
  const nH = hints[qIdx] ?? 0;
  const wrongs = qList.filter((k) => answers[k] !== qs[k].answer);
  const hintedRight = qList.filter((k) => answers[k] === qs[k].answer && (hints[k] ?? 0) > 0).length;
  // Right = 1 point, right with a hint = half a point. Questions not in a retry list keep their point.
  const points = qList.reduce((a, k) => a + (answers[k] === qs[k].answer ? ((hints[k] ?? 0) > 0 ? 0.5 : 1) : 0), 0);
  const score = (fromReader ? points : points + qs.length - qList.length).toLocaleString(lang === 'tr' ? 'tr' : lang === 'fa' ? 'fa' : 'en');
  const total = fromReader ? qList.length : qs.length;

  const examCourse = courses.find((c) => c.id === 'pharmacotherapy');
  const courseName = (id: string) => {
    const c = courses.find((x) => x.id === id);
    return c ? (c.short ?? c.name)[lang] : id;
  };

  const startQuiz = (only?: number[]) => {
    const lst = only ?? qs.map((_, i) => i);
    const a2 = { ...answers };
    lst.forEach((k) => delete a2[k]);
    setAnswers(only ? a2 : {});
    if (!only) setConf({});
    setHints({});
    setFinds({});
    setList(lst);
    setQi(0);
    setTab('quiz');
  };
  const pickTab = (x: Tab) => {
    if (x === 'res' && Object.keys(answers).length === 0) {
      toast(t('solveFirst'));
      return;
    }
    setTab(x);
  };
  const nextQ = () => {
    if (sel === undefined) {
      toast(t('pickFirst'));
      return;
    }
    if (qi >= qList.length - 1) setTab('res');
    else setQi(qi + 1);
  };
  const addHint = () => {
    if (nH >= 3) {
      toast(t('allHints'));
      return;
    }
    setHints({ ...hints, [qIdx]: nH + 1 });
  };

  return (
    <main className={s.main}>
      <div className={s.head}>
        <button className={s.round} aria-label={t('back')} onClick={() => navigate(fromReader ? '/reader' : '/home')}>
          <Icon name="back" size={20} width={1.8} className="flip-rtl" />
        </button>
        <span className={s.titleBox}>
          <h1>
            {t('examA')} <span>{t('examB')}</span>
          </h1>
          <span className={s.sub}>{(examCourse?.name[lang] ?? '') + t('subSuffix')}</span>
          <span className={s.styleBadge}>
            <Icon name="spark" size={11} width={2} />
            {t('teacherStyle')}
          </span>
        </span>
        <div role="radiogroup" className={s.courses}>
          {EXAM_COURSES.map((id, i) => (
            <button
              key={id}
              role="radio"
              aria-checked={i === 0}
              className={i === 0 ? `${s.courseChip} ${s.courseOn}` : s.courseChip}
              onClick={() => i > 0 && toast(courseName(id) + t('pkgA') + t(i === 1 ? 'd21' : 'd23') + t('pkgB'))}
            >
              {courseName(id)}
            </button>
          ))}
        </div>
      </div>

      <div role="tablist" className={s.tabs}>
        {(
          [
            ['sum', 'tabSum'],
            ['quiz', 'tabQuiz'],
            ['res', 'tabRes'],
          ] as const
        ).map(([id, key]) => (
          <button key={id} role="tab" aria-selected={tab === id} className={tab === id ? s.tabOn : ''} onClick={() => pickTab(id)}>
            {t(key)}
          </button>
        ))}
      </div>

      {tab === 'sum' && (
        <div className={s.sumGrid}>
          <section className={s.panel}>
            <span className={`mono ${s.label}`}>{t('byImportance')}</span>
            {pack.topics.map((x, i) => (
              <button key={i} aria-current={i === topic} className={i === topic ? `${s.topic} ${s.topicOn}` : s.topic} onClick={() => setTopic(i)}>
                <span className={`${s.topicNo} ${s[x.kind]}`}>{num(i + 1, lang)}</span>
                <span className={s.topicText}>
                  <b lang={cl} dir={cdir}>
                    {x.title[cl]}
                  </b>
                  <span className={s[`${x.kind}Fg`]}>{x.tag[lang]}</span>
                </span>
              </button>
            ))}
          </section>
          <section className={s.paper}>
            <div className={s.paperTop}>
              <span className="mono">
                {t('summaryPrefix')} {pack.topics[topic].src[cl]}
              </span>
              <span className={`${s.tag} ${s[pack.topics[topic].kind]}`}>{pack.topics[topic].tag[lang]}</span>
            </div>
            <h2 lang={cl} dir={cdir}>
              {pack.topics[topic].title[cl]}
            </h2>
            {pack.topics[topic].points.map((p, i) => (
              <p key={i} className={s.point} lang={cl} dir={cdir}>
                <span>•</span>
                <span>{p[cl]}</span>
              </p>
            ))}
            {pack.topics[topic].teacher && (
              <span className={s.teacher} lang={cl} dir={cdir}>
                <span>
                  <Icon name="mic" size={14} />
                </span>
                {pack.topics[topic].teacher![cl]}
              </span>
            )}
            {pack.topics[topic].molecule && (
              <div className={s.mol}>
                <span className={`mono ${s.label}`}>{t('molLabel')}</span>
                <MolViewer size="full" mark="thiol" contentLang={cl} />
              </div>
            )}
            <div className={s.actions}>
              <button className={s.ghost} onClick={() => setTopic((topic + 1) % pack.topics.length)}>
                {topic < pack.topics.length - 1 ? t('nextTopic') + pack.topics[topic + 1].title[cl] : t('readAgain')}
              </button>
              <button className={s.pri} onClick={() => startQuiz()}>
                {t('startQuiz')}
              </button>
            </div>
          </section>
        </div>
      )}

      {tab === 'quiz' && (
        <section className={s.qCard}>
          <div className={s.qTop}>
            <span className={s.qNo}>
              {t('questionWord')} {num(qi + 1, lang)} / {num(qList.length, lang)}
            </span>
            <span className={`${s.tag} ${s.weak}`}>{Q.kind[lang]}</span>
            <span className={`${s.tag} ${s.imp}`}>{t('inStyle')}</span>
            <span className={s.grow} />
            <span className={s.progress} aria-hidden="true">
              <span style={{ width: `${Math.round(((qi + 1) / qList.length) * 100)}%` }} />
            </span>
          </div>
          <p className={s.qText} lang={cl} dir={cdir}>
            {Q.text[cl]}
          </p>
          {Q.molecule && <MolViewer size="mini" mark="thiol" contentLang={cl} />}
          <div role="radiogroup" className={s.options} lang={cl} dir={cdir}>
            {Q.options.map((o, i) => (
              <button
                key={i}
                role="radio"
                aria-checked={sel === i}
                className={sel === i ? `${s.option} ${s.optionOn}` : s.option}
                onClick={() => setAnswers({ ...answers, [qIdx]: i })}
              >
                <span className={s.letter}>{LETTERS[i]}</span>
                {o[cl]}
              </button>
            ))}
          </div>
          <div className={s.hints} lang={cl} dir={cdir}>
            {Q.hints.slice(0, nH).map((h, i) => (
              <div key={i} className={s.hint}>
                <span className="mono">
                  {t('hintTag')}
                  {i + 1} / 3
                </span>
                <span>{h[cl]}</span>
              </div>
            ))}
            <button className={nH > 0 ? s.hintBtn : `${s.hintBtn} ${s.hintBtnFirst}`} onClick={addHint}>
              <Icon name="bulb" size={16} />
              {nH === 0 ? t('hintFirst') : nH < 3 ? `${t('hintMore')}${nH}/3)` : t('hintsDone')}
            </button>
          </div>
          <div className={s.qFoot}>
            <span className={s.label2}>{t('howSure')}</span>
            {(['sure', 'unsure', 'guess'] as const).map((c) => (
              <button key={c} aria-pressed={conf[qIdx] === c} className={conf[qIdx] === c ? `${s.conf} ${s.confOn}` : s.conf} onClick={() => setConf({ ...conf, [qIdx]: c })}>
                {t(c)}
              </button>
            ))}
            <span className={s.grow} />
            <button className={sel === undefined ? `${s.next} ${s.nextOff}` : s.next} aria-disabled={sel === undefined} onClick={nextQ}>
              {qi >= qList.length - 1 ? t('finish') : t('nextQ')}
            </button>
          </div>
        </section>
      )}

      {tab === 'res' && (
        <div className={s.resGrid}>
          <section className={s.scoreCard}>
            <span className={`mono ${s.resTitle}`}>{t(fromReader ? 'resSection' : 'resExam')}</span>
            <span className={s.score}>
              {score}
              <span>
                {' '}
                / {num(total, lang)}
              </span>
            </span>
            <span className={s.scoreMsg}>
              {(wrongs.length === 0 ? t('allGood') : num(wrongs.length, lang) + t('wrongsA')) + (hintedRight ? ' ' + num(hintedRight, lang) + t('hintedA') : '')}
            </span>
            <button className={s.cont} onClick={() => (navigate('/reader'), !fromReader && toast(t('continueToast')))}>
              {t(fromReader ? 'continueNext' : 'continueLesson')}
              <Icon name="send" size={16} className="flip-rtl" />
            </button>
            <button className={s.heroGhost} onClick={() => startQuiz(wrongs.length ? wrongs : undefined)}>
              {wrongs.length
                ? t('retryA') + num(wrongs.length, lang) + t(wrongs.length === 1 ? 'retryB1' : 'retryB')
                : t('newA') + num(qs.length, lang) + t('retryB')}
            </button>
            <button className={s.heroGhost} onClick={() => addWrongsToPlan(wrongs).then(() => toast(t('addedPlan')))}>
              {t('addPlan')}
            </button>
            <span className={s.timeLabel}>{t('whatTime')}</span>
            <div className={s.times}>
              {TIMES.map((x) => (
                <button
                  key={x}
                  aria-pressed={time === x}
                  className={time === x ? s.timeOn : ''}
                  onClick={() => {
                    setTime(x);
                    setStudyReminder(x).then(() => toast(t('tomorrowA') + x + t('tomorrowB')));
                  }}
                >
                  {x}
                </button>
              ))}
            </div>
            <span className={s.timeNote}>{String(parseInt(time, 10) - 1).padStart(2, '0') + t('noteA') + time + t('noteB')}</span>
          </section>

          <section className={s.panel}>
            <h2 className={s.wrongTitle}>{wrongs.length ? t('wrongTitle') : t('noWrong')}</h2>
            {wrongs.length === 0 && <p className={s.muted}>{t('allRightText')}</p>}
            {wrongs.map((k) => (
              <Wrong
                key={k}
                q={qs[k]}
                cl={cl}
                your={answers[k]}
                sure={conf[k] === 'sure'}
                find={finds[k] ?? { mode: 'choose', hints: 1, bad: -1 }}
                setFind={(v) => setFinds({ ...finds, [k]: v })}
              />
            ))}
          </section>
        </div>
      )}
    </main>
  );
}

function Wrong({
  q,
  cl,
  your,
  sure,
  find,
  setFind,
}: {
  q: QuizQuestion;
  cl: Lang;
  your?: number;
  sure: boolean;
  find: Find;
  setFind: (f: Find) => void;
}) {
  const { t } = useI18n();
  const reveal = find.mode === 'show' || find.mode === 'solved';
  const opt = (i: number) => `${LETTERS[i]}) ${q.options[i][cl]}`;

  return (
    <div className={s.wrong}>
      <span className={s.wrongQ} lang={cl} dir={dirOf(cl)}>
        {q.text[cl]}
      </span>
      <div className={s.wrongTags}>
        <span className={s.bad}>
          {t('yourAnswer')} {your === undefined ? t('emptyAns') : opt(your)}
        </span>
        {reveal && (
          <span className={s.good}>
            {t('correct')} {opt(q.answer)}
          </span>
        )}
        {sure && <span className={s.warn}>{t('wasSure')}</span>}
      </div>

      {find.mode === 'choose' && (
        <div className={s.wrongActs}>
          <button className={s.ghost} onClick={() => setFind({ mode: 'find', hints: 1, bad: -1 })}>
            <Icon name="bulb" size={15} />
            {t('findMyself')}
          </button>
          <button className={s.ghost} onClick={() => setFind({ mode: 'show', hints: 1, bad: -1 })}>
            {t('showAnswer')}
          </button>
        </div>
      )}

      {find.mode === 'find' && (
        <div className={s.findBox} lang={cl} dir={dirOf(cl)}>
          {q.hints.slice(0, find.hints).map((h, i) => (
            <div key={i} className={s.hint}>
              <span className="mono">
                {t('hintTag')}
                {i + 1} / 3
              </span>
              <span>{h[cl]}</span>
            </div>
          ))}
          <span className={s.muted}>{find.bad >= 0 ? t('notQuite') + (find.hints < 3 ? t('oneMoreHint') : t('orShow')) : t('readHint')}</span>
          {q.options.map((_, i) => (
            <button
              key={i}
              className={find.bad === i ? `${s.findOpt} ${s.findBad}` : s.findOpt}
              onClick={() => setFind(i === q.answer ? { ...find, mode: 'solved', bad: -1 } : { ...find, bad: i })}
            >
              {opt(i)}
            </button>
          ))}
          <button
            className={s.ghost}
            onClick={() => setFind(find.hints < 3 ? { mode: 'find', hints: find.hints + 1, bad: -1 } : { ...find, mode: 'show', bad: -1 })}
          >
            {find.hints < 3 ? t('moreHintBtn') : t('showAnswerBtn')}
          </button>
        </div>
      )}

      {reveal && (
        <>
          {find.mode === 'solved' && <span className={s.solved}>{t('solvedSelf')}</span>}
          <span className={s.whyText}>
            <b>{t('why')}</b> {q.why[cl]}
          </span>
          <span className={`mono ${s.src}`}>
            {t('sourcePrefix')} {q.src[cl]}
          </span>
        </>
      )}
    </div>
  );
}
