import React, { useEffect, useState, useCallback, useRef } from 'react';
import { View, ActivityIndicator, Text, TouchableOpacity, StyleSheet, AppState, AppStateStatus } from 'react-native';
import { Stack, useRouter, useSegments } from 'expo-router';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { useFonts } from 'expo-font';
import { Inter_400Regular, Inter_500Medium, Inter_600SemiBold } from '@expo-google-fonts/inter';
import { Manrope_400Regular, Manrope_600SemiBold, Manrope_700Bold, Manrope_800ExtraBold } from '@expo-google-fonts/manrope';
import * as SplashScreen from 'expo-splash-screen';
import * as LocalAuthentication from 'expo-local-authentication';
import * as Notifications from 'expo-notifications';
import { Fingerprint, Lock } from 'lucide-react-native';
import * as Linking from 'expo-linking';
import { DeviceEventEmitter } from 'react-native';
import { useTranslation } from 'react-i18next';
import '../global.css';
import '../src/lib/i18n';
import { supabase } from '../src/lib/supabase';
import { useUserStore } from '../src/store/useUserStore';
import { useSettingsStore } from '../src/store/useSettingsStore';
import Toast from 'react-native-toast-message';
import { startNetworkMonitor } from '../src/lib/networkMonitor';
import { processDueRecurrences } from '../src/lib/recurringService';
import { registerBackgroundFetchAsync } from '../src/lib/backgroundTasks';
import { useCategoryStore } from '../src/store/useCategoryStore';
import { startRealtimeSync, stopRealtimeSync } from '../src/lib/realtimeSync';
import { updateDuaSakuWidget } from '../src/widgets/widget-task-handler';
import { logger } from '../src/lib/logger';

SplashScreen.preventAutoHideAsync();

