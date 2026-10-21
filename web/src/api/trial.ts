import { fakeRequest } from './client';
import { isPremium } from './premium';

// Free trial (CLAUDE.md): 3 days, max 2 PDFs, 60 assistant questions, each PDF max 100 pages.
export const TRIAL_LIMITS = { days: 3, pdfs: 2, questions: 60, pagesPerPdf: 100 };

export type TrialStatus = {
  premium: boolean;
  ended: boolean;
  daysLeft: number;
  pdfsUsed: number;
  questionsUsed: number;
};

const KEY = 'kavis.trial';
// Mock states to try the screens: add ?trial=active | full | ended to any address (remembered).
const MOCKS: Record<string, Omit<TrialStatus, 'premium'>> = {
  active: { ended: false, daysLeft: 2, pdfsUsed: 1, questionsUsed: 23 },
  full: { ended: false, daysLeft: 1, pdfsUsed: 2, questionsUsed: 60 },
  ended: { ended: true, daysLeft: 0, pdfsUsed: 2, questionsUsed: 41 },
};

function mockName() {
  const fromUrl = new URLSearchParams(location.search).get('trial');
  try {
    if (fromUrl && MOCKS[fromUrl]) localStorage.setItem(KEY, fromUrl);
    return localStorage.getItem(KEY) ?? 'active';
  } catch {
    return fromUrl ?? 'active';
  }
}

export function getTrialNow(): TrialStatus {
  return { premium: isPremium(), ...(MOCKS[mockName()] ?? MOCKS.active) };
}

export function getTrial() {
  return fakeRequest(getTrialNow(), 0);
}
