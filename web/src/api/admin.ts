import { supabase } from './supabase';

// The owner's page (/admin): sign-ups, trial / Premium, lessons and AI cost (Edge Function owner-overview, which only
// answers the owner's account). E-mails are personal data (KVKK): only for running the app.

export type AdminUser = {
  email: string;
  name: string;
  joined: string;
  lastLogin: string | null;
  confirmed: boolean;
  status: 'premium' | 'trial' | 'ended';
  lessons: number;
  questions: number;
  cost: number;
};
export type AdminStats = {
  totals: { users: number; new7: number; active7: number; premium: number; trial: number; ended: number; lessons: number; costMonth: number };
  users: AdminUser[];
};

/**
 * 'notAdmin': this account is not the owner. 'failed': the server could not be reached (e.g. a browser add-on
 * blocked it) or answered with an error; the page says so instead of leaving.
 */
export async function getAdminStats(): Promise<AdminStats | 'notAdmin' | 'failed'> {
  const { data, error } = await supabase.functions.invoke('owner-overview', { body: {} });
  if (error) {
    const status = (error as { context?: { status?: number } }).context?.status;
    if (status === 403) return 'notAdmin';
    console.error('owner-overview', error);
    return 'failed';
  }
  return data as AdminStats;
}
