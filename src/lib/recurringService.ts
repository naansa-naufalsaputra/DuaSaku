/**
 * Recurring Transactions Service
 *
 * Manages templates for recurring expenses/incomes (kos, paket data, gaji, etc.)
 * Uses Supabase table `recurring_transactions` to store templates.
 *
 * Schema:
 *   id            UUID (auto)
 *   user_id       UUID (auth.users FK)
 *   title         TEXT
 *   amount        NUMERIC
 *   category      TEXT
 *   type          'expense' | 'income'
 *   frequency     'daily' | 'weekly' | 'monthly'
 *   day_of_week   INT (0-6, Sunday=0) — used for weekly
 *   day_of_month  INT (1-31) — used for monthly
 *   next_due      DATE — the next date this should fire
 *   is_active     BOOLEAN
 *   created_at    TIMESTAMPTZ (auto)
 */

import { supabase } from './supabase';
import { enqueueTransaction } from './offlineSync';
import { DeviceEventEmitter } from 'react-native';
import { useUserStore } from '../store/useUserStore';

export type RecurrenceFrequency = 'daily' | 'weekly' | 'monthly';

export interface RecurringTransaction {
  id: string;
  user_id: string | null;
  title: string;
  amount: number;
  category: string;
  type: 'expense' | 'income';
  frequency: RecurrenceFrequency;
  day_of_week: number | null;
  day_of_month: number | null;
  next_due: string; // YYYY-MM-DD
  is_active: boolean;
  created_at: string;
}

export interface CreateRecurringInput {
  title: string;
  amount: number;
  category: string;
  type: 'expense' | 'income';
  frequency: RecurrenceFrequency;
  day_of_week?: number;
  day_of_month?: number;
}

const FREQUENCY_LABELS: Record<RecurrenceFrequency, string> = {
  daily: 'Harian',
  weekly: 'Mingguan',
  monthly: 'Bulanan',
};

export function getFrequencyLabel(freq: RecurrenceFrequency): string {
  return FREQUENCY_LABELS[freq] || freq;
}

/** Calculate next due date based on frequency */
function calculateNextDue(frequency: RecurrenceFrequency, dayOfWeek?: number, dayOfMonth?: number): string {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  if (frequency === 'daily') {
    // Next occurrence is tomorrow
    const next = new Date(today);
    next.setDate(next.getDate() + 1);
    return next.toISOString().split('T')[0];
  }

  if (frequency === 'weekly') {
    const targetDay = dayOfWeek ?? 1; // Default Monday
    const currentDay = today.getDay();
    let daysUntil = targetDay - currentDay;
    if (daysUntil <= 0) daysUntil += 7;
    const next = new Date(today);
    next.setDate(next.getDate() + daysUntil);
    return next.toISOString().split('T')[0];
  }

  if (frequency === 'monthly') {
    const targetDom = dayOfMonth ?? 1; // Default 1st
    let next = new Date(today.getFullYear(), today.getMonth(), targetDom);
    if (next <= today) {
      next = new Date(today.getFullYear(), today.getMonth() + 1, targetDom);
    }
    return next.toISOString().split('T')[0];
  }

  return today.toISOString().split('T')[0];
}

/** Advance the next_due date after processing a recurring transaction */
function advanceNextDue(current: string, frequency: RecurrenceFrequency, dayOfWeek?: number | null, dayOfMonth?: number | null): string {
  const d = new Date(current + 'T00:00:00');

  if (frequency === 'daily') {
    d.setDate(d.getDate() + 1);
  } else if (frequency === 'weekly') {
    d.setDate(d.getDate() + 7);
  } else if (frequency === 'monthly') {
    d.setMonth(d.getMonth() + 1);
    if (dayOfMonth) {
      d.setDate(Math.min(dayOfMonth, new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()));
    }
  }

  return d.toISOString().split('T')[0];
}

/** Fetch all recurring transactions for a user */
export async function fetchRecurringTransactions(userId: string): Promise<RecurringTransaction[]> {
  const { data, error } = await supabase
    .from('recurring_transactions')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: true });

  if (error) {
    console.error('[RecurringService] Fetch error:', error);
    return [];
  }
  return (data as RecurringTransaction[]) || [];
}

/** Create a new recurring transaction template */
export async function createRecurring(input: CreateRecurringInput): Promise<{ success: boolean; error?: string }> {
  const nextDue = calculateNextDue(input.frequency, input.day_of_week, input.day_of_month);

  const { session } = useUserStore.getState();
  const userId = session?.user?.id;

  const { error } = await supabase.from('recurring_transactions').insert([{
    user_id: userId || null,
    title: input.title,
    amount: input.amount,
    category: input.category,
    type: input.type,
    frequency: input.frequency,
    day_of_week: input.frequency === 'weekly' ? (input.day_of_week ?? 1) : null,
    day_of_month: input.frequency === 'monthly' ? (input.day_of_month ?? 1) : null,
    next_due: nextDue,
    is_active: true,
  }]);

  if (error) return { success: false, error: error.message };
  return { success: true };
}

/** Toggle active state of a recurring transaction */
export async function toggleRecurring(id: string, isActive: boolean): Promise<boolean> {
  const { session } = useUserStore.getState();
  const userId = session?.user?.id;
  if (!userId) return false;

  const { error } = await supabase
    .from('recurring_transactions')
    .update({ is_active: isActive })
    .eq('id', id)
    .eq('user_id', userId);

  if (error) {
    console.error('[RecurringService] Toggle error:', error);
    return false;
  }
  return true;
}

/** Delete a recurring transaction */
export async function deleteRecurring(id: string): Promise<boolean> {
  const { session } = useUserStore.getState();
  const userId = session?.user?.id;
  if (!userId) return false;

  const { error } = await supabase
    .from('recurring_transactions')
    .delete()
    .eq('id', id)
    .eq('user_id', userId);

  if (error) {
    console.error('[RecurringService] Delete error:', error);
    return false;
  }
  return true;
}

/**
 * Process all due recurring transactions for a user.
 * Called by the background fetch task and on app startup.
 *
 * For each active recurring transaction where next_due <= today:
 *   1. Enqueue a real transaction (offline-first)
 *   2. Advance next_due to the next occurrence
 */
export async function processDueRecurrences(userId: string): Promise<{ processed: number }> {
  const today = new Date().toISOString().split('T')[0];

  const { data, error } = await supabase
    .from('recurring_transactions')
    .select('*')
    .eq('user_id', userId)
    .eq('is_active', true)
    .lte('next_due', today);

  if (error || !data || data.length === 0) {
    return { processed: 0 };
  }

  const updatePromises = (data as RecurringTransaction[]).map(async (rt) => {
    // Insert as a real transaction via the offline queue
    enqueueTransaction({
      title: `${rt.title} (auto)`,
      amount: rt.amount,
      type: rt.type,
      category: rt.category,
      latitude: null,
      longitude: null,
      location_name: null,
      created_at: `${rt.next_due}T08:00:00.000Z`,
      user_id: rt.user_id,
    });

    // Advance next_due
    const newDue = advanceNextDue(rt.next_due, rt.frequency, rt.day_of_week, rt.day_of_month);
    return supabase
      .from('recurring_transactions')
      .update({ next_due: newDue })
      .eq('id', rt.id);
  });

  const results = await Promise.all(updatePromises);
  const processed = results.filter(r => !r.error).length;

  if (processed > 0) {
    DeviceEventEmitter.emit('transaction_added');
  }

  return { processed };
}
