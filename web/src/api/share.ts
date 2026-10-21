import { fakeRequest } from './client';

/** Only what the app made can be shared — never the original PDF (CLAUDE.md, Premium only). */
export type ShareItem = 'summary' | 'cards' | 'quiz';

/** Creates a share link. Mock: a random id; the link opens the web page /s/:id. */
export function createShareLink(_pdfId: string, _items: ShareItem[]): Promise<string> {
  const id = Math.random().toString(36).slice(2, 10);
  return fakeRequest(`${location.origin}/s/${id}`, 200);
}
