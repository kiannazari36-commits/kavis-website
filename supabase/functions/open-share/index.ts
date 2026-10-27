// Edge Function open-share: the iPhone app opens a share link (`/s/<slug>`). Only what the app made is shared
// (summary, cards, quiz), never the teacher's PDF. Premium only (CLAUDE.md): a receiver without Premium only gets a
// receipt ("Ders gelen kutunda bekliyor · Premium olunca açılır") and the answer { premium: false }; a Premium receiver
// gets a copy of the shared items as a new lesson of their own (no PDF file, no reader text).
// POST { slug } → { premium: false } | { premium: true, material_id, items } | { own: true, material_id } | 404 { error: 'not found' }
// Writes (service role): share_receipts, shares.opens, materials, summaries, card_decks, flashcards, quizzes, quiz_questions.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

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

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;

async function copyLesson(db: SupabaseClient, uid: string, shareId: string, materialId: string, items: string[]): Promise<string | null> {
  const { data: src } = await db.from('materials').select('title, language').eq('id', materialId).maybeSingle();
  if (!src) return null;
  const { data: mat, error } = await db.from('materials')
    .insert({ user_id: uid, kind: 'pdf', title: src.title, language: src.language, status: 'ready', processed_at: new Date().toISOString() })
    .select('id').single();
  if (error || !mat) return null;
  const newId = mat.id as string;

  if (items.includes('summary')) {
    const { data: sums } = await db.from('summaries').select('lang, kind, content').eq('material_id', materialId).eq('kind', 'lesson');
    if (sums?.length) await db.from('summaries').insert(sums.map((s: Row) => ({ ...s, user_id: uid, material_id: newId })));
  }
  if (items.includes('cards')) {
    const { data: decks } = await db.from('card_decks').select('id, lang, title').eq('material_id', materialId);
    for (const d of decks ?? []) {
      const { data: nd } = await db.from('card_decks').insert({ user_id: uid, material_id: newId, lang: d.lang, title: d.title }).select('id').single();
      const { data: cards } = await db.from('flashcards').select('question, answer, note, page, sort_order').eq('deck_id', d.id);
      if (nd && cards?.length) await db.from('flashcards').insert(cards.map((c: Row) => ({ ...c, deck_id: nd.id, user_id: uid })));
    }
  }
  if (items.includes('quiz')) {
    const { data: quizzes } = await db.from('quizzes').select('id, kind, lang, teacher_style, options').eq('material_id', materialId).in('kind', ['lesson_end', 'exam_prep', 'section_check']);
    for (const q of quizzes ?? []) {
      const { data: nq } = await db.from('quizzes').insert({ user_id: uid, material_id: newId, kind: q.kind, lang: q.lang, teacher_style: q.teacher_style, options: {} }).select('id').single();
      const { data: qs } = await db.from('quiz_questions')
        .select('sort_order, kind, style_tag, text, options, answer_index, model_answer, explanation, source_page, hints, molecule').eq('quiz_id', q.id);
      if (nq && qs?.length) await db.from('quiz_questions').insert(qs.map((x: Row) => ({ ...x, quiz_id: nq.id, user_id: uid })));
    }
  }
  return newId;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const body = await req.json().catch(() => ({}));
  const slug = typeof body.slug === 'string' ? body.slug.trim() : '';
  if (!/^[a-z0-9]{6,32}$/.test(slug)) return json({ error: 'not found' }, 404);

  const { data: share } = await db.from('shares').select('id, user_id, material_id, items, opens').eq('slug', slug).is('revoked_at', null).maybeSingle();
  if (!share) return json({ error: 'not found' }, 404);
  if (share.user_id === uid) return json({ own: true, material_id: share.material_id });

  await db.from('share_receipts').upsert({ share_id: share.id, receiver_id: uid }, { onConflict: 'share_id,receiver_id', ignoreDuplicates: true });
  const { data: premium } = await db.rpc('is_premium', { uid });
  if (!premium) return json({ premium: false });

  const { data: receipt } = await db.from('share_receipts').select('copied_material_id').eq('share_id', share.id).eq('receiver_id', uid).maybeSingle();
  let materialId = receipt?.copied_material_id as string | null;
  if (!materialId) {
    materialId = await copyLesson(db, uid, share.id, share.material_id, share.items as string[]);
    if (!materialId) return json({ error: 'failed' }, 500);
    await db.from('share_receipts').update({ copied_material_id: materialId, opened_at: new Date().toISOString() }).eq('share_id', share.id).eq('receiver_id', uid);
    await db.from('shares').update({ opens: (share.opens ?? 0) + 1 }).eq('id', share.id);
  }
  return json({ premium: true, material_id: materialId, items: share.items });
});
