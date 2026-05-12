import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
  DeviceEventEmitter,
  Switch,
  StyleSheet,
} from 'react-native';
import {
  Plus,
  ArrowRight,
  Zap,
  TrendingDown,
  TrendingUp,
  AlertTriangle,
  Trash2,
  Copy,
  Repeat,
  Calendar,
  Settings,
} from 'lucide-react-native';
import { useRouter } from 'expo-router';
import BottomSheet from '@gorhom/bottom-sheet';
import { useTranslation } from 'react-i18next';
import {
  fetchBudgetsWithSpending,
  deleteBudget,
  getCurrentMonthYear,
  copyBudgetsFromLastMonth,
  type BudgetWithSpending,
} from '../../src/lib/budgetService';
import { useCategoryStore } from '../../src/store/useCategoryStore';
import Animated, { 
  useSharedValue, 
  useAnimatedStyle, 
  withSpring,
  withSequence,
  withTiming
} from 'react-native-reanimated';
import {
  fetchRecurringTransactions,
  toggleRecurring,
  deleteRecurring,
  getFrequencyLabel,
  type RecurringTransaction,
} from '../../src/lib/recurringService';
import AddBudgetSheet from '../../src/components/AddBudgetSheet';
import AddRecurringSheet from '../../src/components/AddRecurringSheet';
import * as Haptics from 'expo-haptics';
import { useUserStore } from '../../src/store/useUserStore';
import EmptyState from '../../src/components/ui/EmptyState';

