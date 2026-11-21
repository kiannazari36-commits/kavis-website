// Run: node --experimental-strip-types supabase/functions/apple-purchase/order.test.ts
import { graceUntil, isStale, restoreOutcome, statusForNotification } from './order.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
const DAY = 86_400_000;

// 1. grace period
check('grace: Apple\'s gracePeriodExpiresDate is used', graceUntil({ gracePeriodExpiresDate: 5_000 * DAY }, 1_000 * DAY, 0).getTime() === 5_000 * DAY);
check('grace: without it, expiry + 16 days', graceUntil(null, 1_000 * DAY, 0).getTime() === 1_016 * DAY);
check('grace: no expiry date → purchase date + 16 days', graceUntil(undefined, undefined, 100 * DAY).getTime() === 116 * DAY);
check('DID_FAIL_TO_RENEW + GRACE_PERIOD → grace', statusForNotification('DID_FAIL_TO_RENEW', 'GRACE_PERIOD') === 'grace');
check('DID_FAIL_TO_RENEW alone → billing_retry', statusForNotification('DID_FAIL_TO_RENEW') === 'billing_retry');
check('EXPIRED / GRACE_PERIOD_EXPIRED → expired', statusForNotification('EXPIRED', 'VOLUNTARY') === 'expired' && statusForNotification('GRACE_PERIOD_EXPIRED') === 'expired');
check('REFUND / REVOKE', statusForNotification('REFUND') === 'refunded' && statusForNotification('REVOKE') === 'revoked');
check('DID_RENEW → decided by the transaction', statusForNotification('DID_RENEW') === undefined);

// 2. order
check('older message is stale', isStale({ raw: { signedDate: 2000 } }, 1000));
check('newer message is not stale', !isStale({ raw: { signedDate: 1000 } }, 2000));
check('same message again is not stale', !isStale({ raw: { signedDate: 1000 } }, 1000));
check('old row without a date is not stale', !isStale({ raw: {} }, 1000) && !isStale({ raw: null }, 1000) && !isStale(null, 1000));
check('message without a date is not stale', !isStale({ raw: { signedDate: 5000 } }, undefined));

// 3. restore
check('restore: own transaction → ok', restoreOutcome(1, 0, false) === 'ok');
check('restore: nothing sent, nothing stored → no_subscription', restoreOutcome(0, 0, false) === 'no_subscription');
check('restore: only another account\'s transactions → account', restoreOutcome(0, 2, false) === 'account');
check('restore: nothing matches but the account already has a subscription → ok', restoreOutcome(0, 1, true) === 'ok');
if (fails) process.exit(1);
