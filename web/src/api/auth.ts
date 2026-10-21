import { fakeRequest } from './client';

export type User = { id: string; name: string; email: string };
export type Provider = 'apple' | 'google';

const SESSION_KEY = 'kavis.session';

function save(user: User) {
  try {
    localStorage.setItem(SESSION_KEY, JSON.stringify(user));
  } catch {
    /* ignore */
  }
  return user;
}

export function currentUser(): User | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    return raw ? (JSON.parse(raw) as User) : null;
  } catch {
    return null;
  }
}

/** Creates the account; the server then emails a 6-digit code. */
export function signUp(name: string, email: string, _password: string) {
  return fakeRequest({ pendingEmail: email || 'elif@ogrenci.edu.tr', name: name || 'Elif Yıldız' });
}

export function verifyEmail(email: string, name: string, code: string) {
  if (code.length !== 6) return Promise.reject(new Error('code'));
  return fakeRequest(save({ id: 'u1', name, email }));
}

export function resendCode(_email: string) {
  return fakeRequest(true);
}

export function logIn(email: string, _password: string) {
  return fakeRequest(save({ id: 'u1', name: 'Elif Yıldız', email: email || 'elif@ogrenci.edu.tr' }));
}

export function socialLogIn(provider: Provider) {
  return fakeRequest(save({ id: 'u1', name: 'Elif Yıldız', email: `elif@${provider}.example` }));
}

export function logOut() {
  try {
    localStorage.removeItem(SESSION_KEY);
  } catch {
    /* ignore */
  }
  return fakeRequest(true, 0);
}
