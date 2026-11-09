// Emails sent by Edge Functions (export-data, delete-account), in the student's app language.
// Live: Resend's HTTP API with the Supabase secret RESEND_API_KEY (never in git).
// Local copy: no key → the email goes to Mailpit (MAILPIT_URL in supabase/functions/.env, seen at http://127.0.0.1:54324).

export type Lang = 'tr' | 'en' | 'fa' | 'ar';
export const asLang = (l: unknown): Lang => (l === 'en' || l === 'fa' || l === 'ar' ? l : 'tr');

/** Where the web app lives (links in the emails). SITE_URL overrides it in the local copy. */
export const siteUrl = () => (Deno.env.get('SITE_URL') ?? 'https://kavis.study').replace(/\/$/, '');

/** Signed Storage links are made with the function's inner address in the local copy; PUBLIC_SUPABASE_URL fixes that. */
export function publicLink(link: string) {
  const pub = Deno.env.get('PUBLIC_SUPABASE_URL');
  if (!pub) return link;
  const u = new URL(link);
  const p = new URL(pub);
  u.protocol = p.protocol;
  u.host = p.host;
  return u.toString();
}

const TEXTS = {
  delete: {
    tr: { subject: 'Kavis Study · Hesabını silme onayı', hi: 'Kavis Study hesabını silmek istediğini bize bildirdin.', body: 'Onaylamak için aşağıdaki düğmeye bas. Hesabın 30 gün sonra silinir; bu sürede uygulamadan istediğin zaman vazgeçebilirsin. Bağlantı 24 saat geçerli ve yalnızca bir kez kullanılabilir.', button: 'Silmeyi onayla', ignore: 'Bunu sen istemediysen bu e-postayı dikkate alma; hesabın olduğu gibi kalır.' },
    en: { subject: 'Kavis Study · Confirm deleting your account', hi: 'You asked us to delete your Kavis Study account.', body: 'Press the button below to confirm. Your account is deleted in 30 days; until then you can change your mind in the app. The link works for 24 hours and only once.', button: 'Confirm deletion', ignore: "If you didn't ask for this, ignore this email; your account stays as it is." },
    fa: { subject: 'Kavis Study · تأیید حذف حساب', hi: 'درخواست حذف حساب Kavis Study خود را فرستادی.', body: 'برای تأیید روی دکمه‌ی زیر بزن. حسابت ۳۰ روز بعد حذف می‌شود و تا آن زمان می‌توانی در برنامه منصرف شوی. این لینک ۲۴ ساعت و فقط یک بار کار می‌کند.', button: 'تأیید حذف', ignore: 'اگر این درخواست از طرف تو نبوده، این ایمیل را نادیده بگیر؛ حسابت همان‌طور می‌ماند.' },
    ar: { subject: 'Kavis Study · تأكيد حذف الحساب', hi: 'طلبت حذف حسابك في Kavis Study.', body: 'اضغط الزر أدناه للتأكيد. يُحذف حسابك بعد 30 يومًا، ويمكنك التراجع من التطبيق حتى ذلك الحين. يعمل الرابط 24 ساعة ومرة واحدة فقط.', button: 'تأكيد الحذف', ignore: 'إن لم تطلب ذلك فتجاهل هذه الرسالة؛ يبقى حسابك كما هو.' },
  },
  export: {
    tr: { subject: 'Kavis Study · Hesap bilgilerin hazır', hi: 'İstediğin hesap bilgilerin hazır.', body: 'Tüm bilgilerin tek bir dosyada. Dosya ve içindeki PDF bağlantıları 7 gün geçerli; sonra dosya sunucudan silinir. Gerekirse uygulamadan yeniden isteyebilirsin.', button: 'Dosyayı indir', ignore: 'Bunu sen istemediysen bize kavisstudy@gmail.com adresinden yaz.' },
    en: { subject: 'Kavis Study · Your account data is ready', hi: 'The account data you asked for is ready.', body: 'All your data is in one file. The file and the PDF links in it work for 7 days; then the file is deleted from the server. You can ask again in the app any time.', button: 'Download the file', ignore: "If you didn't ask for this, write to us at kavisstudy@gmail.com." },
    fa: { subject: 'Kavis Study · اطلاعات حسابت آماده است', hi: 'اطلاعات حسابی که خواسته بودی آماده است.', body: 'همه‌ی اطلاعاتت در یک فایل است. فایل و لینک‌های PDF داخل آن ۷ روز معتبرند و بعد فایل از سرور حذف می‌شود. هر وقت خواستی می‌توانی دوباره از برنامه درخواست کنی.', button: 'دانلود فایل', ignore: 'اگر این درخواست از طرف تو نبوده، به kavisstudy@gmail.com بنویس.' },
    ar: { subject: 'Kavis Study · بيانات حسابك جاهزة', hi: 'بيانات الحساب التي طلبتها جاهزة.', body: 'كل بياناتك في ملف واحد. يعمل الملف وروابط ملفات PDF فيه 7 أيام، ثم يُحذف الملف من الخادم. يمكنك طلبه مرة أخرى من التطبيق في أي وقت.', button: 'تنزيل الملف', ignore: 'إن لم تطلب ذلك فراسلنا على kavisstudy@gmail.com.' },
  },
} as const;

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