// Global Error Handler
if (!__DEV__) {
  const originalHandler = ErrorUtils.getGlobalHandler();
  ErrorUtils.setGlobalHandler((error, isFatal) => {
    logger.fatal(`Global Crash: ${error.message}`, error, { isFatal });
    originalHandler(error, isFatal);
  });
}

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export default function RootLayout() {
  const [loaded, error] = useFonts({
    Inter: Inter_400Regular,
    Inter_Medium: Inter_500Medium,
    Inter_SemiBold: Inter_600SemiBold,
    Manrope: Manrope_400Regular,
    Manrope_SemiBold: Manrope_600SemiBold,
    Manrope_Bold: Manrope_700Bold,
    Manrope_ExtraBold: Manrope_800ExtraBold,
  });

  const [isAuthInitialized, setIsAuthInitialized] = useState(false);
  const [isUnlocked, setIsUnlocked] = useState(false);
  const { t } = useTranslation();
  const segments = useSegments();
  const router = useRouter();

  const { session, setSession, setUserProfile, biometricEnabled } = useUserStore();
  const { hasCompletedTutorial, biometricGracePeriod } = useSettingsStore();
  const lastBackgroundTime = useRef<number | null>(null);

  // Navigation Guard logic
  useEffect(() => {
    if (!isAuthInitialized || !loaded) return;

    const inAuthGroup = segments[0] === '(auth)';
    const inTutorial = segments[0] === 'tutorial';

    if (!session && !inAuthGroup) {
      router.replace('/(auth)/sign-in');
    } else if (session && !hasCompletedTutorial && !inTutorial) {
      router.replace('/tutorial');
    } else if (session && (inAuthGroup || inTutorial) && hasCompletedTutorial) {
      router.replace('/(tabs)');
    }
  }, [session, isAuthInitialized, segments, loaded, router, hasCompletedTutorial]);

  // Biometric Authentication logic
  const authenticate = useCallback(async () => {
    // Jika fitur biometrik dimatikan, jangan kunci
    if (!biometricEnabled) {
      setIsUnlocked(true);
      return;
    }

    // Jika fitur biometrik aktif, cek session secara async
    const sessionResponse = await supabase.auth.getSession();
    const currentSession = sessionResponse.data?.session;
    
    if (!currentSession) {
      setIsUnlocked(true);
      return;
    }

    const hasHardware = await LocalAuthentication.hasHardwareAsync();
    const isEnrolled = await LocalAuthentication.isEnrolledAsync();

    if (hasHardware && isEnrolled) {
      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: t('unlockDesc') || 'Buka brankas DuaSaku',
        fallbackLabel: 'Gunakan PIN/Password',
        cancelLabel: 'Batal',
        disableDeviceFallback: false,
      });

      if (result.success) {
        setIsUnlocked(true);
      }
    } else {
      setIsUnlocked(true);
    }
  }, [biometricEnabled, t]);

  useEffect(() => {
    if (loaded || error) {
      SplashScreen.hideAsync();
    }
  }, [loaded, error]);

  const appState = useRef(AppState.currentState);

  useEffect(() => {
    if (!loaded) return;

    // Initialize session and auth state
    const init = async () => {
      const { data: { session: initialSession } } = await supabase.auth.getSession();
      setSession(initialSession);
      
      if (initialSession) {
        setUserProfile(
          initialSession.user.user_metadata?.display_name || initialSession.user.user_metadata?.full_name || 'User',
          initialSession.user.user_metadata?.avatar_url || null
        );
        // Execute biometric lock for cold start
        await authenticate();
      } else {
        setIsUnlocked(true); // No lock for login screen
      }
      setIsAuthInitialized(true);

      // Start monitoring network for offline sync
      startNetworkMonitor();

      // Request notification permissions for budget alerts
      const setupNotifications = async () => {
        const { status: existingStatus } = await Notifications.getPermissionsAsync();
        let finalStatus = existingStatus;
        if (existingStatus !== 'granted') {
          const { status } = await Notifications.requestPermissionsAsync();
          finalStatus = status;
        }
        if (finalStatus !== 'granted') {
          console.warn('[Notifications] Permission denied — budget alerts will not appear.');
          return;
        }

        try {
          // projectId from app.json
          const projectId = 'db27d986-6bf8-4dad-9139-1d11fd36ce05';
          const tokenData = await Notifications.getExpoPushTokenAsync({ projectId });
          const pushToken = tokenData.data;
          
          if (initialSession?.user) {
            await supabase.from('profiles').update({ expo_push_token: pushToken }).eq('id', initialSession.user.id);
          }
        } catch (error) {
          console.error('[Notifications] Error fetching push token:', error);
        }

        // Schedule daily local notification fallback
        try {
          await Notifications.cancelAllScheduledNotificationsAsync();
          await Notifications.scheduleNotificationAsync({
            content: {
              title: "Jangan lupa catat pengeluaranmu! 📝",
              body: "Sudah 24 jam sejak terakhir kali kamu buka DuaSaku. Yuk, update catatan finansialmu hari ini.",
              data: { url: "/(tabs)" },
            },
            trigger: {
              seconds: 24 * 60 * 60, // 24 hours
              repeats: false,
            } as any,
          });
        } catch (error) {
          console.warn('[Notifications] Error scheduling local fallback:', error);
        }
      };
      setupNotifications();

      // Process any due recurring transactions
      if (initialSession) {
        startRealtimeSync(initialSession.user.id);
        processDueRecurrences(initialSession.user.id).catch(console.error);
      }

      // Register background fetch for periodic sync
      registerBackgroundFetchAsync().catch(console.error);

      // Sync categories to cloud
      if (initialSession) {
        useCategoryStore.getState().syncWithCloud(initialSession.user.id).catch(console.warn);
      }
    };

    // Handle Deep Linking
    const handleUrl = (url: string) => {
      const { path, queryParams } = Linking.parse(url);
      if (path === 'smart-input') {
        DeviceEventEmitter.emit('open-smart-input', queryParams);
      }
    };

    Linking.getInitialURL().then((url) => {
      if (url) handleUrl(url);
    });

    const linkingSub = Linking.addEventListener('url', (event) => {
      handleUrl(event.url);
    });

    const notificationSub = Notifications.addNotificationReceivedListener(notification => {
      console.log('Notification received in foreground:', notification);
    });

    const responseSub = Notifications.addNotificationResponseReceivedListener(response => {
      const url = response.notification.request.content.data?.url;
      if (url) {
        handleUrl(url); // Also, check if it's an internal route that can be navigated to
        if (url.startsWith('/')) {
          router.push(url as any);
        }
      }
    });

    init();

    const { data: { subscription: authSub } } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession);
      if (newSession) {
        setUserProfile(
          newSession.user.user_metadata?.display_name || newSession.user.user_metadata?.full_name || 'User',
          newSession.user.user_metadata?.avatar_url || null
        );
        startRealtimeSync(newSession.user.id);
        // We don't automatically lock on session change unless it's a login
        setIsUnlocked(true);
      } else {
        stopRealtimeSync();
        setIsUnlocked(true);
      }
    });

    // Handle AppState changes (Background to Foreground lock)
    const handleAppStateChange = (nextAppState: AppStateStatus) => {
      if (nextAppState === 'background' || nextAppState === 'inactive') {
        if (appState.current === 'active') {
          lastBackgroundTime.current = Date.now();
          updateDuaSakuWidget().catch(console.warn);
        }
      } else if (nextAppState === 'active' && appState.current.match(/inactive|background/)) {
        if (biometricEnabled && session) {
          const timeInBackground = lastBackgroundTime.current ? (Date.now() - lastBackgroundTime.current) / 1000 : Infinity;
          if (timeInBackground >= biometricGracePeriod) {
            setIsUnlocked(false);
            authenticate();
          }
        }
        lastBackgroundTime.current = null;
      }
      appState.current = nextAppState;
    };

    const appStateSub = AppState.addEventListener('change', handleAppStateChange);

    return () => {
      authSub.unsubscribe();
      appStateSub.remove();
      linkingSub.remove();
      notificationSub.remove();
      responseSub.remove();
    };
  }, [loaded, biometricEnabled, session, authenticate, setSession, setUserProfile, biometricGracePeriod]);

  if (!loaded && !error) return null;

  const renderContent = () => {
    if (!isAuthInitialized) {
      return (
        <View className="flex-1 bg-background items-center justify-center">
          <ActivityIndicator size="large" color="#fafafa" />
        </View>
      );
    }

    if (session && !isUnlocked && biometricEnabled) {
      return (
        <View testID="lock_screen_container" style={styles.lockedContainer}>
          <View style={styles.lockIconContainer}>
            <Lock color="#10b981" size={40} />
          </View>
          <Text style={styles.lockedTitle}>{t('appLocked')}</Text>
          <Text style={styles.lockedSubtitle}>{t('unlockDesc') || 'Gunakan biometrik untuk masuk'}</Text>
          
          <TouchableOpacity testID="lock_screen_unlock_button" style={styles.retryButton} onPress={authenticate} activeOpacity={0.7}>
            <Fingerprint color="#fafafa" size={24} />
            <Text style={styles.retryText}>{t('unlockBtn')}</Text>
          </TouchableOpacity>
        </View>
      );
    }

    return (
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="(auth)" />
        <Stack.Screen name="tutorial" />
      </Stack>
    );
  };

  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: '#09090b' }}>
      {renderContent()}
      <Toast />
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  lockedContainer: {
    flex: 1,
    backgroundColor: '#09090b',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  lockIconContainer: {
    width: 80,
    height: 80,
    borderRadius: 24,
    backgroundColor: '#18181b',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 24,
    borderWidth: 1,
    borderColor: '#27272a',
  },
  lockedTitle: {
    fontFamily: 'Manrope_700Bold',
    fontSize: 28,
    color: '#fafafa',
    marginBottom: 8,
  },
  lockedSubtitle: {
    fontFamily: 'Inter_400Regular',
    fontSize: 16,
    color: '#a1a1aa',
    marginBottom: 48,
    textAlign: 'center',
  },
  retryButton: {
    backgroundColor: '#18181b',
    paddingVertical: 16,
    paddingHorizontal: 32,
    borderRadius: 20,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderWidth: 1,
    borderColor: '#27272a',
  },
  retryText: {
    color: '#ffffff',
    fontSize: 16,
    fontFamily: 'Inter_600SemiBold',
  },
});
