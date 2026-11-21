// Edge Function ai-health: checks that the Claude API key (Supabase secret ANTHROPIC_API_KEY) is set and valid.
// Free: it only lists the models (no tokens used). Never returns the key itself.
// Only the app owner may call it (signed in; ADMIN_USER_IDS overrides the owner id, like owner-overview): the public
// anon key alone gets 401/403, so strangers cannot use it to probe the key or burn the Anthropic rate limit.
import { createClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';

const OWNER = '9a69763b-e12c-4e47-a993-739188d9d652';

function secretKey() {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');
  if (legacy) return legacy;
  const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>;
  return Object.values(keys)[0] ?? '';
}

Deno.serve(async (req) => {
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });
  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return Response.json({ error: 'not signed in' }, { status: 401 });
  const admins = (Deno.env.get('ADMIN_USER_IDS') ?? OWNER).split(',').map((x) => x.trim());
  if (!admins.includes(who.user.id)) return Response.json({ error: 'not admin' }, { status: 403 });

  const key = Deno.env.get('ANTHROPIC_API_KEY')?.trim();
  if (!key) return Response.json({ configured: false });
  try {
    const page = await new Anthropic({ apiKey: key }).models.list();
    return Response.json({ configured: true, valid: true, sonnet55: page.data.some((m) => m.id === 'claude-sonnet-5-5') });
  } catch (e) {
    const err = e as { name?: string; status?: number };
    return Response.json({ configured: true, valid: false, error: err.name ?? null, status: err.status ?? null });
  }
});
