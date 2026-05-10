import React, { useState, useRef, useEffect, useMemo, useCallback } from 'react';
import { 
  View, 
  Text, 
  TextInput, 
  TouchableOpacity, 
  FlatList, 
  KeyboardAvoidingView, 
  Platform,
  ActivityIndicator,
  DeviceEventEmitter
} from 'react-native';
import { 
  Send, 
  Mic, 
  Sparkles, 
  MoreHorizontal,
  User as UserIcon,
  RotateCcw,
  Wallet,
  ArrowRight,
  Search,
  X,
  Plus,
  List,
  Award
} from 'lucide-react-native';
import LottieView from 'lottie-react-native';
import { router } from 'expo-router';
import Animated, { 
  useSharedValue, 
  useAnimatedStyle, 
  withTiming,
  FadeIn,
  FadeOut
} from 'react-native-reanimated';
import { useHaptic } from '../../src/hooks/useHaptic';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { StatusBar } from 'expo-status-bar';
import { useUserStore } from '../../src/store/useUserStore';
import { chatService } from '../../src/lib/chatService';
import { getBudgetHealthSummary } from '../../src/lib/budgetService';
import { parseSearchQuery, answerSearchQuery, suggestActionsLocally, AIAction } from '../../src/lib/aiAdvisor';
import { useSettingsStore } from '../../src/store/useSettingsStore';
import { supabase } from '../../src/lib/supabase';



// Gemini Config
const apiKey = process.env.EXPO_PUBLIC_GEMINI_API_KEY;
const genAI = new GoogleGenerativeAI(apiKey || '');

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  actions?: AIAction[];
}

