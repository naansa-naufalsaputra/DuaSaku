import React, { useState, useEffect, useCallback, useRef } from 'react';
import { View, Text, ScrollView, TouchableOpacity, Dimensions, DeviceEventEmitter, RefreshControl, ActivityIndicator, TextInput } from 'react-native';
import { Menu, UserCircle, Sparkles, TrendingUp, Target as TargetIcon, Calculator, AlertTriangle, ArrowRight } from 'lucide-react-native';
import { BarChart, PieChart } from 'react-native-gifted-charts';
import BottomSheet from '@gorhom/bottom-sheet';
import { supabase } from '../../src/lib/supabase';
import { generateFinancialSummary, predictMonthEnd, recommendBudgets } from '../../src/lib/aiAdvisor';
import { useTranslation } from 'react-i18next';
import { useUserStore } from '../../src/store/useUserStore';
import LottieView from 'lottie-react-native';
import EmptyState from '../../src/components/ui/EmptyState';
import TransactionDetailSheet, { type TransactionItem } from '../../src/components/TransactionDetailSheet';
import { fetchBudgetsWithSpending, BudgetWithSpending } from '../../src/lib/budgetService';
import BudgetGauge from '../../src/components/ui/BudgetGauge';
import { useSettingsStore } from '../../src/store/useSettingsStore';
import { simulateWhatIf } from '../../src/lib/budgetService';
import { HapticService } from '../../src/lib/hapticService';

import { Skeleton } from '../../src/components/Skeleton';
import { PremiumBackground } from '../../src/components/PremiumBackground';
import { useCategoryStore } from '../../src/store/useCategoryStore';

type CategoryDataItem = { value: number, color: string, text: string, name: string, percentage: number, emoji: string };

type TrendDataItem = { value: number; label: string; dateStr: string };

