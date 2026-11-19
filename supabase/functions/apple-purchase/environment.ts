// Which App Store environments may give Premium. Real purchases (Production) always can.
// Sandbox / TestFlight / Xcode transactions cost nothing, so they count only for accounts the owner listed in the
// Supabase secret SANDBOX_ALLOWED_USER_IDS (comma-separated user ids: the App Review demo account, the owner's own
// test accounts). The local copy (APPLE_ALLOW_XCODE=1) also accepts Xcode's test transactions.

export function allowedIds(list: string | undefined | null): Set<string> {
  return new Set((list ?? '').split(/[\s,;]+/).map((x) => x.trim().toLowerCase()).filter(Boolean));
}

export function environmentAllowed(environment: string, uid: string | undefined | null, list: string | undefined | null, allowXcode: boolean): boolean {
  if (environment === 'Production') return true;
  if (allowXcode && (environment === 'Xcode' || environment === 'LocalTesting')) return true;
  return !!uid && allowedIds(list).has(uid.toLowerCase());
}
