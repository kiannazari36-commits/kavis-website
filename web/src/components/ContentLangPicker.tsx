import { LANGS, LANG_NAMES, useI18n, type Lang } from '../i18n/I18nProvider';
import type { ContentLangChoice } from '../api/settings';
import s from './ContentLangPicker.module.css';

// "Content language" choice (CLAUDE.md): Same as PDF / Same as app / a language.
// On a course page `withDefault` adds "Use general setting" (value null).
export default function ContentLangPicker({
  value,
  onChange,
  resolved,
  withDefault = false,
}: {
  value: ContentLangChoice | null;
  onChange: (v: ContentLangChoice | null) => void;
  /** The language that is used now, shown as a hint. */
  resolved: Lang;
  withDefault?: boolean;
}) {
  const { t } = useI18n();
  const options: [ContentLangChoice | null, string][] = [
    ...(withDefault ? [[null, t('clDefault')] as [null, string]] : []),
    ['pdf', t('clSamePdf')],
    ['app', t('clSameApp')],
    ...LANGS.map((l) => [l, LANG_NAMES[l]] as [Lang, string]),
  ];

  return (
    <div className={s.wrap}>
      <div role="radiogroup" aria-label={t('contentLang')} className={s.chips}>
        {options.map(([v, label]) => (
          <button key={v ?? 'default'} role="radio" aria-checked={value === v} className={value === v ? s.on : ''} onClick={() => onChange(v)}>
            {label}
          </button>
        ))}
      </div>
      <span className={s.now}>
        {t('clNow')}
        <b>{LANG_NAMES[resolved]}</b>
      </span>
    </div>
  );
}
