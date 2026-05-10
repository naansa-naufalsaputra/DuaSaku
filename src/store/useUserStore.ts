import { create } from 'zustand';
import { persist, createJSONStorage, StateStorage } from 'zustand/middleware';
import { MMKV } from 'react-native-mmkv';
import { Session } from '@supabase/supabase-js';
import i18n from '../lib/i18n';

const storage = new MMKV({ id: 'user-storage',
  encryptionKey: process.env.EXPO_PUBLIC_MMKV_ENCRYPTION_KEY || 'DuaSaku-BankGrade-SecureKey-2026' });

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

interface UserProfile {
  name: string;
  avatar: string | null;
}

interface UserState {
  session: Session | null;
  userProfile: UserProfile;
  language: 'en' | 'id';
  biometricEnabled: boolean;
  setUserProfile: (name: string, avatar: string | null) => void;
  setSession: (session: Session | null) => void;
  setLanguage: (lang: 'en' | 'id') => void;
  setBiometricEnabled: (enabled: boolean) => void;
}

export const useUserStore = create<UserState>()(
  persist(
    (set) => ({
      session: null,
      userProfile: {
        name: 'User',
        avatar: null,
      },
      language: 'id',
      biometricEnabled: false,
      setUserProfile: (name, avatar) => set({ userProfile: { name, avatar } }),
      setSession: (session) => set({ session }),
      setLanguage: (lang) => {
        i18n.changeLanguage(lang);
        set({ language: lang });
      },
      setBiometricEnabled: (enabled) => set({ biometricEnabled: enabled }),
    }),
    {
      name: 'duasaku-user-storage',
      storage: createJSONStorage(() => mmkvStorage),
      partialize: (state) => ({ 
        language: state.language, 
        biometricEnabled: state.biometricEnabled,
        userProfile: state.userProfile,
        session: state.session // Adding session to persistent storage for faster recovery
      }),
    }
  )
);
