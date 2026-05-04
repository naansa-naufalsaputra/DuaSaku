/**
 * Network Monitor for DuaSaku
 *
 * Wraps @react-native-community/netinfo to provide:
 * 1. Real-time connectivity status
 * 2. Automatic sync trigger when going from offline → online
 * 3. DeviceEventEmitter events for UI indicators
 */

import NetInfo, { NetInfoState } from '@react-native-community/netinfo';
import { DeviceEventEmitter } from 'react-native';
import { processSyncQueue, getPendingCount } from './offlineSync';

let isConnected = true;
let unsubscribe: (() => void) | null = null;

/** Get current connectivity status */
export function getIsConnected(): boolean {
  return isConnected;
}

/** Start listening for network changes */
export function startNetworkMonitor(): void {
  if (unsubscribe) return; // Already listening

  unsubscribe = NetInfo.addEventListener(handleConnectivityChange);

  // Also do an initial check
  NetInfo.fetch().then(handleConnectivityChange);
}

/** Stop listening */
export function stopNetworkMonitor(): void {
  if (unsubscribe) {
    unsubscribe();
    unsubscribe = null;
  }
}

/** Handle connectivity state changes */
async function handleConnectivityChange(state: NetInfoState): Promise<void> {
  const wasOffline = !isConnected;
  isConnected = !!(state.isConnected && state.isInternetReachable !== false);

  DeviceEventEmitter.emit('connectivity_changed', { isConnected });

  // Transition: offline → online — trigger sync!
  if (wasOffline && isConnected) {
    const pending = getPendingCount();
    if (pending > 0) {
      console.log(`[NetworkMonitor] Back online! Syncing ${pending} pending transactions...`);
      DeviceEventEmitter.emit('sync_started', { pending });

      const result = await processSyncQueue();

      if (result.synced > 0) {
        console.log(`[NetworkMonitor] Synced ${result.synced} transactions`);
      }
      if (result.failed > 0) {
        console.warn(`[NetworkMonitor] ${result.failed} transactions moved to failed queue`);
      }
    }
  }
}
