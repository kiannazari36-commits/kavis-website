// Edge Function ai-health: checks that the Claude API key (Supabase secret ANTHROPIC_API_KEY) is set and valid.
// Free: it only lists the models (no tokens used). Never returns the key itself.
import Anthropic from 'npm:@anthropic-ai/sdk';

Deno.serve(async () => {
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
