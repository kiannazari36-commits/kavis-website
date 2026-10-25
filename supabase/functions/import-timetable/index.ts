// Edge Function import-timetable: reads the student's school timetable from a photo or a PDF ("Okul ders
// programım"). POST { file: { media_type, data } } (JPEG / PNG / WebP photo or a PDF, base64)
// → { classes: [{ weekday 1-7, start "HH:MM", end "HH:MM" | null, title, room | null, teacher | null }] }.
// It only reads: the app shows the list, the student checks it and adds the rows (their own timetable data).
// Claude Sonnet 5.5 reads it (about 1-2 cents); the cost counts in the month's AI budget.
import { createClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';

const MODEL = 'claude-sonnet-5-5';
const MONTHLY_BUDGET_USD = 3;
const TYPES = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];

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

const str = { type: 'string' };
const SCHEMA = {
  type: 'object',
  properties: {
    classes: {
      type: 'array',
      items: {
        type: 'object',
        properties: { weekday: { type: 'integer' }, start: str, end: str, title: str, room: str, teacher: str },
        required: ['weekday', 'start', 'end', 'title', 'room', 'teacher'],
        additionalProperties: false,
      },
    },
  },
  required: ['classes'],
  additionalProperties: false,
};

const SYSTEM = `You read a university student's weekly class timetable from a photo or a PDF.
Return every class as one entry: weekday (1 = Monday … 7 = Sunday), start and end time as 24-hour "HH:MM" (end "" if not shown), title = the course name exactly as written (keep codes like "FAR301" only if no name is given), room ("" if none), teacher ("" if none).
A class that spans several hours is one entry (from its first start to its last end). The same course on two days is two entries. Ignore breaks, lunch and empty cells. If the image is not a timetable, return an empty list.`;

type Entry = { weekday: number; start: string; end: string; title: string; room: string; teacher: string };
const hhmm = (x: string) => (/^\d{1,2}[:.]\d{2}$/.test(x.trim()) ? x.trim().replace('.', ':').padStart(5, '0') : null);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const body = await req.json().catch(() => ({}));
  const file = body.file;
  if (!file || !TYPES.includes(file.media_type) || typeof file.data !== 'string' || file.data.length > 14_000_000) return json({ error: 'file' }, 400);

  const month = new Date().toISOString().slice(0, 7) + '-01';
  const { data: use } = await db.from('usage_monthly').select('input_tokens, output_tokens, cost_usd').eq('user_id', uid).eq('month', month).maybeSingle();
  if (use && Number(use.cost_usd) >= MONTHLY_BUDGET_USD) return json({ error: 'budget' }, 429);

  const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
  const source = { type: 'base64', media_type: file.media_type, data: file.data };
  let entries: Entry[];
  let usage = { input_tokens: 0, output_tokens: 0 };
  try {
    const params = {
      model: MODEL,
      max_tokens: 8000,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'low', format: { type: 'json_schema', schema: SCHEMA } },
      system: SYSTEM,
      messages: [
        {
          role: 'user',
          content: [file.media_type === 'application/pdf' ? { type: 'document', source } : { type: 'image', source }, { type: 'text', text: 'Read this timetable.' }],
        },
      ],
    };
    // deno-lint-ignore no-explicit-any
    const res = await client.beta.messages.create(params as any);
    usage = res.usage;
    const text = res.content.filter((b) => b.type === 'text').map((b) => (b as { text: string }).text).join('');
    entries = (JSON.parse(text) as { classes: Entry[] }).classes;
  } catch (e) {
    console.error('import-timetable', e);
    return json({ error: 'ai' }, 502);
  }

  // The month's AI cost (Sonnet 5.5: $2 / $10 per million tokens).
  const cost = Math.round(((usage.input_tokens * 2 + usage.output_tokens * 10) / 1_000_000) * 10000) / 10000;
  await db.from('usage_monthly').upsert({
    user_id: uid,
    month,
    input_tokens: Number(use?.input_tokens ?? 0) + usage.input_tokens,
    output_tokens: Number(use?.output_tokens ?? 0) + usage.output_tokens,
    cost_usd: Number(use?.cost_usd ?? 0) + cost,
  });

  const classes = entries
    .filter((e) => Number.isInteger(e.weekday) && e.weekday >= 1 && e.weekday <= 7 && hhmm(e.start) && e.title.trim())
    .slice(0, 80)
    .map((e) => ({
      weekday: e.weekday,
      start: hhmm(e.start)!,
      end: hhmm(e.end),
      title: e.title.trim().slice(0, 120),
      room: e.room.trim().slice(0, 80) || null,
      teacher: e.teacher.trim().slice(0, 120) || null,
    }));
  return json({ classes });
});
