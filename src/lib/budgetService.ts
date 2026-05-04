/**
 * Budget Service — Supabase CRUD for the `budgets` table
 *
 * Schema:
 *   id          UUID (auto)
 *   user_id     UUID (auth.users FK)
 *   category    TEXT
 *   budget_amount NUMERIC
 *   month_year  TEXT ("2026-05")
 *   created_at  TIMESTAMPTZ (auto)
 */

import { supabase } from './supabase';

export interface Budget {
  id: string;
  user_id: string | null;
  category: string;
  budget_amount: number;
  month: string;
}

export interface BudgetWithSpending extends Budget {
  spent: number;
  percentage: number;
  remaining: number;
  isOver: boolean;
}

/** All supported budget categories (synced with AI parser) */
export const BUDGET_CATEGORIES = [
  { key: 'Food',          label: 'Makan & Minum',  emoji: '🍔', color: '#10b981' },
  { key: 'Transport',     label: 'Transportasi',   emoji: '🚗', color: '#3b82f6' },
  { key: 'Shopping',      label: 'Belanja',        emoji: '🛍️', color: '#ec4899' },
  { key: 'Health',        label: 'Kesehatan',      emoji: '🏥', color: '#ef4444' },
  { key: 'Entertainment', label: 'Hiburan',         emoji: '🎬', color: '#f59e0b' },
  { key: 'Utilities',     label: 'Tagihan',         emoji: '💡', color: '#8b5cf6' },
  { key: 'Education',     label: 'Pendidikan',     emoji: '📚', color: '#6366f1' },
  { key: 'Social',        label: 'Sosial & Zakat', emoji: '🤝', color: '#14b8a6' },
  { key: 'Hobby',         label: 'Hobi & Game',    emoji: '🎮', color: '#d946ef' },
  { key: 'Gift',          label: 'Hadiah',         emoji: '🎁', color: '#f43f5e' },
  { key: 'Subscription',  label: 'Langganan',      emoji: '💳', color: '#0ea5e9' },
  { key: 'Pet',           label: 'Hewan Peliharaan', emoji: '🐾', color: '#fb923c' },
  { key: 'Maintenance',   label: 'Perbaikan',      emoji: '🛠️', color: '#a8a29e' },
  { key: 'Debt',          label: 'Hutang & Cicilan', emoji: '💸', color: '#475569' },
  { key: 'Charity',       label: 'Donasi',         emoji: '🧡', color: '#f87171' },
  { key: 'Investment',    label: 'Investasi',      emoji: '📈', color: '#06b6d4' },
  { key: 'Other',         label: 'Lainnya',         emoji: '📦', color: '#6b7280' },
] as const;