export default function BudgetScreen() {
  const { t } = useTranslation();
  const router = useRouter();
  const [budgets, setBudgets] = useState<BudgetWithSpending[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [editData, setEditData] = useState<{ category: string; budget_amount: number } | null>(null);
  const [recurringItems, setRecurringItems] = useState<RecurringTransaction[]>([]);
  const [isCopying, setIsCopying] = useState(false);
  const { getAllCategories } = useCategoryStore();
  const categories = getAllCategories();

  const { session } = useUserStore();
  const userId = session?.user?.id;

  const sheetRef = useRef<BottomSheet>(null);
  const recurringSheetRef = useRef<BottomSheet>(null);

  const loadBudgets = useCallback(async () => {
    if (!userId) return;
    try {
      const data = await fetchBudgetsWithSpending(userId);
      setBudgets(data);
    } catch (err) {
      console.error('[BudgetScreen] Load error:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [userId]);

  const loadRecurring = useCallback(async () => {
    if (!userId) return;
    try {
      const data = await fetchRecurringTransactions(userId);
      setRecurringItems(data);
    } catch (err) {
      console.error('[BudgetScreen] Recurring load error:', err);
    }
  }, [userId]);

  const loadBudgetsRef = useRef(loadBudgets);
  useEffect(() => { loadBudgetsRef.current = loadBudgets; }, [loadBudgets]);

  useEffect(() => {
    loadBudgets();
    loadRecurring();
  }, [loadBudgets, loadRecurring]);

  useEffect(() => {
    const sub = DeviceEventEmitter.addListener('transaction_added', () => loadBudgetsRef.current());
    return () => sub.remove();
  }, []);

  const handleToggleRecurring = async (id: string, isActive: boolean) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    await toggleRecurring(id, isActive);
    loadRecurring();
  };

  const handleDeleteRecurring = async (id: string) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    await deleteRecurring(id);
    loadRecurring();
  };

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadBudgets();
    loadRecurring();
  }, [loadBudgets, loadRecurring]);

  const handleAddNew = () => {
    setEditData(null);
    sheetRef.current?.snapToIndex(0);
  };

  const handleEdit = (budget: BudgetWithSpending) => {
    setEditData({ category: budget.category, budget_amount: budget.budget_amount });
    sheetRef.current?.snapToIndex(0);
  };

  const handleDelete = async (budgetId: string) => {
    if (!userId) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    await deleteBudget(budgetId, userId);
    loadBudgets();
  };

  const handleSaved = () => {
    loadBudgets();
  };

  const handleCopyFromLastMonth = async () => {
    if (!userId) return;
    setIsCopying(true);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    try {
      const result = await copyBudgetsFromLastMonth(userId);
      if (result.copied > 0) {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        loadBudgets();
      }
    } catch (err) {
      console.error('[BudgetScreen] Copy error:', err);
    } finally {
      setIsCopying(false);
    }
  };

  // Summary calculations
  const totalBudget = budgets.reduce((acc, b) => acc + b.budget_amount, 0);
  const totalSpent = budgets.reduce((acc, b) => acc + b.spent, 0);
  const totalRemaining = totalBudget - totalSpent;
  const overallPercentage = totalBudget > 0 ? Math.round((totalSpent / totalBudget) * 100) : 0;
  const overBudgetCount = budgets.filter(b => b.isOver).length;

  const getStatusLabel = () => {
    if (budgets.length === 0) return { text: 'Belum Diatur', color: '#71717a' };
    if (overBudgetCount > 0) return { text: 'Perlu Perhatian', color: '#ef4444' };
    if (overallPercentage > 75) return { text: 'Hati-hati', color: '#f59e0b' };
    return { text: 'Aman', color: '#10b981' };
  };
  const status = getStatusLabel();

  const monthLabel = (() => {
    const my = getCurrentMonthYear();
    const [y, m] = my.split('-');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return `${months[parseInt(m, 10) - 1]} ${y}`;
  })();

  const formatCurrency = (amount: number) => `Rp ${Math.abs(amount).toLocaleString('id-ID')}`;

  const getCategoryMeta = (key: string) =>
    categories.find(c => c.key === key) || { emoji: '📦', color: '#6b7280', label: key };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.headerRow}>
          <View>
            <Text style={styles.headerTitle}>
              {t('budget')}
            </Text>
            <Text style={styles.headerSubtitle}>
              {monthLabel}
            </Text>
          </View>
          <View style={{ flexDirection: 'row', gap: 12 }}>
            <TouchableOpacity
              onPress={() => router.push('/manage-categories')}
              style={styles.settingsButton}
            >
              <Settings color="#fafafa" size={20} />
            </TouchableOpacity>
            <TouchableOpacity
              onPress={handleAddNew}
              style={styles.addButton}
            >
              <Plus color="#09090b" size={22} />
            </TouchableOpacity>
          </View>
        </View>
      </View>

      <ScrollView
        style={styles.scrollContainer}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#fafafa" />
        }
      >
        {/* Summary Card */}
        <View style={styles.summaryCard}>
          {/* Status Badge */}
          <View style={styles.statusRow}>
            <Zap color={status.color} size={18} />
            <Text style={styles.statusLabel}>
              Status Anggaran
            </Text>
            <View
              style={[styles.statusBadge, { backgroundColor: status.color + '20' }]}
            >
              <Text style={[styles.statusBadgeText, { color: status.color }]}>
                {status.text}
              </Text>
            </View>
          </View>

          {/* Main Amount */}
          <Text style={styles.mainAmount}>
            {loading ? '...' : formatCurrency(totalRemaining)}
          </Text>
          <Text style={styles.amountLabel}>
            Sisa dari total {formatCurrency(totalBudget)}
          </Text>

          {/* Overall Progress Bar */}
          <View style={styles.overallProgressBarContainer}>
            <View
              style={[
                styles.overallProgressBar,
                {
                  width: `${Math.min(overallPercentage, 100)}%`,
                  backgroundColor: overallPercentage > 90 ? '#ef4444' : overallPercentage > 75 ? '#f59e0b' : '#10b981',
                }
              ]}
            />
          </View>

          {/* Two-column stats */}
          <View style={styles.statsRow}>
            <View style={styles.statBox}>
              <View style={styles.statLabelRow}>
                <TrendingDown color="#ef4444" size={14} />
                <Text style={styles.statLabelText}>{t('used')}</Text>
              </View>
              <Text style={styles.statValueText}>
                {formatCurrency(totalSpent)}
              </Text>
            </View>
            <View style={styles.statBox}>
              <View style={styles.statLabelRow}>
                <TrendingUp color="#10b981" size={14} />
                <Text style={styles.statLabelText}>{t('remaining')}</Text>
              </View>
              <Text
                style={[
                  styles.statValueText,
                  { color: totalRemaining < 0 ? '#ef4444' : '#fafafa' }
                ]}
              >
                {totalRemaining < 0 ? '-' : ''}{formatCurrency(totalRemaining)}
              </Text>
            </View>
          </View>
        </View>

        {/* Budget List Header */}
        <View style={styles.listHeader}>
          <Text style={styles.listHeaderTitle}>
            Daftar Anggaran ({budgets.length})
          </Text>
          <TouchableOpacity onPress={handleAddNew} style={styles.listAddButton}>
            <Plus color="#10b981" size={20} />
          </TouchableOpacity>
        </View>

        {/* Budget Items */}
        {loading ? (
          <ActivityIndicator size="small" color="#fafafa" style={{ marginTop: 40 }} />
        ) : budgets.length > 0 ? (
          budgets.map((b) => {
            const meta = getCategoryMeta(b.category);
            return (
              <BudgetItem
                key={b.id}
                budget={b}
                meta={meta}
                onEdit={() => handleEdit(b)}
                onDelete={() => handleDelete(b.id)}
                formatCurrency={formatCurrency}
              />
            );
          })
        ) : (
          <>
            <EmptyState message={t('noBudgetMessage', "Belum ada anggaran ditambahkan")} />
            {/* Copy from last month CTA */}
            <TouchableOpacity
              onPress={handleCopyFromLastMonth}
              disabled={isCopying}
              activeOpacity={0.7}
              style={[styles.copyCard, { opacity: isCopying ? 0.6 : 1 }]}
            >
              <View style={styles.copyIconContainer}>
                {isCopying ? (
                  <ActivityIndicator size="small" color="#3b82f6" />
                ) : (
                  <Copy color="#3b82f6" size={20} />
                )}
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ fontFamily: 'Manrope_700Bold', fontSize: 15, color: '#fafafa' }}>
                  Salin Budget Bulan Lalu
                </Text>
                <Text style={{ fontFamily: 'Inter', fontSize: 12, color: '#71717a', marginTop: 2 }}>
                  Duplikat semua limit kategori sebelumnya
                </Text>
              </View>
              <ArrowRight color="#3b82f6" size={18} />
            </TouchableOpacity>
          </>
        )}

        {/* Over-budget warning */}
        {overBudgetCount > 0 && (
          <View
            style={{
              marginTop: 16,
              padding: 16,
              backgroundColor: '#450a0a',
              borderRadius: 20,
              borderWidth: 1,
              borderColor: '#7f1d1d',
              flexDirection: 'row',
              alignItems: 'center',
              gap: 12,
            }}
          >
            <AlertTriangle color="#fca5a5" size={20} />
            <Text style={{ fontFamily: 'Inter', fontSize: 13, color: '#fca5a5', flex: 1 }}>
              {overBudgetCount} kategori melebihi batas anggaran bulan ini
            </Text>
          </View>
        )}

        {/* Recurring Transactions Section */}
        <View style={{ marginTop: 24 }}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
              <Repeat color="#10b981" size={18} />
              <Text style={{ fontFamily: 'Manrope_700Bold', fontSize: 18, color: '#fafafa' }}>
                Transaksi Berulang
              </Text>
            </View>
            <TouchableOpacity
              onPress={() => recurringSheetRef.current?.snapToIndex(0)}
              style={{
                paddingHorizontal: 14,
                paddingVertical: 8,
                borderRadius: 12,
                backgroundColor: '#09090b',
                borderWidth: 1,
                borderColor: '#27272a',
                flexDirection: 'row',
                alignItems: 'center',
                gap: 6,
              }}
            >
              <Plus color="#10b981" size={14} />
              <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 12, color: '#10b981' }}>{t('add')}</Text>
            </TouchableOpacity>
          </View>

          {recurringItems.length === 0 ? (
            <View
              style={{
                padding: 24,
                backgroundColor: '#18181b',
                borderRadius: 20,
                borderWidth: 1,
                borderColor: '#27272a',
                alignItems: 'center',
              }}
            >
              <Calendar color="#52525b" size={24} />
              <Text style={{ fontFamily: 'Inter', fontSize: 13, color: '#52525b', marginTop: 8, textAlign: 'center' }}>
                Belum ada transaksi berulang.{`\n`}Tambahkan kos, paket data, atau gaji bulananmu.
              </Text>
            </View>
          ) : (
            recurringItems.map((rt: RecurringTransaction) => {
              const catMeta = getCategoryMeta(rt.category);
              return (
                <View
                  key={rt.id}
                  style={{
                    backgroundColor: '#18181b',
                    padding: 16,
                    borderRadius: 20,
                    borderWidth: 1,
                    borderColor: rt.is_active ? '#27272a' : '#1f1f23',
                    marginBottom: 10,
                    opacity: rt.is_active ? 1 : 0.5,
                  }}
                >
                  <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                    <View
                      style={{
                        width: 40,
                        height: 40,
                        borderRadius: 12,
                        backgroundColor: catMeta.color + '15',
                        alignItems: 'center',
                        justifyContent: 'center',
                        marginRight: 12,
                      }}
                    >
                      <Text style={{ fontSize: 18 }}>{catMeta.emoji}</Text>
                    </View>
                    <View style={{ flex: 1 }}>
                      <Text style={{ fontFamily: 'Manrope_600SemiBold', fontSize: 15, color: '#fafafa' }} numberOfLines={1}>
                        {rt.title}
                      </Text>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 3 }}>
                        <View
                          style={{
                            paddingHorizontal: 8,
                            paddingVertical: 2,
                            backgroundColor: '#10b98115',
                            borderRadius: 6,
                          }}
                        >
                          <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 12, color: '#10b981' }}>
                            {getFrequencyLabel(rt.frequency)}
                          </Text>
                        </View>
                        <Text style={{ fontFamily: 'Inter', fontSize: 12, color: '#52525b' }}>
                          Next: {rt.next_due}
                        </Text>
                      </View>
                    </View>
                    <View style={{ alignItems: 'flex-end', gap: 4 }}>
                      <Text style={{ fontFamily: 'Manrope_700Bold', fontSize: 14, color: rt.type === 'income' ? '#34d399' : '#fafafa' }}>
                        {rt.type === 'income' ? '+' : '-'}{formatCurrency(rt.amount)}
                      </Text>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                        <Switch
                          value={rt.is_active}
                          onValueChange={(v) => handleToggleRecurring(rt.id, v)}
                          trackColor={{ false: '#27272a', true: '#10b98140' }}
                          thumbColor={rt.is_active ? '#10b981' : '#52525b'}
                          style={{ transform: [{ scale: 0.75 }] }}
                        />
                        <TouchableOpacity onPress={() => handleDeleteRecurring(rt.id)}>
                          <Trash2 color="#ef4444" size={14} />
                        </TouchableOpacity>
                      </View>
                    </View>
                  </View>
                </View>
              );
            })
          )}
        </View>

        {/* Bottom spacer */}
        <View style={{ height: 100 }} />
      </ScrollView>

      {/* Add/Edit Budget Sheet */}
      <AddBudgetSheet
        ref={sheetRef}
        editData={editData}
        onClose={() => setEditData(null)}
        onSaved={handleSaved}
      />

      {/* Add Recurring Sheet */}
      <AddRecurringSheet
        ref={recurringSheetRef}
        onCreated={() => loadRecurring()}
      />
    </View>
  );
}

