import { supabase } from './supabase';
// import { enqueueTransaction, processSyncQueue } from './offlineSync';
import { getIsConnected } from './networkMonitor';
import { TransactionItem } from '../components/TransactionDetailSheet';

/**
 * Service to handle transaction modifications.
 */
export async function updateTransaction(
  id: string,
  updates: Partial<Omit<TransactionItem, 'id' | 'created_at'>>,
  userId: string | null
) {
  const isOnline = getIsConnected();
  
  // If online, update Supabase directly
  if (isOnline) {
    try {
      const { error } = await supabase
        .from('transactions')
        .update(updates as any)
        .eq('id', id);
        
      if (error) throw error;
      return { success: true };
    } catch (err) {
      console.error('[UpdateTransaction] Online error:', err);
      // Fallback to offline if needed? 
      // For now just return error
      return { success: false, error: err };
    }
  } else {
    // If offline, we need a way to track UPDATES in the queue.
    // Currently enqueueTransaction only supports INSERT.
    // I should modify offlineSync to handle ACTION types.
    console.warn('[UpdateTransaction] Offline updates not fully supported in sync queue yet.');
    return { success: false, error: 'Offline updates coming soon' };
  }
}

/**
 * Delete a transaction.
 */
export async function deleteTransaction(id: string) {
  const isOnline = getIsConnected();
  if (isOnline) {
    const { error } = await supabase
      .from('transactions')
      .delete()
      .eq('id', id);
    if (error) throw error;
    return { success: true };
  }
  return { success: false, error: 'Offline delete not supported' };
}
