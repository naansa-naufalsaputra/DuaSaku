import { supabase } from './supabase';
import { useGamificationStore } from '../store/useGamificationStore';
import { fetchBudgetsWithSpending } from './budgetService';
import { mmkvStorage } from './storage';

/**
 * Menghitung Financial Health Score (1-100)
 */
export const calculateHealthScore = async (userId: string) => {
  const store = useGamificationStore.getState();
  let score = 0;

  try {
    // 1. Budget Health (Max 40 points)
    const budgets = await fetchBudgetsWithSpending(userId);
    if (budgets.length > 0) {
      const underBudgetCount = budgets.filter(b => b.percentage <= 100).length;
      score += (underBudgetCount / budgets.length) * 40;
    } else {
      score += 30; // Default points if no budget set
    }

    // 2. Savings Rate (Max 30 points)
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
    
    const { data: txs } = await supabase
      .from('transactions')
      .select('amount, type')
      .eq('user_id', userId)
      .gte('created_at', startOfMonth);

    if (txs && txs.length > 0) {
      let income = 0;
      let expense = 0;
      txs.forEach(t => {
        if (t.type === 'income') income += t.amount;
        else expense += t.amount;
      });

      if (income > 0) {
        const savingsRate = (income - expense) / income;
        if (savingsRate >= 0.3) score += 30;
        else if (savingsRate > 0) score += (savingsRate / 0.3) * 30;
        
        // Unlock Badge: Money Saver
        if (savingsRate >= 0.3) store.unlockBadge('saver_master');
      }
    }

    // 3. Consistency (Max 20 points)
    const streakPoints = Math.min(store.streakDays * 2.8, 20); // 7 days = ~20 points
    score += streakPoints;

    // 4. Wallet Diversification (Max 5 points)
    const { data: wallets } = await supabase.from('wallets').select('id').eq('user_id', userId);
    if (wallets && wallets.length >= 2) score += 5;

    // 5. Goal Progress (Max 5 points)
    const wishlistData = mmkvStorage.getItem('settings_wishlist');
    if (wishlistData) {
      try {
        const wishlist = JSON.parse(wishlistData as string);
        const hasProgress = wishlist.some((item: any) => item.savedAmount > 0);
        if (hasProgress) score += 5;
      } catch {}
    }

    // Unlock Badge: Streak 7
    if (store.streakDays >= 7) store.unlockBadge('streak_7');

    store.setHealthScore(Math.round(score));
    
  } catch (error) {
    console.error('Error calculating health score:', error);
  }
};
