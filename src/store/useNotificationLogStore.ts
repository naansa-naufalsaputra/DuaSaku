import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from '../lib/storage';

interface NotificationLog {
  id: string;
  timestamp: number;
  app: string;
  title: string;
  body: string;
  status: 'parsed' | 'failed' | 'ignored';
  reason?: string;
  extractedAmount?: number;
}

interface NotificationLogState {
  logs: NotificationLog[];
  addLog: (log: Omit<NotificationLog, 'id' | 'timestamp'>) => void;
  clearLogs: () => void;
}

export const useNotificationLogStore = create<NotificationLogState>()(
  persist(
    (set) => ({
      logs: [],
      addLog: (log) => set((state) => ({
        logs: [
          {
            ...log,
            id: Math.random().toString(36).substring(7),
            timestamp: Date.now(),
          },
          ...state.logs.slice(0, 49), // Simpan 50 log terakhir saja
        ],
      })),
      clearLogs: () => set({ logs: [] }),
    }),
    {
      name: 'notification-logs',
      storage: createJSONStorage(() => mmkvStorage),
    }
  )
);
