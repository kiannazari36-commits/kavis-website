import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import { useI18n, type Lang } from '../i18n/I18nProvider';
import { useToast } from '../components/Toast';
import { supabase } from '../api/supabase';
import { listCourses } from '../api/courses';
import { lessonRecap, lessonSummaryData } from '../api/summary';
import { canSpeak } from '../hooks/speak';
import { buildChapters, secondsOf, SPEEDS, type Chapter, type Topic } from './chapters';

// The "Sesli anlatım" player: keeps reading while the student moves to other pages (the mini player in the
// app shell), until closed. Free: the browser's own voice reads the lesson summary (made once per lesson by the
// server; a new one only when the weak topics changed, which uses one "generate" of the trial, never a question).

const VOICE_LANG: Record<string, string> = { tr: 'tr-TR', en: 'en-US', fa: 'fa-IR', ar: 'ar-SA' };

type Lesson = { title: string; lang: Lang; chapters: Chapter[] };
type Ctx = {
  lesson: Lesson | null;
  loading: boolean;
  playing: boolean;
  /** Current part and sentence. */
  idx: number;
  sent: number;
  speed: number;
  /** Seconds read so far and in all (estimated from the length of the text). */
  elapsed: number;
  total: number;
  /** Starts the lesson the student read last in this course (null = any course). */
  start: (courseId: string | null) => void;
  toggle: () => void;
  pick: (i: number) => void;
  prev: () => void;
  next: () => void;
  cycleSpeed: () => void;
  stop: () => void;
};

const AudioLessonContext = createContext<Ctx | null>(null);

export function AudioLessonProvider({ children }: { children: ReactNode }) {
  const { t, lang: appLang } = useI18n();
  const toast = useToast();
  const [lesson, setLesson] = useState<Lesson | null>(null);
  const [loading, setLoading] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [pos, setPos] = useState({ idx: 0, sent: 0 });
  const [speed, setSpeed] = useState(0);
  // Each new read gets a number, so the end of an utterance that was cancelled does nothing.
  const run = useRef(0);

  const say = useCallback(
    (l: Lesson, idx: number, sent: number, spd: number) => {
      const synth = window.speechSynthesis;
      const id = ++run.current;
      synth.cancel();
      const ch = l.chapters[idx];
      if (!ch) return;
      const voice = synth.getVoices().find((v) => v.lang.toLowerCase().startsWith(l.lang));
      ch.sentences.slice(sent).forEach((text, i) => {
        const u = new SpeechSynthesisUtterance(text);
        u.lang = VOICE_LANG[l.lang] ?? l.lang;
        if (voice) u.voice = voice;
        u.rate = 0.95 * SPEEDS[spd];
        u.onstart = () => run.current === id && setPos({ idx, sent: sent + i });
        if (sent + i === ch.sentences.length - 1)
          u.onend = () => {
            if (run.current !== id) return;
            if (idx + 1 < l.chapters.length) {
              setPos({ idx: idx + 1, sent: 0 });
              say(l, idx + 1, 0, spd);
            } else {
              setPlaying(false);
              setPos({ idx, sent: ch.sentences.length });
              toast(t('auDone').replace('{n}', String(l.chapters.length)));
            }
          };
        synth.speak(u);
      });
    },
    [t, toast],
  );

  const halt = () => {
    run.current++;
    if (canSpeak()) window.speechSynthesis.cancel();
  };

  // Stop reading when the page closes.
  useEffect(() => halt, []);

  const start = useCallback(
    async (courseId: string | null) => {
      if (!canSpeak()) return toast(t('auNoVoice'));
      const courses = await listCourses();
      const pdfs = courses.filter((c) => !courseId || c.id === courseId).flatMap((c) => c.pdfs);
      const pdf = [...pdfs].sort((a, b) => (b.lastRead ?? '').localeCompare(a.lastRead ?? ''))[0];
      if (!pdf) return toast(t('auNoLesson'));
      halt();
      setLoading(true);
      toast(t('auPreparing'));
      const [recap, data, topics] = await Promise.all([
        lessonRecap(pdf.id),
        lessonSummaryData(pdf.id, appLang),
        supabase
          .from('material_topics')
          .select('id, title, page_from, page_to, importance, teacher_minutes, teacher_repeats, teacher_said_exam')
          .eq('material_id', pdf.id)
          .order('sort_order')
          .returns<Topic[]>(),
      ]);
      setLoading(false);
      if ('error' in recap) return toast(t(recap.error === 'locked' ? 'trialLocked' : recap.error === 'budget' ? 'askBudget' : 'auFailed'));
      const chapters = buildChapters(recap.points, topics.data ?? [], data.weak);
      if (!chapters.length) return toast(t('auFailed'));
      const l = { title: pdf.title, lang: recap.lang, chapters };
      setLesson(l);
      setPos({ idx: 0, sent: 0 });
      setPlaying(true);
      say(l, 0, 0, speed);
      const min = Math.max(1, Math.round(secondsOf(chapters.flatMap((c) => c.sentences).join(' ').length) / 60));
      toast(t('auStarted').replace('{n}', String(chapters.length)).replace('{min}', String(min)));
    },
    [appLang, say, speed, t, toast],
  );

  const goTo = (idx: number, sent = 0) => {
    if (!lesson) return;
    setPos({ idx, sent });
    setPlaying(true);
    say(lesson, idx, sent, speed);
  };

  const chars = (l: Lesson | null) => (l ? l.chapters.map((c) => c.sentences.reduce((n, s) => n + s.length + 1, 0)) : []);
  const per = chars(lesson);
  const doneChars = per.slice(0, pos.idx).reduce((a, b) => a + b, 0) + (lesson?.chapters[pos.idx]?.sentences.slice(0, pos.sent).reduce((n, s) => n + s.length + 1, 0) ?? 0);

  const value: Ctx = {
    lesson,
    loading,
    playing,
    idx: pos.idx,
    sent: pos.sent,
    speed,
    elapsed: secondsOf(doneChars),
    total: secondsOf(per.reduce((a, b) => a + b, 0)),
    start,
    toggle: () => {
      if (!lesson) return;
      if (playing) {
        halt();
        setPlaying(false);
      } else if (pos.idx >= lesson.chapters.length - 1 && pos.sent >= lesson.chapters[pos.idx].sentences.length) goTo(0);
      else goTo(pos.idx, pos.sent);
    },
    pick: (i) => goTo(i),
    // Back to the start of this part, or the part before when this one has just begun.
    prev: () => goTo(Math.max(0, pos.sent < 2 ? pos.idx - 1 : pos.idx)),
    next: () => {
      if (!lesson) return;
      if (pos.idx + 1 < lesson.chapters.length) goTo(pos.idx + 1);
      else {
        halt();
        setPlaying(false);
        setPos({ idx: pos.idx, sent: lesson.chapters[pos.idx].sentences.length });
        toast(t('auDone').replace('{n}', String(lesson.chapters.length)));
      }
    },
    cycleSpeed: () => {
      const s = (speed + 1) % SPEEDS.length;
      setSpeed(s);
      if (lesson && playing) say(lesson, pos.idx, pos.sent, s);
    },
    stop: () => {
      halt();
      setLesson(null);
      setPlaying(false);
      toast(t('auStopped'));
    },
  };

  return <AudioLessonContext.Provider value={value}>{children}</AudioLessonContext.Provider>;
}

export function useAudioLesson() {
  const ctx = useContext(AudioLessonContext);
  if (!ctx) throw new Error('useAudioLesson must be used inside AudioLessonProvider');
  return ctx;
}
