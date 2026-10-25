// Edge Function group-sections: a lesson cut into too many small sections (the AI marks a new section per page
// while reading the PDF in batches) is grouped into a few general parts, e.g. 57 sections of 86 pages → 5 parts.
// POST { material_id } → { sections: n, grouped: boolean }. Called by the reader the first time it opens a
// finished lesson with too many sections. Only the section list changes: every block of the teacher's text stays,
// in the same order. Claude Sonnet 5.5 gets only the section titles and pages (cheap, about half a cent).
import { createClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';
import { applyParts, maxSections, outline, pagesOf, targetParts, type Part, type Section } from './lib.ts';

const MODEL = 'claude-sonnet-5-5';

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

const SCHEMA = {
  type: 'object',
  properties: {
    parts: {
      type: 'array',
      items: { type: 'object', properties: { title: { type: 'string' }, first: { type: 'integer' } }, required: ['title', 'first'], additionalProperties: false },
    },
  },
  required: ['parts'],
  additionalProperties: false,
};

type Doc = { language: string; grouped?: boolean; sections: Section[] };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const { material_id } = await req.json().catch(() => ({}));
  if (typeof material_id !== 'string') return json({ error: 'material_id' }, 400);
  const { data: m } = await db.from('materials').select('user_id, status, title').eq('id', material_id).maybeSingle();
  if (!m || m.user_id !== uid) return json({ error: 'not found' }, 404);
  const { data: content } = await db.from('material_content').select('reader_doc').eq('material_id', material_id).maybeSingle();
  const doc = content?.reader_doc as Doc | null;
  // Only a finished lesson, once.
  if (m.status !== 'ready' || !doc?.sections?.length || doc.grouped) return json({ sections: doc?.sections?.length ?? 0, grouped: false });

  const pages = pagesOf(doc.sections);
  if (doc.sections.length <= maxSections(pages)) {
    await db.from('material_content').update({ reader_doc: { ...doc, grouped: true } }).eq('material_id', material_id);
    return json({ sections: doc.sections.length, grouped: false });
  }

  const month = new Date().toISOString().slice(0, 7) + '-01';
  const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
  let parts: Part[];
  let usage = { input_tokens: 0, output_tokens: 0 };
  try {
    const params = {
      model: MODEL,
      max_tokens: 2000,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'low', format: { type: 'json_schema', schema: SCHEMA } },
      system: `You organise a university lecture into a few big study parts. You get the lecture's current sections in order (number, title, pages); they are too small. Group neighbouring sections into at most ${targetParts(pages)} parts, fewer if the lecture has fewer big topics: each part is one big topic a student studies in one go (for example "Yağda çözünen vitaminler", "Suda çözünen vitaminler", "Anemi"). Keep the order; a part is a run of consecutive sections. Return parts in order: first = the number of the part's first section (the first part starts at 0), title = a short general title (2-5 words) in the lecture's language.`,
      messages: [{ role: 'user', content: `Lecture: "${m.title}" (${pages} pages)\n\n${outline(doc.sections)}` }],
    };
    // deno-lint-ignore no-explicit-any
    const res = await client.beta.messages.create(params as any);
    usage = res.usage;
    const text = res.content.filter((b) => b.type === 'text').map((b) => (b as { text: string }).text).join('');
    parts = (JSON.parse(text) as { parts: Part[] }).parts;
  } catch (e) {
    console.error('group-sections', e);
    return json({ error: 'ai' }, 502);
  }

  const grouped = applyParts(doc.sections, parts);
  // The month's AI cost (Sonnet 5.5: $2 / $10 per million tokens).
  const cost = (usage.input_tokens * 2 + usage.output_tokens * 10) / 1_000_000;
  const { data: u } = await db.from('usage_monthly').select('input_tokens, output_tokens, cost_usd').eq('user_id', uid).eq('month', month).maybeSingle();
  await db.from('usage_monthly').upsert({
    user_id: uid,
    month,
    input_tokens: Number(u?.input_tokens ?? 0) + usage.input_tokens,
    output_tokens: Number(u?.output_tokens ?? 0) + usage.output_tokens,
    cost_usd: Number(u?.cost_usd ?? 0) + Math.round(cost * 10000) / 10000,
  });
  if (!grouped) {
    // A grouping that would lose text is not used; the lesson keeps its sections and is not asked again.
    await db.from('material_content').update({ reader_doc: { ...doc, grouped: true } }).eq('material_id', material_id);
    return json({ sections: doc.sections.length, grouped: false });
  }
  await db.from('material_content').update({ reader_doc: { ...doc, grouped: true, sections: grouped } }).eq('material_id', material_id);
  return json({ sections: grouped.length, grouped: true });
});
