// Edge Function add-card: "Kartlara ekle" on a hard word in the reader.
// POST { term_id } → { card_id, added: true } or { card_id, already: true }
// Makes a flash card from the word's ready explanation (no AI, free) in the lesson's deck, in the lesson's content
// language. Cards are written only by the server (service role), never by the apps.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { termCard } from './card.ts';

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const { term_id } = await req.json().catch(() => ({}));
  if (typeof term_id !== 'string') return json({ error: 'term_id' }, 400);

  // Only the student's own word.
  const { data: term } = await db.from('material_terms').select('id, material_id, surface, page, explanation').eq('id', term_id).eq('user_id', uid).maybeSingle();
  if (!term) return json({ error: 'not found' }, 404);
  const { data: mat } = await db.from('materials').select('id, course_id, title, language').eq('id', term.material_id).single();

  // The lesson's deck (made when the lesson was processed); a new one if there is none.
  const { data: decks } = await db.from('card_decks').select('id, lang').eq('user_id', uid).eq('material_id', term.material_id).order('created_at').limit(1);
  const lang = decks?.[0]?.lang ?? (['tr', 'en', 'fa', 'ar'].includes(mat?.language) ? mat!.language : 'tr');
  const card = termCard(term.explanation ?? {}, lang, term.surface);
  if (!card) return json({ error: 'no explanation' }, 422);

  let deckId = decks?.[0]?.id as string | undefined;
  if (!deckId) {
    const { data: deck, error } = await db
      .from('card_decks')
      .insert({ user_id: uid, course_id: mat?.course_id ?? null, material_id: term.material_id, lang, title: mat?.title ?? null })
      .select('id')
      .single();
    if (error) return json({ error: 'deck' }, 500);
    deckId = deck.id;
  }

  // The same word twice → the card that is already there.
  const { data: same } = await db.from('flashcards').select('id').eq('deck_id', deckId).eq('question', card.question).maybeSingle();
  if (same) return json({ card_id: same.id, already: true });

  const { data: last } = await db.from('flashcards').select('sort_order').eq('deck_id', deckId).order('sort_order', { ascending: false }).limit(1);
  const { data: made, error } = await db
    .from('flashcards')
    .insert({ deck_id: deckId, user_id: uid, question: card.question, answer: card.answer, note: card.note, page: term.page, sort_order: (last?.[0]?.sort_order ?? 0) + 1 })
    .select('id')
    .single();
  if (error) return json({ error: 'card' }, 500);
  return json({ card_id: made.id, added: true });
});
