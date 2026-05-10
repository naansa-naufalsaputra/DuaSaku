/**
 * SyncStatusBar — Floating indicator for offline/sync status
 * 
 * Shows a compact bar when:
 * - Device is offline (amber warning)
 * - There are pending transactions in the queue (info)
 * - Sync just completed (success flash)
 */

import React, { useState, useEffect, useCallback } from 'react';
import { Text, TouchableOpacity, Animated, DeviceEventEmitter } from 'react-native';
import { WifiOff, CloudOff, RefreshCw, CheckCircle } from 'lucide-react-native';
import { getPendingCount, processSyncQueue } from '../lib/offlineSync';
import { getIsConnected } from '../lib/networkMonitor';

type SyncState = 'hidden' | 'offline' | 'pending' | 'syncing' | 'success';

export default function SyncStatusBar() {
  const [syncState, setSyncState] = useState<SyncState>('hidden');
  const [pendingCount, setPendingCount] = useState(0);
  const [opacity] = useState(new Animated.Value(0));

  const showBar = useCallback((state: SyncState) => {
    setSyncState(state);
    Animated.timing(opacity, {
      toValue: 1,
      duration: 250,
      useNativeDriver: true,
    }).start();
  }, [opacity]);

  const hideBar = useCallback(() => {
    Animated.timing(opacity, {
      toValue: 0,
      duration: 250,
      useNativeDriver: true,
    }).start(() => setSyncState('hidden'));
  }, [opacity]);

  const checkStatus = useCallback(() => {
    const count = getPendingCount();
    setPendingCount(count);
    const online = getIsConnected();

    if (!online) {
      showBar('offline');
    } else if (count > 0) {
      showBar('pending');
    } else {
      hideBar();
    }
  }, [showBar, hideBar]);

  useEffect(() => {
    // Check initial state
    checkStatus();

    const connectivitySub = DeviceEventEmitter.addListener('connectivity_changed', ({ isConnected }) => {
      if (!isConnected) {
        showBar('offline');
      } else {
        checkStatus();
      }
    });

    const queueSub = DeviceEventEmitter.addListener('sync_queue_changed', ({ pending }) => {
      setPendingCount(pending);
      if (pending > 0 && getIsConnected()) {
        showBar('pending');
      } else if (pending > 0) {
        showBar('offline');
      } else {
        hideBar();
      }
    });

    const syncStartSub = DeviceEventEmitter.addListener('sync_started', () => {
      showBar('syncing');
    });

    const syncCompleteSub = DeviceEventEmitter.addListener('sync_completed', ({ synced }) => {
      if (synced > 0) {
        showBar('success');
        setTimeout(() => hideBar(), 2500);
      }
    });

    return () => {
      connectivitySub.remove();
      queueSub.remove();
      syncStartSub.remove();
      syncCompleteSub.remove();
    };
  }, [checkStatus, showBar, hideBar]);

  const handleRetrySync = useCallback(async () => {
    if (!getIsConnected()) return;
    showBar('syncing');
    await processSyncQueue();
  }, [showBar]);

  if (syncState === 'hidden') return null;

  const config = {
    offline: {
      bg: '#78350f',
      border: '#92400e',
      icon: <WifiOff color="#fbbf24" size={14} />,
      text: `Offline — ${pendingCount} transaksi menunggu`,
      textColor: '#fde68a',
    },
    pending: {
      bg: '#172554',
      border: '#1e3a5f',
      icon: <CloudOff color="#60a5fa" size={14} />,
      text: `${pendingCount} transaksi belum tersinkron`,
      textColor: '#93c5fd',
    },
    syncing: {
      bg: '#172554',
      border: '#1e3a5f',
      icon: <RefreshCw color="#60a5fa" size={14} />,
      text: 'Menyinkronkan...',
      textColor: '#93c5fd',
    },
    success: {
      bg: '#052e16',
      border: '#064e3b',
      icon: <CheckCircle color="#34d399" size={14} />,
      text: 'Semua transaksi tersinkron ✓',
      textColor: '#6ee7b7',
    },
  }[syncState]!;

  return (
    <Animated.View style={{ opacity }}>
      <TouchableOpacity
        onPress={syncState === 'pending' ? handleRetrySync : undefined}
        activeOpacity={syncState === 'pending' ? 0.7 : 1}
        style={{
          backgroundColor: config.bg,
          borderWidth: 1,
          borderColor: config.border,
          borderRadius: 16,
          paddingVertical: 8,
          paddingHorizontal: 14,
          flexDirection: 'row',
          alignItems: 'center',
          gap: 8,
          marginBottom: 12,
        }}
      >
        {config.icon}
        <Text style={{ color: config.textColor, fontSize: 12, fontFamily: 'Inter', flex: 1 }}>
          {config.text}
        </Text>
        {syncState === 'pending' && (
          <Text style={{ color: '#60a5fa', fontSize: 12, fontFamily: 'Inter_SemiBold' }}>Sync</Text>
        )}
      </TouchableOpacity>
    </Animated.View>
  );
}
