import { supabase } from './supabase';
import { mmkvStorage } from './storage';

const ADVICE_CACHE_KEY = 'ai_financial_advice_cache';
const CACHE_TTL = 2 * 60 * 60 * 1000; // 2 Jam

// Helper untuk memanggil Edge Functions dengan praktis
const callAiFunction = async (functionName: string, body: any = {}) => {
  const { data, error } = await supabase.functions.invoke(functionName, {
    body: body,
  });
  
  if (error) {
    // Lempar error agar bisa ditangkap oleh UI (Global Error Handling)
    throw new Error(error.message || 'Terjadi kesalahan pada server AI.');
  }
  return data;
};

export type UserContext = {
  name?: string;
  language?: string;
  personality?: string;
  recentTransactions?: string;
  financialGoals?: string;
};

export const parseTransactionAi = async (text: string, categories?: string[], context?: UserContext) => {
  return await callAiFunction('parse-transaction', { prompt: text, categories, userContext: context });
};

export const getFinancialAdvice = async () => {
  const cachedDataString = mmkvStorage.getItem(ADVICE_CACHE_KEY);
  
  if (cachedDataString) {
    try {
      const { advice, timestamp } = JSON.parse(cachedDataString as string);
      const now = Date.now();
      
      if (now - timestamp < CACHE_TTL) {
        console.log('⚡ Menggunakan data AI dari cache');
        return advice;
      }
    } catch {
      console.log('🗑️ Cache rusak, akan fetch ulang...');
    }
  }

  console.log('☁️ Mengambil saran baru dari Supabase...');
  const newAdvice = await callAiFunction('analyze-budget');

  // Karena data yang dikembalikan oleh Edge Function analyze-budget berbentuk { advice: "..." }
  const adviceText = newAdvice?.advice || newAdvice;

  mmkvStorage.setItem(ADVICE_CACHE_KEY, JSON.stringify({
    advice: adviceText,
    timestamp: Date.now()
  }));

  return adviceText;
};

export const parseAudioWithAI = async (base64Audio: string, mimeType: string, categories?: string[], userContext?: UserContext) => {
  return await callAiFunction('parse-audio', { base64Audio, mimeType, categories, userContext });
};

export const scanReceiptAi = async (base64Image: string, mimeType: string = 'image/jpeg') => {
  return await callAiFunction('scan-receipt', { base64Image, mimeType });
};

