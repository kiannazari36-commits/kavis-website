// Edge Function export-data: "Hesap bilgilerimi iste". Puts everything the signed-in student has in Kavis in one
// JSON file (machine-readable copy) AND a readable HTML report in the private bucket 'exports' and emails a link
// valid for 7 days (the nightly purge in delete-account removes both files afterwards). Storage serves .html as
// text/plain, so the report link goes through the web page /export (it fetches the file and shows it); the
// report file itself stays one self-contained HTML file. → { sent: true } | 429 { error: 'limit' } (3 per hour)
// PDFs are not copied in: each original file comes as a download link valid for 7 days.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { asLang, MAILS_PER_HOUR, newToken, publicLink, sendAccountMail, siteUrl } from '../_shared/mail.ts';
import { buildReport } from '../_shared/report.ts';
import { safeStoragePath } from '../_shared/paths.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

function secretKey() {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');
  if (legacy) return legacy;
  const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>;
  return Object.values(keys)[0] ?? '';
}

// The student's own rows (user_id): every table that carries user_id (21 Nov: push_tokens, promo_attempts,
// promo_redemptions, share_receipts, material_content and material_chunks added).
const TABLES = [
  'user_settings', 'user_devices', 'trial_usage', 'subscriptions', 'usage_monthly', 'account_requests',
  'courses', 'course_exams', 'exam_periods', 'timetable_entries', 'own_plan_items',
  'materials', 'material_files', 'material_topics', 'material_terms', 'term_lookups', 'translations', 'annotations', 'reading_progress',
  'summaries', 'teacher_styles', 'question_samples', 'card_decks', 'flashcards', 'quizzes', 'quiz_questions', 'quiz_attempts', 'quiz_answers',
  'topic_progress', 'review_sessions', 'study_plans', 'plan_items', 'study_sessions',
  'assistant_threads', 'assistant_messages', 'notifications', 'shares', 'support_tickets', 'support_messages',
  'push_tokens', 'promo_attempts', 'promo_redemptions', 'share_receipts', 'material_content', 'material_chunks',
];
const LINK_DAYS = 7;

