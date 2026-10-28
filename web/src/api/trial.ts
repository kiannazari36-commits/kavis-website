import { supabase } from './supabase';
import { currentUser } from './auth';

// Free trial (CLAUDE.md): 3 days, max 2 PDFs, 60 assistant questions, each PDF max 100 pages.
export const TRIAL_LIMITS = { days: 3, pdfs: 2, questions: 60, pagesPerPdf: 100 };

export type TrialStatus = {
  premium: boolean;
  /** When Premium ends (null = no end date or not Premium) and where it came from ('apple' | 'promo' | …). */
  premiumUntil: string | null;
  premiumSource: string | null;
  ended: boolean;
  daysLeft: number;
  pdfsUsed: number;
  questionsUsed: number;
};

/** Shown until the server answers (a fresh trial). */
export const TRIAL_START: TrialStatus = { premium: false, premiumUntil: null, premiumSource: null, ended: false, daysLeft: TRIAL_LIMITS.days, pdfsUsed: 0, questionsUsed: 0 };

/** Premium and trial status from the server (RPC access_status); Premium comes from a verified Apple purchase. */
export async function getTrial(): Promise<TrialStatus | null> {
  // Not signed in (landing, login, terms pages): nothing to ask, and the server would answer with a permission error.
  if (!currentUser()) return null;
  const { data, error } = await supabase.rpc('access_status');
  if (error || !data) {
    if (error) console.error('access_status', error);
    return null;
  }
  const a = data as { premium: boolean; premium_until: string | null; premium_source: string | null; trial_ended: boolean; days_left: number; lessons_used: number; questions_used: number };
  return { premium: a.premium, premiumUntil: a.premium_until, premiumSource: a.premium_source, ended: a.trial_ended, daysLeft: a.days_left, pdfsUsed: a.lessons_used, questionsUsed: a.questions_used };
}
