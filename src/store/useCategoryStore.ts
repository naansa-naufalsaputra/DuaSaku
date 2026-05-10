import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from '../lib/storage';
import { supabase } from '../lib/supabase';

interface CustomCategory {
  id: string;
  name: string;
  emoji: string;
  color: string;
  targetAmount?: number;
}

const DEFAULT_CATEGORIES: { key: string; label: string; emoji: string; color: string; target?: number }[] = [
  { key: 'Food',          label: 'Makan & Minum',  emoji: '🍔', color: '#10b981' },
  { key: 'Transport',     label: 'Transportasi',   emoji: '🚗', color: '#3b82f6' },
  { key: 'Shopping',      label: 'Belanja',        emoji: '🛍️', color: '#ec4899' },
  { key: 'Health',        label: 'Kesehatan',      emoji: '🏥', color: '#ef4444' },
  { key: 'Entertainment', label: 'Hiburan',         emoji: '🎬', color: '#f59e0b' },
  { key: 'Utilities',     label: 'Tagihan',         emoji: '💡', color: '#8b5cf6' },
  { key: 'Education',     label: 'Pendidikan',     emoji: '📚', color: '#6366f1' },
  { key: 'Social',        label: 'Sosial & Zakat', emoji: '🤝', color: '#14b8a6' },
  { key: 'Hobby',         label: 'Hobi & Game',    emoji: '🎮', color: '#d946ef' },
  { key: 'Gift',          label: 'Hadiah',         emoji: '🎁', color: '#f43f5e' },
  { key: 'Subscription',  label: 'Langganan',      emoji: '💳', color: '#0ea5e9' },
  { key: 'Pet',           label: 'Hewan Peliharaan', emoji: '🐾', color: '#fb923c' },
  { key: 'Maintenance',   label: 'Perbaikan',      emoji: '🛠️', color: '#a8a29e' },
  { key: 'Debt',          label: 'Hutang & Cicilan', emoji: '💸', color: '#475569' },
  { key: 'Charity',       label: 'Donasi',         emoji: '🧡', color: '#f87171' },
  { key: 'Investment',    label: 'Investasi',      emoji: '📈', color: '#06b6d4' },
  { key: 'Other',         label: 'Lainnya',         emoji: '📦', color: '#6b7280' },
];

interface CategoryState {
  customCategories: CustomCategory[];
  categoryTargets: Record<string, number>; // name -> target
  addCustomCategory: (category: CustomCategory) => void;
  removeCustomCategory: (id: string) => void;
  setCategoryTarget: (name: string, target: number) => void;
  getAllCategories: () => { key: string; label: string; emoji: string; color: string; target?: number }[];
  syncWithCloud: (userId: string) => Promise<void>;
}

export const useCategoryStore = create<CategoryState>()(
  persist(
    (set, get) => ({
      customCategories: [],
      categoryTargets: {},
      addCustomCategory: (category) => 
        set((state) => ({ customCategories: [...state.customCategories, category] })),
      removeCustomCategory: (id) =>
        set((state) => ({ 
          customCategories: state.customCategories.filter((c) => c.id !== id) 
        })),
      setCategoryTarget: (name, target) =>
        set((state) => ({
          categoryTargets: { ...state.categoryTargets, [name]: target }
        })),
      getAllCategories: () => {
        const { customCategories, categoryTargets } = get();
        const custom = customCategories.map(c => ({
          key: c.name,
          label: c.name,
          emoji: c.emoji,
          color: c.color,
          target: categoryTargets[c.name] ?? c.targetAmount
        }));
        
        const defaults = DEFAULT_CATEGORIES.map(c => ({
          ...c,
          target: categoryTargets[c.key]
        }));

        return [...defaults, ...custom];
      },
      syncWithCloud: async (userId) => {
        const { customCategories, categoryTargets } = get();
        
        // 1. Sync Custom Categories
        const { error: catError } = await supabase
          .from('custom_categories')
          .upsert(
            customCategories.map(c => ({
              id: c.id,
              user_id: userId,
              name: c.name,
              emoji: c.emoji,
              color: c.color,
              target_amount: c.targetAmount
            }))
          );
        
        if (catError) console.error('[CategorySync] Categories error:', catError);

        // 2. Sync Targets
        const targetEntries = Object.entries(categoryTargets).map(([name, target]) => ({
          user_id: userId,
          category_name: name,
          target_amount: target
        }));

        if (targetEntries.length > 0) {
          const { error: targetError } = await supabase
            .from('category_targets')
            .upsert(targetEntries, { onConflict: 'user_id,category_name' });
          
          if (targetError) console.error('[CategorySync] Targets error:', targetError);
        }
      }
    }),
    {
      name: 'duasaku-categories',
      storage: createJSONStorage(() => mmkvStorage),
    }
  )
);
