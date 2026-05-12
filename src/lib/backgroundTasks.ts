import * as TaskManager from 'expo-task-manager';
import * as BackgroundFetch from 'expo-background-fetch';
import { MMKV } from 'react-native-mmkv';
import { supabase } from './supabase';
import { processSyncQueue, getPendingCount } from './offlineSync';
import { processDueRecurrences } from './recurringService';

const BACKGROUND_FETCH_TASK = 'BACKGROUND_FETCH_TASK';
const storage = new MMKV({ id: 'background-tasks', encryptionKey: process.env.EXPO_PUBLIC_MMKV_ENCRYPTION_KEY || 'DuaSaku-BankGrade-SecureKey-2026' });

TaskManager.defineTask(BACKGROUND_FETCH_TASK, async () => {
  try {
    // Step 1: Process sync queue if online
    const pendingCount = getPendingCount();
    if (pendingCount > 0) {
      const result = await processSyncQueue();
      console.log(`[BackgroundTask] Synced ${result.synced}, failed ${result.failed}`);
    }

    // Step 2: Process due recurring transactions (filtered by current session)
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return BackgroundFetch.BackgroundFetchResult.NoData;

    const recurring = await processDueRecurrences(session.user.id);
    if (recurring.processed > 0) {
      console.log(`[BackgroundTask] Auto-recorded ${recurring.processed} recurring transaction(s)`);
    }

    // Step 3: Cache latest transactions for offline reading (filtered by user)

    const { data, error } = await supabase
      .from('transactions')
      .select('*')
      .eq('user_id', session.user.id)
      .order('created_at', { ascending: false })
      .limit(50);

    if (!error && data) {
      storage.set('offline_transactions', JSON.stringify(data));
      return BackgroundFetch.BackgroundFetchResult.NewData;
    }
    return BackgroundFetch.BackgroundFetchResult.NoData;
  } catch {
    return BackgroundFetch.BackgroundFetchResult.Failed;
  }
});

export async function registerBackgroundFetchAsync() {
  return BackgroundFetch.registerTaskAsync(BACKGROUND_FETCH_TASK, {
    minimumInterval: 60 * 15, // 15 minutes
    stopOnTerminate: false, // android only
    startOnBoot: true, // android only
  });
}
