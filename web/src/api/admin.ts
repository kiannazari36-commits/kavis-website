import { supabase } from './supabase';

// The owner's page (/admin): sign-ups, trial / Premium, lessons and AI cost (Edge Function admin-stats, which only
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

/** null: this account is not the owner (or the server could not answer). */
export async function getAdminStats(): Promise<AdminStats | null> {
  const { data, error } = await supabase.functions.invoke('admin-stats', { body: {} });
  if (error) return null;
  return data as AdminStats;
}
