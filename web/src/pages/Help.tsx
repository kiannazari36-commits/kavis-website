import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useI18n } from '../i18n/I18nProvider';
import { SUPPORT_EMAIL, SUPPORT_REPLY_HOURS } from '../config';
import { askHelp, type HelpTurn } from '../api/help';
import Icon from '../components/Icon';
import Thinking from '../components/Thinking';
import s from './Help.module.css';

// AI help chat (decided 27 Oct 2026): Claude Haiku answers from a short public help text. The chat lives only in this
// page's memory (nothing is saved). When the AI cannot help, or any time, the student can e-mail us.
type Msg = HelpTurn & { error?: boolean };

export default function Help() {
  const { t, lang } = useI18n();
  const [msgs, setMsgs] = useState<Msg[]>([]);
  const [draft, setDraft] = useState('');
  const [busy, setBusy] = useState(false);
  const [escalate, setEscalate] = useState(false);
  const end = useRef<HTMLDivElement>(null);

  useEffect(() => {
    end.current?.scrollIntoView({ block: 'end' });
  }, [msgs, busy]);

  const send = async (text: string) => {
    const q = text.trim();
    if (!q || busy) return;
    const next: Msg[] = [...msgs, { role: 'user', content: q }];
    setMsgs(next);
    setDraft('');
    setBusy(true);
    const res = await askHelp(next.filter((m) => !m.error), lang);
    setBusy(false);
    if ('error' in res) {
      setMsgs([...next, { role: 'assistant', content: t(res.error === 'limit' ? 'hpLimit' : 'hpError'), error: true }]);
      setEscalate(true);
      return;
    }
    setMsgs([...next, { role: 'assistant', content: res.answer || t('hpError') }]);
    if (res.escalate) setEscalate(true);
  };

  // The mail starts with the last thing the student typed.
  const lastQuestion = [...msgs].reverse().find((m) => m.role === 'user')?.content ?? '';
  const mailto = `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(t('hpMailSubject'))}&body=${encodeURIComponent(t('hpMailBody').replace('{q}', lastQuestion))}`;
  const reply = t('hpReply').replace('{h}', String(SUPPORT_REPLY_HOURS));

  return (
    <div className={s.main}>
      <header className={s.head}>
        <h1>{t('hpTitle')}</h1>
        <p>{t('hpSub')}</p>
      </header>

      <section className={s.chat} aria-live="polite">
        <div className={`${s.bubble} ${s.bot}`}>{t('hpHello')}</div>
        {msgs.map((m, i) => (
          <div key={i} className={`${s.bubble} ${m.role === 'user' ? s.me : s.bot}`}>
            {m.content}
          </div>
        ))}
        {busy && (
          <div className={`${s.bubble} ${s.bot}`}>
            <Thinking />
          </div>
        )}
        <div ref={end} />
      </section>

      {msgs.length === 0 && (
        <div className={s.quick}>
          {['hpQ1', 'hpQ2', 'hpQ3', 'hpQ4'].map((k) => (
            <button key={k} onClick={() => send(t(k))}>
              {t(k)}
            </button>
          ))}
        </div>
      )}

      <form
        className={s.composer}
        onSubmit={(e: FormEvent) => {
          e.preventDefault();
          send(draft);
        }}
      >
        <input value={draft} onChange={(e) => setDraft(e.target.value)} maxLength={600} placeholder={t('hpPlaceholder')} aria-label={t('hpPlaceholder')} />
        <button type="submit" className={s.sendBtn} aria-label={t('hpSend')} disabled={busy || !draft.trim()}>
          <Icon name="send" size={18} className="flip-rtl" />
        </button>
      </form>

      <section className={escalate ? `${s.mail} ${s.mailOn}` : s.mail}>
        {escalate && <b>{t('hpEmailAsk')}</b>}
        <div className={s.mailRow}>
          <a className={s.mailBtn} href={mailto}>
            <Icon name="mail" size={18} />
            {t('hpEmailBtn')}
          </a>
          <span>{reply}</span>
        </div>
      </section>

      <p className={s.note}>{t('hpNote')}</p>
    </div>
  );
}
