import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { 
  View, 
  Text, 
  TouchableOpacity, 
  SectionList, 
  TextInput,
} from 'react-native';
import { useRouter } from 'expo-router';
import { 
  ChevronLeft, 
  Search, 
  X
} from 'lucide-react-native';
import { StatusBar } from 'expo-status-bar';
import { supabase } from '../src/lib/supabase';
import { useHaptic } from '../src/hooks/useHaptic';

import { useTranslation } from 'react-i18next';
import { Skeleton } from '../src/components/Skeleton';
import { PremiumBackground } from '../src/components/PremiumBackground';
import { CATEGORY_EMOJI } from '../src/lib/categoryIntelligence';
import { useUserStore } from '../src/store/useUserStore';
import EmptyState from '../src/components/ui/EmptyState';

type Transaction = {
  id: string;
  title: string;
  amount: number;
  type: 'income' | 'expense';
  category: string;
  created_at: string;
  note?: string;
};

export default function HistoryScreen() {
  const { t, i18n } = useTranslation();
  const router = useRouter();
  const { hapticLight } = useHaptic();
  
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [filter, setFilter] = useState<'all' | 'income' | 'expense'>('all');

  const { session } = useUserStore();
  const userId = session?.user?.id;

  const fetchTransactions = useCallback(async () => {
    if (!userId) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('transactions')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (!error && data) {
      setTransactions(data as Transaction[]);
    }
    setLoading(false);
  }, [userId]);

  useEffect(() => {
    if (userId) {
      fetchTransactions();
    }
  }, [userId, fetchTransactions]);

  const filteredTransactions = useMemo(() => {
    return transactions.filter(tx => {
      const matchesSearch = (tx.title || tx.note || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
                           (tx.category || '').toLowerCase().includes(searchQuery.toLowerCase());
      const matchesFilter = filter === 'all' || tx.type === filter;
      return matchesSearch && matchesFilter;
    });
  }, [transactions, searchQuery, filter]);

  const sections = useMemo(() => {
    const groups: Record<string, Transaction[]> = {};
    filteredTransactions.forEach(tx => {
      const date = new Date(tx.created_at).toLocaleDateString(i18n.language === 'id' ? 'id-ID' : 'en-US', { 
        day: 'numeric', 
        month: 'long', 
        year: 'numeric' 
      });
      if (!groups[date]) groups[date] = [];
      groups[date].push(tx);
    });

    return Object.keys(groups).map(date => ({
      title: date,
      data: groups[date]
    }));
  }, [filteredTransactions, i18n.language]);

  const formatCurrency = (amount: number) => {
    return `Rp ${Math.abs(amount).toLocaleString('id-ID')}`;
  };

  return (
    <View className="flex-1 bg-[#09090b]">
      <PremiumBackground />
      <StatusBar style="light" />
      
      {/* Header */}
      <View className="px-6 pt-14 pb-4 flex-row items-center justify-between border-b border-white/5">
        <TouchableOpacity 
          onPress={() => router.back()}
          className="w-10 h-10 bg-slate-800/50 rounded-full items-center justify-center border border-white/5"
        >
          <ChevronLeft color="white" size={24} />
        </TouchableOpacity>
        <Text className="text-white text-xl font-bold" style={{ fontFamily: 'Manrope_Bold' }}>{t('transactionHistory')}</Text>
        <View className="w-10" />
      </View>

      {/* Search & Filter */}
      <View className="px-6 mt-6 gap-y-4">
        <View className="flex-row items-center bg-slate-800/30 rounded-2xl px-4 py-3 border border-white/5">
          <Search color="#94a3b8" size={20} />
          <TextInput 
            className="flex-1 ml-3 text-white text-base"
            placeholder={t('searchPlaceholder')}
            placeholderTextColor="#64748b"
            value={searchQuery}
            onChangeText={setSearchQuery}
          />
          {searchQuery.length > 0 && (
            <TouchableOpacity onPress={() => setSearchQuery('')}>
              <X color="#64748b" size={18} />
            </TouchableOpacity>
          )}
        </View>

        <View className="flex-row gap-2">
          {['all', 'income', 'expense'].map((f) => (
            <TouchableOpacity 
              key={f}
              onPress={() => {
                hapticLight();
                setFilter(f as any);
              }}
              className={`px-5 py-2.5 rounded-full border ${filter === f ? 'bg-purple-600 border-purple-400' : 'bg-slate-800/30 border-white/5'}`}
            >
              <Text className={`capitalize font-bold text-sm ${filter === f ? 'text-white' : 'text-slate-400'}`}>
                {t(f)}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* List */}
      {loading ? (
        <View className="px-6 mt-8 gap-y-4">
          <Skeleton width="100%" height={80} radius={24} />
          <Skeleton width="100%" height={80} radius={24} />
          <Skeleton width="100%" height={80} radius={24} />
          <Skeleton width="100%" height={80} radius={24} />
        </View>
      ) : (
        <SectionList
          sections={sections}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ paddingHorizontal: 24, paddingTop: 20, paddingBottom: 100 }}
          stickySectionHeadersEnabled={false}
          renderSectionHeader={({ section: { title } }) => (
            <View className="mt-6 mb-4">
              <Text className="text-slate-500 text-xs font-bold uppercase tracking-[2px]">{title}</Text>
            </View>
          )}
          renderItem={({ item }) => (
            <TouchableOpacity 
              activeOpacity={0.7}
              className="mb-4 bg-slate-900/40 p-4 rounded-3xl border border-white/5 flex-row items-center justify-between"
            >
              <View className="flex-row items-center gap-4">
                <View className="w-12 h-12 bg-slate-800/80 rounded-2xl items-center justify-center border border-white/10">
                  <Text className="text-2xl">
                    {CATEGORY_EMOJI[item.category] || '📦'}
                  </Text>
                </View>
                <View>
                  <Text className="text-white font-bold text-base">{item.title || item.note || 'Transaksi'}</Text>
                  <Text className="text-slate-500 text-xs font-medium uppercase tracking-wider">{item.category || 'Other'}</Text>
                </View>
              </View>
              <View className="items-end">
                <Text className={`font-bold text-base ${item.type === 'income' ? 'text-green-400' : 'text-white'}`}>
                  {item.type === 'income' ? '+' : '-'}{formatCurrency(item.amount)}
                </Text>
                <Text className="text-slate-600 text-[10px]">
                  {new Date(item.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                </Text>
              </View>
            </TouchableOpacity>
          )}
          ListEmptyComponent={
            <EmptyState 
              message={t('history.noResults')} 
              animationAsset="https://assets10.lottiefiles.com/packages/lf20_nsm881db.json"
            />
          }
        />
      )}
    </View>
  );
}
