import { fakeRequest } from './client';
import { COMPARE_ROWS, PREMIUM_PLANS } from './mock/premium';

const KEY = 'kavis.premium';

// Premium is bought only in the iPhone app (Apple in-app purchase). The web only reads the status.
export function getPremiumOffer() {
  return fakeRequest({ rows: COMPARE_ROWS, plans: PREMIUM_PLANS }, 120);
}

/** Mock: Premium status of the account. A real server will check the Apple subscription. */
export function isPremium() {
  try {
    return localStorage.getItem(KEY) === '1';
  } catch {
    return false;
  }
}
