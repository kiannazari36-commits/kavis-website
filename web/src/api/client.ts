// Fake network layer. Replace these helpers with real fetch() calls when the server exists.
export const API_DELAY_MS = 450;

export function fakeRequest<T>(result: T, ms = API_DELAY_MS): Promise<T> {
  return new Promise((resolve) => setTimeout(() => resolve(result), ms));
}
