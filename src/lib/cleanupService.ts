import { createMMKV } from 'react-native-mmkv';
import { clearLottieCache } from './lottieCache';

/**
 * CleanupService — Handles secure data removal during logout or account deletion.
 * Ensures no sensitive data remains in local storage (MMKV).
 */
export const CleanupService = {
  /**
   * Clears all sensitive local data.
   * To be called during logout.
   */
  async clearAllCaches() {
    console.log('[CleanupService] Clearing all local caches...');

    try {
      // 1. Clear Offline Sync Queue
      const syncStorage = createMMKV({ id: 'offline-sync' });
      syncStorage.clearAll();

      // 2. Clear Settings (Optional: depends if you want to keep them for next user)
      // Usually, settings like "isAutoRecordEnabled" should be reset for privacy.
      const settingsStorage = createMMKV({ id: 'settings-storage' });
      settingsStorage.clearAll();

      // 3. Clear Lottie Animations (to keep the app lean)
      await clearLottieCache();

      // 4. User Storage (session, profile) is handled by useUserStore.persist.clear() 
      // or simply by the signOut() flow if managed correctly.
      const userStorage = createMMKV({ id: 'user-storage' });
      userStorage.clearAll();

      console.log('[CleanupService] All caches cleared successfully.');
    } catch (error) {
      console.error('[CleanupService] Error during cache cleanup:', error);
    }
  }
};
