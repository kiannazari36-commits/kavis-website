// Edge Function send-notifications: the push job (pg_cron every minute, migration 20261027120000; the job is
// created SWITCHED OFF until the Apple APNs key is added).
// Sends the due rows of `notifications` as push to the student's iPhone / iPad (push_tokens, platform 'apns'):
//   - new: sent_at empty, send_at reached, not snoozed (or the snooze is over),
//   - snoozed again after it was sent: pushed once more when snoozed_until is reached.
// Not pushed, only marked sent: already read in the app, push switched off in Settings, or older than 2 hours
// (so switching the job on never sends a pile of old news). A dead token is deleted.
// POST {} with header x-cron-key. Without the Supabase secrets APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY
// (and APNS_BUNDLE_ID, APNS_ENV = 'sandbox' for Xcode builds) it does nothing and answers { off: 'no apns key' }.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { apnsConfig, apnsJwt, deadToken, importKey, payload, sendOne } from './apns.ts';

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

function secretKey() {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');
  if (legacy) return legacy;
  const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>;
  return Object.values(keys)[0] ?? '';
}

const STALE_MS = 2 * 3600_000;
const BATCH = 500;
let jwtCache: { jwt: string; at: number } | null = null;

type Row = { id: string; user_id: string; title: string; body: string | null; data: Record<string, unknown> | null; send_at: string; sent_at: string | null; snoozed_until: string | null; read_at: string | null };

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });
  const { data: ok } = await db.rpc('check_cron_key', { key: req.headers.get('x-cron-key') ?? '' });
  if (ok !== true) return json({ error: 'key' }, 401);

  const cfg = apnsConfig((k) => Deno.env.get(k));
  if (!cfg) return json({ off: 'no apns key' });

  const now = Date.now();
  const nowIso = new Date(now).toISOString();
  const cols = 'id, user_id, title, body, data, send_at, sent_at, snoozed_until, read_at';
  const [fresh, snoozed] = await Promise.all([
    db.from('notifications').select(cols).is('sent_at', null).lte('send_at', nowIso)
      .or(`snoozed_until.is.null,snoozed_until.lte.${nowIso}`).order('send_at').limit(BATCH),
    db.from('notifications').select(cols).not('sent_at', 'is', null).lte('snoozed_until', nowIso)
      .gt('snoozed_until', new Date(now - STALE_MS).toISOString()).limit(BATCH),
  ]);
  if (fresh.error || snoozed.error) return json({ error: 'read' }, 500);
  const rows = [
    ...((fresh.data ?? []) as Row[]),
    ...((snoozed.data ?? []) as Row[]).filter((r) => r.sent_at! < r.snoozed_until!),
  ];
  if (!rows.length) return json({ sent: 0, skipped: 0 });

  const users = [...new Set(rows.map((r) => r.user_id))];
  const [settings, tokens] = await Promise.all([
    db.from('user_settings').select('user_id, push_notifications').in('user_id', users),
    db.from('push_tokens').select('id, user_id, token, user_devices(signed_out_at)').eq('platform', 'apns').in('user_id', users),
  ]);
  const pushOn = new Set((settings.data ?? []).filter((s) => s.push_notifications).map((s) => s.user_id));
  const byUser = new Map<string, { id: string; token: string }[]>();
  for (const t of tokens.data ?? []) {
    const dev = (Array.isArray(t.user_devices) ? t.user_devices[0] : t.user_devices) as { signed_out_at: string | null } | null;
    if (dev?.signed_out_at) continue; // a signed-out device gets nothing
    byUser.set(t.user_id, [...(byUser.get(t.user_id) ?? []), { id: t.id, token: t.token }]);
  }

  if (!jwtCache || now - jwtCache.at > 50 * 60_000) jwtCache = { jwt: await apnsJwt(cfg, await importKey(cfg.privateKey)), at: now };
  const out = { sent: 0, skipped: 0, failed: 0, dead: 0 };
  const handled: string[] = [];
  for (const n of rows) {
    handled.push(n.id);
    const due = n.sent_at ? n.snoozed_until! : (n.snoozed_until && n.snoozed_until > n.send_at ? n.snoozed_until : n.send_at);
    const targets = byUser.get(n.user_id) ?? [];
    if (n.read_at || !pushOn.has(n.user_id) || now - Date.parse(due) > STALE_MS || !targets.length) {
      out.skipped++;
      continue;
    }
    for (const t of targets) {
      try {
        const r = await sendOne(cfg, jwtCache.jwt, t.token, payload(n));
        if (r.status === 200) out.sent++;
        else if (deadToken(r.status, r.reason)) {
          out.dead++;
          await db.from('push_tokens').delete().eq('id', t.id);
        } else {
          out.failed++;
          console.error('apns', r.status, r.reason);
        }
      } catch (e) {
        out.failed++;
        console.error('apns', e);
      }
    }
  }
  if (handled.length) await db.from('notifications').update({ sent_at: new Date().toISOString() }).in('id', handled);
  return json(out);
});
