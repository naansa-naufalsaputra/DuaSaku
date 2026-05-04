import * as Notifications from 'expo-notifications';
import { fetchBudgets, fetchMonthlySpending, getCurrentMonthYear, BUDGET_CATEGORIES } from './budgetService';

/** Set notification handler for foreground display */
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
    shouldShowBanner: true,
    shouldShowList: true,
  }),
});

/** Schedule the daily reminder */
export async function refreshDailyReminder() {
  await Notifications.cancelAllScheduledNotificationsAsync();

  await Notifications.scheduleNotificationAsync({
    content: {
      title: 'DuaSaku',
      body: 'Jangan lupa catat pengeluaranmu hari ini!',
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.DAILY,
      hour: 20,
      minute: 0,
    },
  });
}

/** Format currency for notifications */
function formatRp(amount: number): string {
  return `Rp ${Math.abs(amount).toLocaleString('id-ID')}`;
}

/**
 * Check budget utilization for a given category after a new expense.
 * Fires an instant local notification if spending reaches >= 80% of the limit.
 */
export async function checkBudgetAlert(category: string): Promise<void> {
  try {
    const monthYear = getCurrentMonthYear();
    const [budgets, spending] = await Promise.all([
      fetchBudgets(monthYear),
      fetchMonthlySpending(monthYear),
    ]);

    const budget = budgets.find(b => b.category === category);
    if (!budget) return; // No budget set for this category

    const spent = spending[category] || 0;
    const limit = budget.budget_amount;
    if (limit <= 0) return;

    const percentage = (spent / limit) * 100;
    const remaining = limit - spent;

    const categoryMeta = BUDGET_CATEGORIES.find(c => c.key === category);
    const label = categoryMeta?.label || category;
    const emoji = categoryMeta?.emoji || '📊';

    if (percentage >= 100) {
      // Over budget
      await Notifications.scheduleNotificationAsync({
        content: {
          title: `${emoji} Budget ${label} Habis!`,
          body: `Kamu sudah melebihi budget sebesar ${formatRp(Math.abs(remaining))}. Pertimbangkan untuk mengurangi pengeluaran.`,
          data: { type: 'budget_alert', category },
        },
        trigger: null, // Instant
      });
    } else if (percentage >= 80) {
      // Warning threshold
      await Notifications.scheduleNotificationAsync({
        content: {
          title: `${emoji} Awas! Budget ${label} Menipis`,
          body: `Budget ${label} kamu sisa ${formatRp(remaining)} (${Math.round(100 - percentage)}% tersisa). Hati-hati ya!`,
          data: { type: 'budget_alert', category },
        },
        trigger: null, // Instant
      });
    }
  } catch (err) {
    console.warn('[BudgetAlert] Error checking budget:', err);
  }
}
