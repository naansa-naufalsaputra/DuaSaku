import * as TaskManager from 'expo-task-manager';
import * as Location from 'expo-location';
import * as Notifications from 'expo-notifications';
import { createMMKV } from 'react-native-mmkv';

const storage = createMMKV();

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

export async function startGeofencing(transactions: any[]) {
  const { status } = await Location.requestBackgroundPermissionsAsync();
  if (status !== 'granted') return;

  const spotCounts: Record<string, { lat: number, lng: number, count: number, categories: Record<string, number> }> = {};

  transactions.forEach(tx => {
    if (tx.latitude && tx.longitude) {
      const key = `${Number(tx.latitude).toFixed(4)},${Number(tx.longitude).toFixed(4)}`;
      if (!spotCounts[key]) {
        spotCounts[key] = { lat: Number(tx.latitude), lng: Number(tx.longitude), count: 0, categories: {} };
      }
      spotCounts[key].count++;
      const cat = tx.category || 'Unknown';
      spotCounts[key].categories[cat] = (spotCounts[key].categories[cat] || 0) + 1;
    }
  });

  const topSpots = Object.values(spotCounts)
    .sort((a, b) => b.count - a.count)
    .slice(0, 3)
    .map(spot => {
      const topCat = Object.entries(spot.categories).sort((a, b) => b[1] - a[1])[0][0];
      return { lat: spot.lat, lng: spot.lng, count: spot.count, category: topCat };
    });

  if (topSpots.length === 0) return;

  const newTopSpotsStr = JSON.stringify(topSpots);
  const cachedSpotsStr = storage.getString('cached_geofences');

  if (newTopSpotsStr === cachedSpotsStr) {
    return; // Skip registering if unchanged
  }

  const regions = topSpots.map((spot, index) => {
    let radius = 100;
    const cat = spot.category.toLowerCase();
    if (cat.includes('food') || cat.includes('cafe')) {
      radius = 50;
    } else if (cat.includes('shopping') || cat.includes('mall') || cat.includes('entertainment')) {
      radius = 200;
    }

    return {
      identifier: `spot_${index}`,
      latitude: spot.lat,
      longitude: spot.lng,
      radius,
      notifyOnEnter: true,
      notifyOnExit: false,
    };
  });

  try {
    await Location.startGeofencingAsync(GEOFENCE_TASK, regions);
    storage.set('cached_geofences', newTopSpotsStr);
  } catch (e) {
    console.log('Geofencing setup error:', e);
  }
}
