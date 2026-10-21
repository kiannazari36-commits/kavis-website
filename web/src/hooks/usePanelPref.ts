import { useCallback, useState } from 'react';

/**
 * Open/closed state of a side panel, remembered in the browser.
 * Without a saved choice the panel starts open only on screens at least `openFrom` px wide.
 */
export function usePanelPref(key: string, openFrom: number): [boolean, (open: boolean) => void] {
  const [open, setOpenState] = useState(() => {
    try {
      const v = localStorage.getItem(key);
      if (v === '1' || v === '0') return v === '1';
    } catch {
      /* ignore */
    }
    return window.innerWidth >= openFrom;
  });

  const setOpen = useCallback(
    (v: boolean) => {
      setOpenState(v);
      try {
        localStorage.setItem(key, v ? '1' : '0');
      } catch {
        /* ignore */
      }
    },
    [key],
  );

  return [open, setOpen];
}
