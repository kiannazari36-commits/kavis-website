// Pure helper of build-exam (no database), so it can be tested anywhere.

/**
 * What the apps may show when the exam has fewer questions than asked: how many were asked and built, how many the
 * chosen lessons and question types have in all, and why. `reason` is `not_enough_questions` (the student's lessons
 * have fewer questions of these types than asked) or null when the exam is full. The exam itself is built as before.
 */
export function shortfall(requested: number, built: number, available: number) {
  const short = Math.max(0, requested - built);
  return { requested, built, short, available, reason: short > 0 ? ('not_enough_questions' as const) : null };
}
