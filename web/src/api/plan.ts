import { fakeRequest } from './client';
import { BASIC_WEEK, SMART_WEEK } from './mock/plan';
import type { PlanItem } from './types';

export type PlanStage = 'basic' | 'smart';

/** The week plan (Monday first). The mock minutes are for 1.5 h a day. */
export function getWeekPlan(stage: PlanStage): Promise<PlanItem[][]> {
  return fakeRequest(stage === 'smart' ? SMART_WEEK : BASIC_WEEK, 120);
}

/** Moves yesterday's missed tasks to free days. */
export function rescheduleMissed() {
  return fakeRequest(true);
}
