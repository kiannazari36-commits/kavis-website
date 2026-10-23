import { supabase } from './supabase';

// Notifications are written by the server (daily planner, lesson processing, grading, weekly report);
// a scheduled job also sends them as push. The app reads them, marks them read and snoozes them.

export type Notice = {
  id: string;
  kind: string;
  title: string;
  body: string;
  /** Where tapping it goes, e.g. "/cards" (data.to). */
  to: string | null;
  at: string;
  read: boolean;
};

type Row = { id: string; kind: string; title: string; body: string | null; data: { to?: string }; send_at: string; read_at: string | null };

/** Sent notifications, newest first (snoozed ones come back when the snooze ends). */
export async function listNotifications(): Promise<Notice[]> {
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from('notifications')
    .select('id, kind, title, body, data, send_at, read_at')
    .lte('send_at', now)
    .or(`snoozed_until.is.null,snoozed_until.lte.${now}`)
    .order('send_at', { ascending: false })
    .limit(50);
  if (error) {
    console.error('listNotifications', error);
    return [];
  }
  return (data as Row[]).map((r) => ({ id: r.id, kind: r.kind, title: r.title, body: r.body ?? '', to: r.data?.to ?? null, at: r.send_at, read: !!r.read_at }));
}

/** Any unread notification? (the dot on the bell) */
export async function hasUnread() {
  const { count } = await supabase
    .from('notifications')
    .select('id', { count: 'exact', head: true })
    .is('read_at', null)
    .lte('send_at', new Date().toISOString());
  return (count ?? 0) > 0;
}

export async function markAllRead() {
  const { error } = await supabase.from('notifications').update({ read_at: new Date().toISOString() }).is('read_at', null);
  if (error) console.error('markAllRead', error);
}
