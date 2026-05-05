/**
 * Offline Sync Engine for DuaSaku
 *
 * Strategy: "Local-first, sync-when-online"
 * 1. Every transaction is saved to MMKV queue immediately (zero latency UX)
 * 2. If online, push to Supabase in background and remove from queue
 * 3. If offline, keep in queue until connectivity returns
 * 4. NetworkMonitor triggers processSyncQueue() when connection is restored
 */

import { MMKV } from 'react-native-mmkv';
import { supabase } from './supabase';
import { DeviceEventEmitter } from 'react-native';
import { checkBudgetAlert } from './notifications';

const storage = new MMKV({ id: 'offline-sync' });

const QUEUE_KEY = 'sync_queue';
const FAILED_KEY = 'sync_failed';
const MAX_RETRIES = 3;

export interface QueuedTransaction {
  localId: string;
  title: string;
  amount: number;
  type: 'expense' | 'income';
  category: string;
  latitude: number | null;
  longitude: number | null;
  location_name: string | null;
  created_at: string;
  user_id: string | null;
  retryCount: number;
  queuedAt: string;
}

/** Generate a simple unique local ID */
function generateLocalId(): string {
  return `local_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
}

/** Read the current sync queue from MMKV */
export function getSyncQueue(): QueuedTransaction[] {
  const raw = storage.getString(QUEUE_KEY);
  if (!raw) return [];
  try {
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

/** Get the count of pending items */
export function getPendingCount(): number {
  return getSyncQueue().length;
}

/** Get failed items (exceeded max retries) */
export function getFailedQueue(): QueuedTransaction[] {
  const raw = storage.getString(FAILED_KEY);
  if (!raw) return [];
  try {
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

/** Save a transaction to the offline queue */
export function enqueueTransaction(tx: Omit<QueuedTransaction, 'localId' | 'retryCount' | 'queuedAt'>): string {
  const queue = getSyncQueue();
  const localId = generateLocalId();
  const queuedTx: QueuedTransaction = {
    ...tx,
    localId,
    retryCount: 0,
    queuedAt: new Date().toISOString(),
  };
  queue.push(queuedTx);
  storage.set(QUEUE_KEY, JSON.stringify(queue));

  // Notify listeners that a new transaction was queued
  DeviceEventEmitter.emit('sync_queue_changed', { pending: queue.length });

  return localId;
}

/** Remove a transaction from the queue by localId */
function dequeueTransaction(localId: string): void {
  const queue = getSyncQueue().filter(tx => tx.localId !== localId);
  storage.set(QUEUE_KEY, JSON.stringify(queue));
  DeviceEventEmitter.emit('sync_queue_changed', { pending: queue.length });
}

/** Move a transaction to the failed queue */
function moveToFailed(tx: QueuedTransaction): void {
  const failed = getFailedQueue();
  failed.push(tx);
  storage.set(FAILED_KEY, JSON.stringify(failed));
  dequeueTransaction(tx.localId);
}

/** Increment retry count for a queued item */
function incrementRetry(localId: string): void {
  const queue = getSyncQueue().map(tx => {
    if (tx.localId === localId) {
      return { ...tx, retryCount: tx.retryCount + 1 };
    }
    return tx;
  });
  storage.set(QUEUE_KEY, JSON.stringify(queue));
}

let isProcessing = false;

/**
 * Process all pending items in the sync queue.
 * Called by NetworkMonitor when connectivity is restored,
 * and after each new transaction is enqueued while online.
 */
export async function processSyncQueue(): Promise<{ synced: number; failed: number }> {
  if (isProcessing) return { synced: 0, failed: 0 };
  
  const queue = getSyncQueue();
  if (queue.length === 0) return { synced: 0, failed: 0 };

  isProcessing = true;
  let synced = 0;
  let failed = 0;

  try {
    for (const tx of queue) {
      try {
        const { error } = await supabase.from('transactions').insert([
          {
            title: tx.title,
            amount: tx.amount,
            type: tx.type,
            category: tx.category,
            latitude: tx.latitude,
            longitude: tx.longitude,
            location_name: tx.location_name,
            created_at: tx.created_at,
            user_id: tx.user_id,
          },
        ]);

        if (error) {
          throw error;
        }

        // Success — remove from queue
        dequeueTransaction(tx.localId);
        synced++;

        // Trigger budget check after successful sync
        if (tx.type === 'expense') {
          checkBudgetAlert(tx.category).catch(console.warn);
        }
      } catch (err) {
        console.warn(`[OfflineSync] Failed to sync ${tx.localId}:`, err);
        if (tx.retryCount >= MAX_RETRIES) {
          moveToFailed(tx);
          failed++;
        } else {
          incrementRetry(tx.localId);
        }
      }
    }
  } finally {
    isProcessing = false;
  }

  if (synced > 0) {
    // Notify UI to refresh data
    DeviceEventEmitter.emit('transaction_added');
    DeviceEventEmitter.emit('sync_completed', { synced, failed });
  }

  return { synced, failed };
}

/** Clear the failed queue (user acknowledges failures) */
export function clearFailedQueue(): void {
  storage.delete(FAILED_KEY);
}

/** Retry all failed items by moving them back to the main queue */
export function retryFailedQueue(): void {
  const failed = getFailedQueue();
  const queue = getSyncQueue();
  const retried = failed.map(tx => ({ ...tx, retryCount: 0 }));
  storage.set(QUEUE_KEY, JSON.stringify([...queue, ...retried]));
  storage.delete(FAILED_KEY);
  DeviceEventEmitter.emit('sync_queue_changed', { pending: queue.length + retried.length });
}
