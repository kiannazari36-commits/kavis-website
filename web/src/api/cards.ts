import { fakeRequest } from './client';
import { HYPERTENSION_CARDS } from './mock/cards';
import type { CardRating, FlashCard } from './types';

/** Size of the deck shown in the design ("1 / 12"); the mock repeats its 3 sample cards. */
export const DECK_SIZE = 12;

export function getDeck(_courseId: string, _pdfId: string): Promise<FlashCard[]> {
  return fakeRequest(HYPERTENSION_CARDS, 150);
}

export function rateCard(_index: number, _rating: CardRating) {
  return fakeRequest(true, 0);
}
