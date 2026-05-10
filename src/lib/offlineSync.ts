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

const storage = new MMKV({ id: 'offline-sync',
  encryptionKey: process.env.EXPO_PUBLIC_MMKV_ENCRYPTION_KEY || 'DuaSaku-BankGrade-SecureKey-2026' });

const QUEUE_KEY = 'offline_sync_queue';

export interface QueuedTransaction {
  localId: string;
  remoteId?: string; // The UUID from Supabase, required for UPDATE/DELETE
  action: 'INSERT' | 'UPDATE' | 'DELETE';
  title?: string;
  amount?: number;
  type?: 'expense' | 'income';
  category?: string;
  latitude?: number | null;
  longitude?: number | null;
  location_name?: string | null;
  created_at?: string;
  user_id?: string | null;
  wallet_id?: string | null;
  is_transfer?: boolean | null;
  transfer_group_id?: string | null;
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
    const queue = JSON.parse(raw);
    // Migration/Normalization: Ensure all items have an action
    return queue.map((item: any) => ({
      ...item,
      action: item.action || 'INSERT',
    }));
  } catch {
    return [];
  }
}

/** Get the count of pending items */
export function getPendingCount(): number {
  return getSyncQueue().length;
}

/** Save a transaction to the offline queue */
export function enqueueTransaction(
  tx: Omit<QueuedTransaction, 'localId' | 'retryCount' | 'queuedAt' | 'action'>,
  action: 'INSERT' | 'UPDATE' | 'DELETE' = 'INSERT'
): string {
  const queue = getSyncQueue();
  const localId = generateLocalId();
  const queuedTx: QueuedTransaction = {
    ...tx,
    localId,
    action,
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
 */
export async function processSyncQueue(): Promise<{ synced: number; failed: number }> {
  if (isProcessing) return { synced: 0, failed: 0 };
  
  const queue = getSyncQueue();
  if (queue.length === 0) return { synced: 0, failed: 0 };

  isProcessing = true;
  
  try {
    const results = await Promise.allSettled(queue.map(async (tx) => {
      let error;
      
      if (tx.action === 'INSERT') {
        const payload: any = {
          title: tx.title,
          amount: tx.amount,
          type: tx.type,
          category: tx.category,
          latitude: tx.latitude ?? null,
          longitude: tx.longitude ?? null,
          location_name: tx.location_name ?? null,
          created_at: tx.created_at,
          user_id: tx.user_id,
          wallet_id: tx.wallet_id,
          is_transfer: tx.is_transfer ?? false,
          transfer_group_id: tx.transfer_group_id ?? null,
        };
        const { error: insError } = await supabase.from('transactions').insert([payload]);
        error = insError;
      } else if (tx.action === 'UPDATE' && tx.remoteId) {
        const { localId, remoteId, action, retryCount, queuedAt, ...updateData } = tx;
        Object.keys(updateData).forEach(key => (updateData as any)[key] === undefined && delete (updateData as any)[key]);
        
        const { error: updError } = await supabase
          .from('transactions')
          .update(updateData)
          .eq('id', tx.remoteId);
        error = updError;
      } else if (tx.action === 'DELETE' && tx.remoteId) {
        const { error: delError } = await supabase
          .from('transactions')
          .delete()
          .eq('id', tx.remoteId);
        error = delError;
      }

      if (error) throw error;

      // Success
      dequeueTransaction(tx.localId);
      if (tx.type === 'expense' && tx.category) {
        checkBudgetAlert(tx.category).catch(console.warn);
      }
      return tx.localId;
    }));

    const syncedCount = results.filter(r => r.status === 'fulfilled').length;
    const failedCount = results.filter(r => r.status === 'rejected').length;

    // Log failures
    results.forEach((res, idx) => {
      if (res.status === 'rejected') {
        console.warn(`[Sync] Item ${queue[idx].localId} failed:`, res.reason);
        incrementRetry(queue[idx].localId);
      }
    });

    if (syncedCount > 0) {
      DeviceEventEmitter.emit('transaction_added');
      DeviceEventEmitter.emit('sync_completed', { synced: syncedCount, failed: failedCount });
    }

    return { synced: syncedCount, failed: failedCount };
  } finally {
    isProcessing = false;
  }
}

