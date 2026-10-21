import { fakeRequest } from './client';

export type Profile = { name: string; email: string; school: string };

export function saveProfile(p: Profile) {
  return fakeRequest(p);
}

/** Emails the student a copy of their data. */
export function requestMyData() {
  return fakeRequest(true);
}

/** Starts account deletion: the server emails a confirmation link (30 days to change your mind). */
export function deleteAccount() {
  return fakeRequest(true);
}
