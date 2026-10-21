import { fakeRequest } from './client';
import type { L10n } from './types';

// Device limit (CLAUDE.md): max 2 devices per account, the web counts as one.
// UI only for now: the list and the limit check are mock data until the server exists.
export const MAX_DEVICES = 2;

export type Device = { id: string; name: string; kind: 'iphone' | 'ipad' | 'web'; lastUsed: L10n | null; current: boolean };

const OTHER_DEVICES: Device[] = [
  { id: 'iphone', name: 'iPhone 15', kind: 'iphone', current: false, lastUsed: { tr: 'Bugün 09:12', en: 'Today 09:12', fa: 'امروز ۰۹:۱۲', ar: 'اليوم 09:12' } },
  { id: 'ipad', name: 'iPad Air', kind: 'ipad', current: false, lastUsed: { tr: 'Dün 21:40', en: 'Yesterday 21:40', fa: 'دیروز ۲۱:۴۰', ar: 'أمس 21:40' } },
];

/** "Web · Chrome · macOS" from the browser. */
export function thisDeviceName() {
  const ua = navigator.userAgent;
  const browser = /Edg\//.test(ua) ? 'Edge' : /Firefox\//.test(ua) ? 'Firefox' : /Chrome\//.test(ua) ? 'Chrome' : /Safari\//.test(ua) ? 'Safari' : 'Browser';
  const os = /iPhone|iPad/.test(ua) ? 'iOS' : /Android/.test(ua) ? 'Android' : /Mac/.test(ua) ? 'macOS' : /Windows/.test(ua) ? 'Windows' : 'Linux';
  return `Web · ${browser} · ${os}`;
}

const KEY = 'kavis.devices';
const signedOut = (): string[] => {
  try {
    return JSON.parse(localStorage.getItem(KEY) || '[]');
  } catch {
    return [];
  }
};

/** Devices signed in to the account. Mock: the iPhone plus this browser. */
export function listDevices(): Promise<Device[]> {
  const others = OTHER_DEVICES.filter((d) => d.id === 'iphone' && !signedOut().includes(d.id));
  return fakeRequest([...others, { id: 'web', name: thisDeviceName(), kind: 'web', lastUsed: null, current: true }], 120);
}

/**
 * Called after login. Returns the other devices when the account is already on 2 devices.
 * Mock: full only when the login page was opened with ?devices=full.
 */
export function checkDeviceLimit(full: boolean): Promise<Device[] | null> {
  const others = OTHER_DEVICES.filter((d) => !signedOut().includes(d.id));
  return fakeRequest(full && others.length >= MAX_DEVICES ? others : null, 150);
}

export function signOutDevice(id: string) {
  try {
    localStorage.setItem(KEY, JSON.stringify([...signedOut(), id]));
  } catch {
    /* ignore */
  }
  return fakeRequest(true);
}
