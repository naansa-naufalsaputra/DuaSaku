import { supabase } from './supabase';

export interface ChatMessage {
  id?: string;
  user_id: string;
  role: 'user' | 'model';
  content: string;
  created_at?: string;
}

/**
 * Service untuk menangani riwayat chat AI
 */
export const chatService = {
  /**
   * Mengambil riwayat chat terbaru (limit 50)
   */
  async getChatHistory(userId: string): Promise<ChatMessage[]> {
    try {
      const { data, error } = await supabase
        .from('chat_history')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: true })
        .limit(50);

      if (error) throw error;
      return (data as ChatMessage[]) || [];
    } catch (error) {
      console.error('[chatService] Error fetching history:', error);
      return [];
    }
  },

  /**
   * Menyimpan pesan chat baru ke Supabase
   */
  async saveChatMessage(userId: string, role: 'user' | 'model', content: string) {
    try {
      const { error } = await supabase
        .from('chat_history')
        .insert({
          user_id: userId,
          role,
          content
        });

      if (error) throw error;
    } catch (error) {
      console.error('[chatService] Error saving message:', error);
    }
  },

  /**
   * Menghapus semua riwayat chat user
   */
  async clearHistory(userId: string) {
    try {
      const { error } = await supabase
        .from('chat_history')
        .delete()
        .eq('user_id', userId);

      if (error) throw error;
    } catch (error) {
      console.error('[chatService] Error clearing history:', error);
    }
  }
};
