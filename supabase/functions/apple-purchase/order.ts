// Pure helpers for apple-purchase: notification order, grace period, restore outcome (tested in order.test.ts).

/** Apple lets a subscriber keep access for up to 16 days while it retries a failed payment (grace period). */
export const GRACE_FALLBACK_DAYS = 16;

type Stored = { raw?: { signedDate?: number } | null } | null | undefined;

/**
 * A message older than the one already stored must not overwrite it (Apple can deliver out of order: an old EXPIRED
 * arriving after a newer DID_RENEW would switch Premium off). `signedDate` = when Apple signed it (ms).
 * A stored row without a date (written before this check) or a message without a date is never "stale".
 */
export function isStale(stored: Stored, incomingSignedDate: number | undefined): boolean {
  const have = stored?.raw?.signedDate;
  if (typeof have !== 'number' || typeof incomingSignedDate !== 'number') return false;
  return incomingSignedDate < have;
}

/** Until when Premium stays on while the payment is retried: Apple's gracePeriodExpiresDate (renewal info), else expiry + 16 days. */
export function graceUntil(renewal: { gracePeriodExpiresDate?: number } | null | undefined, expiresDate: number | undefined, purchaseDate: number): Date {
  if (renewal?.gracePeriodExpiresDate) return new Date(renewal.gracePeriodExpiresDate);
  return new Date((expiresDate ?? purchaseDate) + GRACE_FALLBACK_DAYS * 86_400_000);
}

/** Subscription status a notification stands for (undefined = the transaction alone tells it). */
export function statusForNotification(type: string, subtype?: string): string | undefined {
  if (type === 'DID_FAIL_TO_RENEW') return subtype === 'GRACE_PERIOD' ? 'grace' : 'billing_retry';
  if (type === 'GRACE_PERIOD_EXPIRED' || type === 'EXPIRED') return 'expired';
  if (type === 'REFUND') return 'refunded';
  if (type === 'REVOKE') return 'revoked';
  return undefined;
}

/**
 * Result of "Restore purchases". The app sends the transactions it finds (can be none).
 *  matched: transactions that belong to this account; foreign: transactions bought by another account (appAccountToken
 *  is someone else's id); stored: this account already has a subscription row.
 *  'ok' = answer with the account's Premium state; 'no_subscription' (404) = nothing to restore for this account;
 *  'account' (403) = the Apple subscription belongs to another Kavis account.
 */
export function restoreOutcome(matched: number, foreign: number, stored: boolean): 'ok' | 'no_subscription' | 'account' {
  if (matched > 0 || stored) return 'ok';
  return foreign > 0 ? 'account' : 'no_subscription';
}
