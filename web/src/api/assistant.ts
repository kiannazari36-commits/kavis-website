import { fakeRequest } from './client';
import { ASSISTANT_TOPICS, SAMPLE_ATTACHMENTS } from './mock/assistant';
import type { AssistantTopic, Attachment, AttachmentKind } from './types';

export type SourceMode = 'pdf' | 'ai';

export function listAssistantTopics(): Promise<AssistantTopic[]> {
  return fakeRequest(ASSISTANT_TOPICS, 120);
}

/** Uploads a file; the server guesses which course it belongs to. */
export function uploadForAssistant(kind: AttachmentKind): Promise<Attachment> {
  return fakeRequest(SAMPLE_ATTACHMENTS[kind], 300);
}

/** Asks the assistant. The mock always returns the topic's sample answer. */
export function askAssistant(topicId: string, _question: string, _mode: SourceMode) {
  const topic = ASSISTANT_TOPICS.find((t) => t.id === topicId) ?? ASSISTANT_TOPICS[0];
  return fakeRequest(topic.sample, 500);
}
