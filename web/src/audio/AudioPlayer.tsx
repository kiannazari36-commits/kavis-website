import { useI18n } from '../i18n/I18nProvider';
import { num, percent } from '../i18n/format';
import Icon from '../components/Icon';
import { useAudioLesson } from './AudioLesson';
import { SPEEDS, type ChapterTag } from './chapters';
import s from './AudioPlayer.module.css';

// Design: design/NewIPad.dc.html "Sesli anlatım": the big card on the assistant screen and the small player at the
// bottom left of every other page.

const PLAY = 'M8 5v14l11-7z';
const PAUSE = 'M7 5h3.5v14H7z M13.5 5H17v14h-3.5z';

function useLabels() {
  const { t, lang } = useI18n();
  const a = useAudioLesson();
  const fmt = (x: number) => `${Math.floor(x / 60)}:${String(Math.floor(x % 60)).padStart(2, '0')}`;
  const tag = (g: ChapterTag) =>
    g.k === 'weak'
      ? g.n != null
        ? t('auTagWeak').replace('{p}', percent(g.n, lang))
        : t('auTagWeakNo')
      : g.k === 'minutes' || g.k === 'repeats'
        ? t(g.k === 'minutes' ? 'auTagMin' : 'auTagRep').replace('{n}', num(g.n, lang))
        : t({ exam: 'auTagExam', important: 'auTagImp', summary: 'auTagSum' }[g.k]);
  const pages = (a: number, b: number) => `${t('pageAbbr')} ${num(a, lang)}${b !== a ? `–${num(b, lang)}` : ''}`;
  return { t, lang, a, fmt, tag, pages, pct: a.total ? Math.min(100, Math.round((a.elapsed / a.total) * 100)) : 0 };
}

export function AudioCard() {
  const { t, lang, a, fmt, tag, pages, pct } = useLabels();
  if (!a.lesson) return null;
  const ch = a.lesson.chapters;
  const cur = ch[a.idx];
  const min = Math.max(1, Math.round(a.total / 60));
  const sp = SPEEDS[a.speed];
  const speedLabel = num((sp === 1 ? '1.0' : String(sp)).replace('.', lang === 'en' ? '.' : ','), lang);
  return (
    <section className={s.card} aria-label={t('auName')}>
      <div className={s.head}>
        <span className={a.playing ? `${s.star} ${s.ring}` : s.star} aria-hidden="true" />
        <span className={s.headText}>
          <span className={`mono ${s.kicker}`}>
            {t('auKicker')} · {a.lesson.title.toLocaleUpperCase(lang)}
          </span>
          <b>{t('auHead')}</b>
          <span>{t('auSub').replace('{n}', num(ch.length, lang)).replace('{min}', num(min, lang))}</span>
        </span>
        <button className={s.ghost} aria-label={t('auClose')} onClick={a.stop}>
          <Icon name="close" size={16} />
        </button>
      </div>
      <div className={s.parts} style={{ gridTemplateColumns: `repeat(${ch.length}, minmax(0, 1fr))` }}>
        {ch.map((c, i) => (
          <button key={i} aria-current={i === a.idx ? 'step' : undefined} className={i === a.idx ? s.partOn : i < a.idx ? s.partDone : ''} onClick={() => a.pick(i)}>
            <span>{c.title || pages(c.pageFrom, c.pageTo)}</span>
            <small className={c.tag.k === 'weak' ? s.tagWeak : s.tagImp}>{tag(c.tag)}</small>
          </button>
        ))}
      </div>
      <p className={s.caption} lang={a.lesson.lang} dir={a.lesson.lang === 'fa' || a.lesson.lang === 'ar' ? 'rtl' : 'ltr'}>
        {cur?.sentences.join(' ')}
      </p>
      <div className={s.track}>
        <span className="mono">{fmt(a.elapsed)}</span>
        <span className={s.bar}>
          <span style={{ width: `${pct}%` }} />
        </span>
        <span className="mono">{fmt(a.total)}</span>
      </div>
      <div className={s.controls}>
        <button className={s.side} aria-label={t('auPrev')} onClick={a.prev}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" className="flip-rtl">
            <path d="M6 5h2v14H6z M20 5v14L9 12z" />
          </svg>
        </button>
        <button className={s.play} aria-label={t(a.playing ? 'auPause' : 'auResume')} onClick={a.toggle}>
          <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d={a.playing ? PAUSE : PLAY} />
          </svg>
        </button>
        <button className={s.side} aria-label={t('auNext')} onClick={a.next}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" className="flip-rtl">
            <path d="M16 5h2v14h-2z M4 5v14l11-7z" />
          </svg>
        </button>
        <button className={s.speed} aria-label={t('auSpeed')} onClick={a.cycleSpeed}>
          {speedLabel}×
        </button>
      </div>
      <div className={s.note}>
        <Icon name="headphones" size={18} />
        <span>
          {t('auKeepA')} <b>{t('auKeepB')}</b>
          {t('auKeepC')}
        </span>
      </div>
    </section>
  );
}

/** The small player on the other pages; tapping it goes back to the assistant. */
export function AudioMini({ onOpen, className }: { onOpen: () => void; className?: string }) {
  const { t, a, fmt, pct } = useLabels();
  if (!a.lesson) return null;
  const cur = a.lesson.chapters[a.idx];
  return (
    <div role="region" aria-label={t('auRegion')} className={`${s.mini} ${className ?? ''}`}>
      <button className={s.miniStar} aria-label={t('auOpen')} onClick={onOpen} />
      <button className={s.miniText} onClick={onOpen}>
        <span className="mono">
          {t(a.playing ? 'auPlaying' : 'auPaused')} · {fmt(a.elapsed)}
        </span>
        <b>
          {a.idx + 1}/{a.lesson.chapters.length} · {cur?.title || a.lesson.title}
        </b>
        <span className={s.miniBar}>
          <span style={{ width: `${pct}%` }} />
        </span>
      </button>
      <button className={s.miniPlay} aria-label={t(a.playing ? 'auPause' : 'auResume')} onClick={a.toggle}>
        <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          <path d={a.playing ? PAUSE : PLAY} />
        </svg>
      </button>
      <button className={s.miniClose} aria-label={t('auClose')} onClick={a.stop}>
        <Icon name="close" size={14} />
      </button>
    </div>
  );
}
