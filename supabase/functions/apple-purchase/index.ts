// Edge Function apple-purchase: Premium bought in the iPhone app (Apple in-app purchase, StoreKit 2). Premium is kept
// in the account (subscriptions), so it unlocks every device through access_status().
// POST { action: 'purchase', signed_transaction } (signed in) → the app sends each transaction it gets (a purchase,
//   a renewal, "Satın alımları geri yükle"). Checked with Apple's certificates; the transaction's appAccountToken must
//   be the student's user id. → { premium, expires_at, status }
// POST { signedPayload } (no login) → App Store Server Notifications V2 (renewal, failed payment, expiry, refund):
//   the subscription with that original transaction id is updated. → 200. A message older than the stored one is
//   ignored (Apple can deliver out of order). During the grace period (failed payment, Apple keeps access on) the
//   subscription counts as Premium until Apple's gracePeriodExpiresDate.
// POST { action: 'restore', signed_transactions: [...] } (signed in) → "Satın alımları geri yükle": the transactions the app
//   found (may be none). → { premium, expires_at, status } | 404 { error: 'no_subscription' } (nothing to restore for this
//   account) | 403 { error: 'account' } (the Apple subscription belongs to another Kavis account) | 403 { error: 'sandbox' }
// verify_jwt is off because Apple's notifications have no login; 'purchase' checks the student's login itself.
// Sandbox / TestFlight / Xcode transactions give Premium only to the user ids in the secret SANDBOX_ALLOWED_USER_IDS
// (comma-separated: the App Review demo account, the owner's test accounts); for everyone else they are refused.
// Writes (service role): subscriptions.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { AppleSignatureError, verifyApple } from './apple.ts';
import { environmentAllowed } from './environment.ts';
import { graceUntil, isStale, restoreOutcome, statusForNotification } from './order.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

function secretKey() {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');
  if (legacy) return legacy;
  const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>;
  return Object.values(keys)[0] ?? '';
}

const BUNDLE_ID = 'study.kavis.app';
/** The products (App Store Connect). The term is a non-renewing 5-month subscription (Apple has no 5-month period). */
const PRODUCTS = ['study.kavis.premium.year', 'study.kavis.premium.term', 'study.kavis.premium.month'];
const TERM_MONTHS = 5;
const allowXcode = () => Deno.env.get('APPLE_ALLOW_XCODE') === '1';

/** The fields of a JWSTransactionDecodedPayload the server uses. */
type Transaction = {
  bundleId: string; productId: string; transactionId: string; originalTransactionId: string; type: string;
  purchaseDate: number; expiresDate?: number; revocationDate?: number; revocationReason?: number;
  appAccountToken?: string; environment: string; signedDate?: number;
};
type RenewalInfo = { gracePeriodExpiresDate?: number; isInBillingRetryPeriod?: boolean };
type Notification = {
  notificationType: string; subtype?: string; signedDate?: number;
  data?: { bundleId: string; environment: string; signedTransactionInfo?: string; signedRenewalInfo?: string };
};

function expiry(t: Transaction): Date | null {
  if (t.expiresDate) return new Date(t.expiresDate);
  if (t.productId.endsWith('.term')) {
    const d = new Date(t.purchaseDate);
    d.setUTCMonth(d.getUTCMonth() + TERM_MONTHS);
    return d;
  }
  return null;
}

/** Status from the transaction itself (a notification can say more: grace period, billing retry). */
function statusOf(t: Transaction, exp: Date | null): string {
  if (t.revocationDate) return t.revocationReason === 1 ? 'refunded' : 'revoked';
  if (exp && exp <= new Date()) return 'expired';
  return 'active';
}

async function save(db: SupabaseClient, uid: string, t: Transaction, status?: string, opts: { signedDate?: number; renewal?: RenewalInfo | null } = {}) {
  let exp = expiry(t);
  // Grace period: Apple keeps the subscriber's access on while it retries the payment, so Premium runs to that date.
  if (status === 'grace') exp = graceUntil(opts.renewal, t.expiresDate, t.purchaseDate);
  const signedDate = opts.signedDate ?? t.signedDate;
  const row = {
    user_id: uid,
    provider: 'apple',
    product_id: t.productId,
    original_transaction_id: t.originalTransactionId,
    status: status ?? statusOf(t, exp),
    started_at: new Date(t.purchaseDate).toISOString(),
    expires_at: exp?.toISOString() ?? null,
    environment: t.environment === 'Production' ? 'production' : 'sandbox',
    raw: { ...t, signedDate },
  };
  // A renewal keeps the first start day (the fair-use month starts on the purchase day).
  const { data: old } = await db.from('subscriptions').select('user_id, started_at, status, expires_at, raw').eq('provider', 'apple').eq('original_transaction_id', t.originalTransactionId).maybeSingle();
  // A purchase stays with the account that bought it.
  if (old && old.user_id !== uid) throw new AppleSignatureError('another account');
  // An older message than the stored one changes nothing (out-of-order delivery).
  if (old && isStale(old, signedDate)) return { ...row, status: old.status, expires_at: old.expires_at, stale: true };
  if (old) row.started_at = old.started_at;
  const { error } = await db.from('subscriptions').upsert(row, { onConflict: 'provider,original_transaction_id' });
  if (error) throw error;
  return row;
}