/** Sends one of the two emails with a button to `link`. Throws when it could not be sent. */
export async function sendAccountMail(kind: keyof typeof TEXTS, to: string, lang: Lang, link: string) {
  const t = TEXTS[kind][lang];
  const dir = lang === 'fa' || lang === 'ar' ? 'rtl' : 'ltr';
  const font = lang === 'fa' || lang === 'ar' ? 'Vazirmatn, Tahoma, Arial, sans-serif' : 'Poppins, Helvetica, Arial, sans-serif';
  const html = `<!doctype html><html lang="${lang}" dir="${dir}"><body style="margin:0;background:#F1E9DA;font-family:${font};color:#2A2420">
<div style="max-width:520px;margin:0 auto;padding:32px 20px">
<div style="background:#FBF6EC;border:1px solid #E0D4BE;border-radius:24px;padding:28px">
<div style="font-weight:700;font-size:18px;color:#9C2F3A;margin-bottom:16px">Kavis Study</div>
<p style="font-size:16px;font-weight:600;margin:0 0 12px">${esc(t.hi)}</p>
<p style="font-size:14px;line-height:1.6;color:#6E645A;margin:0 0 24px">${esc(t.body)}</p>
<a href="${esc(link)}" style="display:inline-block;background:#9C2F3A;color:#FBF6EC;text-decoration:none;font-weight:600;font-size:15px;padding:12px 24px;border-radius:999px">${esc(t.button)}</a>
<p style="font-size:12px;line-height:1.5;color:#6E645A;margin:24px 0 0">${esc(t.ignore)}</p>
</div><div style="font-size:11px;color:#6E645A;text-align:center;margin-top:16px">Kavis Study · Always Improve More</div>
</div></body></html>`;
  const text = `${t.hi}\n\n${t.body}\n\n${t.button}: ${link}\n\n${t.ignore}`;
  const from = Deno.env.get('MAIL_FROM') ?? 'Kavis Study <kod@kavis.study>';

  const key = Deno.env.get('RESEND_API_KEY');
  if (key) {
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from, to: [to], subject: t.subject, html, text }),
    });
    if (!r.ok) throw new Error(`resend ${r.status}: ${await r.text()}`);
    return;
  }
  const mailpit = Deno.env.get('MAILPIT_URL');
  if (!mailpit) throw new Error('no email service (RESEND_API_KEY missing)');
  const m = from.match(/^(.*)<(.+)>$/);
  const r = await fetch(`${mailpit.replace(/\/$/, '')}/api/v1/send`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ From: { Email: m ? m[2] : from, Name: m ? m[1].trim() : '' }, To: [{ Email: to }], Subject: t.subject, HTML: html, Text: text }),
  });
  if (!r.ok) throw new Error(`mailpit ${r.status}: ${await r.text()}`);
}

/** Max 3 emails of one kind per student per hour (counted on account_requests). */
export const MAILS_PER_HOUR = 3;

/** A random one-time token for a link (base64url, 43 characters) and its SHA-256 (hex) for the database. */
export async function newToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const token = btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token)));
  return { token, hash: [...hash].map((b) => b.toString(16).padStart(2, '0')).join('') };
}
