import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { MMKV } from 'react-native-mmkv';

const storage = new MMKV({ encryptionKey: process.env.EXPO_PUBLIC_MMKV_ENCRYPTION_KEY || 'DuaSaku-BankGrade-SecureKey-2026' });

const mmkvStorage = {
  setItem: (name: string, value: string) => storage.set(name, value),
  getItem: (name: string) => storage.getString(name) ?? null,
  removeItem: (name: string) => storage.delete(name),
};

interface Badge {
  id: string;
  name: string;
  description: string;
  icon: string;
  unlockedAt?: string;
}

interface CommunityChallenge {
  id: string;
  title: string;
  description: string;
  targetValue: number;
  currentValue: number;
  reward: string;
  endDate: string;
  participantCount: number;
}

interface GamificationState {
  healthScore: number;
  badges: Badge[];
  streakDays: number;
  lastRecordDate: string | null;
  activeChallenges: CommunityChallenge[];
  
  setHealthScore: (score: number) => void;
  unlockBadge: (badgeId: string) => void;
  updateStreak: () => void;
}

export const useGamificationStore = create<GamificationState>()(
  persist(
    (set) => ({
      healthScore: 70,
      badges: [
        { id: 'first_tx', name: 'First Step', description: 'Mencatat transaksi pertama', icon: '🌱' },
        { id: 'streak_7', name: 'On Fire', description: 'Mencatat 7 hari berturut-turut', icon: '🔥' },
        { id: 'saver_master', name: 'Money Saver', description: 'Menabung lebih dari 30% pendapatan', icon: '💰' },
        { id: 'budget_king', name: 'Budget King', description: 'Tidak melampaui budget sebulan penuh', icon: '👑' },
        { id: 'transfer_expert', name: 'Bridge Builder', description: 'Melakukan transfer antar dompet pertama', icon: '🌉' },
        { id: 'emergency_hero', name: 'Emergency Hero', description: 'Membangun dana darurat yang aman', icon: '🛡️' },
        { id: 'investment_rookie', name: 'Future Thinker', description: 'Mulai berinvestasi untuk masa depan', icon: '📈' },
        { id: 'night_owl', name: 'Night Owl', description: 'Mencatat transaksi di larut malam', icon: '🦉' },
      ],
      streakDays: 0,
      lastRecordDate: null,
      activeChallenges: [
        {
          id: 'global_savings',
          title: 'Hemat Bersama: Ramadan',
          description: 'Seluruh komunitas menghemat Rp 500.000.000',
          targetValue: 500000000,
          currentValue: 125000000,
          reward: 'Exclusive Ramadhan Badge',
          endDate: '2026-05-31',
          participantCount: 1240
        },
        {
          id: 'no_spend_weekend',
          title: 'Weekend Tanpa Jajan',
          description: 'Tidak ada pengeluaran kategori "Jajan" di hari Sabtu & Minggu',
          targetValue: 2,
          currentValue: 1,
          reward: 'Savings Master Badge',
          endDate: '2026-05-11',
          participantCount: 450
        }
      ],

      setHealthScore: (score) => set({ healthScore: score }),
      
      unlockBadge: (badgeId) => set((state) => ({
        badges: state.badges.map(b => 
          b.id === badgeId && !b.unlockedAt 
            ? { ...b, unlockedAt: new Date().toISOString() } 
            : b
        )
      })),

      updateStreak: () => set((state) => {
        const today = new Date().toISOString().split('T')[0];
        if (state.lastRecordDate === today) return state;

        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        const yesterdayStr = yesterday.toISOString().split('T')[0];

        const newStreak = state.lastRecordDate === yesterdayStr ? state.streakDays + 1 : 1;
        
        return {
          streakDays: newStreak,
          lastRecordDate: today
        };
      }),
    }),
    {
      name: 'duasaku-gamification',
      storage: createJSONStorage(() => mmkvStorage),
    }
  )
);
