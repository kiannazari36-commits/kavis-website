import { fakeRequest } from './client';
import { COMPARE_ROWS, PREMIUM_PLANS } from './mock/premium';
import type { PremiumPlan } from './types';

const KEY = 'kavis.premium';

export function getPremiumOffer() {
  return fakeRequest({ rows: COMPARE_ROWS, plans: PREMIUM_PLANS }, 120);
}

export function isPremium() {
  try {
    return localStorage.getItem(KEY) === '1';
  } catch {
    return false;
  }
}

/** Starts the 3-day free trial of the chosen plan. A real server will create the subscription. */
export function startTrial(_plan: PremiumPlan['id']) {
  try {
    localStorage.setItem(KEY, '1');
  } catch {
    /* ignore */
  }
  return fakeRequest(true);
}

/** Checks earlier purchases; the mock never finds one. */
export function restorePurchases() {
  return fakeRequest(false);
}
