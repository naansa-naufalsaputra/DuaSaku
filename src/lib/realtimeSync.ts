import { supabase } from './supabase';
import { DeviceEventEmitter } from 'react-native';

let subscription: ReturnType<typeof supabase.channel> | null = null;

export const startRealtimeSync = (userId: string) => {
  if (subscription) {
    stopRealtimeSync();
  }

  subscription = supabase
    .channel('public:transactions')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'transactions',
        filter: `user_id=eq.${userId}`,
      },
      (payload) => {
        console.log('[RealtimeSync] Change received!', payload);
        DeviceEventEmitter.emit('transaction_added');
      }
    )
    .subscribe((status) => {
      console.log('[RealtimeSync] Status:', status);
    });
};

export const stopRealtimeSync = () => {
  if (subscription) {
    supabase.removeChannel(subscription);
    subscription = null;
  }
};
