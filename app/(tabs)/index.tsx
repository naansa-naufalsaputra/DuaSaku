import React, { useState, useEffect, useCallback, useRef } from 'react';
import { View, Text, TouchableOpacity, RefreshControl, DeviceEventEmitter, StyleSheet } from 'react-native';
import { 
  Bell, 
  Search, 
  Plus, 
  CreditCard, 
  Target as TargetIcon, 
  Cpu,
  History,
  EyeOff,
  TrendingUp
} from 'lucide-react-native';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { 
  useSharedValue, 
  useAnimatedScrollHandler
} from 'react-native-reanimated';
import { supabase } from '../../src/lib/supabase';
import { useUserStore } from '../../src/store/useUserStore';
import { useSettingsStore, WishlistItem } from '../../src/store/useSettingsStore';
import { useTranslation } from 'react-i18next';
import { Skeleton } from '../../src/components/Skeleton';
import { PremiumBackground } from '../../src/components/PremiumBackground';
import { useHaptic } from '../../src/hooks/useHaptic';
import SyncStatusBar from '../../src/components/SyncStatusBar';
import { getSyncQueue } from '../../src/lib/offlineSync';
import { router } from 'expo-router';
import EmptyState from '../../src/components/ui/EmptyState';
import { useCategoryStore } from '../../src/store/useCategoryStore';
import { useGamificationStore } from '../../src/store/useGamificationStore';
import { calculateHealthScore } from '../../src/lib/gamificationService';
import { calculateSpendingForecast } from '../../src/lib/budgetService';

