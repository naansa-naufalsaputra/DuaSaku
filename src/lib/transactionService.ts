import { supabase } from './supabase';
import { enqueueTransaction } from './offlineSync';
import { getIsConnected } from './networkMonitor';
import { TransactionItem } from '../components/TransactionDetailSheet';

/**
 * Create a new transaction (handles both online and offline).
 */
export async function createTransaction(data: {
  title: string;
  amount: number;
  type: 'expense' | 'income';
  category: string;
  user_id: string | null;
  wallet_id?: string;
  created_at?: string;
  latitude?: number | null;
  longitude?: number | null;
  location_name?: string | null;
}) {
  const isOnline = getIsConnected();
  const createdAt = data.created_at || new Date().toISOString();

  if (isOnline) {
    try {
      const { error } = await supabase.from('transactions').insert([{
        ...data,
        created_at: createdAt,
      }]);
      if (error) throw error;
      return { success: true };
    } catch (err) {
      console.error('[CreateTransaction] Online error:', err);
      // Fallback to offline on failure
    }
  }

  // Offline or online failure: enqueue
  enqueueTransaction({
    ...data,
    created_at: createdAt,
    latitude: data.latitude || null,
    longitude: data.longitude || null,
    location_name: data.location_name || null,
  });
  
  return { success: true, offline: true };
}

/**
 * Service to handle transaction modifications.
 */
export async function updateTransaction(
  id: string,
  updates: Partial<Omit<TransactionItem, 'id' | 'created_at'>>,
  userId: string | null
) {
  const isOnline = getIsConnected();
  
  if (isOnline) {
    try {
      if (!userId) throw new Error('User ID is required for update');

      const { error } = await supabase
        .from('transactions')
        .update(updates as any)
        .eq('id', id)
        .eq('user_id', userId); // Security: ensure user owns the record
        
      if (error) throw error;
      return { success: true };
    } catch (err: any) {
      console.error('[UpdateTransaction] Online error:', err);
      return { success: false, error: err.message || 'Unknown error' };
    }
  }

  // Offline or online failure: enqueue UPDATE action
  enqueueTransaction({
    ...updates,
    remoteId: id,
    user_id: userId,
  } as any, 'UPDATE');

  return { success: true, offline: true };
}

/**
 * Delete a transaction.
 */
export async function deleteTransaction(id: string, userId: string | null) {
  const isOnline = getIsConnected();
  if (isOnline) {
    try {
      if (!userId) throw new Error('User ID is required for delete');

      const { error } = await supabase
        .from('transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', userId); // Security: ensure user owns the record
      if (error) throw error;
      return { success: true };
    } catch (err: any) {
      console.error('[DeleteTransaction] Online error:', err);
      return { success: false, error: err.message || 'Unknown error' };
    }
  }

  // Offline or online failure: enqueue DELETE action
  enqueueTransaction({
    remoteId: id,
    user_id: userId,
  } as any, 'DELETE');

  return { success: true, offline: true };
}

