# "Reset password" email template (Supabase Dashboard)

Why: the old default link (`{{ .ConfirmationURL }}`) breaks when the reset was asked from the iPhone app (the app uses
PKCE, so the link arrives as `?code=` and the web page has no key for it), and an email scanner that opens the link
burns it. This link goes straight to the web page with `token_hash`; `web/src/pages/Login.tsx` (`Reset`) exchanges it
with `verifyOtp`. It works for web and iPhone requests, old app builds included. (Tested locally 23 Nov 2026.)

Where: Supabase → Authentication → Emails → Templates → **Reset password**. Subject: `Kavis Study — Şifre sıfırlama / Password reset`.

```html
{{ if eq .Data.app_lang "en" }}
<h2>Reset your password</h2>
<p>Tap the button to choose a new password. Use only the link in the most recent email; each new request cancels the older link.</p>
<p><a href="{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=recovery">Choose a new password</a></p>
<p>If you didn't ask for this, ignore this email.</p>
{{ else if eq .Data.app_lang "fa" }}
<div dir="rtl">
<h2>بازنشانی رمز</h2>
<p>برای انتخاب رمز تازه روی دکمه بزن. فقط از لینک آخرین ایمیل استفاده کن؛ هر درخواست تازه لینک قبلی را باطل می‌کند.</p>
<p><a href="{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=recovery">انتخاب رمز تازه</a></p>
<p>اگر این درخواست از تو نبود، این ایمیل را نادیده بگیر.</p>
</div>
{{ else if eq .Data.app_lang "ar" }}
<div dir="rtl">
<h2>إعادة تعيين كلمة المرور</h2>
<p>اضغط على الزر لاختيار كلمة مرور جديدة. استخدم الرابط في أحدث رسالة فقط؛ كل طلب جديد يلغي الرابط الأقدم.</p>
<p><a href="{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=recovery">اختر كلمة مرور جديدة</a></p>
<p>إذا لم تطلب ذلك، تجاهل هذه الرسالة.</p>
</div>
{{ else }}
<h2>Şifreni sıfırla</h2>
<p>Yeni şifre belirlemek için düğmeye dokun. Yalnızca en son gelen e-postadaki bağlantıyı kullan; her yeni istek eski bağlantıyı iptal eder.</p>
<p><a href="{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=recovery">Yeni şifre belirle</a></p>
<p>Bunu sen istemediysen bu e-postayı yok say.</p>
{{ end }}
```

`{{ .RedirectTo }}` is `https://kavis.study/login?mode=reset` (both clients send it), so `&token_hash=…` is appended
correctly. Do the change only after the web fix is live on kavis.study, otherwise the new link has no page to open it.
