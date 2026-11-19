import { assertEquals } from 'jsr:@std/assert@1';
import { environmentAllowed } from './environment.ts';

const U1 = '11111111-1111-1111-1111-111111111111';
const U2 = '22222222-2222-2222-2222-222222222222';

Deno.test('production is always accepted', () => {
  assertEquals(environmentAllowed('Production', U1, '', false), true);
});
Deno.test('sandbox only for listed accounts', () => {
  assertEquals(environmentAllowed('Sandbox', U1, `${U1}, ${U2}`, false), true);
  assertEquals(environmentAllowed('Sandbox', U2, U1, false), false);
  assertEquals(environmentAllowed('Sandbox', U1, undefined, false), false);
  assertEquals(environmentAllowed('Sandbox', null, U1, false), false);
  assertEquals(environmentAllowed('Sandbox', U1.toUpperCase(), U1, false), true);
});
Deno.test('Xcode only in the local copy', () => {
  assertEquals(environmentAllowed('Xcode', U1, '', false), false);
  assertEquals(environmentAllowed('Xcode', U1, '', true), true);
  assertEquals(environmentAllowed('Sandbox', U1, '', true), false);
});
