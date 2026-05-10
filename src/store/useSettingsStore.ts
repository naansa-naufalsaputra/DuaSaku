import { create } from 'zustand';
import { persist, createJSONStorage, StateStorage } from 'zustand/middleware';
import { MMKV } from 'react-native-mmkv';

const storage = new MMKV({ encryptionKey: process.env.EXPO_PUBLIC_MMKV_ENCRYPTION_KEY || 'DuaSaku-BankGrade-SecureKey-2026' });

const mmkvStorage: StateStorage = {
  setItem: (name, value) => {
    return storage.set(name, value);
  },
  getItem: (name) => {
    const value = storage.getString(name);
    return value ?? null;
  },
  removeItem: (name) => {
    return storage.delete(name);
  },
};

export interface WishlistItem {
  id: string;
  name: string;
  price: number;
  savedAmount: number;
  icon: string;
  createdAt: string;
}

interface SettingsState {
  isAutoRecordEnabled: boolean;
  isPrivacyModeEnabled: boolean;
  useGasWebhook: boolean;
  gasWebhookUrl: string;
  customBankApps: string[];
  customIncomeKeywords: string[];
  aiPersonality: 'strict' | 'casual' | 'coach';
  financialGoal: {
    name: string;
    targetAmount: number;
    currentAmount: number;
  };
  wishlist: WishlistItem[];
  hasCompletedTutorial: boolean;
  toggleAutoRecord: () => void;
  togglePrivacyMode: () => void;
  setUseGasWebhook: (enabled: boolean) => void;
  setGasWebhookUrl: (url: string) => void;
  setAiPersonality: (personality: 'strict' | 'casual' | 'coach') => void;
  setFinancialGoal: (goal: { name: string; targetAmount: number; currentAmount: number }) => void;
  updateGoalAmount: (amount: number) => void;
  setHasCompletedTutorial: (completed: boolean) => void;
  addToWishlist: (item: Omit<WishlistItem, 'id' | 'createdAt'>) => void;
  removeFromWishlist: (id: string) => void;
  updateWishlistSavedAmount: (id: string, amount: number) => void;
  addFundsToWishlist: (id: string, amount: number) => void;
  addCustomApp: (packageName: string) => void;
  removeCustomApp: (packageName: string) => void;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      isAutoRecordEnabled: false,
      isPrivacyModeEnabled: false,
      useGasWebhook: true,
      gasWebhookUrl: 'https://script.google.com/macros/s/AKfycbzCAyDdtBR3_fQ9z4fHYUnFZ-3OJeYvBYnknoSrTjLUGmbAo9JbJDMEjG6xqE9lPOfq/exec',
      customBankApps: [
        'com.gojek.app', 'id.dana', 'ovo.id', 'com.shopee.id', 'com.telkom.mwallet',
        'com.bca', 'id.bmri.livin', 'id.co.bri.brimo', 'tgt.bni.co.id', 'com.jago.digitalBanking', 'com.bke.seabank'
      ],
      customIncomeKeywords: ["masuk", "menerima", "top up", "refund", "berhasil ditambahkan", "terima"],
      aiPersonality: 'casual',
      financialGoal: {
        name: '',
        targetAmount: 0,
        currentAmount: 0
      },
      wishlist: [],
      hasCompletedTutorial: false,
      toggleAutoRecord: () => set((state) => ({ isAutoRecordEnabled: !state.isAutoRecordEnabled })),
      togglePrivacyMode: () => set((state) => ({ isPrivacyModeEnabled: !state.isPrivacyModeEnabled })),
      setUseGasWebhook: (enabled) => set({ useGasWebhook: enabled }),
      setGasWebhookUrl: (url) => set({ gasWebhookUrl: url }),
      setAiPersonality: (personality) => set({ aiPersonality: personality }),
      setFinancialGoal: (goal) => set({ financialGoal: goal }),
      updateGoalAmount: (amount) => set((state) => ({ 
        financialGoal: { ...state.financialGoal, currentAmount: amount } 
      })),
      setHasCompletedTutorial: (completed) => set({ hasCompletedTutorial: completed }),
      
      addToWishlist: (item) => set((state) => ({
        wishlist: [
          ...state.wishlist,
          { ...item, id: Math.random().toString(36).substr(2, 9), createdAt: new Date().toISOString() }
        ]
      })),
      
      removeFromWishlist: (id) => set((state) => ({
        wishlist: state.wishlist.filter((i) => i.id !== id)
      })),
      
      updateWishlistSavedAmount: (id, amount) => set((state) => ({
        wishlist: state.wishlist.map((i) => i.id === id ? { ...i, savedAmount: amount } : i)
      })),

      addFundsToWishlist: (id, amount) => set((state) => ({
        wishlist: state.wishlist.map((i) => i.id === id ? { ...i, savedAmount: i.savedAmount + amount } : i)
      })),

      addCustomApp: (pkg) => set((state) => ({ 
        customBankApps: state.customBankApps.includes(pkg) ? state.customBankApps : [...state.customBankApps, pkg] 
      })),
      removeCustomApp: (pkg) => set((state) => ({ 
        customBankApps: state.customBankApps.filter(p => p !== pkg) 
      })),
    }),
    {
      name: 'duasaku-settings-storage',
      storage: createJSONStorage(() => mmkvStorage),
    }
  )
);
