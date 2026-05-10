import React from 'react';
import { View, Text, TouchableOpacity, ScrollView } from 'react-native';
import { ChevronLeft, Trophy, Medal, TrendingUp, Users } from 'lucide-react-native';
import { router } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
import { useHaptic } from '../src/hooks/useHaptic';
import { PremiumBackground } from '../src/components/PremiumBackground';
import { useGamificationStore } from '../src/store/useGamificationStore';

const MOCK_LEADERBOARD = [
  { id: '1', name: 'Naufal Saputra', score: 2850, streak: 12, avatar: '👤', rank: 1, trend: 'up' },
  { id: '2', name: 'Andi Wijaya', score: 2720, streak: 8, avatar: '👤', rank: 2, trend: 'up' },
  { id: '3', name: 'Budi Santoso', score: 2680, streak: 15, avatar: '👤', rank: 3, trend: 'down' },
  { id: '4', name: 'Siti Aminah', score: 2450, streak: 5, avatar: '👤', rank: 4, trend: 'stable' },
  { id: '5', name: 'Rizky Pratama', score: 2310, streak: 3, avatar: '👤', rank: 5, trend: 'up' },
  { id: '6', name: 'Dewi Lestari', score: 2100, streak: 7, avatar: '👤', rank: 6, trend: 'down' },
  { id: '7', name: 'Eko Prasetyo', score: 1980, streak: 2, avatar: '👤', rank: 7, trend: 'up' },
];

export default function LeaderboardScreen() {
  const { hapticLight } = useHaptic();
  const { streakDays, healthScore } = useGamificationStore();

  return (
    <View className="flex-1 bg-[#020617]">
      <PremiumBackground />
      
      {/* Header */}
      <View className="px-6 pt-14 pb-6 flex-row items-center justify-between">
        <TouchableOpacity 
          className="p-2 bg-surface-container rounded-full border border-white/5"
          onPress={() => {
            hapticLight();
            router.back();
          }}
        >
          <ChevronLeft color="white" size={24} />
        </TouchableOpacity>
        <Text className="text-white font-h2 text-xl">{t('leaderboardTitle')}</Text>
        <TouchableOpacity className="p-2 bg-surface-container rounded-full border border-white/5">
          <Users color="white" size={20} />
        </TouchableOpacity>
      </View>

      <ScrollView className="flex-1 px-6" showsVerticalScrollIndicator={false}>
        {/* Top 3 Podium */}
        <View className="flex-row justify-center items-end gap-4 mt-8 mb-10 h-48">
          {/* Rank 2 */}
          <View className="items-center">
            <View className="w-14 h-14 rounded-full bg-surface-container border-2 border-slate-400 items-center justify-center mb-2">
              <Text className="text-2xl">{MOCK_LEADERBOARD[1].avatar}</Text>
            </View>
            <View className="w-16 h-20 bg-surface-container rounded-t-2xl border-t border-x border-slate-400/30 items-center pt-2">
              <Text className="text-on-surface-variant font-bold text-xs">#2</Text>
              <Medal color="#94a3b8" size={16} />
            </View>
          </View>

          {/* Rank 1 */}
          <View className="items-center">
            <View className="w-18 h-18 rounded-full bg-surface-container border-2 border-amber-400 items-center justify-center mb-2 shadow-lg shadow-amber-400/20">
              <Text className="text-3xl">{MOCK_LEADERBOARD[0].avatar}</Text>
            </View>
            <View className="w-20 h-28 bg-surface-container rounded-t-2xl border-t border-x border-amber-400/30 items-center pt-2">
              <Trophy color="#fbbf24" size={24} />
              <Text className="text-amber-400 font-bold text-sm mt-1">#1</Text>
            </View>
          </View>

          {/* Rank 3 */}
          <View className="items-center">
            <View className="w-14 h-14 rounded-full bg-surface-container border-2 border-amber-700 items-center justify-center mb-2">
              <Text className="text-2xl">{MOCK_LEADERBOARD[2].avatar}</Text>
            </View>
            <View className="w-16 h-16 bg-surface-container rounded-t-2xl border-t border-x border-amber-700/30 items-center pt-2">
              <Text className="text-amber-700 font-bold text-xs">#3</Text>
              <Medal color="#b45309" size={16} />
            </View>
          </View>
        </View>

        {/* User Stats Card */}
        <LinearGradient
          colors={['#1e1b4b', '#0f172a']}
          className="p-5 rounded-[32px] border border-indigo-500/20 mb-10"
        >
          <View className="flex-row justify-between items-center">
            <View className="flex-row items-center gap-4">
              <View className="w-12 h-12 bg-indigo-500/20 rounded-2xl items-center justify-center border border-indigo-500/20">
                <Text className="text-2xl">👤</Text>
              </View>
              <View>
                <Text className="text-white font-bold text-lg">{t('you')}</Text>
                <Text className="text-indigo-300 text-xs font-medium">{t('globalRank', { rank: 42 })}</Text>
              </View>
            </View>
            <View className="items-end">
              <Text className="text-white font-bold text-xl">{healthScore * 10}</Text>
              <Text className="text-indigo-400 text-[10px] font-bold uppercase tracking-widest">{t('points')}</Text>
            </View>
          </View>
          
          <View className="h-[1px] bg-indigo-500/10 my-4" />
          
          <View className="flex-row justify-around">
            <View className="items-center">
              <Text className="text-white font-bold text-base">🔥 {streakDays}</Text>
              <Text className="text-on-surface-variant text-[8px] font-bold uppercase">{t('streak')}</Text>
            </View>
            <View className="items-center">
              <Text className="text-white font-bold text-base">3</Text>
              <Text className="text-on-surface-variant text-[8px] font-bold uppercase">{t('badges')}</Text>
            </View>
            <View className="items-center">
              <Text className="text-white font-bold text-base">Top 15%</Text>
              <Text className="text-on-surface-variant text-[8px] font-bold uppercase">{t('percentile')}</Text>
            </View>
          </View>
        </LinearGradient>

        {/* Full List */}
        <Text className="text-on-surface-variant font-bold text-xs uppercase tracking-widest mb-6 ml-2">{t('topSaviours')}</Text>
        
        <View className="mb-20">
          {MOCK_LEADERBOARD.map((item) => (
            <View 
              key={item.id}
              className="flex-row items-center justify-between mb-4 bg-surface-container p-4 rounded-3xl border border-white/5"
            >
              <View className="flex-row items-center gap-4">
                <View className="w-8 items-center">
                  <Text className={`font-bold ${item.rank <= 3 ? 'text-white' : 'text-on-surface-variant'}`}>{item.rank}</Text>
                </View>
                <View className="w-10 h-10 bg-surface-container rounded-xl items-center justify-center">
                  <Text className="text-lg">{item.avatar}</Text>
                </View>
                <View>
                  <Text className="text-white font-bold text-sm">{item.name}</Text>
                  <View className="flex-row items-center gap-1">
                    <Text className="text-on-surface-variant text-[10px]">🔥 {item.streak} days</Text>
                    {item.trend === 'up' && <TrendingUp size={10} color="#10b981" />}
                  </View>
                </View>
              </View>
              
              <View className="items-end">
                <Text className="text-white font-bold text-sm">{item.score.toLocaleString()}</Text>
                <Text className="text-on-surface-variant/50 text-[8px] font-bold uppercase tracking-wider">{t('points')}</Text>
              </View>
            </View>
          ))}
        </View>
      </ScrollView>
    </View>
  );
}
