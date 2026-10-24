import { supabase } from './supabase';
import { currentUser } from './auth';

// "Kendi planım": the student's own weekly plan (table own_plan_items, written by the app).

export type OwnItem = { id: string; weekday: number; courseId: string; minutes: number };

export async function listOwnPlan(): Promise<OwnItem[]> {
  const { data, error } = await supabase.from('own_plan_items').select('id, weekday, course_id, minutes').order('weekday').order('sort_order');
  if (error) console.error('listOwnPlan', error);
  return (data ?? []).map((r) => ({ id: r.id, weekday: r.weekday, courseId: r.course_id, minutes: r.minutes }));
}

export async function addOwnItem(weekday: number, courseId: string, order: number, minutes = 45) {
  const user = currentUser();
  if (!user) return null;
  const { data, error } = await supabase
    .from('own_plan_items')
    .insert({ user_id: user.id, weekday, course_id: courseId, minutes, sort_order: order })
    .select('id')
    .single();
  if (error) console.error('addOwnItem', error);
  return (data?.id as string) ?? null;
}

export async function setOwnMinutes(id: string, minutes: number) {
  const { error } = await supabase.from('own_plan_items').update({ minutes }).eq('id', id);
  if (error) console.error('setOwnMinutes', error);
}

export async function removeOwnItem(id: string) {
  const { error } = await supabase.from('own_plan_items').delete().eq('id', id);
  if (error) console.error('removeOwnItem', error);
}
