// Edge Function apple-purchase: Premium bought in the iPhone app (Apple in-app purchase, StoreKit 2). Premium is kept
// in the account (subscriptions), so it unlocks every device through access_status().
// POST { action: 'purchase', signed_transaction } (signed in) → the app sends each transaction it gets (a purchase,
//   a renewal, "Satın alımları geri yükle"). Checked with Apple's certificates; the transaction's appAccountToken must
//   be the student's user id. → { premium, expires_at, status }
// POST { signedPayload } (no login) → App Store Server Notifications V2 (renewal, failed payment, expiry, refund):
//   the subscription with that original transaction id is updated. → 200
// verify_jwt is off because Apple's notifications have no login; 'purchase' checks the student's login itself.
// Writes (service role): subscriptions.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { AppleSignatureError, verifyApple } from './apple.ts';

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
  appAccountToken?: string; environment: string;
};
type Notification = {
  notificationType: string; subtype?: string;
  data?: { bundleId: string; environment: string; signedTransactionInfo?: string };
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

async function save(db: SupabaseClient, uid: string, t: Transaction, status?: string) {
  const exp = expiry(t);
  const row = {
    user_id: uid,
    provider: 'apple',
    product_id: t.productId,
    original_transaction_id: t.originalTransactionId,
    status: status ?? statusOf(t, exp),
    started_at: new Date(t.purchaseDate).toISOString(),
    expires_at: exp?.toISOString() ?? null,
    environment: t.environment === 'Production' ? 'production' : 'sandbox',
    raw: t,
  };
  // A renewal keeps the first start day (the fair-use month starts on the purchase day).
  const { data: old } = await db.from('subscriptions').select('user_id, started_at').eq('provider', 'apple').eq('original_transaction_id', t.originalTransactionId).maybeSingle();
  // A purchase stays with the account that bought it.
  if (old && old.user_id !== uid) throw new AppleSignatureError('another account');
  if (old) row.started_at = old.started_at;
  const { error } = await db.from('subscriptions').upsert(row, { onConflict: 'provider,original_transaction_id' });
  if (error) throw error;
  return row;
}

function checkTransaction(t: Transaction) {
  if (t.bundleId !== BUNDLE_ID) throw new AppleSignatureError('bundle');
  if (!PRODUCTS.includes(t.productId)) throw new AppleSignatureError('product');
}

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
      const status =
        n.notificationType === 'DID_FAIL_TO_RENEW' ? (n.subtype === 'GRACE_PERIOD' ? 'grace' : 'billing_retry')
        : n.notificationType === 'GRACE_PERIOD_EXPIRED' || n.notificationType === 'EXPIRED' ? 'expired'
        : n.notificationType === 'REFUND' ? 'refunded'
        : n.notificationType === 'REVOKE' ? 'revoked'
        : undefined;
      await save(db, uid, t, status);
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
      const row = await save(db, who.user.id, t);
      const { data: premium } = await db.rpc('is_premium', { uid: who.user.id });
      return json({ premium: !!premium, expires_at: row.expires_at, status: row.status });
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
