import * as TaskManager from 'expo-task-manager';
import * as Location from 'expo-location';
import * as Notifications from 'expo-notifications';
import { MMKV } from 'react-native-mmkv';

const storage = new MMKV({ encryptionKey: process.env.EXPO_PUBLIC_MMKV_ENCRYPTION_KEY || 'DuaSaku-BankGrade-SecureKey-2026' });

const GEOFENCE_TASK = 'GEOFENCE_TASK';

TaskManager.defineTask(GEOFENCE_TASK, async ({ data: { eventType, region }, error }: any) => {
  if (error) {
    console.error(error.message);
    return;
  }
  if (eventType === Location.GeofencingEventType.Enter) {
    await Notifications.scheduleNotificationAsync({
      content: {
        title: '⚠️ Watch your wallet!',
        body: "You've entered a frequent spending area.",
      },
      trigger: null,
    });
  }
});

export function getCachedTopSpots() {
  try {
    const cached = storage.getString('cached_geofences');
    return cached ? JSON.parse(cached) : [];
  } catch {
    return [];
  }
}

