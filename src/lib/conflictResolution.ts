import { MMKV } from 'react-native-mmkv';
import { getSyncQueue } from './offlineSync';
import { supabase } from './supabase';

const CONFLICT_WINDOW_MS = 15 * 60 * 1000; // 15 minutes (smarter window)
const storage = new MMKV({ encryptionKey: process.env.EXPO_PUBLIC_MMKV_ENCRYPTION_KEY || 'DuaSaku-BankGrade-SecureKey-2026' });

interface TransactionCheck {
  amount: number;
  type: 'expense' | 'income';
  user_id: string | null;
  created_at: string;
}

/**
 * Checks if a similar transaction already exists in the local sync queue.
 */
function checkLocalDuplicate(newTx: TransactionCheck): boolean {
  const queue = getSyncQueue();
  const newDate = new Date(newTx.created_at).getTime();

  return queue.some(tx => {
    if (!tx.created_at || tx.amount === undefined) return false;
    const txDate = new Date(tx.created_at).getTime();
    const isSimilarTime = Math.abs(newDate - txDate) <= CONFLICT_WINDOW_MS;
    const isSameAmount = Math.abs(tx.amount) === Math.abs(newTx.amount);
    const isSameType = tx.type === newTx.type;
    const isSameUser = tx.user_id === newTx.user_id;

    return isSimilarTime && isSameAmount && isSameType && isSameUser;
  });
}

/**
 * Checks if a similar transaction exists in the background cache (offline_transactions).
 */
function checkCacheDuplicate(newTx: TransactionCheck): boolean {
  const raw = storage.getString('offline_transactions');
  if (!raw) return false;

  try {
    const cache: any[] = JSON.parse(raw);
    const newDate = new Date(newTx.created_at).getTime();

    return cache.some(tx => {
      if (!tx.created_at || tx.amount === undefined) return false;
      const txDate = new Date(tx.created_at).getTime();
      const isSimilarTime = Math.abs(newDate - txDate) <= CONFLICT_WINDOW_MS;
      const isSameAmount = Math.abs(tx.amount) === Math.abs(newTx.amount);
      const isSameType = tx.type === newTx.type;
      const isSameUser = tx.user_id === newTx.user_id;

      return isSimilarTime && isSameAmount && isSameType && isSameUser;
    });
  } catch {
    return false;
  }
}

/**
 * Checks if a similar transaction already exists in Supabase.
 */
async function checkServerDuplicate(newTx: TransactionCheck): Promise<boolean> {
  if (!newTx.user_id) return false;

  const newDate = new Date(newTx.created_at);
  const startTime = new Date(newDate.getTime() - CONFLICT_WINDOW_MS).toISOString();
  const endTime = new Date(newDate.getTime() + CONFLICT_WINDOW_MS).toISOString();

  const { data, error } = await supabase
    .from('transactions')
    .select('id')
    .eq('user_id', newTx.user_id)
    .eq('amount', newTx.amount)
    .eq('type', newTx.type)
    .gte('created_at', startTime)
    .lte('created_at', endTime)
    .limit(1);

  if (error) {
    console.warn('[ConflictResolution] Server check failed:', error);
    return false;
  }

  return data && data.length > 0;
}

/**
 * Main entry point to verify if a transaction is a duplicate.
 */
export async function isDuplicateTransaction(newTx: TransactionCheck): Promise<boolean> {
  // 1. Check local queue first (fast)
  if (checkLocalDuplicate(newTx)) return true;

  // 2. Check local history cache (offline-safe)
  if (checkCacheDuplicate(newTx)) return true;

  // 3. Check server (if online)
  try {
    const isDupe = await checkServerDuplicate(newTx);
    return isDupe;
  } catch {
    return false;
  }
}
