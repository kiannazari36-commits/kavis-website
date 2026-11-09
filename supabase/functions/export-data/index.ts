// Edge Function export-data: "Hesap bilgilerimi iste". Puts everything the signed-in student has in Kavis in one
// JSON file in the private bucket 'exports' and emails a download link valid for 7 days (the nightly purge in
// delete-account removes the file afterwards). → { sent: true } | 429 { error: 'limit' } (3 per hour)
// PDFs are not copied in: each original file comes as a download link valid for 7 days.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { asLang, MAILS_PER_HOUR, newToken, publicLink, sendAccountMail } from '../_shared/mail.ts';

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

// The student's own rows (user_id). Left out: the PDF text cut into pieces (material_chunks, material_content —
// the PDF itself is linked), push tokens (device secrets).
const TABLES = [
  'user_settings', 'user_devices', 'trial_usage', 'subscriptions', 'usage_monthly', 'account_requests',
  'courses', 'course_exams', 'exam_periods', 'timetable_entries', 'own_plan_items',
  'materials', 'material_files', 'material_topics', 'material_terms', 'term_lookups', 'translations', 'annotations', 'reading_progress',
  'summaries', 'teacher_styles', 'question_samples', 'card_decks', 'flashcards', 'quizzes', 'quiz_questions', 'quiz_attempts', 'quiz_answers',
  'topic_progress', 'review_sessions', 'study_plans', 'plan_items', 'study_sessions',
  'assistant_threads', 'assistant_messages', 'notifications', 'shares', 'support_tickets', 'support_messages',
];
const LINK_DAYS = 7;

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
      const { data: link } = await db.storage.from('materials').createSignedUrl(f.storage_path, LINK_DAYS * 86400);
      pdfs.push({ material_id: f.material_id, path: f.storage_path, link: link ? publicLink(link.signedUrl) : null });
    }
    const file = JSON.stringify({
      app: 'Kavis Study',
      exported_at: new Date().toISOString(),
      account: { id: uid, email, created_at: who.user.created_at },
      profile,
      files: { links_valid_days: LINK_DAYS, pdfs },
      data,
    }, null, 2);
    // A random file name, so a link cannot be guessed from another one.
    const path = `${uid}/kavis-study-${new Date().toISOString().slice(0, 10)}-${(await newToken()).token.slice(0, 16)}.json`;
    const { error: up } = await db.storage.from('exports').upload(path, new Blob([file], { type: 'application/json' }), { contentType: 'application/json' });
    if (up) throw up;
    const { data: link, error: le } = await db.storage.from('exports').createSignedUrl(path, LINK_DAYS * 86400, { download: true });
    if (le || !link) throw le ?? new Error('link');
    await sendAccountMail('export', email, asLang((profile as { app_lang?: string } | null)?.app_lang), publicLink(link.signedUrl));
    await db.from('account_requests').insert({ user_id: uid, kind: 'export', status: 'done', done_at: new Date().toISOString(), file_path: path });
    return json({ sent: true });
  } catch (e) {
    console.error('export-data', e);
    return json({ error: 'export' }, 500);
  }
});
