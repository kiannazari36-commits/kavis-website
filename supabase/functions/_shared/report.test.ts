// Run: node --experimental-strip-types supabase/functions/_shared/report.test.ts
import { buildReport } from './report.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
for (const lang of ['tr', 'en', 'fa', 'ar'] as const) {
  const html = buildReport({
    lang, exportedAt: new Date('2026-11-21T10:00:00Z'), email: 'a@b.c',
    profile: { full_name: 'Ada', adult_confirmed_at: '2026-11-01T10:00:00Z', ai_consent_at: '2026-11-01T10:00:00Z', terms_accepted_at: '2026-11-01T10:00:00Z' },
    data: {
      push_tokens: [{ token: 'APNS-TOKEN' }], promo_attempts: [{}, {}], promo_redemptions: [{}], share_receipts: [{}],
      material_content: [{ material_id: 'm1' }], material_chunks: [{}, {}, {}],
    },
    pdfs: [], linkDays: 7,
    extraFiles: [{ kind: 'avatar', name: 'me.png', link: 'https://x.test/a?b=1&c=2' }, { kind: 'ink', name: 'p1.json', link: null }, { kind: 'support', name: '<img src=x onerror=1>.png', link: 'https://x.test/s' }],
  });
  check(`${lang}: extra section present`, html.includes('id="extra"'));
  check(`${lang}: file link present and escaped`, html.includes('href="https://x.test/a?b=1&#38;c=2"'));
  check(`${lang}: file name escaped`, !html.includes('<img src=x onerror=1>'));
  check(`${lang}: no token value shown`, !html.includes('APNS-TOKEN'));
  check(`${lang}: consent rows in profile`, html.includes({ tr: 'Yaş onayı', en: 'Age confirmation', fa: 'تأیید سن', ar: 'تأكيد العمر' }[lang]));
}
check('no extra section when nothing to show', !buildReport({ lang: 'en', exportedAt: new Date(), email: 'a@b.c', profile: null, data: {}, pdfs: [], linkDays: 7 }).includes('id="extra"'));
if (fails) process.exit(1);
