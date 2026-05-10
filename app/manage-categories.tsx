import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, ScrollView, TouchableOpacity, ActivityIndicator, RefreshControl } from 'react-native';
import { useRouter } from 'expo-router';
import { ArrowLeft, Plus, ChevronRight, PieChart, Trash2 } from 'lucide-react-native';
import { useTranslation } from 'react-i18next';
import EmptyState from '../src/components/ui/EmptyState';
import { fetchBudgetsWithSpending, type BudgetWithSpending } from '../src/lib/budgetService';
import { useUserStore } from '../src/store/useUserStore';
import { useCategoryStore } from '../src/store/useCategoryStore';
import * as Haptics from 'expo-haptics';

export default function ManageCategoriesScreen() {
  const router = useRouter();
  const { t } = useTranslation();
  const { session } = useUserStore();
  const userId = session?.user?.id;
  const { getAllCategories, customCategories, removeCustomCategory } = useCategoryStore();
  const categories = getAllCategories();
  
  const [budgets, setBudgets] = useState<BudgetWithSpending[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const loadData = useCallback(async () => {
    if (!userId) return;
    try {
      const data = await fetchBudgetsWithSpending(userId);
      setBudgets(data);
    } catch (err) {
      console.error('[ManageCategories] Load error:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [userId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const onRefresh = () => {
    setRefreshing(true);
    loadData();
  };

  const formatCurrency = (amount: number) => `Rp ${Math.abs(amount).toLocaleString('id-ID')}`;

  return (
    <View style={{ flex: 1, backgroundColor: '#09090b' }}>
      {/* Header */}
      <View
        style={{
          paddingHorizontal: 24,
          paddingTop: 56,
          paddingBottom: 16,
          backgroundColor: '#09090b',
          borderBottomWidth: 1,
          borderBottomColor: '#18181b',
          flexDirection: 'row',
          alignItems: 'center',
          gap: 16,
        }}
      >
        <TouchableOpacity
          onPress={() => router.back()}
          style={{
            width: 40,
            height: 40,
            borderRadius: 12,
            backgroundColor: '#18181b',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <ArrowLeft color="#fafafa" size={20} />
        </TouchableOpacity>
        <View style={{ flex: 1 }}>
          <Text style={{ fontFamily: 'Manrope_800ExtraBold', fontSize: 20, color: '#fafafa' }}>
            {t('manageCategories') || 'Kelola Kategori'}
          </Text>
          <Text style={{ fontFamily: 'Inter', fontSize: 12, color: '#71717a' }}>
            Konfigurasi limit dan monitoring
          </Text>
        </View>
      </View>

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ padding: 24, paddingBottom: 100 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#fafafa" />}
      >
        <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 11, color: '#71717a', textTransform: 'uppercase', letterSpacing: 1.5, marginBottom: 16 }}>
          Kategori Aktif ({budgets.length})
        </Text>

        {loading ? (
          <ActivityIndicator color="#fafafa" style={{ marginTop: 40 }} />
        ) : budgets.length > 0 ? (
          <>
            {budgets.map((b) => {
              const meta = categories.find(c => c.key === b.category) || { emoji: '📦', color: '#6b7280', label: b.category };
              const isCustom = customCategories.some(c => c.name === b.category);
              
              return (
                <View key={b.id} style={{ marginBottom: 12 }}>
                  <TouchableOpacity
                    activeOpacity={0.7}
                    onPress={() => {
                      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                      router.push('/(tabs)/budget'); // Redirect to budget to edit
                    }}
                    style={{
                      backgroundColor: '#18181b',
                      padding: 16,
                      borderRadius: 20,
                      borderWidth: 1,
                      borderColor: '#27272a',
                      flexDirection: 'row',
                      alignItems: 'center',
                    }}
                  >
                    <View style={{ width: 44, height: 44, borderRadius: 14, backgroundColor: meta.color + '15', alignItems: 'center', justifyContent: 'center', marginRight: 16 }}>
                      <Text style={{ fontSize: 22 }}>{meta.emoji}</Text>
                    </View>
                    <View style={{ flex: 1 }}>
                      <Text style={{ fontFamily: 'Manrope_700Bold', fontSize: 16, color: '#fafafa' }}>
                        {meta.label}
                      </Text>
                      <Text style={{ fontFamily: 'Inter', fontSize: 12, color: '#71717a' }}>
                        Limit: {formatCurrency(b.budget_amount)}
                      </Text>
                    </View>
                    
                    {isCustom && (
                      <TouchableOpacity 
                        onPress={() => {
                          const custom = customCategories.find(c => c.name === b.category);
                          if (custom) removeCustomCategory(custom.id);
                          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
                        }}
                        style={{ padding: 8, marginRight: 4 }}
                      >
                        <Trash2 color="#ef4444" size={18} />
                      </TouchableOpacity>
                    )}
                    
                    <ChevronRight color="#3f3f46" size={20} />
                  </TouchableOpacity>
                </View>
              );
            })}

            <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 11, color: '#71717a', textTransform: 'uppercase', letterSpacing: 1.5, marginTop: 32, marginBottom: 16 }}>
              Kategori Lainnya
            </Text>

            {categories.reduce((acc: React.ReactNode[], c) => {
              if (!budgets.find(b => b.category === c.key)) {
                const isCustom = customCategories.some(cust => cust.name === c.key);
                acc.push(
                  <View key={c.key} style={{ marginBottom: 12 }}>
                    <TouchableOpacity
                      activeOpacity={0.7}
                      onPress={() => {
                        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                        router.push('/(tabs)/budget');
                      }}
                      style={{
                        backgroundColor: '#18181b',
                        padding: 16,
                        borderRadius: 20,
                        borderWidth: 1,
                        borderColor: '#27272a',
                        flexDirection: 'row',
                        alignItems: 'center',
                        opacity: 0.6,
                      }}
                    >
                      <View style={{ width: 44, height: 44, borderRadius: 14, backgroundColor: (c.color || '#6b7280') + '15', alignItems: 'center', justifyContent: 'center', marginRight: 16 }}>
                        <Text style={{ fontSize: 22 }}>{c.emoji}</Text>
                      </View>
                      <View style={{ flex: 1 }}>
                        <Text style={{ fontFamily: 'Manrope_700Bold', fontSize: 16, color: '#fafafa' }}>
                          {c.label}
                        </Text>
                        <Text style={{ fontFamily: 'Inter', fontSize: 12, color: '#52525b' }}>
                          Belum diatur anggarannya
                        </Text>
                      </View>

                      {isCustom && (
                        <TouchableOpacity 
                          onPress={() => {
                            const custom = customCategories.find(cust => cust.name === c.key);
                            if (custom) removeCustomCategory(custom.id);
                          }}
                          style={{ padding: 8, marginRight: 4 }}
                        >
                          <Trash2 color="#ef4444" size={18} />
                        </TouchableOpacity>
                      )}

                      <Plus color="#3f3f46" size={20} />
                    </TouchableOpacity>
                  </View>
                );
              }
              return acc;
            }, [])}
          </>
        ) : (
          <EmptyState 
            message="Belum ada anggaran yang diatur. Mulai kelola keuanganmu dengan menambah limit kategori."
          />
        )}
      </ScrollView>

      {/* Floating Action Hint */}
      <View style={{ position: 'absolute', bottom: 40, left: 24, right: 24, backgroundColor: '#10b98110', padding: 16, borderRadius: 20, borderWidth: 1, borderColor: '#10b98120', flexDirection: 'row', alignItems: 'center', gap: 12 }}>
        <PieChart color="#10b981" size={20} />
        <Text style={{ fontFamily: 'Inter', fontSize: 13, color: '#10b981', flex: 1 }}>
          Ketuk kategori untuk mengubah limit atau melihat detail pengeluaran.
        </Text>
      </View>
    </View>
  );
}
