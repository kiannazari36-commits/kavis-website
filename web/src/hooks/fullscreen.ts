// Browser fullscreen with the older Safari (webkit) names as fallback.
type FsDocument = Document & {
  webkitFullscreenElement?: Element | null;
  webkitExitFullscreen?: () => Promise<void> | void;
};
type FsElement = HTMLElement & { webkitRequestFullscreen?: () => Promise<void> | void };

export function fullscreenElement(): Element | null {
  const d = document as FsDocument;
  return d.fullscreenElement ?? d.webkitFullscreenElement ?? null;
}

/** Resolves to true when the browser really went fullscreen. */
export async function enterFullscreen(el: HTMLElement = document.documentElement): Promise<boolean> {
  const e = el as FsElement;
  try {
    if (e.requestFullscreen) await e.requestFullscreen();
    else if (e.webkitRequestFullscreen) await e.webkitRequestFullscreen();
    else return false;
    return true;
  } catch {
    // Refused (e.g. inside an embedded preview, or iPhone Safari): focus mode still works.
    return false;
  }
}

export async function exitFullscreen() {
  if (!fullscreenElement()) return;
  const d = document as FsDocument;
  try {
    if (d.exitFullscreen) await d.exitFullscreen();
    else await d.webkitExitFullscreen?.();
  } catch {
    /* already left */
  }
}

/** Calls cb whenever the browser enters or leaves fullscreen (including Esc). */
export function onFullscreenChange(cb: () => void) {
  document.addEventListener('fullscreenchange', cb);
  document.addEventListener('webkitfullscreenchange', cb);
  return () => {
    document.removeEventListener('fullscreenchange', cb);
    document.removeEventListener('webkitfullscreenchange', cb);
  };
}
