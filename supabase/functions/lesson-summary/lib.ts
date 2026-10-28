// Pure helpers (no database, no AI).

/** Claude Sonnet 5.5 list price in US dollars (input $2, output $10 per million tokens). */
// Cache writes (5 minutes) $2.50, cache reads $0.20 per million tokens.
export const costUsd = (input: number, output: number, cacheWrite = 0, cacheRead = 0) =>
  Math.round(((input * 2 + output * 10 + cacheWrite * 2.5 + cacheRead * 0.2) / 1_000_000) * 10000) / 10000;