/** All files under "<user>/" in a bucket (folders are walked through). */
async function filesOf(db: SupabaseClient, bucket: string, prefix: string): Promise<string[]> {
  const out: string[] = [];
  for (let offset = 0; ; offset += 100) {
    const { data, error } = await db.storage.from(bucket).list(prefix, { limit: 100, offset });
    if (error || !data?.length) break;
    for (const item of data) {
      const path = `${prefix}/${item.name}`;
      if (item.id === null) out.push(...(await filesOf(db, bucket, path)));
      else out.push(path);
    }
    if (data.length < 100) break;
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;
  const email = who.user.email;
  if (!email) return json({ error: 'no_email' }, 400);
  const since = new Date(Date.now() - 3_600_000).toISOString();
  const { count } = await db.from('account_requests').select('id', { count: 'exact', head: true }).eq('user_id', uid).eq('kind', 'export').gte('created_at', since);
  if ((count ?? 0) >= MAILS_PER_HOUR) return json({ error: 'limit' }, 429);

  try {
    const { data: profile } = await db.from('profiles').select('*').eq('id', uid).single();
    const data: Record<string, unknown[]> = {};
    for (const table of TABLES) {
      const rows: unknown[] = [];
      for (let from = 0; ; from += 1000) {
        const { data: page, error } = await db.from(table).select('*').eq('user_id', uid).range(from, from + 999);
        if (error) throw new Error(`${table}: ${error.message}`);
        rows.push(...(page ?? []));
        if (!page || page.length < 1000) break;
      }
      data[table] = rows;
    }
    // Original files: a download link each.
    const files = (data.material_files ?? []) as { material_id: string; storage_path: string }[];
    const pdfs = [];
    for (const f of files) {
      const p = safeStoragePath(uid, f.storage_path);
      const { data: link } = p ? await db.storage.from('materials').createSignedUrl(p, LINK_DAYS * 86400) : { data: null };
      pdfs.push({ material_id: f.material_id, path: f.storage_path, link: link ? publicLink(link.signedUrl) : null });
    }
    // The other files: profile photo, handwriting (ink), question samples, support attachments (a 7-day link each).
    const extraFiles: { kind: 'avatar' | 'ink' | 'sample' | 'support'; bucket: string; path: string; name: string; link: string | null }[] = [];
    const wanted: { kind: 'avatar' | 'ink' | 'sample' | 'support'; bucket: string; path: string }[] = [];
    const av = safeStoragePath(uid, (profile as { avatar_path?: string | null } | null)?.avatar_path);
    if (av) wanted.push({ kind: 'avatar', bucket: 'avatars', path: av });
    for (const p of await filesOf(db, 'ink', uid)) wanted.push({ kind: 'ink', bucket: 'ink', path: p });
    for (const r of (data.question_samples ?? []) as { storage_path: string | null }[]) { const p = safeStoragePath(uid, r.storage_path); if (p) wanted.push({ kind: 'sample', bucket: 'question-samples', path: p }); }
    for (const r of (data.support_messages ?? []) as { attachment_path: string | null }[]) { const p = safeStoragePath(uid, r.attachment_path); if (p) wanted.push({ kind: 'support', bucket: 'support', path: p }); }
    for (const w of wanted) {
      const { data: link } = await db.storage.from(w.bucket).createSignedUrl(w.path, LINK_DAYS * 86400, { download: true });
      extraFiles.push({ ...w, name: w.path.split('/').slice(1).join('/'), link: link ? publicLink(link.signedUrl) : null });
    }
    const file = JSON.stringify({
      app: 'Kavis Study',
      exported_at: new Date().toISOString(),
      account: { id: uid, email, created_at: who.user.created_at },
      profile,
      files: { links_valid_days: LINK_DAYS, pdfs, other: extraFiles },
      data,
    }, null, 2);
    // A random file name, so a link cannot be guessed from another one.
    const base = `${uid}/kavis-study-${new Date().toISOString().slice(0, 10)}-${(await newToken()).token.slice(0, 16)}`;
    const path = `${base}.json`;
    const reportPath = `${base}.html`;
    const lang = asLang((profile as { app_lang?: string } | null)?.app_lang);
    const report = buildReport({ lang, exportedAt: new Date(), email, createdAt: who.user.created_at, profile, data: data as Record<string, Record<string, unknown>[]>, pdfs, linkDays: LINK_DAYS, extraFiles });
    // The request row comes first, so the nightly job always finds the files (and the hourly limit counts a failed try too).
    const { data: reqRow, error: reqErr } = await db.from('account_requests').insert({ user_id: uid, kind: 'export', status: 'pending', file_path: path }).select('id').single();
    if (reqErr) throw reqErr;
    try {
    const { error: up } = await db.storage.from('exports').upload(path, new Blob([file], { type: 'application/json' }), { contentType: 'application/json' });
    if (up) throw up;
    const { error: up2 } = await db.storage.from('exports').upload(reportPath, new Blob([report], { type: 'text/html' }), { contentType: 'text/html' });
    if (up2) throw up2;
    const { data: link, error: le } = await db.storage.from('exports').createSignedUrl(path, LINK_DAYS * 86400, { download: true });
    if (le || !link) throw le ?? new Error('link');
    const { data: rlink, error: re } = await db.storage.from('exports').createSignedUrl(reportPath, LINK_DAYS * 86400);
    if (re || !rlink) throw re ?? new Error('link');
    const viewer = `${siteUrl()}/export#u=${encodeURIComponent(publicLink(rlink.signedUrl))}`;
    await sendAccountMail('export', email, lang, viewer, publicLink(link.signedUrl));
    await db.from('account_requests').update({ status: 'done', done_at: new Date().toISOString() }).eq('id', reqRow.id);
    return json({ sent: true });
    } catch (e) {
      // The mail did not go (or an upload failed): do not leave personal data behind.
      await db.storage.from('exports').remove([path, reportPath]);
      await db.from('account_requests').update({ status: 'cancelled', file_path: null }).eq('id', reqRow.id);
      throw e;
    }
  } catch (e) {
    console.error('export-data', e);
    return json({ error: 'export' }, 500);
  }
});
