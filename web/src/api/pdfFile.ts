import { supabase } from './supabase';

// The teacher's original PDF of a lesson ("Orijinal PDF" in the reader): the private bucket "materials",
// read through a short-lived signed link. The bytes are kept in this browser (Cache Storage), so a lesson opened
// again does not download the file a second time. Same file as the iPad's "tam ekran PDF".

const CACHE = 'kavis-pdf-v1';

/** The storage path of the lesson's PDF; null for photo lessons, the exam summary or a copied lesson. */
export async function pdfPath(materialId: string): Promise<string | null> {
  const { data, error } = await supabase
    .from('material_files')
    .select('storage_path')
    .eq('material_id', materialId)
    .order('sort_order')
    .limit(1)
    .maybeSingle<{ storage_path: string }>();
  if (error) console.error('pdfPath', error);
  const path = data?.storage_path;
  return path && path.toLowerCase().endsWith('.pdf') ? path : null;
}

/** The PDF's bytes: this browser's copy when there is one, else downloaded once and kept. null = not available. */
export async function pdfBytes(materialId: string, path: string): Promise<ArrayBuffer | null> {
  const key = `/pdf/${materialId}`;
  const cache = await caches.open(CACHE).catch(() => null);
  const kept = await cache?.match(key);
  if (kept) return kept.arrayBuffer();
  const { data, error } = await supabase.storage.from('materials').createSignedUrl(path, 3600);
  if (error || !data) {
    console.error('pdfBytes', error);
    return null;
  }
  const res = await fetch(data.signedUrl).catch(() => null);
  if (!res?.ok) return null;
  const bytes = await res.arrayBuffer();
  cache?.put(key, new Response(bytes.slice(0), { headers: { 'content-type': 'application/pdf' } })).catch(() => {});
  return bytes;
}

/** Forgets the kept copy (when a lesson is deleted). */
export function forgetPdf(materialId: string) {
  caches.open(CACHE).then((c) => c.delete(`/pdf/${materialId}`)).catch(() => {});
}
