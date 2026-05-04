import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { createMMKV } from 'react-native-mmkv';

const storage = createMMKV();

const mmkvStorage = {
  setItem: (name: string, value: string) => storage.set(name, value),
  getItem: (name: string) => storage.getString(name) ?? null,
  removeItem: (name: string) => storage.remove(name),
};

export interface Badge {
  id: string;
  name: string;
  description: string;
  icon: string;
  unlockedAt?: string;
}

interface GamificationState {
  healthScore: number;
  badges: Badge[];
  streakDays: number;
  lastRecordDate: string | null;
  
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
      ],
      streakDays: 0,
      lastRecordDate: null,

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
