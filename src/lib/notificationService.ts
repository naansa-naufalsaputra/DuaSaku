import { MMKV } from 'react-native-mmkv';
import { supabase } from './supabase';
import { useSettingsStore } from '../store/useSettingsStore';
import { enqueueTransaction, processSyncQueue } from './offlineSync';
import { isDuplicateTransaction } from './conflictResolution';
import { predictCategory } from './categoryIntelligence';
import { checkBudgetAlert } from './notifications';
import { useNotificationLogStore } from '../store/useNotificationLogStore';

const storage = new MMKV({ id: 'notification-history' });
const LAST_TX_KEY = 'last_processed_notification';

/**
 * Utilitas untuk ekstraksi nominal dan deteksi tipe transaksi
 */
const parseNotificationData = (text: string, incomeKeywords: string[]) => {
  // 1. Deteksi Tipe (Income/Expense)
  const isIncome = incomeKeywords.some(keyword => text.toLowerCase().includes(keyword.toLowerCase()));
  const type = isIncome ? 'income' : 'expense';

  // 2. Templates Spesifik untuk Akurasi Tinggi
  
  // Pattern: Mencari angka setelah "Rp" atau "IDR" atau angka besar yang berdiri sendiri
  // Regex ini menangani: Rp 50.000, Rp. 50.000, 50.000,00
  const amountPatterns = [
    /(?:Rp\.?\s?|IDR\s?|Nominal:\s?|Sebesar\s?|Sejumlah\s?)(\d{1,3}(?:\.\d{3})+)/i,
    /(\d{1,3}(?:\.\d{3})+(?:\.\d{2})?)/ // Fallback: angka berformat titik (ribuan)
  ];

  let amount = 0;
  for (const pattern of amountPatterns) {
    const match = text.match(pattern);
    if (match) {
      // Hilangkan titik ribuan dan ambil angka bulatnya
      const rawAmount = match[1].replace(/\./g, '').split(',')[0];
      amount = parseInt(rawAmount, 10);
      
      // Validasi: Abaikan jika angka terlalu kecil (mungkin bukan nominal, misal jam 10.00)
      if (amount > 100) break; 
    }
  }

  return { amount, type };
};

/**
 * Headless Task Utama untuk Notification Listener
 */
export const notificationService = async (notification: any) => {
  const { app, title, text } = notification;
  const addLog = useNotificationLogStore.getState().addLog;
  
  const settings = useSettingsStore.getState();
  if (!settings.isAutoRecordEnabled) return;

  const targetApps = settings.customBankApps;

  if (!targetApps.includes(app)) {
    // Optional: Log ignored apps if needed for debugging
    return;
  }

  const { amount, type } = parseNotificationData(text, settings.customIncomeKeywords);

  if (amount <= 0) {
    addLog({
      app,
      title: title || 'N/A',
      body: text,
      status: 'failed',
      reason: 'Failed to extract amount',
    });
    return;
  }

  try {
    const now = Date.now();
    const signature = `${app}_${amount}`;
    
    // 1. CEK DEBOUNCE LOKAL (MMKV)
    const lastTxStr = storage.getString(LAST_TX_KEY);
    if (lastTxStr) {
      const { signature: lastSig, timestamp: lastTs } = JSON.parse(lastTxStr);
      if (signature === lastSig && (now - lastTs) < 60000) {
        addLog({
          app,
          title: title || 'N/A',
          body: text,
          status: 'ignored',
          reason: 'Debounce (duplicate within 60s)',
          extractedAmount: amount,
        });
        return; 
      }
    }

    const { data: { session } } = await supabase.auth.getSession();
    const userId = session?.user?.id || null;

    // 2. CEK SMART CONFLICT RESOLUTION (Magic Merge)
    // Cek apakah user baru saja input manual nominal yang sama
    const isDupe = await isDuplicateTransaction({
      amount,
      type: type as 'expense' | 'income',
      user_id: userId,
      created_at: new Date().toISOString(),
    });

    if (isDupe) {
      addLog({
        app,
        title: title || 'N/A',
        body: text,
        status: 'ignored',
        reason: 'Conflict with manual input',
        extractedAmount: amount,
      });
      return; 
    }

    const predictedCategory = predictCategory(text);
    const appName = app.split('.').pop() || app;

    // GUNAKAN OFFLINE QUEUE (Agar tetap tercatat meski offline)
    enqueueTransaction({
      title: `Auto-record ${appName}`,
      amount: amount,
      type: type as 'expense' | 'income',
      category: predictedCategory,
      latitude: null,
      longitude: null,
      location_name: null,
      user_id: userId,
      created_at: new Date().toISOString(),
    });

    addLog({
      app,
      title: title || 'N/A',
      body: text,
      status: 'parsed',
      extractedAmount: amount,
    });

    // Notify budget health (non-blocking)
    if (type === 'expense') {
      checkBudgetAlert(predictedCategory).catch(console.warn);
    }

    // Sync queue immediately if online
    processSyncQueue();

    // Update storage data transaksi terakhir
    storage.set(LAST_TX_KEY, JSON.stringify({ signature, timestamp: now }));
  } catch (error) {
    console.error('[NotificationService] Error:', error);
    addLog({
      app,
      title: title || 'N/A',
      body: text,
      status: 'failed',
      reason: error instanceof Error ? error.message : 'Unknown error',
    });
  }
};

