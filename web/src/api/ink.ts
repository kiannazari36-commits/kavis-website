import { supabase } from './supabase';
import { currentUser } from './auth';
import { inkKey, blockOrdinals, groupInk, type InkSurface, type PageInk, type Stroke } from './inkKey';

// The pen on the reading page: lines drawn over a page, kept per page (table annotations, kind 'ink').
// One format for every app (see Stroke): points are parts of the page's width and height (0–1), so the drawing fits
// any screen size. Two surfaces with different page shapes, kept apart: the reading mode's page cards (no
// `anchor.surface`, `anchor.block` = the card's number on its page) and the original PDF pages (`anchor.surface = 'pdf'`).

export { inkKey, blockOrdinals };
export type { InkSurface, PageInk, Stroke };

export async function loadInk(materialId: string, surface: InkSurface = 'card'): Promise<Record<string, PageInk>> {
  const { data, error } = await supabase.from('annotations').select('id, page, ink_path, anchor').eq('material_id', materialId).eq('kind', 'ink');
  if (error) console.error('loadInk', error);
  return groupInk(data ?? [], surface);
}

/** Saves a page's drawing; returns its row id (null when the page has no lines any more). */
export async function saveInk(materialId: string, page: number, ink: PageInk, surface: InkSurface = 'card', block = 0): Promise<string | null> {
  const user = currentUser();
  if (!user) return ink.id;
  if (ink.others?.length) await supabase.from('annotations').delete().in('id', ink.others);
  if (!ink.strokes.length) {
    if (ink.id) await supabase.from('annotations').delete().eq('id', ink.id);
    return null;
  }
  // Numbers rounded to 4 decimals: small rows, no visible difference.
  const r = (n: number) => Math.round(n * 1e4) / 1e4;
  const strokes = ink.strokes.map((s) => ({ ...s, ...(s.w ? { w: r(s.w) } : {}), points: s.points.map(([x, y]) => [r(x), r(y)]) }));
  const anchor = surface === 'card' ? { block, strokes } : { surface, strokes };
  if (ink.id) {
    const { error } = await supabase.from('annotations').update({ anchor }).eq('id', ink.id);
    if (error) console.error('saveInk', error);
    return ink.id;
  }
  const { data, error } = await supabase
    .from('annotations')
    .insert({ user_id: user.id, material_id: materialId, page, kind: 'ink', anchor })
    .select('id')
    .single();
  if (error) console.error('saveInk', error);
  return (data?.id as string) ?? null;
}