export default function DashboardScreen() {
  const { t } = useTranslation();
  const { hapticLight, hapticMedium } = useHaptic();
  const userProfile = useUserStore(state => state.userProfile);
  const { isPrivacyModeEnabled, togglePrivacyMode } = useSettingsStore();
  const [balance, setBalance] = useState(0);
  const [monthlyIncome, setMonthlyIncome] = useState(0);
  const [monthlyExpense, setMonthlyExpense] = useState(0);
  const [recentTransactions, setRecentTransactions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [forecast, setForecast] = useState<any>(null);
  
  const { healthScore, streakDays } = useGamificationStore();
  const { wishlist } = useSettingsStore();
  const [wallets, setWallets] = useState<any[]>([]);
  const { session } = useUserStore();
  const userId = session?.user?.id;

  const [topBudget, setTopBudget] = useState<any>(null);
  const categories = useCategoryStore(state => state.getAllCategories());

  const averageSavings = monthlyIncome - monthlyExpense;
  
  const calculateDaysLeft = (item: WishlistItem) => {
    const remaining = item.price - item.savedAmount;
    if (remaining <= 0) return 0;
    if (averageSavings <= 0) return null;
    const dailySavings = averageSavings / 30;
    return Math.ceil(remaining / dailySavings);
  };

  // Animation Values
  const scrollY = useSharedValue(0);
  const scrollHandler = useAnimatedScrollHandler((event) => {
    scrollY.value = event.contentOffset.y;
  });


  const getCategoryMeta = (name: string) => {
    return categories.find(c => c.label === name) || { emoji: '📦', color: '#6366f1' };
  };

  const fetchData = useCallback(async () => {
    if (!userId) return;
    try {
      // 1. Fetch Transactions
      const { data, error } = await supabase
        .from('transactions')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(5);

      if (error) throw error;

      // Merge server transactions with local offline queue
      const offlineQueue = getSyncQueue().filter(q => q.user_id === userId);
      const offlineTxs = offlineQueue.map(q => ({
        id: q.localId,
        title: q.title,
        amount: q.amount,
        type: q.type,
        category: q.category,
        created_at: q.created_at,
        note: q.title,
        _isPending: true,
      }));
      
      const merged = [...offlineTxs, ...(data || [])]
        .sort((a, b) => {
          const dateA = new Date(a.created_at || 0).getTime();
          const dateB = new Date(b.created_at || 0).getTime();
          return dateB - dateA;
        })
        .slice(0, 5);

      setRecentTransactions(merged);

      // 2. Calculate Totals & Monthly Stats
      const { data: allData, error: allErr } = await supabase
        .from('transactions')
        .select('amount, type, created_at')
        .eq('user_id', userId);
      
      if (!allErr && allData) {
        const now = new Date();
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

        let total = 0;
        let inc = 0;
        let exp = 0;

        allData.forEach(tx => {
          const amt = Number(tx.amount || 0);
          const txDate = new Date(tx.created_at || 0);
          
          if (tx.type === 'income') {
            total += amt;
            if (txDate >= startOfMonth) inc += amt;
          } else {
            total -= amt;
            if (txDate >= startOfMonth) exp += amt;
          }
        });

        // Add offline queue to totals
        offlineQueue.forEach(tx => {
          const amt = Number(tx.amount || 0);
          if (tx.type === 'income') {
            total += amt;
            inc += amt;
          } else {
            total -= amt;
            exp += amt;
          }
        });

        setBalance(total);
        setMonthlyIncome(inc);
        setMonthlyExpense(exp);
      }

      // 2.5 Fetch Wallets
      const { data: walletData } = await supabase
        .from('wallets')
        .select('*')
        .eq('user_id', userId)
        .order('name');
      
      if (walletData) {
        setWallets(walletData);
        const totalNetWorth = walletData.reduce((acc, w) => acc + (w.balance || 0), 0);
        setBalance(totalNetWorth); // Use wallet sum for balance
      }

      // 3. Fetch Budgets for Widget
      const { data: budgetData } = await supabase
        .from('category_budgets')
        .select('*')
        .eq('user_id', userId!);

      if (budgetData && budgetData.length > 0) {
        // Calculate spending per category this month
        const now = new Date();
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
        
        const { data: monthTxs } = await supabase
          .from('transactions')
          .select('amount, category')
          .eq('user_id', userId!)
          .eq('type', 'expense')
          .gte('created_at', startOfMonth);

        const spendingMap: Record<string, number> = {};
        monthTxs?.forEach(tx => {
          spendingMap[tx.category] = (spendingMap[tx.category] || 0) + (Number(tx.amount) || 0);
        });

        const budgetProgress = budgetData.map(b => {
          const spent = spendingMap[b.category] || 0;
          return {
            ...b,
            spent,
            percentage: (spent / b.budget_amount) * 100
          };
        }).sort((a, b) => b.percentage - a.percentage);

        setTopBudget(budgetProgress[0]); // Get the most critical one
      }
      // 4. Update Gamification Score
      if (userId) {
        calculateHealthScore(userId);
        const fc = await calculateSpendingForecast(userId);
        setForecast(fc);
      }
    } catch (err) {
      console.error('Fetch Error:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [userId]);

  const fetchDataRef = useRef(fetchData);
  useEffect(() => { fetchDataRef.current = fetchData; }, [fetchData]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  useEffect(() => {
    const sub = DeviceEventEmitter.addListener('transaction_added', () => fetchDataRef.current());
    return () => sub.remove();
  }, []);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    fetchData();
  }, [fetchData]);

  const formatCurrency = (amount: number) => {
    return `Rp ${Math.abs(amount || 0).toLocaleString('id-ID')}`;
  };

  const getTimeOfDay = () => {
    const hour = new Date().getHours();
    if (hour < 12) return t('morning');
    if (hour < 17) return t('afternoon');
    return t('evening');
  };

  return (
    <View className="flex-1 bg-[#020617]">
      <PremiumBackground />
      {/* Header */}
      <View className="px-6 pt-14 pb-4 flex-row justify-between items-center">
        <View>
          <View className="flex-row items-center gap-2">
            <Text className="text-slate-400 font-body-sm text-sm">{getTimeOfDay()}</Text>
            {streakDays > 0 && (
              <View className="flex-row items-center bg-orange-500/10 px-3 py-1 rounded-full border border-orange-500/20">
                <Text className="text-xs mr-1">🔥</Text>
                <Text className="text-orange-400 text-xs font-bold">{streakDays} Days</Text>
              </View>
            )}
          </View>
          <View className="flex-row items-center gap-3">
            <Text className="text-white font-h1 text-2xl tracking-tight">{userProfile?.name || 'User'}</Text>
            <View style={[
              styles.scoreBadge,
              {
                backgroundColor: healthScore >= 80 ? 'rgba(34, 197, 94, 0.1)' : 
                               healthScore >= 50 ? 'rgba(245, 158, 11, 0.1)' : 
                               'rgba(239, 68, 68, 0.1)',
                borderColor: healthScore >= 80 ? 'rgba(34, 197, 94, 0.2)' : 
                           healthScore >= 50 ? 'rgba(245, 158, 11, 0.2)' : 
                           'rgba(239, 68, 68, 0.2)'
              }
            ]}>
              <Text style={[
                styles.scoreText,
                {
                  color: healthScore >= 80 ? '#4ade80' : 
                         healthScore >= 50 ? '#fbbf24' : 
                         '#f87171'
                }
              ]}>
                Score: {healthScore}
              </Text>
            </View>
          </View>
        </View>
        <View className="flex-row gap-3">
          <TouchableOpacity className="p-2.5 bg-slate-800/50 rounded-full border border-white/5">
            <Bell color="#fafafa" size={20} />
          </TouchableOpacity>
          <TouchableOpacity className="p-2.5 bg-slate-800/50 rounded-full border border-white/5">
            <Search color="#fafafa" size={20} />
          </TouchableOpacity>
        </View>
      </View>

      <Animated.ScrollView 
        className="flex-1 px-6"
        showsVerticalScrollIndicator={false}
        onScroll={scrollHandler}
        scrollEventThrottle={16}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#fafafa" />
        }
      >
        {/* Sync Status */}
        <SyncStatusBar />

        {/* Total Assets Card (Multi-Wallet Optimization) */}
        <LinearGradient
          colors={['#1e1b4b', '#0f172a']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.assetsCard}
        >
          {/* Decorative background elements */}
          <View style={styles.glowRight} />
          <View style={styles.glowLeft} />
          
          <View className="flex-row justify-between items-start mb-6">
            <View>
              <Text style={styles.assetsTitle}>Total Assets</Text>
              <View className="flex-row items-center gap-2">
                <Text style={styles.balanceText}>
                  {isPrivacyModeEnabled ? '••••••' : formatCurrency(balance)}
                </Text>
                <TouchableOpacity onPress={togglePrivacyMode}>
                  <EyeOff color="#6366f1" size={16} opacity={0.5} />
                </TouchableOpacity>
              </View>
            </View>
            <View className="bg-white/5 p-2.5 rounded-2xl border border-white/5">
              <TrendingUp color="#10b981" size={20} />
            </View>
          </View>

          <View style={styles.cashflowContainer}>
            <View>
              <Text style={styles.cashflowLabel}>Monthly Cashflow</Text>
              <View className="flex-row items-center gap-1.5">
                <View className="w-2 h-2 rounded-full bg-green-500" />
                <Text className="text-white font-bold text-sm">{formatCurrency(monthlyIncome)}</Text>
              </View>
            </View>
            <View className="w-[1px] h-8 bg-white/10" />
            <View className="items-end">
              <Text style={styles.cashflowLabel}>Expense Forecast</Text>
              <View className="flex-row items-center gap-1.5">
                <Text className="text-white font-bold text-sm">{formatCurrency(forecast?.predicted_total || 0)}</Text>
                <View className="w-2 h-2 rounded-full bg-orange-500" />
              </View>
            </View>
          </View>
        </LinearGradient>

        {/* Wallet List (Multi-Wallet Optimization) */}
        <View className="mt-8">
          <View className="flex-row justify-between items-center mb-4 px-2">
            <View>
              <Text className="text-white font-h2 text-xl">{t('myWallets') || 'Dompet Saya'}</Text>
              <Text className="text-slate-500 text-xs uppercase font-bold tracking-widest mt-0.5">Manage Assets</Text>
            </View>
            <TouchableOpacity 
              className="flex-row items-center gap-1.5 bg-purple-500/10 px-4 py-2 rounded-full border border-purple-500/20"
              onPress={() => {
                hapticMedium();
                DeviceEventEmitter.emit('open_smart_input', { mode: 'transfer' });
              }}
            >
              <Plus color="#c084fc" size={14} />
              <Text className="text-purple-400 font-bold text-xs">Transfer</Text>
            </TouchableOpacity>
          </View>
          
          <Animated.ScrollView 
            horizontal 
            showsHorizontalScrollIndicator={false}
            className="-mx-6 px-6"
            contentContainerStyle={{ paddingRight: 40 }}
          >
            {wallets.length > 0 ? (
              wallets.map((w) => (
                <TouchableOpacity 
                  key={w.id}
                  style={styles.walletCard}
                  onPress={() => hapticLight()}
                >
                  <LinearGradient
                    colors={[`${w.color || '#6366f1'}15`, 'transparent']}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 1 }}
                    className="absolute inset-0"
                  />
                  <View className="flex-row justify-between items-start">
                    <View style={styles.walletIconContainer}>
                      <CreditCard color={w.color || '#6366f1'} size={20} />
                    </View>
                    <View className="bg-white/5 px-2 py-1 rounded-lg">
                      <Text className="text-white/40 font-bold text-[12px] uppercase tracking-tighter">
                        {w.icon_name || 'Personal'}
                      </Text>
                    </View>
                  </View>
                  <View className="mt-auto">
                    <Text style={styles.walletName}>{w.name}</Text>
                    <Text style={styles.balanceText}>
                      {isPrivacyModeEnabled ? '••••••' : formatCurrency(w.balance)}
                    </Text>
                  </View>
                </TouchableOpacity>
              ))
            ) : (
              <View className="w-full h-32 bg-slate-900/20 rounded-[32px] border border-white/5 items-center justify-center border-dashed px-10">
                <Text className="text-slate-600 text-center text-sm">No wallets found. Add one to track your assets.</Text>
              </View>
            )}
            
            {/* Add Wallet Placeholder */}
            <TouchableOpacity 
              className="w-52 h-32 bg-slate-900/20 p-5 rounded-[32px] border border-white/10 border-dashed mr-4 items-center justify-center"
              onPress={() => hapticMedium()}
            >
              <View className="w-12 h-12 bg-slate-800/50 rounded-full items-center justify-center mb-2 border border-white/5">
                <Plus color="#94a3b8" size={24} />
              </View>
              <Text className="text-slate-500 font-bold text-xs">Tambah Dompet</Text>
            </TouchableOpacity>
          </Animated.ScrollView>
        </View>

        {/* Community Challenges Section (Gamification Phase 2) */}
        <View className="mt-10">
          <View className="flex-row justify-between items-center mb-6">
            <View className="flex-row items-center gap-2">
              <View className="w-8 h-8 bg-orange-500/10 rounded-full items-center justify-center border border-orange-500/20">
                <Cpu color="#f97316" size={16} />
              </View>
              <Text className="text-white font-h2 text-xl">Challenges</Text>
            </View>
            <TouchableOpacity 
              className="px-3 py-1 bg-white/5 rounded-full"
              onPress={() => router.push('/leaderboard' as any)}
            >
              <Text className="text-slate-400 text-xs font-bold uppercase tracking-wider">Top players</Text>
            </TouchableOpacity>
          </View>

          <TouchableOpacity 
            style={styles.challengeCard}
            onPress={() => {
              hapticMedium();
              router.push('/leaderboard' as any);
            }}
          >
            {/* Glow effect */}
            <View className="absolute -right-20 -top-20 w-60 h-60 bg-orange-500/5 rounded-full blur-3xl" />
            
            <View className="flex-row justify-between items-center mb-5">
              <View className="flex-1">
                <View className="flex-row items-center gap-2 mb-1">
                  <Text className="text-orange-400 font-bold text-xs uppercase tracking-[2px]">Active Challenge</Text>
                  <View className="w-1.5 h-1.5 bg-orange-500/30 rounded-full" />
                  <Text className="text-slate-500 font-bold text-xs uppercase tracking-wider">Expires in 2d</Text>
                </View>
                <Text className="text-white font-bold text-xl">7-Day Savings Streak</Text>
                <Text className="text-slate-400 text-sm mt-1 leading-4">Don't spend more than Rp 50k today to keep your streak alive!</Text>
              </View>
              <View className="items-center bg-orange-500/10 p-4 rounded-[28px] border border-orange-500/20">
                <Text className="text-white font-bold text-3xl">🔥{streakDays}</Text>
                <Text className="text-orange-400 text-[12px] font-bold uppercase tracking-widest">DAYS</Text>
              </View>
            </View>

            <View style={styles.progressBar}>
              <LinearGradient
                colors={['#f97316', '#fbbf24']}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
                style={{ width: `${Math.min((streakDays / 7) * 100, 100)}%`, height: '100%' }}
              />
            </View>

            <View className="flex-row justify-between items-center">
              <View className="flex-row -space-x-2">
                {[1, 2, 3].map((i) => (
                  <View key={i} className="w-8 h-8 rounded-full bg-slate-800 border border-slate-900 items-center justify-center">
                    <Text className="text-xs">👤</Text>
                  </View>
                ))}
                <Text className="text-slate-500 text-xs font-bold ml-4 mt-1">+420 participants</Text>
              </View>
              <Text className="text-orange-400 font-bold text-sm">Lihat Leaderboard</Text>
            </View>
          </TouchableOpacity>
        </View>


        {/* Goal Tracker Widget */}
        {useSettingsStore.getState().financialGoal.name ? (
          <TouchableOpacity 
            className="mt-8 bg-purple-600/10 p-5 rounded-[32px] border border-purple-500/20"
            onPress={() => router.push('/profile')}
          >
            <View className="flex-row justify-between items-center mb-3">
              <View className="flex-row items-center gap-3">
                <View className="w-10 h-10 bg-purple-500/20 rounded-xl items-center justify-center border border-purple-500/20">
                  <TargetIcon color="#c084fc" size={20} />
                </View>
                <View>
                  <Text className="text-white font-bold text-base">{useSettingsStore.getState().financialGoal.name}</Text>
                  <Text className="text-slate-400 text-[12px] uppercase font-bold tracking-widest">Target Keuangan</Text>
                </View>
              </View>
              <Text className="text-purple-400 font-bold text-lg">
                {Math.round((useSettingsStore.getState().financialGoal.currentAmount / useSettingsStore.getState().financialGoal.targetAmount) * 100) || 0}%
              </Text>
            </View>

            <View className="w-full h-3 bg-slate-800 rounded-full overflow-hidden border border-white/5">
              <View 
                className="h-full bg-purple-500 rounded-full"
                style={{ 
                  width: `${Math.min((useSettingsStore.getState().financialGoal.currentAmount / useSettingsStore.getState().financialGoal.targetAmount) * 100, 100) || 0}%` 
                }}
              />
            </View>
            
            <View className="flex-row justify-between mt-3">
              <Text className="text-slate-400 text-xs font-medium">
                {formatCurrency(useSettingsStore.getState().financialGoal.currentAmount)} terkumpul
              </Text>
              <Text className="text-slate-500 text-xs">
                {formatCurrency(useSettingsStore.getState().financialGoal.targetAmount)}
              </Text>
            </View>
          </TouchableOpacity>
        ) : null}


        {/* Budget Progress Widget */}
        {topBudget && (
          <TouchableOpacity 
            className="mt-8 bg-slate-900/60 p-5 rounded-[28px] border border-white/10"
            onPress={() => router.push('/analytics')}
          >
            <View className="flex-row justify-between items-center mb-3">
              <View className="flex-row items-center gap-2">
                <Text className="text-xl">{getCategoryMeta(topBudget.category).emoji}</Text>
                <Text className="text-white font-bold text-lg">{topBudget.category}</Text>
              </View>
              <Text className={`font-bold ${topBudget.percentage >= 100 ? 'text-red-400' : topBudget.percentage >= 80 ? 'text-amber-400' : 'text-slate-400'}`}>
                {Math.round(topBudget.percentage)}%
              </Text>
            </View>
            
            {/* Progress Bar Container */}
            <View className="w-full h-2 bg-slate-800 rounded-full overflow-hidden">
              <View 
                className={`h-full rounded-full ${topBudget.percentage >= 100 ? 'bg-red-500' : topBudget.percentage >= 80 ? 'bg-amber-500' : 'bg-purple-500'}`}
                style={{ width: `${Math.min(topBudget.percentage, 100)}%` }}
              />
            </View>
            
            <View className="flex-row justify-between mt-2">
              <Text className="text-slate-500 text-[12px] font-bold uppercase tracking-wider">
                {formatCurrency(topBudget.spent)} {t('of')} {formatCurrency(topBudget.budget_amount)}
              </Text>
              {topBudget.percentage >= 100 && (
                <Text className="text-red-400 text-[12px] font-bold uppercase">{t('limitExceeded')}</Text>
              )}
            </View>
          </TouchableOpacity>
        )}

        {/* Wishlist Section */}
        {wishlist.length > 0 && (
          <View className="mt-10">
            <View className="flex-row justify-between items-center mb-6">
              <View className="flex-row items-center gap-2">
                <View className="w-8 h-8 bg-slate-800 rounded-full items-center justify-center border border-white/5">
                  <Plus color="#94a3b8" size={16} />
                </View>
                <Text className="text-white font-h2 text-xl">Wishlist</Text>
              </View>
              <TouchableOpacity onPress={() => router.push('/profile')}>
                <Text className="text-purple-400 font-bold">{t('manage')}</Text>
              </TouchableOpacity>
            </View>
            
            <Animated.ScrollView 
              horizontal 
              showsHorizontalScrollIndicator={false}
              className="-mx-6 px-6"
              contentContainerStyle={{ paddingRight: 40 }}
            >
              {wishlist.map((item) => {
                const daysLeft = calculateDaysLeft(item);
                const progress = (item.savedAmount / item.price) * 100;
                
                return (
                  <TouchableOpacity 
                    key={item.id}
                    className="w-64 bg-slate-900/60 p-5 rounded-[32px] border border-white/10 mr-4"
                    onPress={() => hapticLight()}
                  >
                    <View className="flex-row justify-between items-start mb-4">
                      <View className="w-12 h-12 bg-slate-800 rounded-2xl items-center justify-center border border-white/5">
                        <Text style={styles.wishlistEmoji}>{item.icon || '🛍️'}</Text>
                      </View>
                      <View className="items-end">
                        <Text className="text-white font-bold text-lg">{formatCurrency(item.price)}</Text>
                        <Text className="text-slate-500 text-[12px] uppercase font-bold tracking-widest">{item.name}</Text>
                      </View>
                    </View>

                    <View className="w-full h-2 bg-slate-800 rounded-full overflow-hidden mb-3">
                      <View 
                        className="h-full bg-purple-500 rounded-full"
                        style={{ width: `${Math.min(progress, 100)}%` }}
                      />
                    </View>

                    <View className="flex-row justify-between items-center">
                      <View className="flex-1">
                        <Text className="text-slate-400 text-[12px] font-bold uppercase">
                          {Math.round(progress)}% {t('saved')}
                        </Text>
                        <Text className="text-purple-400 text-[12px] font-bold uppercase">
                          {daysLeft === null ? 'Need Savings Data' : daysLeft === 0 ? 'Ready!' : `${daysLeft} days left`}
                        </Text>
                      </View>
                      <TouchableOpacity 
                        className="w-8 h-8 bg-purple-600 rounded-full items-center justify-center shadow-lg"
                        onPress={() => {
                          hapticMedium();
                          // Simple mock: add 50k
                          useSettingsStore.getState().addFundsToWishlist(item.id, 50000);
                        }}
                      >
                        <Plus color="white" size={16} />
                      </TouchableOpacity>
                    </View>
                  </TouchableOpacity>
                );
              })}
            </Animated.ScrollView>
          </View>
        )}

        {/* Smart Forecast Alert */}
        {forecast && forecast.forecastedExpense > monthlyIncome && (
          <View className="mt-8 bg-red-500/10 p-5 rounded-[28px] border border-red-500/20 flex-row items-center gap-4">
            <View className="w-12 h-12 bg-red-500/20 rounded-2xl items-center justify-center">
              <Bell color="#f87171" size={24} />
            </View>
            <View className="flex-1">
              <Text className="text-red-400 font-bold text-sm uppercase tracking-wider">Smart Warning</Text>
              <Text className="text-white font-medium text-sm mt-1">
                You're spending too fast! Projected month-end expense: {formatCurrency(forecast.forecastedExpense)}
              </Text>
            </View>
          </View>
        )}

        {/* Action Buttons */}
        <View className="mt-8 flex-row gap-4">
          <TouchableOpacity 
            testID="add_transaction_fab"
            className="flex-1 bg-purple-600 h-14 rounded-2xl flex-row items-center justify-center gap-2 shadow-lg shadow-purple-600/30"
            onPress={() => {
              hapticMedium();
              DeviceEventEmitter.emit('open_smart_input');
            }}
          >
            <Plus color="white" size={20} />
            <Text className="text-white font-bold text-base">{t('newTransaction')}</Text>
          </TouchableOpacity>
          <TouchableOpacity 
            className="w-14 h-14 bg-slate-800/50 rounded-2xl items-center justify-center border border-white/10"
            onPress={() => hapticLight()}
          >
            <CreditCard color="white" size={20} />
          </TouchableOpacity>
        </View>

        {/* Recent Transactions */}
        <View className="mt-10 mb-20">
          <View className="flex-row justify-between items-center mb-6">
            <View className="flex-row items-center gap-2">
              <View className="w-8 h-8 bg-slate-800 rounded-full items-center justify-center border border-white/5">
                <History color="#94a3b8" size={16} />
              </View>
              <Text className="text-white font-h2 text-xl">{t('recentTransactions')}</Text>
            </View>
            <TouchableOpacity onPress={() => router.push('/history')}>
              <Text className="text-purple-400 font-bold">{t('seeAll')}</Text>
            </TouchableOpacity>
          </View>

          {loading ? (
            <View className="gap-3 mt-4">
              <Skeleton width="100%" height={70} radius={24} />
              <Skeleton width="100%" height={70} radius={24} />
              <Skeleton width="100%" height={70} radius={24} />
            </View>
          ) : recentTransactions.length > 0 ? (
            recentTransactions.map((tx, idx) => (
              <View 
                key={tx.id || idx} 
                style={[
                  styles.transactionCard,
                  tx._isPending ? styles.pendingTx : styles.regularTx
                ]}
              >
                <View className="flex-row items-center gap-4">
                  <View style={styles.categoryIcon}>
                    <Text style={styles.emoji}>{getCategoryMeta(tx.category).emoji}</Text>
                  </View>
                  <View>
                    <Text className="text-white font-bold text-base">
                      {tx.note || tx.title || t('transaction')}
                      {tx._isPending && <Text className="text-amber-400 text-xs italic"> • {t('syncing')}</Text>}
                    </Text>
                    <Text className="text-slate-500 text-xs font-medium uppercase tracking-wider">{tx.category || t('other')}</Text>
                  </View>
                </View>
                <View className="items-end">
                  <Text style={[
                    styles.amountText,
                    tx.type === 'income' ? styles.incomeText : styles.expenseText
                  ]}>
                    {tx.type === 'income' ? '+' : '-'}{formatCurrency(tx.amount)}
                  </Text>
                  <Text className="text-slate-600 text-xs">
                    {new Date(tx.created_at || Date.now()).toLocaleDateString(t('language') === 'Bahasa' ? 'id-ID' : 'en-US', { day: 'numeric', month: 'short' })}
                  </Text>
                </View>
              </View>
            ))
          ) : (
            <EmptyState 
              message={t('dashboard.noTransactions')} 
              animationAsset="https://assets9.lottiefiles.com/packages/lf20_glp9al7u.json"
            />
          )}
        </View>
      </Animated.ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  scoreBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 8,
    borderWidth: 1,
  },
  scoreText: {
    fontSize: 12,
    fontWeight: 'bold',
    textTransform: 'uppercase',
    letterSpacing: -0.5,
  },
  assetsCard: {
    marginTop: 24,
    padding: 24,
    borderRadius: 40,
    borderWidth: 1,
    borderColor: 'rgba(99, 102, 241, 0.2)',
    position: 'relative',
    overflow: 'hidden',
  },
  glowRight: {
    position: 'absolute',
    right: -40,
    top: -40,
    width: 160,
    height: 160,
    backgroundColor: 'rgba(79, 70, 229, 0.1)',
    borderRadius: 80,
  },
  glowLeft: {
    position: 'absolute',
    left: -40,
    bottom: -40,
    width: 160,
    height: 160,
    backgroundColor: 'rgba(147, 51, 234, 0.05)',
    borderRadius: 80,
  },
  assetsTitle: {
    color: '#818cf8',
    fontSize: 12,
    textTransform: 'uppercase',
    fontWeight: 'bold',
    letterSpacing: 2,
    marginBottom: 4,
  },
  balanceText: {
    color: '#ffffff',
    fontWeight: 'bold',
    fontSize: 30,
    fontFamily: 'Manrope_700Bold',
  },
  cashflowContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    padding: 16,
    borderRadius: 24,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.05)',
  },
  cashflowLabel: {
    color: '#94a3b8',
    fontSize: 12,
    textTransform: 'uppercase',
    fontWeight: 'bold',
    letterSpacing: 1,
    marginBottom: 4,
  },
  walletCard: {
    width: 208,
    height: 128,
    backgroundColor: 'rgba(15, 23, 42, 0.6)',
    padding: 20,
    borderRadius: 32,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    marginRight: 16,
    position: 'relative',
    overflow: 'hidden',
  },
  walletIconContainer: {
    width: 40,
    height: 40,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(30, 41, 59, 0.8)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
  },
  walletName: {
    color: '#94a3b8',
    fontSize: 12,
    textTransform: 'uppercase',
    fontWeight: 'bold',
    letterSpacing: 1,
    marginBottom: 4,
  },
  challengeCard: {
    backgroundColor: 'rgba(15, 23, 42, 0.6)',
    padding: 24,
    borderRadius: 40,
    borderWidth: 1,
    borderColor: 'rgba(249, 115, 22, 0.1)',
    position: 'relative',
    overflow: 'hidden',
  },
  progressBar: {
    width: '100%',
    height: 10,
    backgroundColor: 'rgba(30, 41, 59, 0.5)',
    borderRadius: 5,
    overflow: 'hidden',
    marginBottom: 20,
  },
  transactionCard: {
    marginBottom: 16,
    backgroundColor: 'rgba(15, 23, 42, 0.4)',
    padding: 16,
    borderRadius: 24,
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  categoryIcon: {
    width: 48,
    height: 48,
    backgroundColor: 'rgba(30, 41, 59, 0.8)',
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
  },
  emoji: {
    fontSize: 22,
  },
  amountText: {
    fontWeight: 'bold',
    fontSize: 16,
  },
  wishlistEmoji: {
    fontSize: 24,
  },
  pendingTx: {
    borderColor: 'rgba(245, 158, 11, 0.3)',
    backgroundColor: 'rgba(245, 158, 11, 0.05)',
  },
  regularTx: {
    borderColor: 'rgba(255, 255, 255, 0.05)',
    backgroundColor: 'rgba(15, 23, 42, 0.4)',
  },
  incomeText: {
    color: '#4ade80',
  },
  expenseText: {
    color: '#ffffff',
  }
});