/** Individual budget item card */
function BudgetItem({
  budget,
  meta,
  onEdit,
  onDelete,
  formatCurrency,
}: {
  budget: BudgetWithSpending;
  meta: { emoji: string; color: string; label: string; target?: number };
  onEdit: () => void;
  onDelete: () => void;
  formatCurrency: (n: number) => string;
}) {
  const scale = useSharedValue(1);
  const progress = useSharedValue(0);

  useEffect(() => {
    // Initial pop animation on mount
    scale.value = withSequence(
      withSpring(1.2, { damping: 2 }),
      withSpring(1)
    );
    // Animate progress bar
    progress.value = withTiming(budget.percentage, { duration: 1000 });
  }, [budget.percentage, progress, scale]);

  const animatedIconStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }]
  }));

  const animatedBarStyle = useAnimatedStyle(() => ({
    width: `${Math.min(progress.value, 100)}%`
  }));


  const barColor = budget.isOver ? '#ef4444' : budget.percentage > 75 ? '#f59e0b' : meta.color;

  return (
    <TouchableOpacity
      activeOpacity={0.7}
      onPress={onEdit}
      style={{
        backgroundColor: '#18181b',
        padding: 20,
        borderRadius: 24,
        borderWidth: 1,
        borderColor: budget.isOver ? '#7f1d1d' : '#27272a',
        marginBottom: 12,
      }}
    >
      {/* Top row */}
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
          <Animated.View
            style={[{
              width: 44,
              height: 44,
              borderRadius: 14,
              backgroundColor: meta.color + '15',
              alignItems: 'center',
              justifyContent: 'center',
            }, animatedIconStyle]}
          >
            <Text style={{ fontSize: 22 }}>{meta.emoji}</Text>
          </Animated.View>
          <View>
            <Text style={{ fontFamily: 'Manrope_700Bold', fontSize: 16, color: '#fafafa' }}>
              {meta.label}
            </Text>
            <Text style={{ fontFamily: 'Inter', fontSize: 12, color: '#71717a', marginTop: 2 }}>
              {budget.isOver ? 'Melebihi batas!' : `Sisa ${formatCurrency(budget.remaining)}`}
              {meta.target ? ` • Target: ${formatCurrency(meta.target)}` : ''}
            </Text>
          </View>
        </View>
        <View style={{ flexDirection: 'row', gap: 6 }}>
          <TouchableOpacity
            onPress={onEdit}
            style={{
              width: 32,
              height: 32,
              borderRadius: 10,
              backgroundColor: '#09090b',
              alignItems: 'center',
              justifyContent: 'center',
              borderWidth: 1,
              borderColor: '#27272a',
            }}
          >
            <ArrowRight color="#71717a" size={16} />
          </TouchableOpacity>
          <TouchableOpacity
            onPress={onDelete}
            style={{
              width: 32,
              height: 32,
              borderRadius: 10,
              backgroundColor: '#450a0a',
              alignItems: 'center',
              justifyContent: 'center',
              borderWidth: 1,
              borderColor: '#7f1d1d',
            }}
          >
            <Trash2 color="#ef4444" size={14} />
          </TouchableOpacity>
        </View>
      </View>

      {/* Progress Bar Container */}
      <View style={{ height: 8, backgroundColor: '#09090b', borderRadius: 4, overflow: 'hidden', marginBottom: 12 }}>
        <Animated.View
          style={[
            {
              height: '100%',
              backgroundColor: barColor,
              borderRadius: 4,
            },
            animatedBarStyle
          ]}
        />
      </View>

      {/* Stats row */}
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 13, color: '#fafafa' }}>
            {Math.round(budget.percentage)}%
          </Text>
          <Text style={{ fontFamily: 'Inter', fontSize: 12, color: '#52525b' }}>
            terpakai
          </Text>
        </View>
        <Text style={{ fontFamily: 'Inter_Medium', fontSize: 12, color: '#71717a' }}>
          {formatCurrency(budget.spent)} / {formatCurrency(budget.budget_amount)}
        </Text>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#09090b',
  },
  header: {
    paddingHorizontal: 24,
    paddingTop: 60,
    paddingBottom: 20,
    backgroundColor: '#09090b',
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: 28,
    fontFamily: 'Manrope_800ExtraBold',
    color: '#fafafa',
  },
  headerSubtitle: {
    fontSize: 14,
    fontFamily: 'Inter_Medium',
    color: '#71717a',
    marginTop: 2,
  },
  settingsButton: {
    width: 44,
    height: 44,
    borderRadius: 14,
    backgroundColor: '#18181b',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#27272a',
  },
  addButton: {
    width: 44,
    height: 44,
    borderRadius: 14,
    backgroundColor: '#10b981',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#10b981',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 4,
  },
  scrollContainer: {
    flex: 1,
    paddingHorizontal: 20,
  },
  summaryCard: {
    backgroundColor: '#18181b',
    padding: 24,
    borderRadius: 32,
    borderWidth: 1,
    borderColor: '#27272a',
    marginTop: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.2,
    shadowRadius: 20,
    elevation: 5,
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 20,
  },
  statusLabel: {
    fontFamily: 'Inter_Medium',
    fontSize: 13,
    color: '#71717a',
    marginLeft: 8,
    flex: 1,
  },
  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 8,
  },
  statusBadgeText: {
    fontFamily: 'Inter_Bold',
    fontSize: 12,
    textTransform: 'uppercase',
  },
  mainAmount: {
    fontFamily: 'Manrope_800ExtraBold',
    fontSize: 32,
    color: '#fafafa',
  },
  amountLabel: {
    fontFamily: 'Inter',
    fontSize: 13,
    color: '#71717a',
    marginTop: 4,
  },
  overallProgressBarContainer: {
    height: 10,
    backgroundColor: '#09090b',
    borderRadius: 5,
    marginTop: 24,
    overflow: 'hidden',
  },
  overallProgressBar: {
    height: '100%',
    borderRadius: 5,
  },
  statsRow: {
    flexDirection: 'row',
    marginTop: 24,
    gap: 12,
  },
  statBox: {
    flex: 1,
    backgroundColor: '#09090b',
    padding: 16,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#27272a',
  },
  statLabelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 6,
  },
  statLabelText: {
    fontFamily: 'Inter_Medium',
    fontSize: 12,
    color: '#71717a',
  },
  statValueText: {
    fontFamily: 'Manrope_700Bold',
    fontSize: 15,
    color: '#fafafa',
  },
  listHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 32,
    marginBottom: 16,
    paddingHorizontal: 4,
  },
  listHeaderTitle: {
    fontFamily: 'Manrope_700Bold',
    fontSize: 18,
    color: '#fafafa',
  },
  listAddButton: {
    width: 32,
    height: 32,
    borderRadius: 10,
    backgroundColor: '#10b98115',
    alignItems: 'center',
    justifyContent: 'center',
  },
  copyCard: {
    marginTop: 16,
    padding: 20,
    backgroundColor: '#3b82f610',
    borderRadius: 24,
    borderWidth: 1,
    borderColor: '#3b82f630',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  copyIconContainer: {
    width: 44,
    height: 44,
    borderRadius: 14,
    backgroundColor: '#3b82f615',
    alignItems: 'center',
    justifyContent: 'center',
  },
});
