// App-wide settings for the web.

// Store pages of the apps. Empty = not published yet: the button shows "Yakında" and cannot be clicked.
// Put the real link here when the app is live (see TODO.md).
/** Kavis Study iPhone / iPad app on the App Store. */
export const APP_STORE_URL = '';
/** Android app on Google Play (no Android app yet, CLAUDE.md). */
export const PLAY_STORE_URL = '';
/** Mac app on the Mac App Store. */
export const MAC_STORE_URL = '';

/** No Android app yet (CLAUDE.md): Android users use the web with the free trial. */
export const isAndroid = () => /Android/i.test(navigator.userAgent);

/** Support e-mail and how fast we answer it (shown on the Help page; Kian may change it to 48 later). */
export const SUPPORT_EMAIL = 'kavisstudy@gmail.com';
export const SUPPORT_REPLY_HOURS = 24;
