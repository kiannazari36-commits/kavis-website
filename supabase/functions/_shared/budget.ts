// The monthly AI budget, shared by every Edge Function that calls the AI.
// Spending is written with ONE atomic SQL increment (rpc add_usage, service role only); never read-then-write.
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2';

/** AI spending per student per month (US dollars). */
export const MONTHLY_BUDGET_USD = 4;

/** First day of this month, the key of usage_monthly. */
export const thisMonth = () => new Date().toISOString().slice(0, 7) + '-01';

/** True when the student's AI spending this month has reached the budget. Call before every AI call or batch. */
export async function overBudget(db: SupabaseClient, uid: string, month = thisMonth()): Promise<boolean> {
  const { data } = await db.from('usage_monthly').select('cost_usd').eq('user_id', uid).eq('month', month).maybeSingle();
  return Number(data?.cost_usd ?? 0) >= MONTHLY_BUDGET_USD;
}

export type UsageDelta = {
  input?: number;
  output?: number;
  cost?: number;
  generations?: number;
  questions?: number;
  cacheRead?: number;
  cacheWrite?: number;
};

/** Adds to this month's usage atomically; returns the new month cost (or null if the write failed). */
export async function addUsage(db: SupabaseClient, uid: string, u: UsageDelta, month = thisMonth()): Promise<number | null> {
  const { data, error } = await db.rpc('add_usage', {
    p_uid: uid,
    p_month: month,
    p_input: Math.round(u.input ?? 0),
    p_output: Math.round(u.output ?? 0),
    p_cost: Math.round((u.cost ?? 0) * 10000) / 10000,
    p_generations: u.generations ?? 0,
    p_questions: u.questions ?? 0,
    p_cache_read: Math.round(u.cacheRead ?? 0),
    p_cache_write: Math.round(u.cacheWrite ?? 0),
  });
  if (error) {
    console.error('add_usage', error.message);
    return null;
  }
  return Number(data);
}