/** Get the current month string in "YYYY-MM" format */
export function getCurrentMonthYear(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

/** Fetch all budgets for a user and month */
export async function fetchBudgets(userId: string, monthYear?: string): Promise<Budget[]> {
  const target = monthYear || getCurrentMonthYear();

  const { data, error } = await supabase
    .from('category_budgets')
    .select('*')
    .eq('user_id', userId)
    .eq('month', target);

  if (error) {
    console.error('[BudgetService] Fetch error:', error);
    return [];
  }
  return data || [];
}

/** Calculate total spending per category for a user and month */
export async function fetchMonthlySpending(userId: string, monthYear?: string): Promise<Record<string, number>> {
  const target = monthYear || getCurrentMonthYear();
  const startDate = `${target}-01`;

  // Calculate end date (first day of next month)
  const [year, month] = target.split('-').map(Number);
  const nextMonth = month === 12 ? 1 : month + 1;
  const nextYear = month === 12 ? year + 1 : year;
  const endDate = `${nextYear}-${String(nextMonth).padStart(2, '0')}-01`;

  const { data, error } = await supabase
    .from('transactions')
    .select('category, amount')
    .eq('user_id', userId)
    .eq('type', 'expense')
    .gte('created_at', startDate)
    .lt('created_at', endDate);

  if (error) {
    console.error('[BudgetService] Spending fetch error:', error);
    return {};
  }

  const spending: Record<string, number> = {};
  (data || []).forEach(tx => {
    const cat = tx.category || 'Other';
    spending[cat] = (spending[cat] || 0) + Number(tx.amount);
  });

  return spending;
}

/** Combine budgets with actual spending data for a user */
export async function fetchBudgetsWithSpending(userId: string, monthYear?: string): Promise<BudgetWithSpending[]> {
  const [budgets, spending] = await Promise.all([
    fetchBudgets(userId, monthYear),
    fetchMonthlySpending(userId, monthYear),
  ]);

  return budgets.map(budget => {
    const spent = spending[budget.category] || 0;
    const percentage = budget.budget_amount > 0
      ? Math.min(Math.round((spent / budget.budget_amount) * 100), 100)
      : 0;
    const remaining = budget.budget_amount - spent;

    return {
      ...budget,
      spent,
      percentage,
      remaining,
      isOver: spent > budget.budget_amount,
    };
  });
}

/** Create or update a budget for a category in a given month */
export async function upsertBudget(
  userId: string,
  category: string,
  limitAmount: number,
  monthYear?: string
): Promise<{ success: boolean; error?: string }> {
  const target = monthYear || getCurrentMonthYear();

  // Check if a budget already exists for this category + month (for this user)
  const { data: existing } = await supabase
    .from('category_budgets')
    .select('id')
    .eq('user_id', userId)
    .eq('category', category)
    .eq('month', target)
    .maybeSingle();

  if (existing && !Array.isArray(existing)) {
    // Update existing
    const { error } = await supabase
      .from('category_budgets')
      .update({ budget_amount: limitAmount })
      .eq('id', (existing as any).id)
      .eq('user_id', userId);

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  // Insert new
  const { error } = await supabase
    .from('category_budgets')
    .insert([{ 
      category, 
      budget_amount: limitAmount, 
      month: target,
      user_id: userId
    }]);

  if (error) return { success: false, error: error.message };
  return { success: true };
}

/** Delete a budget entry */
export async function deleteBudget(budgetId: string, userId: string): Promise<boolean> {
  const { error } = await supabase
    .from('category_budgets')
    .delete()
    .eq('id', budgetId)
    .eq('user_id', userId);

  if (error) {
    console.error('[BudgetService] Delete error:', error);
    return false;
  }
  return true;
}

/** Get the previous month in "YYYY-MM" format */
export function getLastMonthYear(): string {
  const now = new Date();
  const lastMonth = now.getMonth() === 0 ? 12 : now.getMonth();
  const year = now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear();
  return `${year}-${String(lastMonth).padStart(2, '0')}`;
}

/**
 * Copy all budgets from last month into the current month for a user.
 * Uses upsert logic to avoid duplicating categories that already exist.
 */
export async function copyBudgetsFromLastMonth(userId: string): Promise<{ copied: number; error?: string }> {
  const lastMY = getLastMonthYear();
  const currentMY = getCurrentMonthYear();

  const lastBudgets = await fetchBudgets(userId, lastMY);

  if (lastBudgets.length === 0) {
    return { copied: 0, error: 'Tidak ada budget bulan lalu untuk disalin' };
  }

  let copied = 0;
  for (const budget of lastBudgets) {
    const result = await upsertBudget(userId, budget.category, budget.budget_amount, currentMY);
    if (result.success) copied++;
  }

  return { copied };
}

/**
 * Generates a text summary of budget health for AI context
 */
export async function getBudgetHealthSummary(userId: string, monthYear?: string): Promise<string> {
  const budgets = await fetchBudgetsWithSpending(userId, monthYear);
  if (budgets.length === 0) return 'Belum ada budget yang diatur bulan ini.';

  return budgets.map(b => {
    const status = b.isOver 
      ? 'OVER BUDGET! 🚨' 
      : b.percentage > 80 
        ? 'Hampir Habis (Peringatan) ⚠️' 
        : 'Aman ✅';
    return `${b.category}: ${status} (Limit: Rp ${b.budget_amount.toLocaleString()}, Sisa: Rp ${b.remaining.toLocaleString()})`;
  }).join(' | ');
}

/**
 * Smart Budget Forecasting
 * Calculates projected end-of-month expense based on current velocity.
 */
export async function calculateSpendingForecast(userId: string): Promise<{
  currentExpense: number;
  forecastedExpense: number;
  velocity: number;
  daysRemaining: number;
}> {
  const currentMonth = getCurrentMonthYear();
  const spending = await fetchMonthlySpending(userId, currentMonth);
  const currentExpense = Object.values(spending).reduce((acc, val) => acc + val, 0);

  const now = new Date();
  const currentDay = now.getDate();
  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  const daysRemaining = daysInMonth - currentDay;

  const velocity = currentExpense / currentDay;
  const forecastedExpense = velocity * daysInMonth;

  return {
    currentExpense,
    forecastedExpense,
    velocity,
    daysRemaining
  };
}

/**
 * Financial "What-If" Simulator
 * Projects the impact of a one-time large purchase on financial health.
 */
export function simulateWhatIf(
  currentBalance: number,
  monthlyIncome: number,
  monthlyExpense: number,
  purchaseAmount: number,
  monthsToProject: number = 6
): {
  month: number;
  balance: Record<string, number>;
}[] {
  const monthlySavings = monthlyIncome - monthlyExpense;
  const projection = [];
  
  let balanceAfterPurchase = currentBalance - purchaseAmount;
  
  for (let i = 1; i <= monthsToProject; i++) {
    balanceAfterPurchase += monthlySavings;
    projection.push({
      month: i,
      balance: {
        amount: balanceAfterPurchase
      }
    });
  }
  
  return projection as any;
}
