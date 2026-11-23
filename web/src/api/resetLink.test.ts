// Run: node --experimental-strip-types web/src/api/resetLink.test.ts
import { resetPlan } from './resetLink.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};

check('token_hash link is verified by the page', resetPlan('?mode=reset&token_hash=abc&type=recovery', '', false) === 'verify');
check('token_hash without type is still a recovery', resetPlan('?mode=reset&token_hash=abc', '', false) === 'verify');
check('token_hash of another type is not a reset', resetPlan('?mode=reset&token_hash=abc&type=signup', '', false) === 'expired');
check('old-style link that signed in shows the form', resetPlan('?mode=reset', '', true) === 'form');
check('used link (#error=...) is expired', resetPlan('?mode=reset', '#error=access_denied&error_code=otp_expired', false) === 'expired');
check('used link is expired even if an old session exists', resetPlan('?mode=reset', '#error=access_denied&error_code=otp_expired', true) === 'expired');
check('iPhone (PKCE) link has ?code= and no session', resetPlan('?code=1234&mode=reset', '', false) === 'app');
check('no session and no link data is expired', resetPlan('?mode=reset', '', false) === 'expired');
check('consent state does not matter: only session and link decide', resetPlan('?mode=reset', '', true) === 'form');
if (fails) throw new Error(`${fails} failed`);
