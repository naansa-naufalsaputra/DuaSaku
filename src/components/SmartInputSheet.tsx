import React, { useCallback, useMemo, forwardRef, useState, useRef, useEffect } from 'react';
import { View, Text, TouchableOpacity, ActivityIndicator, DeviceEventEmitter, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withRepeat,
  withSequence,
  Easing,
  type SharedValue,
} from 'react-native-reanimated';
import BottomSheet, { BottomSheetTextInput } from '@gorhom/bottom-sheet';
import { Sparkles, Plus, WifiOff, Mic, Square, ArrowRight, Wallet as WalletIcon } from 'lucide-react-native';
import { Audio } from 'expo-av';
import LottieView from 'lottie-react-native';
import { getCachedLottie } from '../lib/lottieCache';
import { cssInterop } from 'nativewind';
import { File } from 'expo-file-system/next';
import * as Location from 'expo-location';
import * as Haptics from 'expo-haptics';
import { refreshDailyReminder, checkBudgetAlert } from '../lib/notifications';
import { getCachedTopSpots } from '../lib/geofencing';
import { supabase } from '../lib/supabase';
import { parseTransactionWithAI, parseAudioWithAI, type UserContext } from '../lib/aiAdvisor';
import { enqueueTransaction, processSyncQueue } from '../lib/offlineSync';
import { getIsConnected } from '../lib/networkMonitor';
import { useTranslation } from 'react-i18next';
import { useUserStore } from '../store/useUserStore';
import { useSettingsStore } from '../store/useSettingsStore';
import { useGamificationStore } from '../store/useGamificationStore';
import { calculateHealthScore } from '../lib/gamificationService';
import { useCategoryStore } from '../store/useCategoryStore';
import { isDuplicateTransaction } from '../lib/conflictResolution';
import { updateTransaction } from '../lib/transactionService';
import { createTransfer } from '../lib/transferService';
// import { predictCategory } from '../lib/categoryIntelligence';

