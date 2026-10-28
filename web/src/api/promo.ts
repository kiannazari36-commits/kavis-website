import { supabase } from './supabase';

export type RedeemError = 'rate_limited' | 'unknown' | 'expired' | 'used_up' | 'already_redeemed' | 'promo_active' | 'already_premium' | 'failed';
export type RedeemResult = { ok: true; endsAt: string; days: number } | { ok: false; error: RedeemError; endsAt?: string };

/** Redeems an invite code (Edge Function "redeem-code"): free Premium for the days the code grants, from now. */
export async function redeemCode(code: string): Promise<RedeemResult> {
  const { data, error } = await supabase.functions.invoke('redeem-code', { body: { code } });
  // A 4xx/5xx answer still carries our JSON body in error.context.
  let d = data as { ok?: boolean; error?: string; ends_at?: string; days?: number } | null;
  if (error && !d) d = await (error as { context?: Response }).context?.json().catch(() => null);
  if (!d) return { ok: false, error: 'failed' };
  if (d.ok && d.ends_at) return { ok: true, endsAt: d.ends_at, days: d.days ?? 0 };
  const known = ['rate_limited', 'unknown', 'expired', 'used_up', 'already_redeemed', 'promo_active', 'already_premium'];
  return { ok: false, error: known.includes(d.error ?? '') ? (d.error as RedeemError) : 'failed', endsAt: d.ends_at };
}
