import { fakeRequest } from './client';
import { COMPARE_ROWS, PREMIUM_PLANS } from './mock/premium';

// Premium is bought only in the iPhone app (Apple in-app purchase). The web only reads the status.
export function getPremiumOffer() {
  return fakeRequest({ rows: COMPARE_ROWS, plans: PREMIUM_PLANS }, 120);
}
