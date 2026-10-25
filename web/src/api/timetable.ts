import { supabase } from './supabase';
import { currentUser } from './auth';
import { photoForAssistant } from './assistant';

// School timetable ("Okul ders programım", design NewSchedule). Typed in by the student (own rows), or read from a
// photo / PDF by the server (Edge Function import-timetable): the student checks the list, then the rows are added.

export type ClassEntry = {
  id: string;
  /** 1 = Monday … 7 = Sunday */
  weekday: number;
  start: string;
  end: string | null;
  title: string;
  room: string | null;
  teacher: string | null;
  remind: boolean;
  courseId: string | null;
};

type Row = { id: string; weekday: number; start_time: string; end_time: string | null; title: string; room: string | null; teacher: string | null; remind: boolean; course_id: string | null };
const hm = (t: string | null) => (t ? t.slice(0, 5) : null);

export async function listClasses(): Promise<ClassEntry[]> {
  const { data, error } = await supabase
    .from('timetable_entries')
    .select('id, weekday, start_time, end_time, title, room, teacher, remind, course_id')
    .order('weekday')
    .order('start_time');
  if (error) console.error('listClasses', error);
  return ((data ?? []) as Row[]).map((r) => ({
    id: r.id,
    weekday: r.weekday,
    start: hm(r.start_time)!,
    end: hm(r.end_time),
    title: r.title,
    room: r.room,
    teacher: r.teacher,
    remind: r.remind,
    courseId: r.course_id,
  }));
}

export async function addClass(c: Omit<ClassEntry, 'id' | 'remind'>) {
  const user = currentUser();
  if (!user) return null;
  const { data, error } = await supabase
    .from('timetable_entries')
    .insert({
      user_id: user.id,
      weekday: c.weekday,
      start_time: c.start,
      end_time: c.end || null,
      title: c.title.trim(),
      room: c.room?.trim() || null,
      teacher: c.teacher?.trim() || null,
      course_id: c.courseId,
    })
    .select('id')
    .single();
  if (error) console.error('addClass', error);
  return data?.id as string | undefined;
}

export async function setClassRemind(id: string, remind: boolean) {
  const { error } = await supabase.from('timetable_entries').update({ remind }).eq('id', id);
  if (error) console.error('setClassRemind', error);
}

export async function deleteClass(id: string) {
  const { error } = await supabase.from('timetable_entries').delete().eq('id', id);
  if (error) console.error('deleteClass', error);
}

/** A class found on the timetable photo / PDF, before the student adds it. */
export type FoundClass = Omit<ClassEntry, 'id' | 'remind' | 'courseId'>;

/** Reads a timetable photo (made small first) or PDF (at most 10 MB) on the server (AI, about 1-2 cents). */
export async function readTimetable(file: File): Promise<FoundClass[] | { error: 'file' | 'budget' | 'failed' }> {
  const pdf = file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf');
  let payload: { media_type: string; data: string };
  try {
    if (pdf) {
      if (file.size > 10 * 1048576) return { error: 'file' };
      const bytes = new Uint8Array(await file.arrayBuffer());
      let bin = '';
      for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
      payload = { media_type: 'application/pdf', data: btoa(bin) };
    } else payload = await photoForAssistant(file);
  } catch {
    return { error: 'file' };
  }
  const { data, error } = await supabase.functions.invoke('import-timetable', { body: { file: payload } });
  if (error) {
    const status = (error as { context?: { status?: number } }).context?.status;
    return { error: status === 429 ? 'budget' : status === 400 ? 'file' : 'failed' };
  }
  return (data as { classes: FoundClass[] }).classes;
}
