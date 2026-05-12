import { useState, useEffect, useCallback } from 'react';
import { Alert } from 'react-native';
import { getFinancialAdvice } from '../lib/aiAdvisor';

export const useFinancialAdvice = () => {
  const [advice, setAdvice] = useState<string>('');
  const [loading, setLoading] = useState(true);

  const fetchAdvice = useCallback(async () => {
    try {
      setLoading(true);
      const data = await getFinancialAdvice();
      setAdvice(data);
    } catch (error: any) {
      console.error('AI Fetch Error:', error);
      // Notifikasi Global Error Handling
      Alert.alert(
        'Gagal Memuat Saran',
        'Sesi otentikasi mungkin bermasalah atau koneksi terputus. Silakan coba lagi.',
        [{ text: 'OK', style: 'cancel' }]
      );
      setAdvice('Gagal memuat saran AI saat ini.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAdvice();
  }, [fetchAdvice]);

  return { advice, loading, refetch: fetchAdvice };
};
