import { useEffect, useState } from 'react';

/** Runs an API call when deps change; returns undefined while loading. */
export function useAsync<T>(fn: () => Promise<T>, deps: unknown[]): T | undefined {
  const [data, setData] = useState<T>();
  useEffect(() => {
    let alive = true;
    fn().then((d) => alive && setData(d));
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  return data;
}
