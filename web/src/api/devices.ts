import { supabase } from './supabase';
import { logOut } from './auth';

// Device limit (CLAUDE.md): max 2 devices per account, the web counts as one.
// The server keeps the list (table user_devices) and enforces the limit (RPC register_device).
export const MAX_DEVICES = 2;

export type Device = { id: string; name: string; kind: 'iphone' | 'ipad' | 'android' | 'mac' | 'web'; lastUsed: string | null; current: boolean };

/** Every browser shares one install id, so the whole web is one device slot. */
const WEB_INSTALL_ID = 'web';

/** "Web · Chrome · macOS" from the browser. */
export function thisDeviceName() {
  const ua = navigator.userAgent;
  const browser = /Edg\//.test(ua) ? 'Edge' : /Firefox\//.test(ua) ? 'Firefox' : /Chrome\//.test(ua) ? 'Chrome' : /Safari\//.test(ua) ? 'Safari' : 'Browser';
  const os = /iPhone|iPad/.test(ua) ? 'iOS' : /Android/.test(ua) ? 'Android' : /Mac/.test(ua) ? 'macOS' : /Windows/.test(ua) ? 'Windows' : 'Linux';
  return `Web · ${browser} · ${os}`;
}

type Row = { id: string; install_id: string; name: string; kind: Device['kind']; last_seen_at: string };
const toDevice = (r: Row): Device => ({
  id: r.id,
  name: r.name,
  kind: r.kind,
  lastUsed: r.install_id === WEB_INSTALL_ID ? null : r.last_seen_at,
  current: r.install_id === WEB_INSTALL_ID,
});

/** Devices signed in to the account (this browser first). */
export async function listDevices(): Promise<Device[]> {
  const { data, error } = await supabase
    .from('user_devices')
    .select('id, install_id, name, kind, last_seen_at')
    .is('signed_out_at', null)
    .order('last_seen_at', { ascending: false });
  if (error) {
    console.error('listDevices', error);
    return [];
  }
  return (data as Row[]).map(toDevice).sort((a, b) => Number(b.current) - Number(a.current));
}

/**
 * Registers the web as one of the account's devices (after every login and at start).
 * Returns the other devices when the account is already on 2 devices: then the student must sign one out first.
 */
export async function checkDeviceLimit(): Promise<Device[] | null> {
  const { data, error } = await supabase.rpc('register_device', {
    p_install_id: WEB_INSTALL_ID,
    p_kind: 'web',
    p_name: thisDeviceName(),
    p_app_version: null,
  });
  if (error) {
    console.error('register_device', error);
    return null;
  }
  const r = data as { ok: boolean; devices?: { id: string; name: string; kind: Device['kind']; last_seen_at: string }[] };
  if (r.ok) return null;
  return (r.devices ?? []).map((d) => ({ id: d.id, name: d.name, kind: d.kind, lastUsed: d.last_seen_at, current: false }));
}

/**
 * At start: if another device signed the web out, log out here too (signedOut). Otherwise register again,
 * which refreshes "last seen"; full = the account is on 2 other devices now.
 */
export async function checkThisDevice(): Promise<{ signedOut: boolean; full: boolean }> {
  const { data } = await supabase
    .from('user_devices')
    .select('signed_out_at')
    .eq('install_id', WEB_INSTALL_ID)
    .maybeSingle<{ signed_out_at: string | null }>();
  if (data?.signed_out_at) {
    await logOut();
    return { signedOut: true, full: false };
  }
  return { signedOut: false, full: (await checkDeviceLimit()) !== null };
}

/** Signs one device out (RPC sign_out_device). Ending that device's login at once needs the Edge Function "sign-out-device" (later). */
export async function signOutDevice(id: string) {
  const { data, error } = await supabase.rpc('sign_out_device', { p_device_id: id });
  if (error) console.error('sign_out_device', error);
  return data === true;
}

/** On "log out": frees the web's device slot before the login ends. */
export async function signOutThisDevice() {
  const { data } = await supabase.from('user_devices').select('id').eq('install_id', WEB_INSTALL_ID).is('signed_out_at', null).maybeSingle<{ id: string }>();
  if (data) await signOutDevice(data.id);
}
