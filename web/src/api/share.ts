import { supabase } from './supabase';

/** Only what the app made can be shared — never the original PDF, which belongs to the teacher (CLAUDE.md). */
export type ShareItem = 'summary' | 'cards' | 'quiz';

/**
 * Creates a share link (Edge Function create-share, Premium only). The link opens the web page /s/:id, which only
 * says "download the app"; null when it could not be made.
 */
export async function createShareLink(pdfId: string, items: ShareItem[]): Promise<string | null> {
  const { data, error } = await supabase.functions.invoke('create-share', { body: { material_id: pdfId, items } });
  if (error || !data?.slug) {
    console.error('create-share', error);
    return null;
  }
  return `${location.origin}/s/${data.slug as string}`;
}
