import { supabase } from './supabase';
import { getIsConnected } from './networkMonitor';
import { enqueueTransaction } from './offlineSync';

/**
 * Service to handle inter-wallet transfers.
 * A transfer consists of two transactions:
 * 1. An 'expense' from the source wallet.
 * 2. An 'income' to the destination wallet.
 */
export async function createTransfer(params: {
  fromWalletId: string;
  toWalletId: string;
  amount: number;
  title: string;
  category: string;
  userId: string | null;
}) {
  const { fromWalletId, toWalletId, amount, title, category, userId } = params;

  if (amount <= 0) {
    return { success: false, error: 'Amount must be greater than zero' };
  }

  if (fromWalletId === toWalletId) {
    return { success: false, error: 'Source and destination wallets must be different' };
  }
  const transferGroupId = typeof crypto !== 'undefined' && crypto.randomUUID 
    ? crypto.randomUUID() 
    : `tg_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`;
  const createdAt = new Date().toISOString();

  const isOnline = getIsConnected();

  if (isOnline) {
    try {
      // We use a single insert with multiple rows for atomicity in Supabase
      const { error } = await supabase.from('transactions').insert([
        {
          user_id: userId,
          wallet_id: fromWalletId,
          amount: amount,
          title: `${title} (Out)`,
          type: 'expense',
          category,
          is_transfer: true,
          transfer_group_id: transferGroupId,
          created_at: createdAt,
        },
        {
          user_id: userId,
          wallet_id: toWalletId,
          amount: amount,
          title: `${title} (In)`,
          type: 'income',
          category,
          is_transfer: true,
          transfer_group_id: transferGroupId,
          created_at: createdAt,
        },
      ]);

      if (error) throw error;

      // Update wallet balances (optional if DB triggers handle this, but let's assume they don't yet or we want UI sync)
      // Actually, standard Supabase pattern for DuaSaku seems to be letting the DB handle it or refreshing.
      
      return { success: true, transferGroupId };
    } catch (err) {
      console.error('[TransferService] Error:', err);
      return { success: false, error: err };
    }
  } else {
    // Offline support: Enqueue both transactions
    enqueueTransaction({
      user_id: userId,
      wallet_id: fromWalletId,
      amount: amount,
      title: `${title} (Out)`,
      type: 'expense',
      category,
      is_transfer: true,
      transfer_group_id: transferGroupId,
      created_at: createdAt,
      latitude: null,
      longitude: null,
      location_name: null,
    });

    enqueueTransaction({
      user_id: userId,
      wallet_id: toWalletId,
      amount: amount,
      title: `${title} (In)`,
      type: 'income',
      category,
      is_transfer: true,
      transfer_group_id: transferGroupId,
      created_at: createdAt,
      latitude: null,
      longitude: null,
      location_name: null,
    });

    return { success: true, offline: true, transferGroupId };
  }
}
