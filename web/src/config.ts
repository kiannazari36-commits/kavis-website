// App-wide settings for the web.

/** Kavis Study on the App Store. Empty until the iPhone app is published (see TODO.md). */
export const APP_STORE_URL = '';

/** No Android app yet (CLAUDE.md): Android users use the web with the free trial. */
export const isAndroid = () => /Android/i.test(navigator.userAgent);