function checkTransaction(t: Transaction) {
  if (t.bundleId !== BUNDLE_ID) throw new AppleSignatureError('bundle');
  if (!PRODUCTS.includes(t.productId)) throw new AppleSignatureError('product');
}

/** A non-production (free) transaction counts only for the accounts listed in SANDBOX_ALLOWED_USER_IDS. */
const envOk = (t: Transaction, uid: string | undefined | null) => environmentAllowed(t.environment, uid, Deno.env.get('SANDBOX_ALLOWED_USER_IDS'), allowXcode());

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });
  const body = await req.json().catch(() => ({}));

  try {
    // App Store Server Notifications V2.
    if (typeof body.signedPayload === 'string') {
      const n = await verifyApple<Notification>(body.signedPayload, allowXcode());
      if (n.data?.bundleId !== BUNDLE_ID || !n.data.signedTransactionInfo) return json({ ok: true });
      const t = await verifyApple<Transaction>(n.data.signedTransactionInfo, allowXcode());
      checkTransaction(t);
      const { data: sub } = await db.from('subscriptions').select('user_id').eq('provider', 'apple').eq('original_transaction_id', t.originalTransactionId).maybeSingle();
      const uid = sub?.user_id ?? t.appAccountToken?.toLowerCase();
      if (!uid) return json({ ok: true }); // not one of ours yet; the app sends it after the purchase
      if (!envOk(t, uid)) return json({ ok: true }); // a sandbox transaction of an account that may not use sandbox
      const status = statusForNotification(n.notificationType, n.subtype);
      let renewal: RenewalInfo | null = null;
      if (status === 'grace' && n.data.signedRenewalInfo) renewal = await verifyApple<RenewalInfo>(n.data.signedRenewalInfo, allowXcode());
      await save(db, uid, t, status, { signedDate: n.signedDate, renewal });
      return json({ ok: true });
    }

    if (body.action === 'purchase') {
      const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
      const { data: who } = await db.auth.getUser(token);
      if (!who?.user) return json({ error: 'not signed in' }, 401);
      const t = await verifyApple<Transaction>(String(body.signed_transaction ?? ''), allowXcode());
      checkTransaction(t);
      // The app buys with appAccountToken = the student's id, so a purchase cannot be moved to another account.
      if (t.appAccountToken?.toLowerCase() !== who.user.id) return json({ error: 'account' }, 403);
      if (!envOk(t, who.user.id)) return json({ error: 'sandbox' }, 403);
      const row = await save(db, who.user.id, t);
      const { data: premium } = await db.rpc('is_premium', { uid: who.user.id });
      return json({ premium: !!premium, expires_at: row.expires_at, status: row.status });
    }

    if (body.action === 'restore') {
      const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
      const { data: who } = await db.auth.getUser(token);
      if (!who?.user) return json({ error: 'not signed in' }, 401);
      const list: unknown[] = Array.isArray(body.signed_transactions) ? body.signed_transactions.slice(0, 20) : [];
      let matched = 0;
      let foreign = 0;
      for (const jws of list) {
        const t = await verifyApple<Transaction>(String(jws ?? ''), allowXcode());
        checkTransaction(t);
        if (t.appAccountToken?.toLowerCase() !== who.user.id) { foreign++; continue; }
        if (!envOk(t, who.user.id)) return json({ error: 'sandbox' }, 403);
        await save(db, who.user.id, t);
        matched++;
      }
      const { data: mine } = await db.from('subscriptions').select('status, expires_at').eq('user_id', who.user.id).eq('provider', 'apple').order('expires_at', { ascending: false, nullsFirst: true }).limit(1).maybeSingle();
      const outcome = restoreOutcome(matched, foreign, !!mine);
      if (outcome === 'no_subscription') return json({ error: 'no_subscription' }, 404);
      if (outcome === 'account') return json({ error: 'account' }, 403);
      const { data: premium } = await db.rpc('is_premium', { uid: who.user.id });
      return json({ premium: !!premium, expires_at: mine?.expires_at ?? null, status: mine?.status ?? null });
    }
    return json({ error: 'action' }, 400);
  } catch (e) {
    if (e instanceof AppleSignatureError) {
      console.error('apple-purchase: not from Apple', e.message);
      return json({ error: 'signature' }, 400);
    }
    console.error('apple-purchase', e);
    return json({ error: 'purchase' }, 500);
  }
});
