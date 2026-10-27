import { COMPARE_ROWS, PREMIUM_PLANS } from './premiumOffer';

// Premium is bought only in the iPhone app (Apple in-app purchase). The web only shows what Premium gives;
// the student's own status comes from access_status() (api/trial.ts). Same text for every student, so no server call.
export const premiumOffer = { rows: COMPARE_ROWS, plans: PREMIUM_PLANS };
