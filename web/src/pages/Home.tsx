import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { useToast } from '../components/Toast';
import TopBar from '../components/TopBar';
import Icon, { type IconName } from '../components/Icon';
import { COURSE_COLOR } from '../components/courseColors';
import type { CourseColor } from '../api/types';
import { useTrial } from '../trial/TrialProvider';
import s from './Home.module.css';

// Design: design/DeskApp.dc.html, screen "home" (web).

// "My Courses" cards on home: last opened PDFs (texts and numbers as in the design).
const RECENT: { course: string; pdf: string; title: string; courseKey: string; pct: number; level: string; color: CourseColor }[] = [
  { course: 'pharmacotherapy', pdf: 'hypertension', title: 'k77', courseKey: 'k53', pct: 62, level: 'k78', color: 'amb' },
  { course: 'pharmacotherapy', pdf: 'diabetes', title: 'k80', courseKey: 'k53', pct: 8, level: 'k81', color: 'red' },
  { course: 'pharm-tech-3', pdf: 'tablet-formulation', title: 'k82', courseKey: 'k55', pct: 96, level: 'k83', color: 'grn' },
];

const PLAN = [
  { time: '09:00', title: 'k85', sub: 'k86' },
  { time: '09:40', title: 'k87', sub: 'k88' },
  { time: '18:00', title: 'k89', sub: 'k90' },
];

export default function Home() {
  const { t } = useI18n();
  const toast = useToast();
  const { guard } = useTrial();
  const navigate = useNavigate();
  const upload = () => guard('pdf', () => toast(t('k165')));
  const [showReview, setShowReview] = useState(true);
  const [done, setDone] = useState<boolean[]>([true, false, false]);
  const [ask, setAsk] = useState('');

  const uploads: [IconName, string, boolean][] = [
    ['upload', 'k33', true],
    ['camera', 'k69', false],
    ['mic', 'k70', false],
    ['help', 'k71', false],
  ];
  const tools: [IconName, string, string, string, string][] = [
    ['list', 'k72', 'var(--pri-soft)', 'var(--pri-t)', '/quiz'],
    ['cards', 'k73', 'var(--amb-soft)', 'var(--amb-t)', '/cards'],
    ['book', 'k74', 'var(--good-soft)', 'var(--good)', '/reader'],
  ];

  const sendAsk = (e: FormEvent) => {
    e.preventDefault();
    if (ask.trim()) return guard('question', () => navigate(`/assistant?q=${encodeURIComponent(ask.trim())}`));
    navigate(ask.trim() ? `/assistant?q=${encodeURIComponent(ask.trim())}` : '/assistant');
  };

  return (
    <main className={s.main}>
      <div className={s.left}>
        <div className={s.head}>
          <TopBar />
          <h1 className={s.hello}>
            <span>{t('k63')}</span> {t('k64')}
          </h1>
        </div>

        {showReview && (
          <section className={s.review}>
            <span className={s.reviewIcon}>
              <Icon name="refresh" size={26} />
            </span>
            <span className={s.reviewText}>
              <b>{t('k65')}</b>
              <span>{t('k66')}</span>
            </span>
            <span className={s.reviewBtns}>
              <button className={s.reviewGo} onClick={() => navigate('/cards')}>
                <Icon name="play" size={15} />
                {t('k67')}
              </button>
              <button className={s.reviewLater} onClick={() => setShowReview(false)}>
                {t('k68')}
              </button>
            </span>
          </section>
        )}

        <div className={s.uploads}>
          {uploads.map(([icon, key, primary]) => (
            <button key={key} className={primary ? `${s.upload} ${s.uploadPri}` : s.upload} onClick={upload}>
              <Icon name={icon} size={20} />
              {t(key)}
            </button>
          ))}
        </div>

        <div className={s.tools}>
          {tools.map(([icon, key, bg, fg, to]) => (
            <Link key={key} to={to} className={s.tool}>
              <span className={s.toolIcon} style={{ background: bg, color: fg }}>
                <Icon name={icon} size={19} />
              </span>
              {t(key)}
              <Icon name="chevron" size={16} className={`flip-rtl ${s.chev}`} />
            </Link>
          ))}
        </div>

        <div className={s.coursesHead}>
          <h2>{t('k48')}</h2>
          <span className={s.count}>{t('k75')}</span>
          <Link to="/courses" className={s.folderLink}>
            {t('k76')}
          </Link>
        </div>
        <div className={s.recent}>
          {RECENT.map((r) => {
            const col = COURSE_COLOR[r.color];
            return (
              <Link key={r.pdf} to={`/reader?course=${r.course}&pdf=${r.pdf}`} className={s.pdfCard}>
                <span className={`mono ${s.pdfBadge}`} style={{ background: col.soft, color: col.fg }}>
                  PDF
                </span>
                <b>{t(r.title)}</b>
                <span className={s.pdfCourse}>{t(r.courseKey)}</span>
                <span className={s.bar}>
                  <span style={{ width: `${r.pct}%`, background: col.main }} />
                </span>
                <span className={s.pdfFoot}>
                  <span className={s.level} style={{ background: col.soft, color: col.fg }}>
                    {t(r.level)}
                  </span>
                  <span className={`mono ${s.device}`}>{t('k79')}</span>
                </span>
              </Link>
            );
          })}
        </div>
      </div>

      <aside className={s.right}>
        <section className={s.panel}>
          <div className={s.panelHead}>
            <h2>{t('k84')}</h2>
            <span className={s.badge}>{PLAN.length}</span>
          </div>
          {PLAN.map((p, i) => (
            <div key={p.time} className={s.planRow}>
              <span className={`mono ${s.time}`}>{p.time}</span>
              <span className={s.planText}>
                <b>{t(p.title)}</b>
                <span>{t(p.sub)}</span>
              </span>
              <button
                role="checkbox"
                aria-checked={done[i]}
                aria-label={t(p.title)}
                className={done[i] ? `${s.check} ${s.checkOn}` : s.check}
                onClick={() => setDone(done.map((d, j) => (j === i ? !d : d)))}
              >
                {done[i] && <Icon name="check" size={13} width={2.4} />}
              </button>
            </div>
          ))}
          <Link to="/plan" className={s.countdown}>
            <b>7</b>
            {t('k91')}
          </Link>
        </section>

        <section className={`${s.panel} ${s.assistant}`}>
          <div className={s.asstHead}>
            <span className="star-btn" style={{ width: 36, height: 36 }} aria-hidden="true" />
            <span className={s.asstTitle}>
              <b>{t('k92')}</b>
              <span>{t('k93')}</span>
            </span>
          </div>
          <div className={s.bubble}>
            {t('k94')} <b>{t('k95')}</b>
            {t('k96')}
          </div>
          <div className={s.chips}>
            {['k97', 'k98', 'k99'].map((k) => (
              <button
                key={k}
                onClick={() =>
                  k === 'k97' ? guard('question', () => navigate(`/assistant?q=${encodeURIComponent(t(k))}`)) : guard('generate', () => navigate(k === 'k98' ? '/quiz' : '/cards'))
                }
              >
                {t(k)}
              </button>
            ))}
          </div>
          <span className={s.grow} />
          <form className={s.ask} onSubmit={sendAsk}>
            <input value={ask} onChange={(e) => setAsk(e.target.value)} placeholder={t('k100')} aria-label={t('k100')} />
            <button type="submit" aria-label={t('k100')}>
              <Icon name="send" size={16} className="flip-rtl" />
            </button>
          </form>
        </section>
      </aside>
    </main>
  );
}