export default function AnalyticsScreen() {
  const { t } = useTranslation();
  const [trendData, setTrendData] = useState<TrendDataItem[]>([]);
  const [categoryData, setCategoryData] = useState<CategoryDataItem[]>([]);
  const [budgets, setBudgets] = useState<BudgetWithSpending[]>([]);
  const [totalExpense, setTotalExpense] = useState(0);
  const [rawTransactions, setRawTransactions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [filter, setFilter] = useState<'7days' | 'month' | 'lastMonth'>('7days');
  
  const [aiSummary, setAiSummary] = useState<string | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [spendingTrend, setSpendingTrend] = useState<{ value: number, isDown: boolean } | null>(null);
  const [currentMonthTotal, setCurrentMonthTotal] = useState(0);
  const [prediction, setPrediction] = useState<string | null>(null);
  const [budgetRecommendations, setBudgetRecommendations] = useState<string | null>(null);
  const [isPredicting, setIsPredicting] = useState(false);

  // Interactive chart state
  const [selectedDayTransactions, setSelectedDayTransactions] = useState<TransactionItem[]>([]);
  const [selectedDateLabel, setSelectedDateLabel] = useState('');
  const detailSheetRef = useRef<BottomSheet>(null);
  const [showSparkle, setShowSparkle] = useState(false);

  // What-If Simulator State
  const [purchaseAmount, setPurchaseAmount] = useState('');
  const [simulationResult, setSimulationResult] = useState<any[]>([]);
  const [showSimulator, setShowSimulator] = useState(false);

  const screenWidth = Dimensions.get('window').width;
  const yAxisLabelWidth = 40;
  // 32px for container margin (16px * 2), 40px for card padding (20px * 2)
  const chartWidth = screenWidth - 32 - 40 - yAxisLabelWidth;
  const barWidth = 22;
  const spacing = Math.max((chartWidth - (7 * barWidth)) / 6, 8);

  const { session } = useUserStore();
  const userId = session?.user?.id;
  const { userProfile, language } = useUserStore();
  const { aiPersonality, financialGoal } = useSettingsStore();
  const { getAllCategories } = useCategoryStore();
  const categories = getAllCategories();

  const getCategoryMeta = useCallback((name: string) => {
    return categories.find(c => c.label === name) || { emoji: '📦', color: '#52525b' };
  }, [categories]);

  const fetchAnalytics = useCallback(async () => {
    if (!userId) return;
    try {
      const today = new Date();
      let startDate = new Date();
      let endDate = new Date();

      if (filter === '7days') {
        startDate.setDate(today.getDate() - 6);
        startDate.setHours(0, 0, 0, 0);
      } else if (filter === 'month') {
        startDate = new Date(today.getFullYear(), today.getMonth(), 1);
      } else if (filter === 'lastMonth') {
        startDate = new Date(today.getFullYear(), today.getMonth() - 1, 1);
        endDate = new Date(today.getFullYear(), today.getMonth(), 0);
      }

      const { data, error } = await supabase
        .from('transactions')
        .select('*')
        .eq('user_id', userId)
        .eq('type', 'expense')
        .gte('created_at', startDate.toISOString())
        .lte('created_at', endDate.toISOString())
        .order('created_at', { ascending: true });

      if (error) throw error;
      
      setRawTransactions(data || []);

      // Calculate Trend: Compare Current Month vs Last Month
      const startOfCurrent = new Date(today.getFullYear(), today.getMonth(), 1);
      const startOfLast = new Date(today.getFullYear(), today.getMonth() - 1, 1);
      const endOfLast = new Date(today.getFullYear(), today.getMonth(), 0);

      const { data: trendDataRaw, error: trendErr } = await supabase
        .from('transactions')
        .select('amount, created_at')
        .eq('user_id', userId)
        .eq('type', 'expense')
        .gte('created_at', startOfLast.toISOString())
        .lte('created_at', today.toISOString());

      if (!trendErr && trendDataRaw) {
        let currentMonth = 0;
        let lastMonth = 0;
        
        trendDataRaw.forEach(tx => {
          const txDate = new Date(tx.created_at);
          const amt = Number(tx.amount);
          if (txDate >= startOfCurrent) {
            currentMonth += amt;
          } else if (txDate >= startOfLast && txDate <= endOfLast) {
            lastMonth += amt;
          }
        });

        setCurrentMonthTotal(currentMonth);
        if (lastMonth > 0) {
          const diff = ((currentMonth - lastMonth) / lastMonth) * 100;
          setSpendingTrend({ value: Math.abs(Math.round(diff)), isDown: diff <= 0 });
        } else {
          setSpendingTrend(null);
        }

        // Fetch Budget Status
        const budgetStatus = await fetchBudgetsWithSpending(userId!);
        setBudgets(budgetStatus);
      }

      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      let trend: TrendDataItem[] = [];
      
      if (filter === '7days') {
        for (let i = 6; i >= 0; i--) {
          const d = new Date();
          d.setDate(today.getDate() - i);
          const dateStr = d.toISOString().split('T')[0];
          trend.push({ label: days[d.getDay()], value: 0, dateStr });
        }
      } else {
        for (let i = 6; i >= 0; i--) {
          const d = new Date(endDate);
          d.setDate(endDate.getDate() - i);
          const dateStr = d.toISOString().split('T')[0];
          trend.push({ label: days[d.getDay()], value: 0, dateStr });
        }
      }

      let total = 0;
      const categoryTotals: Record<string, number> = {};

      if (data) {
        data.forEach(tx => {
          total += Number(tx.amount);
          const dateStr = tx.created_at.split('T')[0];
          
          const dayData = trend.find(d => d.dateStr === dateStr);
          if (dayData) {
            dayData.value += Number(tx.amount);
          }

          const cat = tx.category || 'Uncategorized';
          if (!categoryTotals[cat]) {
            categoryTotals[cat] = 0;
          }
          categoryTotals[cat] += Number(tx.amount);
        });
      }

      setTrendData(trend);
      setTotalExpense(total);

      const catArray = Object.keys(categoryTotals).map((catName) => {
        return {
          name: catName,
          value: categoryTotals[catName],
          percentage: total > 0 ? (categoryTotals[catName] / total) * 100 : 0
        };
      }).sort((a, b) => b.value - a.value);

      const formattedCategoryData = catArray.map((item) => {
        const meta = getCategoryMeta(item.name);
        return {
          value: item.value,
          color: meta.color,
          text: item.percentage >= 5 ? `${Math.round(item.percentage)}%` : '',
          name: item.name,
          emoji: meta.emoji,
          percentage: item.percentage
        };
      });

      setCategoryData(formattedCategoryData);
      
    } catch (error) {
      console.error('Error fetching analytics:', error);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [filter, userId, getCategoryMeta]);

  const handleGenerateSummary = async () => {
    if (isAnalyzing || rawTransactions.length === 0) return;
    setIsAnalyzing(true);
    setIsPredicting(true);
    try {
      const balance = 50000000; // Mock balance or fetch from wallet store
      const monthlyIncome = 10000000; // Mock income or fetch from settings

      const userContext = {
        name: userProfile?.name || 'User',
        language: language || 'en',
        personality: aiPersonality || 'casual',
        financialGoals: financialGoal.name || ''
      };
      
      // 1. Generate General Summary
      const summary = await generateFinancialSummary(rawTransactions, userContext as any);
      setAiSummary(summary);

      // 2. Generate Prediction
      const pred = await predictMonthEnd(rawTransactions, balance, userContext as any);
      setPrediction(pred);

      // 3. Generate Recommendations
      const recs = await recommendBudgets(rawTransactions, monthlyIncome, userContext as any);
      setBudgetRecommendations(recs);

    } catch (e) {
      console.error(e);
      setAiSummary("Gagal membuat analisis saat ini.");
    } finally {
      setIsAnalyzing(false);
      setIsPredicting(false);
    }
  };

  useEffect(() => {
    fetchAnalytics();
    
    const subscription = DeviceEventEmitter.addListener('transaction_added', () => {
      fetchAnalytics();
    });

    return () => subscription.remove();
  }, [fetchAnalytics]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    setAiSummary(null);
    fetchAnalytics();
  }, [fetchAnalytics]);

  const formatCurrency = (amount: number) => {
    return `Rp ${amount.toLocaleString('id-ID')}`;
  };


  /** Handle bar press — open drill-down sheet */
  const handleBarPress = useCallback((item: any, index: number) => {
    const dayInfo = trendData[index];
    if (!dayInfo) return;

    const dayTransactions = rawTransactions.filter(
      (tx) => tx.created_at.split('T')[0] === dayInfo.dateStr
    ) as TransactionItem[];

    const d = new Date(dayInfo.dateStr + 'T00:00:00');
    const dateLabel = d.toLocaleDateString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });

    setSelectedDayTransactions(dayTransactions);
    setSelectedDateLabel(dateLabel);
    detailSheetRef.current?.snapToIndex(0);

    // Play sparkle micro-interaction
    setShowSparkle(true);
    setTimeout(() => setShowSparkle(false), 1200);
  }, [trendData, rawTransactions]);

  /** Handle pie slice press — filter by category */
  const handlePiePress = useCallback((item: CategoryDataItem) => {
    const categoryTx = rawTransactions.filter(
      (tx) => (tx.category || 'Uncategorized') === item.name
    ) as TransactionItem[];

    setSelectedDayTransactions(categoryTx);
    setSelectedDateLabel(`${item.name} — ${item.percentage.toFixed(1)}%`);
    detailSheetRef.current?.snapToIndex(0);
  }, [rawTransactions]);

  const handleSimulate = () => {
    HapticService.medium();
    const amount = parseInt(purchaseAmount.replace(/[^0-9]/g, '')) || 0;
    if (amount <= 0) return;

    // Estimate monthly income/expense from current month
    const monthlyIncome = 10000000; // Mock or fetch from user settings if available
    const monthlyExpense = currentMonthTotal;
    const currentBalance = 50000000; // Mock or fetch from wallets

    const projection = simulateWhatIf(currentBalance, monthlyIncome, monthlyExpense, amount, 6);
    setSimulationResult(projection);
    setShowSimulator(true);
  };

  /** Build chartData with onPress handlers and selected state highlight */
  const chartDataWithHandlers = trendData.map((item, index) => ({
    value: item.value,
    label: item.label,
    onPress: () => handleBarPress(item, index),
    frontColor: selectedDateLabel && item.dateStr === trendData.find(
      (t) => {
        const d = new Date(t.dateStr + 'T00:00:00');
        const label = d.toLocaleDateString('id-ID', {
          weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
        });
        return label === selectedDateLabel;
      }
    )?.dateStr ? '#c084fc' : '#4b5563', // Neon purple if selected, slate-600 if not
  }));

  return (
    <View className="flex-1 bg-[#121212]">
      <PremiumBackground />
      {/* TopAppBar */}
      <View className="flex-row justify-between items-center px-6 h-24 pt-10">
        <TouchableOpacity className="w-10 h-10 bg-white/5 rounded-full items-center justify-center border border-white/10">
          <Menu color="#fafafa" size={20} />
        </TouchableOpacity>
        <Text className="text-white text-lg" style={{ fontFamily: 'Manrope_700Bold' }}>{t('analytics')}</Text>
        <TouchableOpacity className="w-10 h-10 bg-white/5 rounded-full items-center justify-center border border-white/10">
          <UserCircle color="#fafafa" size={20} />
        </TouchableOpacity>
      </View>

      <ScrollView 
        className="flex-1"
        contentContainerStyle={{ paddingHorizontal: 20, paddingTop: 10, paddingBottom: 120 }}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#fafafa" />
        }
      >
        {/* Header Analytic: Total Spending & Trend */}
        <View className="mb-8 px-2">
          <Text className="text-slate-500 font-medium text-[10px] uppercase tracking-[3px] mb-2">{t('totalSpendingThisMonth')}</Text>
          <View className="flex-row items-baseline gap-3">
            {loading ? (
              <Skeleton width={200} height={40} radius={8} />
            ) : (
              <Text className="text-white text-4xl" style={{ fontFamily: 'Manrope_800ExtraBold' }}>
                {formatCurrency(currentMonthTotal)}
              </Text>
            )}
            {spendingTrend && (
              <View className={`flex-row items-center px-2.5 py-1 rounded-full ${spendingTrend.isDown ? 'bg-green-500/10' : 'bg-red-500/10'}`}>
                <Text className={`text-[11px] font-bold ${spendingTrend.isDown ? 'text-green-400' : 'text-red-400'}`}>
                  {spendingTrend.isDown ? '↓' : '↑'} {spendingTrend.value}%
                </Text>
              </View>
            )}
          </View>
          <View className="flex-row items-center mt-2 opacity-60">
            <Text className="text-slate-400 text-xs">{t('vsLastMonth')} </Text>
            <Text className="text-slate-300 text-xs font-medium">{formatCurrency(currentMonthTotal - (currentMonthTotal / (1 + (spendingTrend?.value || 0) / 100)))}</Text>
          </View>
        </View>

        {/* Filter Chips */}
        <View className="mb-8">
          <ScrollView horizontal showsHorizontalScrollIndicator={false} className="flex-row h-11">
            {[
              { id: '7days', label: t('last7DaysShort') },
              { id: 'month', label: t('thisMonth') },
              { id: 'lastMonth', label: t('lastMonthShort') }
            ].map((item, index) => (
              <TouchableOpacity 
                key={item.id}
                className={`px-6 rounded-2xl justify-center mr-3 border ${filter === item.id ? 'bg-purple-600 border-purple-500 shadow-lg shadow-purple-500/30' : 'bg-white/5 border-white/10'}`}
                onPress={() => setFilter(item.id as any)}
              >
                <Text className={`text-[13px] font-bold ${filter === item.id ? 'text-white' : 'text-slate-400'}`}>{item.label}</Text>
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>

        {/* AI Advisor Card - Premium Glassmorphism */}
        <View className="mb-8">
          <View className="bg-[#1a1a1a]/80 border border-white/10 p-6 rounded-[32px] overflow-hidden">
            {/* Background Blur Decoration */}
            <View className="absolute -top-10 -right-10 w-32 h-32 bg-purple-600/10 rounded-full blur-3xl" />
            
            <View className="flex-row items-center gap-3 mb-4">
              <View className="w-10 h-10 bg-purple-500/20 rounded-2xl items-center justify-center border border-purple-500/20">
                <Sparkles color="#c084fc" size={20} />
              </View>
              <Text className="text-lg text-white" style={{ fontFamily: 'Manrope_700Bold' }}>{t('aiAdvisor')}</Text>
            </View>
            
            {aiSummary ? (
              <Text className="text-slate-300 text-[13.5px] leading-[22px] mb-5">
                {aiSummary}
              </Text>
            ) : (
              <Text className="text-slate-400 text-[13.5px] leading-[22px] mb-5">
                {t('aiAnalyzingDesc')}
              </Text>
            )}

            <TouchableOpacity 
              className={`py-4 rounded-2xl flex-row items-center justify-center ${isAnalyzing ? 'bg-white/5' : 'bg-purple-600'}`}
              onPress={handleGenerateSummary}
              disabled={isAnalyzing || rawTransactions.length === 0}
            >
              {isAnalyzing ? (
                <ActivityIndicator size="small" color="#c084fc" />
              ) : (
                <>
                  <Sparkles color="#fff" size={16} />
                  <Text className="ml-2 font-bold text-white text-sm">{aiSummary ? t('refreshAnalysis') : t('generateAnalysis')}</Text>
                </>
              )}
            </TouchableOpacity>
          </View>
        </View>

        {/* Financial What-If Simulator */}
        <View className="mb-8">
          <View className="bg-slate-900/60 border border-white/10 p-6 rounded-[32px]">
            <View className="flex-row items-center gap-3 mb-4">
              <View className="w-10 h-10 bg-blue-500/20 rounded-2xl items-center justify-center border border-blue-500/20">
                <Calculator color="#60a5fa" size={20} />
              </View>
              <View>
                <Text className="text-lg text-white font-bold">What-If Simulator</Text>
                <Text className="text-slate-500 text-xs">Model the impact of large purchases</Text>
              </View>
            </View>

            <View className="flex-row items-center gap-3 mb-4 bg-white/5 p-3 rounded-2xl border border-white/10">
              <Text className="text-slate-400 font-bold ml-2">Rp</Text>
              <TextInput
                className="flex-1 text-white font-bold text-lg p-0"
                placeholder="Enter amount (e.g. 15.000.000)"
                placeholderTextColor="#4b5563"
                keyboardType="numeric"
                value={purchaseAmount}
                onChangeText={setPurchaseAmount}
              />
              <TouchableOpacity 
                className="bg-blue-600 px-4 py-2 rounded-xl"
                onPress={handleSimulate}
              >
                <ArrowRight color="white" size={20} />
              </TouchableOpacity>
            </View>

            {showSimulator && simulationResult.length > 0 && (
              <View className="mt-2 bg-blue-500/5 p-4 rounded-2xl border border-blue-500/10">
                <View className="flex-row items-start gap-3 mb-4">
                  <AlertTriangle color="#60a5fa" size={16} />
                  <Text className="text-blue-400 text-xs flex-1 leading-5">
                    If you buy this today, your balance will be {formatCurrency(simulationResult[0].balance.amount)} after 1 month and {formatCurrency(simulationResult[5].balance.amount)} after 6 months.
                  </Text>
                </View>
                
                {/* Micro-chart mock or visual indicator */}
                <View className="flex-row justify-between items-end h-16 px-2">
                  {simulationResult.map((res, i) => (
                    <View key={i} className="items-center gap-2">
                      <View 
                        className="w-4 bg-blue-500/40 rounded-t-lg" 
                        style={{ height: Math.max(10, (res.balance.amount / (simulationResult[5].balance.amount || 1)) * 40) }} 
                      />
                      <Text className="text-[8px] text-slate-500">M{res.month}</Text>
                    </View>
                  ))}
                </View>
              </View>
            )}
          </View>
        </View>

        {/* AI Prediction & Recommendations Card */}
        {(isPredicting || prediction || budgetRecommendations) && (
          <View className="mb-8 gap-4">
            {isPredicting ? (
              <View className="bg-slate-900/40 border border-white/5 p-6 rounded-[32px] items-center py-10">
                <ActivityIndicator color="#c084fc" size="small" />
                <Text className="text-slate-500 text-[10px] uppercase font-bold tracking-widest mt-3">🧠 Menghitung Proyeksi Finansial...</Text>
              </View>
            ) : (
              <>
                {prediction && (
              <View className="bg-slate-900/60 border border-white/10 p-6 rounded-[32px]">
                <View className="flex-row items-center gap-3 mb-3">
                  <View className="w-8 h-8 bg-blue-500/20 rounded-xl items-center justify-center">
                    <TrendingUp color="#60a5fa" size={16} />
                  </View>
                  <Text className="text-white font-bold">Prediksi Akhir Bulan</Text>
                </View>
                <Text className="text-slate-300 text-xs leading-5">{prediction}</Text>
              </View>
            )}

            {budgetRecommendations && (
              <View className="bg-slate-900/60 border border-white/10 p-6 rounded-[32px]">
                <View className="flex-row items-center gap-3 mb-3">
                  <View className="w-8 h-8 bg-green-500/20 rounded-xl items-center justify-center">
                    <TargetIcon color="#4ade80" size={16} />
                  </View>
                  <Text className="text-white font-bold">Rekomendasi Anggaran</Text>
                </View>
                <Text className="text-slate-300 text-xs leading-5">{budgetRecommendations}</Text>
              </View>
            )}
          </>
        )}
      </View>
    )}

        {/* Trends Section */}
        <View className="mb-8">
          <View className="flex-row justify-between items-end mb-5 px-1">
            <View>
              <Text className="text-slate-500 text-[10px] uppercase font-bold tracking-widest mb-1">Expense Flow</Text>
              <Text className="text-white text-xl" style={{ fontFamily: 'Manrope_700Bold' }}>{t('trends')}</Text>
            </View>
            <View className="bg-white/5 px-2.5 py-1 rounded-lg border border-white/5">
              <Text className="text-slate-500 text-[9px] uppercase font-bold tracking-tighter">{t('tapBarForDetail')}</Text>
            </View>
          </View>
          
          <View 
            className="bg-[#1a1a1a]/80 border border-white/10 rounded-[32px] p-6 h-[300px] justify-center items-center shadow-2xl"
          >
            {loading && !refreshing ? (
              <ActivityIndicator size="large" color="#c084fc" />
            ) : (
              <>
                <BarChart
                  data={chartDataWithHandlers}
                  frontColor="#8b5cf6"
                  barWidth={barWidth}
                  spacing={spacing}
                  roundedTop
                  roundedBottom
                  hideRules
                  xAxisThickness={0}
                  yAxisThickness={0}
                  yAxisTextStyle={{ color: '#64748b', fontSize: 10, fontFamily: 'Inter' }}
                  xAxisLabelTextStyle={{ color: '#64748b', fontSize: 10, textAlign: 'center', fontFamily: 'Inter' }}
                  noOfSections={4}
                  yAxisLabelWidth={yAxisLabelWidth}
                  height={180}
                  isAnimated
                  animationDuration={500}
                  width={chartWidth}
                  disablePress={false}
                  activeOpacity={0.7}
                />
                {showSparkle && (
                  <View style={{ position: 'absolute', pointerEvents: 'none' }}>
                    <LottieView
                      source={{ uri: 'https://assets9.lottiefiles.com/packages/lf20_m6cuL6.json' }}
                      autoPlay
                      loop={false}
                      style={{ width: 300, height: 300 }}
                    />
                  </View>
                )}
              </>
            )}
          </View>
        </View>

        {/* Top Categories Section */}
        <View className="mb-10">
          <View className="flex-row justify-between items-end mb-5 px-1">
            <View>
              <Text className="text-slate-500 text-[10px] uppercase font-bold tracking-widest mb-1">{t('distribution')}</Text>
              <Text className="text-white text-xl" style={{ fontFamily: 'Manrope_700Bold' }}>{t('topCategories')}</Text>
            </View>
            <View className="bg-white/5 px-2.5 py-1 rounded-lg border border-white/5">
              <Text className="text-slate-500 text-[9px] uppercase font-bold tracking-tighter">{t('tapSliceForDetail')}</Text>
            </View>
          </View>

          <View className="bg-[#1a1a1a]/80 border border-white/10 rounded-[32px] p-6 shadow-2xl">
            {loading && !refreshing ? (
              <ActivityIndicator size="large" color="#c084fc" style={{ marginVertical: 40 }} />
            ) : categoryData.length > 0 ? (
              <>
                <View className="items-center justify-center mb-10 mt-4">
                  <PieChart
                    data={categoryData.map((item) => ({
                      ...item,
                      onPress: () => handlePiePress(item),
                    }))}
                    donut
                    radius={100}
                    innerRadius={75}
                    innerCircleColor={'#1a1a1a'}
                    textColor="white"
                    textSize={12}
                    strokeWidth={4}
                    strokeColor="#1a1a1a"
                    focusOnPress
                  />
                  <View className="absolute items-center justify-center">
                    <Text className="text-slate-500 text-[10px] uppercase font-bold tracking-widest mb-1">{t('total')}</Text>
                    <Text className="text-white text-lg" style={{ fontFamily: 'Manrope_700Bold' }}>{formatCurrency(totalExpense)}</Text>
                  </View>
                </View>

                <View className="flex-col gap-3">
                  {categoryData.map((item, index) => (
                    <TouchableOpacity 
                      key={index} 
                      style={{
                        flexDirection: 'row',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        backgroundColor: '#18181b',
                        padding: 16,
                        borderRadius: 20,
                        marginBottom: 12,
                        borderWidth: 1,
                        borderColor: '#27272a',
                      }}
                      onPress={() => handlePiePress(item)}
                    >
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                        <View style={{
                          width: 40,
                          height: 40,
                          borderRadius: 12,
                          backgroundColor: `${item.color}15`,
                          alignItems: 'center',
                          justifyContent: 'center'
                        }}>
                          <Text style={{ fontSize: 20 }}>{item.emoji}</Text>
                        </View>
                        <View>
                          <Text style={{ color: '#fff', fontSize: 15, fontWeight: '600', fontFamily: 'Inter' }}>{item.name}</Text>
                          <Text style={{ color: '#71717a', fontSize: 12, fontFamily: 'Inter' }}>{item.percentage.toFixed(0)}% dari pengeluaran</Text>
                        </View>
                      </View>
                      <Text style={{ color: '#fff', fontSize: 16, fontWeight: '700', fontFamily: 'Inter' }}>
                        {formatCurrency(item.value)}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </>
            ) : (
              <EmptyState 
                message={t('noExpenseData')} 
                animationAsset="https://assets6.lottiefiles.com/packages/lf20_y98ybejr.json"
              />
            )}
          </View>
        </View>

        {/* Budget Health Section */}
        {budgets.length > 0 && (
          <View className="mb-10">
            <View className="mb-5 px-1">
              <Text className="text-slate-500 text-[10px] uppercase font-bold tracking-widest mb-1">{t('budgetStatus') || 'Budget Health'}</Text>
              <Text className="text-white text-xl" style={{ fontFamily: 'Manrope_700Bold' }}>{t('budgetMonitoring') || 'Budget Monitoring'}</Text>
            </View>
            
            <View className="bg-[#1a1a1a]/80 border border-white/10 rounded-[32px] p-6 shadow-2xl">
              {budgets.map((budget, index) => (
                <BudgetGauge
                  key={budget.id || index}
                  label={budget.category}
                  percentage={budget.percentage}
                  amount={`${formatCurrency(budget.spent)} / ${formatCurrency(budget.budget_amount)}`}
                />
              ))}
            </View>
          </View>
        )}
      </ScrollView>

      {/* Transaction Detail Bottom Sheet */}
      <TransactionDetailSheet
        ref={detailSheetRef}
        transactions={selectedDayTransactions}
        dateLabel={selectedDateLabel}
        onClose={() => setSelectedDateLabel('')}
      />
    </View>
  );
}