function getDistance(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 6371e3;
  const p1 = lat1 * Math.PI / 180;
  const p2 = lat2 * Math.PI / 180;
  const dp = (lat2 - lat1) * Math.PI / 180;
  const dl = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(dp / 2) * Math.sin(dp / 2) +
    Math.cos(p1) * Math.cos(p2) *
    Math.sin(dl / 2) * Math.sin(dl / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

const NUM_BARS = 24;

/** Single animated waveform bar */
const WaveBar = ({ levels, index }: { levels: SharedValue<number[]>; index: number }) => {
  const animatedStyle = useAnimatedStyle(() => {
    // Each bar reacts to the level at its index
    const level = levels.value[index] || 0;
    const offset = Math.sin(index * 0.8) * 0.15;
    const height = Math.max(3, (level + offset) * 28);
    return {
      height,
      opacity: 0.5 + level * 0.5,
    };
  });

  return (
    <Animated.View
      style={[
        styles.waveBar,
        animatedStyle,
      ]}
    />
  );
};

interface SmartInputSheetProps {
  onClose?: () => void;
}

cssInterop(BottomSheetTextInput, { className: 'style' });

const SmartInputSheet = forwardRef<BottomSheet, SmartInputSheetProps>(({ onClose }, ref) => {
  const { t } = useTranslation();
  const { userProfile, language, session } = useUserStore();
  const { aiPersonality, financialGoal } = useSettingsStore();
  const { getAllCategories } = useCategoryStore();
  const categories = getAllCategories().map(c => c.label);
  const userId = session?.user?.id;
  const [inputText, setInputText] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [suggestion, setSuggestion] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [showSuccess, setShowSuccess] = useState(false);
  const [successUri, setSuccessUri] = useState<string | null>(null);
  const [showCelebration, setShowCelebration] = useState(false);
  const [unlockedBadge, setUnlockedBadge] = useState<any>(null);

  // Transfer Mode state
  const [isTransferMode, setIsTransferMode] = useState(false);
  const [wallets, setWallets] = useState<any[]>([]);
  const [fromWalletId, setFromWalletId] = useState<string | null>(null);
  const [toWalletId, setToWalletId] = useState<string | null>(null);
  const [selectingWalletFor, setSelectingWalletFor] = useState<'from' | 'to' | null>(null);

  // Edit Mode state
  const [editingId, setEditingId] = useState<string | null>(null);
  const isEditMode = !!editingId;

  /**
   * Mengambil ringkasan transaksi terakhir untuk memori AI
   */
  const getRecentContext = async (): Promise<string> => {
    if (!userId) return '';
    try {
      const { data } = await supabase
        .from('transactions')
        .select('title, amount, type')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(5);
      
      if (!data || data.length === 0) return '';
      return data.map(t => `${t.type === 'expense' ? '-' : '+'}${t.amount} untuk ${t.title}`).join(', ');
    } catch {
      return '';
    }
  };

  useEffect(() => {
    // High-quality confetti celebration
    getCachedLottie('https://lottie.host/819d44c8-3c5e-42c2-8419-867c2957f864/D3m6Jv2X1R.json').then(setSuccessUri);
    
    // Fetch wallets
    if (userId) {
      supabase.from('wallets').select('*').eq('user_id', userId).then(({ data }) => {
        if (data) {
          setWallets(data);
          if (data.length > 0) {
            setFromWalletId(data[0].id);
            if (data.length > 1) {
              setToWalletId(data[1].id);
            } else {
              setToWalletId(data[0].id);
            }
          }
        }
      });
    }
  }, [userId]);

  // Voice recording state
  const [isRecording, setIsRecording] = useState(false);
  const [recordingDuration, setRecordingDuration] = useState(0);
  const recordingRef = useRef<Audio.Recording | null>(null);
  const durationTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  // Waveform metering — a single shared value array to satisfy rules-of-hooks
  const waveformLevels = useSharedValue<number[]>(new Array(NUM_BARS).fill(0));

  // Pulse animation for the recording dot
  const dotScale = useSharedValue(1);

  const lottieSource = useMemo(() => ({ 
    uri: showCelebration 
      ? 'https://lottie.host/df2c1c3f-4e9e-4e4b-9e4f-0e4b3a2c1d0f/celebrate.json' 
      : (successUri || 'https://assets3.lottiefiles.com/packages/lf20_at6ayqnr.json') 
  }), [showCelebration, successUri]);

  useEffect(() => {
    const sub = DeviceEventEmitter.addListener('open_smart_input', (data?: { text?: string }) => {
      setEditingId(null);
      if (data?.text) {
        setInputText(data.text);
      }
      (ref as any).current?.snapToIndex(1);
    });

    const editSub = DeviceEventEmitter.addListener('edit_transaction', (tx: any) => {
      setEditingId(tx.id);
      setInputText(`${tx.title} ${tx.amount}`);
      (ref as any).current?.snapToIndex(1);
    });

    return () => {
      sub.remove();
      editSub.remove();
    };
  }, [ref]);

  useEffect(() => {
    if (isRecording) {
      dotScale.value = withRepeat(
        withSequence(
          withTiming(1.4, { duration: 600, easing: Easing.inOut(Easing.ease) }),
          withTiming(1, { duration: 600, easing: Easing.inOut(Easing.ease) })
        ),
        -1,
        true
      );
    } else {
      dotScale.value = withTiming(1, { duration: 200 });
      // Reset waveform bars
      waveformLevels.value = withTiming(new Array(NUM_BARS).fill(0), { duration: 200 });
    }
  }, [isRecording, dotScale, waveformLevels]);

  const dotAnimStyle = useAnimatedStyle(() => ({
    transform: [{ scale: dotScale.value }],
  }));

  const snapPoints = useMemo(() => ['30%', '65%', '90%'], []);

  const handleSheetChanges = useCallback(async (index: number) => {
    if (index === -1 && onClose) {
      onClose();
      setSuggestion(null);
      setStatusMessage(null);
      setEditingId(null);
      if (recordingRef.current) {
        try {
          await recordingRef.current.stopAndUnloadAsync();
        } catch { /* already stopped */ }
        recordingRef.current = null;
        setIsRecording(false);
        if (durationTimer.current) clearInterval(durationTimer.current);
      }
    } else if (index >= 0) {
      const { status } = await Location.getForegroundPermissionsAsync();
      if (status === 'granted') {
        try {
          const location = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
          const lat = location.coords.latitude;
          const lon = location.coords.longitude;
          
          const spots = getCachedTopSpots();
          for (const spot of spots) {
            const distance = getDistance(lat, lon, spot.lat, spot.lng);
            if (distance <= 100) {
              setSuggestion(`Frequent Spot: ${spot.category || 'Spending'} zone. Amount?`);
              break;
            }
          }
        } catch {
          // ignore
        }
      }
    }
  }, [onClose]);

  /** Callback for expo-av recording status updates — drives waveform */
  const onRecordingStatusUpdate = useCallback((status: Audio.RecordingStatus) => {
    if (!status.isRecording || status.metering === undefined) return;

    // status.metering is in dBFS (typically -160 to 0), normalize to 0..1
    const dbfs = status.metering ?? -160;
    const normalized = Math.max(0, Math.min(1, (dbfs + 60) / 60));

    // Shift existing levels right and insert new reading at position 0
    const current = [...waveformLevels.value];
    for (let i = current.length - 1; i > 0; i--) {
      current[i] = current[i - 1];
    }
    current[0] = normalized;
    
    waveformLevels.value = withTiming(current, { duration: 80 });
  }, [waveformLevels]);

  /** Start audio recording */
  const startRecording = async () => {
    try {
      const permission = await Audio.requestPermissionsAsync();
      if (!permission.granted) {
        setStatusMessage('⚠️ Izin mikrofon diperlukan');
        return;
      }

      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });

      const { recording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );

      // Enable metering updates for waveform
      recording.setOnRecordingStatusUpdate(onRecordingStatusUpdate);
      recording.setProgressUpdateInterval(80); // ~12 FPS for smooth waveform

      recordingRef.current = recording;
      setIsRecording(true);
      setRecordingDuration(0);
      setStatusMessage(null);
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

      durationTimer.current = setInterval(() => {
        setRecordingDuration(prev => prev + 1);
      }, 1000);
    } catch (err) {
      console.error('[Recording] Start error:', err);
      setStatusMessage('❌ Gagal memulai rekaman');
    }
  };

  /** Stop recording and send to Gemini */
  const stopRecording = async () => {
    if (!recordingRef.current) return;

    setIsRecording(false);
    if (durationTimer.current) {
      clearInterval(durationTimer.current);
      durationTimer.current = null;
    }

    setSubmitting(true);
    setStatusMessage('🧠 Memproses audio dengan AI...');

    try {
      await recordingRef.current.stopAndUnloadAsync();
      const uri = recordingRef.current.getURI();
      recordingRef.current = null;

      if (!uri) {
        setStatusMessage('❌ File rekaman tidak ditemukan');
        setSubmitting(false);
        return;
      }

      const audioFile = new File(uri);
      const base64Audio = await audioFile.base64();

      const mimeType = 'audio/mp4';
      
      const recentContext = await getRecentContext();
      const userContext: UserContext = {
        name: userProfile?.name || 'User',
        language: language || 'en',
        personality: aiPersonality || 'helpful',
        recentTransactions: recentContext,
        financialGoals: financialGoal.name || ''
      };

      const parsedData = await parseAudioWithAI(base64Audio, mimeType, categories, userContext);

      if (!parsedData) {
        setStatusMessage('⚠️ AI tidak bisa memproses audio, coba lagi');
        setSubmitting(false);
        return;
      }

      if (parsedData.amount === 0) {
        setStatusMessage('⚠️ Nominal tidak terdeteksi dari suara');
        setSubmitting(false);
        return;
      }

      await saveTransaction(parsedData);
      try { 
        audioFile.delete(); 
      } catch (e) {
        console.warn('Failed to delete temporary audio file:', e);
      }
    } catch (err) {
      console.error('[Recording] Stop/process error:', err);
      setStatusMessage('❌ Gagal memproses rekaman');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    } finally {
      setSubmitting(false);
    }
  };

  const handleMicPress = () => {
    if (isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  };

  /** Shared save logic for both text and voice input */
  const saveTransaction = async (parsedData: {
    title: string;
    amount: number;
    category: string;
    type: 'expense' | 'income';
    date: string;
  }) => {
    let latitude = null;
    let longitude = null;
    let location_name = null;

    const { status } = await Location.requestForegroundPermissionsAsync();
    if (status === 'granted') {
      try {
        const location = await Location.getCurrentPositionAsync({});
        latitude = location.coords.latitude;
        longitude = location.coords.longitude;
        
        const geocode = await Location.reverseGeocodeAsync({ latitude, longitude });
        if (geocode.length > 0) {
          const loc = geocode[0];
          location_name = [loc.name, loc.city, loc.region].filter(Boolean).join(', ');
        }
      } catch (e) {
        console.log('Location error:', e);
      }
    }

    const createdAt = parsedData.date 
      ? `${parsedData.date}T${new Date().toISOString().split('T')[1]}` 
      : new Date().toISOString();

    // Step 0: Check for duplicates (Smart Conflict Resolution)
    const isDupe = await isDuplicateTransaction({
      amount: parsedData.amount,
      type: parsedData.type,
      user_id: userId || null,
      created_at: createdAt,
    });

    if (isDupe) {
      setStatusMessage('✨ Transaksi serupa terdeteksi — digabung otomatis');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
      setTimeout(() => {
        (ref as any).current?.close();
        setInputText('');
        setSuggestion(null);
      }, 1500);
      return;
    }

    if (isEditMode && editingId) {
      setStatusMessage('✨ Memperbarui transaksi...');
      const res = await updateTransaction(editingId, {
        title: parsedData.title,
        amount: parsedData.amount,
        type: parsedData.type,
        category: parsedData.category,
      }, userId || null);
      
      if (!res.success) {
        setStatusMessage(`❌ Gagal: ${res.error}`);
        return;
      }
    } else if (isTransferMode && fromWalletId && toWalletId) {
      setStatusMessage('✨ Memproses transfer...');
      const res = await createTransfer({
        fromWalletId,
        toWalletId,
        amount: parsedData.amount,
        title: parsedData.title,
        category: parsedData.category,
        userId: userId || null,
      });

      if (!res.success) {
        setStatusMessage(`❌ Gagal: ${res.error}`);
        return;
      }
      
      // Unlock badge for first transfer
      useGamificationStore.getState().unlockBadge('transfer_expert');
    } else {
      enqueueTransaction({
        title: parsedData.title,
        amount: parsedData.amount,
        type: parsedData.type,
        category: parsedData.category,
        latitude,
        longitude,
        location_name,
        created_at: createdAt,
        user_id: userId || null,
        wallet_id: fromWalletId || undefined,
      });
    }

    const online = getIsConnected();
    if (online) {
      processSyncQueue().catch(console.warn);
      setStatusMessage(null);
    } else {
      setStatusMessage('📱 Disimpan offline — akan sync otomatis');
    }

    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    refreshDailyReminder();
    DeviceEventEmitter.emit('transaction_added');

    // Gamification Updates
    const state = useGamificationStore.getState();
    const oldUnlockedIds = new Set(state.badges.reduce((acc, b) => {
      if (b.unlockedAt) acc.push(b.id);
      return acc;
    }, [] as string[]));
    
    state.updateStreak();
    if (userId) await calculateHealthScore(userId);
    
    const currentBadges = useGamificationStore.getState().badges;
    const newlyUnlocked = currentBadges.find(b => b.unlockedAt && !oldUnlockedIds.has(b.id));

    // Task B: Check budget alert for this category (non-blocking)
    if (parsedData.type === 'expense') {
      checkBudgetAlert(parsedData.category).catch(console.warn);
    }

    setInputText('');
    setSuggestion(null);
    
    if (newlyUnlocked) {
      setUnlockedBadge(newlyUnlocked);
      setShowCelebration(true);
    }
    
    // Show success animation then close
    setShowSuccess(true);
    // Add a slightly different haptic for celebration
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    
    setTimeout(() => {
      setShowSuccess(false);
      (ref as any).current?.close();
    }, 1800);
  };

  const handleSubmit = async () => {
    if (!inputText.trim() || submitting) return;

    setSubmitting(true);
    setStatusMessage(null);
    try {
      const recentContext = await getRecentContext();
      const userContext: UserContext = {
        name: userProfile?.name || 'User',
        language: language || 'en',
        personality: aiPersonality || 'helpful',
        recentTransactions: recentContext,
        financialGoals: financialGoal.name || ''
      };
      
      let parsedData = await parseTransactionWithAI(inputText, categories, userContext);
      
      if (!parsedData) {
        const amountMatch = inputText.match(/(\d+[.,]?\d*)\s*(k|rb|ribu)?/i);
        let amount = 0;
        if (amountMatch) {
          amount = parseFloat(amountMatch[1].replace(',', '.'));
          if (amountMatch[2] && /k|rb|ribu/i.test(amountMatch[2])) {
            amount *= 1000;
          }
        }
        
        parsedData = {
          title: inputText.replace(/\d+[.,]?\d*\s*(k|rb|ribu)?/i, '').trim() || inputText,
          amount: amount || 0,
          category: 'Other',
          type: 'expense',
          date: new Date().toISOString().split('T')[0],
        };
      }

      if (parsedData.amount === 0) {
        setStatusMessage('⚠️ Nominal tidak terdeteksi');
        setSubmitting(false);
        return;
      }

      await saveTransaction(parsedData);
    } catch (err) {
      console.error('Error saving transaction:', err);
      setStatusMessage('❌ Gagal menyimpan');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    } finally {
      setSubmitting(false);
    }
  };

  const isOffline = !getIsConnected();

  const formatDuration = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${String(s).padStart(2, '0')}`;
  };

  return (
    <BottomSheet
      ref={ref}
      index={-1}
      snapPoints={snapPoints}
      enablePanDownToClose={true}
      onChange={handleSheetChanges}
      handleIndicatorStyle={{ backgroundColor: '#27272a', width: 48, marginTop: 4 }}
      backgroundStyle={{ backgroundColor: '#18181b', borderRadius: 24, borderWidth: 1, borderColor: '#27272a' }}
    >
      <View className="flex-1 px-4 flex-col py-4">
        {showSuccess ? (
          <View style={styles.successContainer}>
            <LottieView
              source={lottieSource}
              autoPlay
              loop={showCelebration}
              style={styles.lottie}
            />
            <Text 
              testID="smart_input_success_text"
              style={styles.successText}
            >
              {unlockedBadge ? `Badge Unlocked: ${unlockedBadge.name}!` : 'Transaction Saved!'}
            </Text>
            {unlockedBadge && (
              <Text className="text-slate-400 text-sm mt-2 text-center px-10">
                {unlockedBadge.description}
              </Text>
            )}
          </View>
        ) : (
          <>
            {/* Header */}
            <View className="flex-row items-center justify-between pb-2">
              <Text className="font-h3 text-h3 text-foreground">
                {isEditMode ? 'Edit Transaction' : 'AI Smart Input'}
              </Text>
              <View className="flex-row items-center gap-2">
                {isOffline && <WifiOff color="#f59e0b" size={16} />}
                <Sparkles color="#10b981" size={20} />
              </View>
            </View>

            {/* Waveform Recording Indicator */}
            {isRecording && (
              <View style={styles.recordingIndicator}>
                {/* Pulsing red dot */}
                <Animated.View
                  style={[
                    styles.pulseDot,
                    dotAnimStyle,
                  ]}
                />

                {/* Live waveform visualization */}
                <View style={styles.waveformContainer}>
                  {Array.from({ length: NUM_BARS }).map((_, i) => (
                    <WaveBar key={i} levels={waveformLevels} index={i} />
                  ))}
                </View>

                {/* Duration counter */}
                <Text style={styles.durationText}>
                  {formatDuration(recordingDuration)}
                </Text>
              </View>
            )}

            {/* Status message */}
            {statusMessage && !isRecording && (
              <Text className="text-xs font-body-sm text-on-surface-variant pb-2">{statusMessage}</Text>
            )}

            {/* Mode Switcher & Wallet Selectors */}
            <View className="mb-4">
              <View className="flex-row items-center justify-between mb-3 bg-[#09090b] rounded-2xl p-1 border border-border">
                <TouchableOpacity 
                  onPress={() => setIsTransferMode(false)}
                  className={`flex-1 py-2 rounded-xl items-center ${!isTransferMode ? 'bg-background border border-border' : ''}`}
                >
                  <Text className={`font-label-sm ${!isTransferMode ? 'text-foreground' : 'text-slate-500'}`}>Transaksi</Text>
                </TouchableOpacity>
                <TouchableOpacity 
                  onPress={() => setIsTransferMode(true)}
                  className={`flex-1 py-2 rounded-xl items-center ${isTransferMode ? 'bg-background border border-border' : ''}`}
                >
                  <Text className={`font-label-sm ${isTransferMode ? 'text-foreground' : 'text-slate-500'}`}>Transfer</Text>
                </TouchableOpacity>
              </View>

              {isTransferMode && (
                <View className="mb-3">
                  <View className="flex-row items-center gap-3 bg-[#09090b] rounded-3xl p-3 border border-border">
                    <TouchableOpacity 
                      onPress={() => setSelectingWalletFor('from')}
                      className={`flex-1 ${selectingWalletFor === 'from' ? 'border border-primary/50 bg-primary/5 rounded-2xl' : ''}`}
                    >
                      <Text className="text-xs text-slate-500 uppercase font-bold mb-1 ml-1">Dari</Text>
                      <View className="flex-row items-center gap-2 bg-background rounded-2xl px-3 py-2 border border-border/50">
                        <WalletIcon size={14} color="#ef4444" />
                        <Text className="text-sm text-foreground flex-1" numberOfLines={1}>
                          {wallets.find(w => w.id === fromWalletId)?.name || 'Pilih Wallet'}
                        </Text>
                      </View>
                    </TouchableOpacity>
                    
                    <View className="mt-4">
                      <ArrowRight size={16} color="#71717a" />
                    </View>

                    <TouchableOpacity 
                      onPress={() => setSelectingWalletFor('to')}
                      className={`flex-1 ${selectingWalletFor === 'to' ? 'border border-primary/50 bg-primary/5 rounded-2xl' : ''}`}
                    >
                      <Text className="text-xs text-slate-500 uppercase font-bold mb-1 ml-1">Ke</Text>
                      <View className="flex-row items-center gap-2 bg-background rounded-2xl px-3 py-2 border border-border/50">
                        <WalletIcon size={14} color="#10b981" />
                        <Text className="text-sm text-foreground flex-1" numberOfLines={1}>
                          {wallets.find(w => w.id === toWalletId)?.name || 'Pilih Wallet'}
                        </Text>
                      </View>
                    </TouchableOpacity>
                  </View>

                  {selectingWalletFor && (
                    <Animated.View className="mt-2 bg-[#09090b] rounded-2xl p-2 border border-border">
                      <Animated.ScrollView horizontal showsHorizontalScrollIndicator={false}>
                        {wallets.map((w) => (
                          <TouchableOpacity
                            key={w.id}
                            onPress={() => {
                              if (selectingWalletFor === 'from') setFromWalletId(w.id);
                              else setToWalletId(w.id);
                              setSelectingWalletFor(null);
                            }}
                            className={`mr-2 px-4 py-2 rounded-xl border ${
                              (selectingWalletFor === 'from' ? fromWalletId : toWalletId) === w.id 
                                ? 'bg-primary border-primary' 
                                : 'bg-background border-border'
                            }`}
                          >
                            <Text className={`text-xs font-bold ${
                              (selectingWalletFor === 'from' ? fromWalletId : toWalletId) === w.id 
                                ? 'text-[#18181b]' 
                                : 'text-slate-400'
                            }`}>
                              {w.name}
                            </Text>
                          </TouchableOpacity>
                        ))}
                      </Animated.ScrollView>
                    </Animated.View>
                  )}
                </View>
              )}
            </View>

            {/* Input Row */}
            <View className="flex-row items-center gap-2">
              {/* Mic Button */}
              <TouchableOpacity
                onPress={handleMicPress}
                disabled={submitting && !isRecording}
                style={[
                  styles.micButton,
                  {
                    backgroundColor: isRecording ? '#ef4444' : '#09090b',
                    borderColor: isRecording ? '#7f1d1d' : '#27272a',
                  }
                ]}
              >
                {isRecording ? (
                  <Square color="#fafafa" size={18} fill="#fafafa" />
                ) : (
                  <Mic color="#71717a" size={20} />
                )}
              </TouchableOpacity>

              {/* Text Input */}
              <View className="flex-1 bg-background rounded-3xl px-4 py-3 border border-border flex-row items-center">
                <BottomSheetTextInput
                  testID="smart_input_field"
                  className="flex-1 bg-transparent text-body-md text-foreground p-0"
                  placeholder={suggestion || t('inputPlaceholder')}
                  placeholderTextColor={suggestion ? "#10b981" : "#a1a1aa"}
                  style={{ fontSize: 16 }}
                  value={inputText}
                  onChangeText={setInputText}
                  onSubmitEditing={handleSubmit}
                  editable={!isRecording}
                />
              </View>

              {/* Submit Button */}
              <TouchableOpacity 
                testID="smart_input_save_button"
                className={`h-12 px-4 rounded-3xl ${submitting ? 'bg-secondary' : 'bg-primary'} flex-row items-center justify-center shadow-sm`}
                onPress={handleSubmit}
                disabled={submitting || isRecording}
              >
                {submitting ? (
                  <ActivityIndicator size="small" color="#18181b" />
                ) : (
                  <>
                    <Plus color="#18181b" size={20} />
                    <Text className="ml-1 font-label-md text-[#18181b]">{t('saveButton')}</Text>
                  </>
                )}
              </TouchableOpacity>
            </View>
          </>
        )}
      </View>
    </BottomSheet>
  );
});

SmartInputSheet.displayName = 'SmartInputSheet';

const styles = StyleSheet.create({
  waveBar: {
    width: 3,
    borderRadius: 1.5,
    backgroundColor: '#ef4444',
    marginHorizontal: 1.5,
  },
  successContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  lottie: {
    width: 200,
    height: 200,
  },
  successText: {
    fontFamily: 'Manrope_700Bold',
    color: '#10b981',
    marginTop: 10,
    fontSize: 18,
  },
  recordingIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingVertical: 10,
    paddingHorizontal: 14,
    backgroundColor: '#450a0a',
    borderRadius: 14,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: '#7f1d1d',
  },
  pulseDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#ef4444',
  },
  waveformContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    height: 32,
  },
  durationText: {
    fontFamily: 'Manrope_700Bold',
    fontSize: 14,
    color: '#fca5a5',
  },
  micButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
  }
});

export default SmartInputSheet;
