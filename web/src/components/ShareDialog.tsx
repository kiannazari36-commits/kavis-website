import { useState } from 'react';
import { useI18n } from '../i18n/I18nProvider';
import { useToast } from './Toast';
import Icon, { type IconName } from './Icon';
import { createShareLink, type ShareItem } from '../api/share';
import s from './ShareDialog.module.css';

// Design: design/NewIPad.dc.html share sheet ("sh"). CLAUDE.md: Premium only, and only what the
// app made (summary, cards, quiz) — the PDF option of the design is removed: the PDF belongs to the teacher.
const ITEMS: [ShareItem, string, string][] = [
  ['summary', 'shareSum', 'shareSumS'],
  ['cards', 'shareCards', 'shareCardsS'],
  ['quiz', 'shareQuiz', 'shareQuizS'],
];

export default function ShareDialog({ pdfId, onClose }: { pdfId: string; onClose: () => void }) {
  const { t } = useI18n();
  const toast = useToast();
  const [sel, setSel] = useState<ShareItem[]>(['summary']);
  const [url, setUrl] = useState('');

  const link = async () => {
    if (!sel.length) {
      toast(t('sharePickFirst'));
      return null;
    }
    const u = await createShareLink(pdfId, sel);
    if (!u) {
      toast(t('shareFailed'));
      return null;
    }
    setUrl(u);
    return u;
  };
  const ways: [string, IconName, () => Promise<void>][] = [
    [
      'shareCopy',
      'send',
      async () => {
        const url = await link();
        if (!url) return;
        // The link is also shown below, in case the browser does not allow copying.
        const ok = await navigator.clipboard?.writeText(url).then(
          () => true,
          () => false,
        );
        if (ok) toast(t('shareCopied'));
      },
    ],
    [
      'shareMsg',
      'mail',
      async () => {
        const url = await link();
        if (url) window.location.href = `sms:?&body=${encodeURIComponent(url)}`;
      },
    ],
    [
      'shareOther',
      'share',
      async () => {
        const url = await link();
        if (!url) return;
        if (navigator.share) await navigator.share({ title: 'Kavis Study', url }).catch(() => {});
        else toast(t('shareMenu'));
      },
    ],
  ];

  return (
    <div className={s.modal}>
      <div className={s.scrim} onClick={onClose} />
      <section role="dialog" aria-modal="true" aria-labelledby="share-title" className={s.dialog}>
        <div className={s.top}>
          <span className={s.title}>
            <b id="share-title">{t('share')}</b>
            <span>{t('shareSub')}</span>
          </span>
          <button className={s.x} aria-label={t('close')} onClick={onClose}>
            <Icon name="close" size={16} />
          </button>
        </div>
        <span className={s.what}>{t('shareWhat')}</span>
        {ITEMS.map(([id, title, sub]) => {
          const on = sel.includes(id);
          return (
            <button
              key={id}
              role="checkbox"
              aria-checked={on}
              className={on ? `${s.item} ${s.itemOn}` : s.item}
              onClick={() => setSel(on ? sel.filter((x) => x !== id) : [...sel, id])}
            >
              <span className={s.box}>{on && <Icon name="check" size={14} width={2.6} />}</span>
              <span className={s.itemText}>
                <b>{t(title)}</b>
                <span>{t(sub)}</span>
              </span>
            </button>
          );
        })}
        <span className={s.noPdf}>
          <Icon name="lock" size={14} />
          {t('shareNoPdf')}
        </span>
        <div className={s.ways}>
          {ways.map(([label, icon, fn]) => (
            <button key={label} onClick={fn}>
              <Icon name={icon} size={20} />
              {t(label)}
            </button>
          ))}
        </div>
        {url && (
          <input className={s.url} readOnly value={url} dir="ltr" aria-label={t('shareCopy')} onFocus={(e) => e.target.select()} />
        )}
      </section>
    </div>
  );
}
