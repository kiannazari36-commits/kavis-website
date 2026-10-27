import { supabase } from './supabase';

export type HelpTurn = { role: 'user' | 'assistant'; content: string };
export type HelpResult = { answer: string; escalate: boolean } | { error: 'limit' | 'other' };

/**
 * Asks the AI help chat (Edge Function "help-chat", Claude Haiku). Nothing is saved: the page keeps the chat only in
 * its own memory and sends the last few turns each time.
 */
export async function askHelp(messages: HelpTurn[], lang: string): Promise<HelpResult> {
  const { data, error } = await supabase.functions.invoke('help-chat', { body: { messages: messages.slice(-6), lang } });
  if (error) {
    const status = (error as { context?: Response }).context?.status;
    return { error: status === 429 ? 'limit' : 'other' };
  }
  if (!data || typeof data.answer !== 'string') return { error: 'other' };
  return { answer: data.answer, escalate: !!data.escalate };
}
