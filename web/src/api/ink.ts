import { supabase } from './supabase';
import { currentUser } from './auth';

// The pen on the reading page: lines drawn over a page, kept per page (table annotations, kind 'ink').
// Points are stored as parts of the page's width and height (0–1), so the drawing fits any screen size.

export type Stroke = { color: string; points: [number, number][] };
export type PageInk = { id: string | null; strokes: Stroke[] };

export async function loadInk(materialId: string): Promise<Record<number, PageInk>> {
  const { data, error } = await supabase.from('annotations').select('id, page, anchor').eq('material_id', materialId).eq('kind', 'ink');
  if (error) console.error('loadInk', error);
  const out: Record<number, PageInk> = {};
  for (const r of data ?? []) out[r.page] = { id: r.id, strokes: ((r.anchor as { strokes?: Stroke[] }).strokes ?? []) };
  return out;
}

/** Saves a page's drawing; returns its row id (null when the page has no lines any more). */
export async function saveInk(materialId: string, page: number, ink: PageInk): Promise<string | null> {
  const user = currentUser();
  if (!user) return ink.id;
  if (!ink.strokes.length) {
    if (ink.id) await supabase.from('annotations').delete().eq('id', ink.id);
    return null;
  }
  // Points rounded to 4 decimals: small rows, no visible difference.
  const strokes = ink.strokes.map((s) => ({ color: s.color, points: s.points.map(([x, y]) => [Math.round(x * 1e4) / 1e4, Math.round(y * 1e4) / 1e4]) }));
  if (ink.id) {
    const { error } = await supabase.from('annotations').update({ anchor: { strokes } }).eq('id', ink.id);
    if (error) console.error('saveInk', error);
    return ink.id;
  }
  const { data, error } = await supabase
    .from('annotations')
    .insert({ user_id: user.id, material_id: materialId, page, kind: 'ink', anchor: { strokes } })
    .select('id')
    .single();
  if (error) console.error('saveInk', error);
  return (data?.id as string) ?? null;
}
