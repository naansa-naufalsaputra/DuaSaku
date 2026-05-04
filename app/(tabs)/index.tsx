import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, TouchableOpacity, RefreshControl, DeviceEventEmitter } from 'react-native';
import { ArrowUpRight, ArrowDownLeft, Plus, History, Bell, Search, CreditCard, Cpu, Wifi, Eye, EyeOff, Target as TargetIcon } from 'lucide-react-native';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { 
  useSharedValue, 
  useAnimatedStyle, 
  useAnimatedScrollHandler, 
  interpolate, 
  Extrapolate
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

  const card3Style = useAnimatedStyle(() => {
    const scale = interpolate(scrollY.value, [-100, 0, 200], [1, 0.9, 0.85], Extrapolate.CLAMP);
    const translateY = interpolate(scrollY.value, [0, 200], [16, 40], Extrapolate.CLAMP);
    const opacity = interpolate(scrollY.value, [0, 200], [0.3, 0.1], Extrapolate.CLAMP);
    return { transform: [{ scale }, { translateY }], opacity };
  });

  const card2Style = useAnimatedStyle(() => {
    const scale = interpolate(scrollY.value, [-100, 0, 200], [1.05, 0.95, 0.9], Extrapolate.CLAMP);
    const translateY = interpolate(scrollY.value, [0, 200], [8, 20], Extrapolate.CLAMP);
    const opacity = interpolate(scrollY.value, [0, 200], [0.6, 0.3], Extrapolate.CLAMP);
    return { transform: [{ scale }, { translateY }], opacity };
  });

  const mainCardStyle = useAnimatedStyle(() => {
    const scale = interpolate(scrollY.value, [-100, 0, 200], [1.1, 1, 0.95], Extrapolate.CLAMP);
    return { transform: [{ scale }] };
  });

  const { session } = useUserStore();
  const userId = session?.user?.id;

  const [topBudget, setTopBudget] = useState<any>(null);
  const categories = useCategoryStore(state => state.getAllCategories());

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
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
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
          const amt = Number(tx.amount);
          const txDate = new Date(tx.created_at);
          
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
          if (tx.type === 'income') {
            total += tx.amount;
            inc += tx.amount;
          } else {
            total -= tx.amount;
            exp += tx.amount;
          }
        });

        setBalance(total);
        setMonthlyIncome(inc);
        setMonthlyExpense(exp);
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
          spendingMap[tx.category] = (spendingMap[tx.category] || 0) + tx.amount;
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

  useEffect(() => {
    fetchData();
    const sub = DeviceEventEmitter.addListener('transaction_added', fetchData);
    return () => sub.remove();
  }, [fetchData]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    fetchData();
  }, [fetchData]);

  const formatCurrency = (amount: number) => {
    return `Rp ${Math.abs(amount).toLocaleString('id-ID')}`;
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
              <View className="flex-row items-center bg-orange-500/10 px-2 py-0.5 rounded-full border border-orange-500/20">
                <Text className="text-[10px] mr-1">🔥</Text>
                <Text className="text-orange-400 text-[10px] font-bold">{streakDays} Days</Text>
              </View>
            )}
          </View>
          <View className="flex-row items-center gap-3">
            <Text className="text-white font-h1 text-2xl tracking-tight">{userProfile?.name || 'User'}</Text>
            <View className={`px-2 py-0.5 rounded-lg border ${
              healthScore >= 80 ? 'bg-green-500/10 border-green-500/20' : 
              healthScore >= 50 ? 'bg-amber-500/10 border-amber-500/20' : 
              'bg-red-500/10 border-red-500/20'
            }`}>
              <Text className={`text-[10px] font-bold uppercase tracking-tighter ${
                healthScore >= 80 ? 'text-green-400' : 
                healthScore >= 50 ? 'text-amber-400' : 
                'text-red-400'
              }`}>
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

        {/* Wallet Card Stack */}
        <View className="mt-6 items-center">
          {/* Card 3 (Backmost) */}
          <Animated.View 
            className="absolute w-[85%] h-52 bg-slate-800/20 rounded-[32px] border border-white/5" 
            style={card3Style} 
          />
          {/* Card 2 (Middle) */}
          <Animated.View 
            className="absolute w-[92%] h-52 bg-slate-800/40 rounded-[32px] border border-white/10" 
            style={card2Style} 
          />
          
          {/* Main Card */}
          <Animated.View 
            className="w-full h-56 rounded-[32px] overflow-hidden border border-white/20 shadow-2xl shadow-purple-500/30"
            style={mainCardStyle}
          >
            <LinearGradient
              colors={['#1e293b', '#0f172a', '#020617']}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              className="flex-1 p-6 justify-between"
            >
              {/* Card Top: Chip & Logo */}
              <View className="flex-row justify-between items-center">
                <View className="w-12 h-9 bg-slate-700/40 rounded-lg items-center justify-center border border-white/10">
                  <Cpu color="#e2e8f0" size={24} />
                </View>
                <View className="flex-row items-center gap-2">
                  <Wifi color="#94a3b8" size={18} opacity={0.6} />
                  <Text className="text-white/20 font-bold text-lg tracking-tighter italic">VISA</Text>
                </View>
              </View>

              {/* Card Middle: Balance */}
              <View>
                <View className="flex-row justify-between items-center mb-2">
                  <Text className="text-slate-400 font-medium text-xs uppercase tracking-[3px]">
                    {t('balance')}
                  </Text>
                  <TouchableOpacity 
                    testID="privacy_toggle_button"
                    onPress={() => {
                      hapticLight();
                      togglePrivacyMode();
                    }}
                    hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
                  >
                    {isPrivacyModeEnabled ? (
                      <EyeOff color="#94a3b8" size={16} />
                    ) : (
                      <Eye color="#94a3b8" size={16} />
                    )}
                  </TouchableOpacity>
                </View>
                {loading ? (
                  <Skeleton width={180} height={40} radius={8} />
                ) : (
                  <Text 
                    testID="dashboard_balance_text"
                    className="text-white font-bold text-4xl tracking-tighter" 
                    style={{ fontFamily: 'Manrope_Bold' }}
                  >
                    {isPrivacyModeEnabled ? '••••••••' : formatCurrency(balance)}
                  </Text>
                )}
              </View>

              {/* Card Bottom: Stats */}
              <View className="flex-row justify-between items-center pt-4 border-t border-white/10">
                <View className="flex-row items-center gap-3">
                  <View className="w-8 h-8 bg-green-500/20 rounded-full items-center justify-center">
                    <ArrowDownLeft color="#4ade80" size={16} />
                  </View>
                  <View>
                    <Text className="text-slate-500 text-[10px] uppercase font-bold">{t('income')}</Text>
                    {loading ? (
                      <Skeleton width={80} height={16} radius={4} />
                    ) : (
                      <Text className="text-white font-h3 text-sm">{formatCurrency(monthlyIncome)}</Text>
                    )}
                  </View>
                </View>
                <View className="flex-row items-center gap-3">
                  <View className="w-8 h-8 bg-red-500/20 rounded-full items-center justify-center">
                    <ArrowUpRight color="#f87171" size={16} />
                  </View>
                  <View className="items-end">
                    <Text className="text-slate-500 text-[10px] uppercase font-bold">{t('expense')}</Text>
                    {loading ? (
                      <Skeleton width={80} height={16} radius={4} />
                    ) : (
                      <Text className="text-white font-h3 text-sm">{formatCurrency(monthlyExpense)}</Text>
                    )}
                  </View>
                </View>
              </View>
            </LinearGradient>
          </Animated.View>
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
                  <Text className="text-slate-400 text-[10px] uppercase font-bold tracking-widest">Target Keuangan</Text>
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
              <Text className="text-slate-500 text-[10px] font-bold uppercase tracking-wider">
                {formatCurrency(topBudget.spent)} {t('of')} {formatCurrency(topBudget.budget_amount)}
              </Text>
              {topBudget.percentage >= 100 && (
                <Text className="text-red-400 text-[10px] font-bold uppercase">{t('limitExceeded')}</Text>
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
                        <Text style={{ fontSize: 24 }}>{item.icon || '🛍️'}</Text>
                      </View>
                      <View className="items-end">
                        <Text className="text-white font-bold text-lg">{formatCurrency(item.price)}</Text>
                        <Text className="text-slate-500 text-[10px] uppercase font-bold tracking-widest">{item.name}</Text>
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
                        <Text className="text-slate-400 text-[10px] font-bold uppercase">
                          {Math.round(progress)}% {t('saved')}
                        </Text>
                        <Text className="text-purple-400 text-[10px] font-bold uppercase">
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
                className={`mb-4 bg-slate-900/40 p-4 rounded-3xl border flex-row items-center justify-between ${tx._isPending ? 'border-amber-500/30 bg-amber-500/5' : 'border-white/5'}`}
              >
                <View className="flex-row items-center gap-4">
                  <View className="w-12 h-12 bg-slate-800/80 rounded-2xl items-center justify-center border border-white/10 shadow-sm">
                    <Text style={{ fontSize: 22 }}>{getCategoryMeta(tx.category).emoji}</Text>
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
                  <Text className={`font-bold text-base ${tx.type === 'income' ? 'text-green-400' : 'text-white'}`}>
                    {tx.type === 'income' ? '+' : '-'}{formatCurrency(tx.amount)}
                  </Text>
                  <Text className="text-slate-600 text-[10px]">
                    {new Date(tx.created_at).toLocaleDateString(t('language') === 'Bahasa' ? 'id-ID' : 'en-US', { day: 'numeric', month: 'short' })}
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