export default function AIScreen() {
  const { session } = useUserStore();
  const userId = session?.user?.id;
  
  const { hapticLight, hapticMedium, hapticSuccess } = useHaptic();
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputText, setInputText] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [isOfflineMode] = useState(!apiKey);
  const [loading, setLoading] = useState(false);
  const [budgetContext, setBudgetContext] = useState<string>('');
  const flatListRef = useRef<FlatList>(null);
  
  // Animation Values
  const micScale = useSharedValue(1);
  const lottieSpeed = useSharedValue(1);

  const pulseMic = () => {
    micScale.value = withTiming(1.2, { duration: 200 });
  };
  
  const stopPulse = () => {
    micScale.value = withTiming(1, { duration: 200 });
  };

  const loadHistory = useCallback(async () => {
    if (!userId) return;
    const history = await chatService.getChatHistory(userId);
    if (history.length > 0) {
      const formatted = history.map(m => ({
        id: m.id || Math.random().toString(),
        role: m.role === 'model' ? 'assistant' : 'user' as any,
        content: m.content,
        timestamp: new Date(m.created_at || Date.now())
      }));
      setMessages(formatted);
    } else {
      setMessages([
        {
          id: '1',
          role: 'assistant',
          content: 'Halo! Saya AI Advisor Anda. Ada yang bisa saya bantu dengan keuangan Anda hari ini?',
          timestamp: new Date()
        }
      ]);
    }
  }, [userId]);

  const loadBudgetContext = useCallback(async () => {
    try {
      if (!userId) return;
      const summary = await getBudgetHealthSummary(userId);
      setBudgetContext(summary);
    } catch (error) {
      console.warn('[AI] Gagal memuat konteks budget:', error);
    }
  }, [userId]);

  const filteredMessages = useMemo(() => {
    if (!searchQuery.trim()) return messages;
    return messages.filter(m => 
      m.content.toLowerCase().includes(searchQuery.toLowerCase())
    );
  }, [messages, searchQuery]);

  useEffect(() => {
    if (userId) {
      loadHistory();
      loadBudgetContext();
    }
  }, [userId, loadHistory, loadBudgetContext]);

  useEffect(() => {
    if (loading) {
      lottieSpeed.value = withTiming(2, { duration: 500 });
    } else {
      lottieSpeed.value = withTiming(1, { duration: 500 });
    }
  }, [loading, lottieSpeed]);

  const handleSend = async () => {
    if (!inputText.trim() || loading || !userId) return;

    const userMsgContent = inputText.trim();
    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: userMsgContent,
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);
    setInputText('');
    setLoading(true);
    hapticMedium();

    chatService.saveChatMessage(userId, 'user', userMsgContent);
    
    // Auto scroll to bottom
    setTimeout(() => flatListRef.current?.scrollToEnd({ animated: true }), 100);

    try {
      const userContext = {
        name: session?.user?.email?.split('@')[0] || 'User',
        language: 'id' as const,
        personality: useSettingsStore.getState().aiPersonality || 'casual',
      };

      // 1. Detect if it's a history search query
      const searchKeywords = ['berapa', 'kapan', 'total', 'pengeluaran', 'cari', 'pencarian', 'habis', 'list', 'tunjukkan', 'daftar'];
      const isSearchLikely = searchKeywords.some(k => userMsgContent.toLowerCase().includes(k));

      if (isSearchLikely) {
        const filters = await parseSearchQuery(userMsgContent, userContext);
        
        if (filters && (filters.category || filters.startDate || filters.keyword)) {
          // Perform the search in Supabase
          let query = supabase.from('transactions').select('*').eq('user_id', userId);
          
          if (filters.category) query = query.ilike('category', `%${filters.category}%`);
          if (filters.startDate) query = query.gte('created_at', filters.startDate);
          if (filters.endDate) query = query.lte('created_at', filters.endDate);
          if (filters.type && filters.type !== 'all') query = query.eq('type', filters.type);
          if (filters.keyword) query = query.or(`title.ilike.%${filters.keyword}%,note.ilike.%${filters.keyword}%`);

          const { data: searchResults, error } = await query.order('created_at', { ascending: false }).limit(20);

          if (!error && searchResults && searchResults.length > 0) {
            const aiAnswer = await answerSearchQuery(userMsgContent, searchResults, userContext);
            const aiMessage: Message = {
              id: (Date.now() + 1).toString(),
              role: 'assistant',
              content: aiAnswer,
              timestamp: new Date(),
              actions: suggestActionsLocally(userMsgContent, searchResults)
            };
            setMessages(prev => [...prev, aiMessage]);
            chatService.saveChatMessage(userId, 'model', aiAnswer);
            hapticSuccess();
            setLoading(false);
            return;
          }
        }
      }

      // 2. Fallback to normal chat if not a search or no results found
      const model = genAI.getGenerativeModel({ 
        model: 'gemini-1.5-flash',
        systemInstruction: `Anda adalah penasihat keuangan cerdas bernama DuaSaku AI.
        Berikan saran yang praktis, suportif, dan berbasis data. Gunakan gaya bahasa yang ramah namun profesional (Indonesian).
        
        === BUDGET CONTEXT (REAL-TIME) ===
        Status pengeluaran user saat ini: [${budgetContext || 'Belum ada data budget'}]
        
        === INSTRUKSI KHUSUS ===
        1. Analisis Budget: Selalu perhatikan sisa budget saat user bercerita tentang rencana belanja atau pengeluaran.
        2. Proaktif: Jika pengeluaran yang disebutkan user membuat budget kategori tersebut hampir habis (sisa < 15%) atau sudah melebihi limit, berikan peringatan yang empati tapi tegas.
        3. Action Tag: Gunakan tag aksi format: [ACTION:ADD_TRANSACTION|title:Nama|amount:Angka|category:Kategori] jika user berniat mencatat transaksi.
        4. Transisi Mulus: Jangan hanya memberikan tag, tapi berikan respon tekstual yang menjelaskan bahwa Anda akan membantu mencatatnya.
        
        Contoh Respon: "Waduh, kalau kamu beli Kopi Rp 50rb sekarang, budget Makan kamu bulan ini bakal minus lho. Tapi kalau tetap mau dicatat, ini draftnya: [ACTION:ADD_TRANSACTION|title:Kopi|amount:50000|category:Food]"`
      });

      const chat = model.startChat({
        history: messages.slice(-10).map(m => ({ 
          role: m.role === 'user' ? 'user' : 'model',
          parts: [{ text: m.content }],
        })),
      });

      const result = await chat.sendMessage(userMsgContent);
      const response = await result.response;
      const text = response.text();

      const aiMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: text,
        timestamp: new Date(),
        actions: suggestActionsLocally(userMsgContent)
      };

      setMessages(prev => [...prev, aiMessage]);
      chatService.saveChatMessage(userId, 'model', text);
      hapticSuccess();
      
      // Update budget context after each transaction suggestion (optional, but good for accuracy)
      loadBudgetContext();
    } catch (error) {
      console.error('Chat error:', error);
      const errorMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: 'Maaf, saya sedang mengalami gangguan koneksi. Bisa ulangi lagi?',
        timestamp: new Date()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setLoading(false);
    }
  };

  const handleAction = (action: AIAction) => {
    hapticMedium();
    if (action.type === 'NAVIGATE') {
      router.push(action.payload.screen);
    } else if (action.type === 'OPEN_SHEET') {
      // Implement specific sheet opening if needed
    }
  };

  const handleClearChat = async () => {
    if (!userId) return;
    hapticMedium();
    await chatService.clearHistory(userId);
    setMessages([
      {
        id: Date.now().toString(),
        role: 'assistant',
        content: 'Riwayat percakapan telah dibersihkan. Ada yang bisa saya bantu lagi?',
        timestamp: new Date()
      }
    ]);
  };

  const handleActionConfirm = (title: string, amount: string) => {
    hapticSuccess();
    DeviceEventEmitter.emit('open_smart_input', { 
      text: `${title} ${amount}`
    });
  };

  const renderMessageContent = (msg: Message) => {
    const actionRegex = /\[ACTION:ADD_TRANSACTION\|title:([^|]+)\|amount:([^|]+)\|category:([^\]]+)\]/;
    const match = msg.content.match(actionRegex);
    
    if (match && msg.role === 'assistant') {
      const fullContent = msg.content.replace(actionRegex, '').trim();
      const [, title, amount, category] = match;

      return (
        <View>
          {fullContent ? (
            <Text className="text-white text-[15px] leading-6 mb-3" style={{ fontFamily: 'Manrope_Medium' }}>
              {fullContent}
            </Text>
          ) : null}
          
          <View className="bg-slate-900/80 border border-purple-500/40 rounded-3xl p-5 shadow-2xl overflow-hidden">
            {/* Glossy Background Accent */}
            <View className="absolute -right-6 -top-6 w-24 h-24 bg-purple-600/10 rounded-full" />
            
            <View className="flex-row items-center mb-4">
              <View className="w-12 h-12 bg-purple-500/20 rounded-2xl items-center justify-center mr-3 border border-purple-500/20">
                <Wallet color="#c084fc" size={24} />
              </View>
              <View>
                <Text className="text-purple-400 text-[12px] uppercase font-bold tracking-widest mb-0.5">Analisis Transaksi</Text>
                <Text className="text-white font-bold text-lg">{title}</Text>
              </View>
            </View>
            
            <View className="bg-black/40 rounded-2xl p-4 mb-4 border border-white/5">
              <View className="flex-row justify-between items-center mb-1">
                <Text className="text-slate-400 text-xs">Kategori</Text>
                <Text className="text-white font-semibold">{category}</Text>
              </View>
              <View className="flex-row justify-between items-center">
                <Text className="text-slate-400 text-xs">Jumlah</Text>
                <Text className="text-purple-400 font-bold text-lg">Rp {parseInt(amount).toLocaleString()}</Text>
              </View>
            </View>

            <TouchableOpacity 
              onPress={() => handleActionConfirm(title, amount)}
              activeOpacity={0.8}
              className="bg-purple-600 flex-row items-center justify-center py-4 rounded-2xl shadow-lg"
            >
              <Text className="text-white font-bold text-base mr-2">Simpan ke Catatan</Text>
              <ArrowRight color="white" size={18} />
            </TouchableOpacity>
          </View>
        </View>
      );
    }

    return (
      <Text className="text-white text-[15px] leading-6" style={{ fontFamily: 'Manrope_Medium' }}>
        {msg.content}
      </Text>
    );
  };

  const micAnimatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: micScale.value }]
  }));

  return (
    <View className="flex-1 bg-[#121212]">
      <StatusBar style="light" />
      
      {/* Header & Lottie Orb */}
      <View className="pt-14 pb-2 items-center">
        <View className="w-40 h-40 items-center justify-center">
          <LottieView
            source={{ uri: 'https://lottie.host/626d70a3-f0a5-48b4-8255-78e8749f106f/Mv9ZqD3r8F.json' }}
            autoPlay
            loop
            speed={loading ? 2 : 1}
            style={{ width: '100%', height: '100%' }}
          />
        </View>
        
        {isOfflineMode && (
          <Animated.View 
            entering={FadeIn} 
            className="absolute top-16 right-6 bg-amber-500/20 border border-amber-500/50 px-3 py-1 rounded-full flex-row items-center gap-1"
          >
            <View className="w-1.5 h-1.5 bg-amber-500 rounded-full" />
            <Text className="text-amber-500 text-[12px] font-bold uppercase tracking-widest">Hybrid Mode (Local)</Text>
          </Animated.View>
        )}

        <View className="flex-row items-center gap-2 mt-[-10]">
          <View className="absolute w-24 h-24 bg-purple-600/20 rounded-full blur-3xl" />
        </View>
        <Text className="text-white text-lg font-bold -mt-4" style={{ fontFamily: 'Manrope_Bold' }}>AI Financial Advisor</Text>
        
        {/* Search Bar Glassmorphism */}
        <View className="w-full px-6 mt-4">
          <Animated.View 
            entering={FadeIn.delay(300)}
            className="flex-row items-center bg-white/5 border border-white/10 rounded-3xl px-5 py-3 shadow-sm"
          >
            <Search color="#94a3b8" size={18} />
            <TextInput
              className="flex-1 text-white ml-3 text-sm font-body-md"
              placeholder="Cari dalam obrolan..."
              placeholderTextColor="#64748b"
              value={searchQuery}
              onChangeText={(text) => {
                if (text.length > searchQuery.length) hapticLight();
                setSearchQuery(text);
              }}
            />
            {searchQuery.length > 0 && (
              <TouchableOpacity onPress={() => setSearchQuery('')} className="ml-2">
                <X color="#94a3b8" size={18} />
              </TouchableOpacity>
            )}
          </Animated.View>
        </View>
        
        <TouchableOpacity 
          onPress={handleClearChat}
          className="absolute right-6 top-16 w-8 h-8 bg-slate-800/50 rounded-full items-center justify-center border border-white/5"
        >
          <RotateCcw color="#94a3b8" size={16} />
        </TouchableOpacity>
      </View>

      <FlatList 
        ref={flatListRef}
        data={filteredMessages}
        keyExtractor={(item) => item.id}
        className="flex-1 px-4"
        contentContainerStyle={{ paddingBottom: 120, paddingTop: 10 }}
        onContentSizeChange={() => {
          if (!searchQuery) flatListRef.current?.scrollToEnd({ animated: true });
        }}
        renderItem={({ item }) => (
          <View 
            className={`mb-6 flex-row ${item.role === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            {item.role === 'assistant' && (
              <View className="w-8 h-8 rounded-full bg-slate-800 items-center justify-center mr-2 mt-auto border border-white/10">
                <Sparkles color="#a855f7" size={16} />
              </View>
            )}
            
            <View 
              className={`max-w-[85%] p-4 ${
                item.role === 'user' 
                ? 'bg-slate-800 rounded-2xl rounded-br-none' 
                : 'bg-slate-900/60 border border-purple-500/30 rounded-2xl rounded-bl-[4px]'
              } shadow-sm`}
              style={item.role === 'assistant' ? {
                shadowColor: '#a855f7',
                shadowOffset: { width: 0, height: 0 },
                shadowOpacity: 0.2,
                shadowRadius: 10,
                elevation: 5
              } : {}}
            >
              {renderMessageContent(item)}

              {item.actions && item.actions.length > 0 && (
                <View className="flex-row flex-wrap gap-2 mt-4 pt-3 border-t border-white/5">
                  {item.actions.map((action: AIAction) => (
                    <TouchableOpacity 
                      key={action.id}
                      onPress={() => handleAction(action)}
                      className="flex-row items-center bg-purple-600/20 border border-purple-500/30 px-3 py-2 rounded-xl"
                    >
                      {action.icon === 'plus' && <Plus size={14} color="#a855f7" />}
                      {action.icon === 'list' && <List size={14} color="#a855f7" />}
                      {action.icon === 'award' && <Award size={14} color="#a855f7" />}
                      <Text className="text-purple-300 text-xs font-bold ml-1.5">{action.label}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              )}
              
              <View className="flex-row justify-between items-center mt-2 border-t border-white/5 pt-2">
                <Text className="text-slate-600 text-[12px] uppercase tracking-tighter">
                  {item.role === 'assistant' ? 'DuaSaku AI' : 'Anda'}
                </Text>
                <Text className="text-slate-500 text-[12px]">
                  {item.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </Text>
              </View>
            </View>

            {item.role === 'user' && (
              <View className="w-8 h-8 rounded-full bg-purple-600 items-center justify-center ml-2 mt-auto">
                <UserIcon color="white" size={16} />
              </View>
            )}
          </View>
        )}
        ListEmptyComponent={searchQuery.length > 0 ? (
          <Animated.View entering={FadeIn} exiting={FadeOut} className="flex-1 items-center justify-center mt-10">
            <Search color="#334155" size={48} />
            <Text className="text-slate-500 mt-4 font-body-md text-center">
              Tidak ada riwayat obrolan terkait &quot;{searchQuery}&quot;
            </Text>
          </Animated.View>
        ) : null}
        ListFooterComponent={loading ? (
          <View className="flex-row justify-start mb-6">
            <View className="w-8 h-8 rounded-full bg-slate-800 items-center justify-center mr-2 border border-white/10">
              <Sparkles color="#a855f7" size={16} />
            </View>
            <View className="bg-slate-900/40 p-4 rounded-3xl rounded-bl-none border border-white/10">
              <MoreHorizontal color="#94a3b8" size={24} />
            </View>
          </View>
        ) : null}
      />

      {/* Floating Input Area */}
      <KeyboardAvoidingView 
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 100 : 0}
        className="absolute bottom-6 left-4 right-4"
      >
        <View className="flex-row items-center gap-3 bg-slate-900/95 p-2 rounded-[32px] border border-white/10 shadow-2xl">
          <TouchableOpacity 
            onPressIn={() => {
              hapticLight();
              pulseMic();
            }}
            onPressOut={() => {
              stopPulse();
            }}
            className="w-12 h-12 bg-purple-600 rounded-full items-center justify-center shadow-lg"
          >
            <Animated.View style={micAnimatedStyle}>
              <Mic color="white" size={22} />
            </Animated.View>
          </TouchableOpacity>

          <TextInput
            className="flex-1 text-white px-2 h-12 text-base"
            placeholder="Tanyakan sesuatu..."
            placeholderTextColor="#64748b"
            value={inputText}
            onChangeText={setInputText}
            multiline
            style={{ maxHeight: 100 }}
          />

          <TouchableOpacity 
            onPress={handleSend}
            disabled={!inputText.trim() || loading}
            className={`w-12 h-12 rounded-full items-center justify-center ${inputText.trim() ? 'bg-white' : 'bg-slate-800'}`}
          >
            {loading ? (
              <ActivityIndicator color={inputText.trim() ? '#121212' : '#94a3b8'} size="small" />
            ) : (
              <Send color={inputText.trim() ? '#121212' : '#94a3b8'} size={20} />
            )}
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}
