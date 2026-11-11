import { useEffect, useState } from 'react';
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL as string;

// Page behind the main button of the "Hesap bilgilerimi iste" email (/export#u=<signed link of the HTML report>).
// Storage serves .html files as plain text, so the page fetches the file and shows it in a sandboxed frame
// (no scripts; links may open in a new tab). Only links to our own Supabase 'exports' bucket are accepted.
const MSG: Record<string, string> = {
  tr: 'Bu bağlantı geçersiz ya da süresi dolmuş. Uygulamadan raporu yeniden isteyebilirsin.',
  en: 'This link is invalid or has expired. You can ask for the report again in the app.',
  fa: 'این لینک نامعتبر است یا منقضی شده. می‌توانی گزارش را دوباره از برنامه درخواست کنی.',
  ar: 'هذا الرابط غير صالح أو منتهي الصلاحية. يمكنك طلب التقرير مرة أخرى من التطبيق.',
};

function allowed(u: string) {
  try {
    const x = new URL(u);
    const base = new URL(SUPABASE_URL);
    return x.origin === base.origin && x.pathname.startsWith('/storage/v1/object/sign/exports/');
  } catch {
    return false;
  }
}

export default function ExportView() {
  const [html, setHtml] = useState<string | null>(null);
  const [bad, setBad] = useState(false);

  useEffect(() => {
    const u = new URLSearchParams(window.location.hash.slice(1)).get('u') ?? '';
    if (!allowed(u)) return setBad(true);
    fetch(u)
      .then((r) => (r.ok ? r.text() : Promise.reject()))
      .then((t) => {
        // Tell the report's links to open outside the frame.
        setHtml(t.replace('<head>', '<head><base target="_blank">'));
        document.title = 'Kavis Study';
      })
      .catch(() => setBad(true));
  }, []);

  if (bad) {
    const l = (document.documentElement.lang || navigator.language || 'tr').slice(0, 2);
    return <p style={{ padding: 32, textAlign: 'center', fontFamily: 'Poppins, sans-serif' }}>{MSG[l] ?? MSG.tr}</p>;
  }
  if (html === null) return <div style={{ position: 'fixed', inset: 0, background: '#F1E9DA' }} />;
  return <iframe title="Kavis Study" sandbox="allow-popups allow-popups-to-escape-sandbox" srcDoc={html} style={{ position: 'fixed', inset: 0, width: '100%', height: '100%', border: 0 }} />;
}
