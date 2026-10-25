// Edge Function translate: "Çevir" on the reading page. The teacher's text stays as it is; this makes a translation
// next to it, in the student's chosen language and style, and keeps it (table translations, one per text, language
// and style), so the same page is never paid for twice.
// POST { material_id, text, target_lang: 'tr' | 'en' | 'fa' | 'ar', style: 'literal' | 'natural' } → { text }
import { createClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';

const MODEL = 'claude-sonnet-5-5';
const MONTHLY_BUDGET_USD = 3;
const MAX_CHARS = 6000;

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

const LANG_NAMES: Record<string, string> = { tr: 'Turkish', en: 'English', fa: 'Persian', ar: 'Arabic' };

/** The same hash as the apps use to look a translation up. */
async function sha256(text: string) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

const costUsd = (input: number, output: number) => Math.round(((input * 2 + output * 10) / 1_000_000) * 10000) / 10000;

const system = (target: string, style: string) => `You translate a part of a university lecturer's text for a student, into ${LANG_NAMES[target]}.
${
  style === 'literal'
    ? 'Literal: follow the lecturer\'s sentences closely, word for word where the language allows, so the student learns the exact terms.'
    : 'Natural: say the same meaning the way it is naturally said in that language, so it is easy to understand. Do not add or leave out facts.'
}
Keep drug names, doses, numbers and abbreviations exactly. Keep the line breaks and bullet points. Reply with the translation only.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const body = await req.json().catch(() => ({}));
  const text = typeof body.text === 'string' ? body.text.trim() : '';
  const target = String(body.target_lang ?? '');
  const style = body.style === 'literal' ? 'literal' : 'natural';
  if (!text || text.length > MAX_CHARS || !LANG_NAMES[target] || typeof body.material_id !== 'string') return json({ error: 'input' }, 400);
  const { data: m } = await db.from('materials').select('user_id').eq('id', body.material_id).maybeSingle();
  if (!m || m.user_id !== uid) return json({ error: 'not found' }, 404);

  // Already translated: free.
  const hash = await sha256(text);
  const { data: kept } = await db.from('translations').select('text').eq('material_id', body.material_id).eq('source_hash', hash).eq('target_lang', target).eq('style', style).maybeSingle();
  if (kept) return json({ text: kept.text });

  // A new translation is AI work: the trial or Premium, and the monthly budget.
  const { data: allowed } = await db.rpc('can_use', { feature: 'generate', uid });
  if (!allowed) return json({ error: 'locked' }, 403);
  const month = new Date().toISOString().slice(0, 7) + '-01';
  const { data: use } = await db.from('usage_monthly').select('input_tokens, output_tokens, cost_usd, generations').eq('user_id', uid).eq('month', month).maybeSingle();
  if (use && Number(use.cost_usd) >= MONTHLY_BUDGET_USD) return json({ error: 'budget' }, 429);

  try {
    const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
    const params = {
      model: MODEL,
      max_tokens: 8000,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'low' },
      system: system(target, style),
      messages: [{ role: 'user', content: text }],
    };
    // deno-lint-ignore no-explicit-any
    const res = await client.beta.messages.create(params as any);
    if (res.stop_reason === 'refusal') return json({ error: 'declined' }, 422);
    const out = res.content.filter((b) => b.type === 'text').map((b) => (b as { text: string }).text).join('').trim();
    if (!out) return json({ error: 'ai' }, 502);
    await db.from('translations').upsert(
      { material_id: body.material_id, user_id: uid, source_hash: hash, target_lang: target, style, text: out },
      { onConflict: 'material_id,source_hash,target_lang,style' },
    );
    await db.from('usage_monthly').upsert({
      user_id: uid,
      month,
      input_tokens: Number(use?.input_tokens ?? 0) + res.usage.input_tokens,
      output_tokens: Number(use?.output_tokens ?? 0) + res.usage.output_tokens,
      cost_usd: Number(use?.cost_usd ?? 0) + costUsd(res.usage.input_tokens, res.usage.output_tokens),
      generations: Number(use?.generations ?? 0) + 1,
    });
    return json({ text: out });
  } catch (e) {
    console.error('translate', e);
    return json({ error: 'ai' }, 502);
  }
});
