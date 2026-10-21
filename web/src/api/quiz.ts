import { fakeRequest } from './client';
import { EXAM_TOPICS, QUIZ_QUESTIONS } from './mock/quiz';
import type { ExamTopic, QuizQuestion } from './types';

/** Exam-prep pack for a course: summary topics by importance + questions in the lecturer's style. */
export function getExamPack(_courseId: string): Promise<{ topics: ExamTopic[]; questions: QuizQuestion[] }> {
  return fakeRequest({ topics: EXAM_TOPICS, questions: QUIZ_QUESTIONS }, 150);
}

export function addWrongsToPlan(_questionIndexes: number[]) {
  return fakeRequest(true);
}

export function setStudyReminder(_time: string) {
  return fakeRequest(true);
}
