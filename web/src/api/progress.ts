import { fakeRequest } from './client';
import { COURSE_RANKING, WEAK_TOPICS, WEEK_MINUTES } from './mock/progress';

export function getProgress() {
  return fakeRequest({ ranking: COURSE_RANKING, weekMinutes: WEEK_MINUTES, weak: WEAK_TOPICS }, 120);
}

/** Turns "congratulations" notifications on or off. */
export function setCheerNotifications(_on: boolean) {
  return fakeRequest(true, 0);
}
