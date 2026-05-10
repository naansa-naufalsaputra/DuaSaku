import { GoogleGenerativeAI } from '@google/generative-ai';
import { BUDGET_CATEGORIES } from './budgetService';
import { mmkvStorage } from './storage';

// Ambil API Key dari file .env yang sudah kamu buat sebelumnya
const apiKey = process.env.EXPO_PUBLIC_GEMINI_API_KEY;

if (!apiKey) {
  console.warn('EXPO_PUBLIC_GEMINI_API_KEY belum dipasang di file .env!');
}

const genAI = new GoogleGenerativeAI(apiKey || '');

// Daftar model dari yang paling pintar ke yang paling ringan
const MODEL_FALLBACK_LIST = [
  'gemini-3.1-pro-preview',
  'gemini-3-flash-preview',
  'gemini-3.1-flash-lite-preview'
];

/**
 * CACHE: Simple AI Response Caching using MMKV
 */
const AI_CACHE_PREFIX = 'ai_cache_';
const CACHE_TTL = 1000 * 60 * 60; // 1 hour

function getAICache(key: string): string | null {
  try {
    const cached = mmkvStorage.getItem(AI_CACHE_PREFIX + key);
    if (!cached) return null;
    const { value, timestamp } = JSON.parse(cached as string);
    if (Date.now() - timestamp > CACHE_TTL) {
      mmkvStorage.removeItem(AI_CACHE_PREFIX + key);
      return null;
    }
    return value;
  } catch { return null; }
}

function setAICache(key: string, value: string) {
  try {
    const cacheData = JSON.stringify({ value, timestamp: Date.now() });
    mmkvStorage.setItem(AI_CACHE_PREFIX + key, cacheData);
  } catch {}
}

/**
 * LOCAL SENTIMENT: Detect user emotion locally to adjust AI tone
 */
function detectSentimentLocally(input: string): 'happy' | 'sad' | 'worried' | 'neutral' {
  const query = input.toLowerCase();
  const sadKeywords = ['sedih', 'boros', 'susah', 'rugi', 'gagal', 'kurang', 'aduh', 'waduh', 'hiks'];
  const happyKeywords = ['senang', 'hemat', 'untung', 'berhasil', 'yeay', 'mantap', 'hore', 'alhamdulillah'];
  const worriedKeywords = ['takut', 'cemas', 'bingung', 'gimana', 'bahaya', 'gawat'];

  if (sadKeywords.some(k => query.includes(k))) return 'sad';
  if (happyKeywords.some(k => query.includes(k))) return 'happy';
  if (worriedKeywords.some(k => query.includes(k))) return 'worried';
  return 'neutral';
}

/**
 * Helper internal untuk memanggil Gemini dengan sistem fallback otomatis
 */
async function callGeminiWithFallback(
  prompt: string, 
  isMultimodal: boolean = false, 
  audioData?: { mimeType: string, data: string },
  systemInstruction?: string
) {
  let lastError: any = null;

  for (const modelName of MODEL_FALLBACK_LIST) {
    try {
      console.log(`[AI] Mencoba model: ${modelName}...`);
      const model = genAI.getGenerativeModel({ 
        model: modelName,
        systemInstruction: systemInstruction 
      });
      
      let result;
      if (isMultimodal && audioData) {
        result = await model.generateContent([
          { inlineData: audioData },
          { text: prompt },
        ]);
      } else {
        result = await model.generateContent(prompt);
      }

      return result;
    } catch (error) {
      console.warn(`[AI] Model ${modelName} gagal:`, error);
      lastError = error;
      // Lanjut ke model berikutnya dalam list
    }
  }

  throw lastError || new Error("Semua model AI gagal merespon.");
}

export interface AIAction {
  id: string;
  label: string;
  icon: string;
  payload: any;
  type: 'ADD_BUDGET' | 'VIEW_HISTORY' | 'NAVIGATE' | 'OPEN_SHEET';
}

export interface UserContext {
  name: string;
  language: 'id' | 'en';
  personality: 'strict' | 'casual' | 'coach';
  recentTransactions?: string; // Deskripsi singkat transaksi terakhir
  financialGoals?: string;    // Target keuangan user
}

/**
 * LOCAL: Suggest quick actions based on query context
 */

/**
 * Membangun instruksi sistem yang dinamis berdasarkan profil user
 */
function buildSystemInstruction(context?: UserContext): string {
  const name = context?.name || 'User';
  const lang = context?.language || 'id';
  const personality = context?.personality || 'casual';

  const base = lang === 'id' 
    ? `Anda adalah asisten keuangan pribadi untuk ${name}. Bicara dalam Bahasa Indonesia.`
    : `You are a personal financial advisor for ${name}. Speak in English.`;

  const personalities = {
    strict: lang === 'id' 
      ? "Gaya bicara: Tegas, disiplin, dan sedikit pedas jika pengeluaran tidak penting. Jangan ragu memarahi user jika mereka boros. Fokus pada penghematan ekstrem."
      : "Tone: Strict, disciplined, and critical of unnecessary spending. Don't hesitate to scold the user if they're wasteful. Focus on extreme savings.",
    casual: lang === 'id'
      ? "Gaya bicara: Santai, seperti teman akrab, gunakan bahasa yang ramah, hangat, dan suportif."
      : "Tone: Casual, like a close friend, use friendly, warm, and supportive language.",
    coach: lang === 'id'
      ? "Gaya bicara: Motivator, fokus pada strategi jangka panjang, investasi, dan pertumbuhan kekayaan. Berikan tips keuangan yang mendidik."
      : "Tone: Motivational, focus on long-term strategy, investment, and wealth growth. Provide educational financial tips."
  };

  let instruction = `${base} ${personalities[personality]}`;

  if (context?.recentTransactions) {
    instruction += lang === 'id' 
      ? `\nKonteks transaksi terakhir user: ${context.recentTransactions}. Gunakan ini untuk memberi komentar jika relevan.`
      : `\nUser's recent transactions context: ${context.recentTransactions}. Use this to provide relevant comments.`;
  }

  if (context?.financialGoals) {
    instruction += lang === 'id'
      ? `\nTarget keuangan user: ${context.financialGoals}. Ingatkan user tentang target ini jika mereka berencana mengeluarkan uang banyak.`
      : `\nUser's financial goals: ${context.financialGoals}. Remind the user about these goals if they plan to spend a lot.`;
  }

  return `${instruction} Hasilkan output dalam format JSON murni jika diminta untuk parsing data, atau teks naratif yang sangat personal jika sedang memberikan saran/komentar.`;
}

/**
 * LOCAL FALLBACK: Parse transaction using regex when AI is offline/busy
 */
function parseTransactionLocally(input: string): any | null {
  const amountMatch = input.match(/(\d+[\d\s,.]*k?|[\d\s,.]*ribu|[\d\s,.]*jt)/i);
  if (!amountMatch) return null;

  let amountStr = amountMatch[0].toLowerCase().replace(/\s/g, '').replace(/,/g, '');
  let amount = 0;

  if (amountStr.includes('jt')) amount = parseFloat(amountStr) * 1000000;
  else if (amountStr.includes('k')) amount = parseFloat(amountStr) * 1000;
  else if (amountStr.includes('ribu')) amount = parseFloat(amountStr) * 1000;
  else amount = parseFloat(amountStr);

  if (isNaN(amount)) return null;

  // Simple category matching
  const category = BUDGET_CATEGORIES.find(c => 
    input.toLowerCase().includes(c.key.toLowerCase()) || 
    input.toLowerCase().includes(c.label.toLowerCase())
  )?.key || 'Other';

  // Title is basically the input without the amount
  const title = input.replace(amountMatch[0], '').trim() || 'Transaksi';

  return {
    title,
    amount,
    type: 'expense',
    category,
    date: new Date().toISOString().split('T')[0],
    confidence: 0.5 // Low confidence because it's local regex
  };
}

/**
 * Fungsi cerdas untuk mengekstrak teks santai menjadi data transaksi terstruktur.
 */
export async function parseTransactionWithAI(
  inputText: string, 
  categoryList: string[] = ['Food', 'Transport', 'Entertainment', 'Utilities', 'Income', 'Other'],
  userContext?: UserContext
): Promise<any | null> {
  if (!apiKey) return parseTransactionLocally(inputText);

  try {
    const today = new Date().toISOString().split('T')[0];
    const sentiment = detectSentimentLocally(inputText);
    const systemInstruction = buildSystemInstruction({
      ...userContext,
      personality: sentiment === 'sad' ? 'coach' : userContext?.personality || 'casual'
    } as any);

    const prompt = `
      Anda adalah asisten pencatat keuangan cerdas. 
      Tugas Anda adalah mengekstrak teks input pengguna menjadi format JSON murni tanpa tambahan teks markdown atau backticks (\`\`\`):
      
      Hari ini adalah tanggal: ${today}.

      Format JSON wajib:
      {
        "title": "Nama transaksi singkat",
        "amount": 0,
        "category": "${categoryList.join('/')}",
        "type": "expense" atau "income",
        "date": "YYYY-MM-DD"
      }

      Aturan:
      1. Jika ada kata "k" atau "rb", kalikan dengan 1000.
      2. Kategori HARUS salah satu dari: ${categoryList.join(', ')}.
      3. Jika tidak ada keterangan waktu, gunakan tanggal hari ini: ${today}.

      Input pengguna: "${inputText}"
    `;

    const result = await callGeminiWithFallback(prompt, false, undefined, systemInstruction);
    const responseText = result.response.text().trim();
    const jsonStr = responseText
      .replace(/^```json\s*/i, '')
      .replace(/^```\s*/i, '')
      .replace(/```$/i, '')
      .trim();

    return JSON.parse(jsonStr);
  } catch (error) {
    console.error('Gagal memparsing dengan AI, menggunakan fallback lokal:', error);
    return parseTransactionLocally(inputText);
  }
}

/**
 * Legacy summary function - kept for compatibility with other screens
 */
export async function generateFinancialSummary(transactions: any[], userContext?: UserContext) {
  const cacheKey = `summary_${transactions.length}_${transactions[0]?.id || 'empty'}`;
  const cached = getAICache(cacheKey);
  if (cached) return cached;

  try {
    if (!apiKey) throw new Error("API key missing");
    
    const formattedData = transactions.map(t => ({
      date: t.created_at,
      amount: t.amount,
      category: t.category,
      location: t.location_name
    }));

    const sentiment = detectSentimentLocally(JSON.stringify(formattedData));
    const systemInstruction = buildSystemInstruction({
      ...userContext,
      personality: sentiment === 'sad' ? 'coach' : userContext?.personality || 'casual'
    } as any);

    const result = await callGeminiWithFallback(JSON.stringify(formattedData), false, undefined, systemInstruction);
    const response = await result.response;
    const text = response.text();
    setAICache(cacheKey, text);
    return text;
  } catch (error) {
    console.error("AI Advisor error:", error);
    return "I couldn't analyze your transactions right now. Try again later!";
  }
}

/**
 * Multimodal audio parsing — sends base64 audio to Gemini 1.5 Flash
 */
export async function parseAudioWithAI(
  base64Audio: string,
  mimeType: string,
  categoryList: string[] = ['Food', 'Transport', 'Entertainment', 'Utilities', 'Income', 'Other'],
  userContext?: UserContext
): Promise<any | null> {
  if (!apiKey) return null;

  try {
    const today = new Date().toISOString().split('T')[0];
    const systemInstruction = buildSystemInstruction(userContext);

    const textPrompt = `
      Anda menerima rekaman suara pengguna yang sedang mencatat transaksi keuangan.
      Transkripsi audio tersebut, lalu ekstrak menjadi JSON murni tanpa markdown atau backticks.

      Hari ini adalah tanggal: ${today}.

      Format JSON wajib:
      {
        "title": "Nama transaksi singkat",
        "amount": 0,
        "category": "${categoryList.join('/')}",
        "type": "expense" atau "income",
        "date": "YYYY-MM-DD"
      }

      Aturan:
      1. Jika ada kata "k", "rb", atau "ribu", kalikan angka dengan 1000.
      2. Kategori HARUS salah satu dari: ${categoryList.join(', ')}.
      3. Jika tidak ada keterangan waktu, gunakan tanggal hari ini: ${today}.
      4. Hasilkan HANYA JSON murni.
    `;

    const result = await callGeminiWithFallback(textPrompt, true, {
      mimeType,
      data: base64Audio
    }, systemInstruction);

    const responseText = result.response.text().trim();
    const jsonStr = responseText
      .replace(/^```json\s*/i, '')
      .replace(/^```\s*/i, '')
      .replace(/```$/i, '')
      .trim();

    return JSON.parse(jsonStr);
  } catch (error) {
    console.error('[parseAudioWithAI] Error (Semua model fallback gagal):', error);
    return null;
  }
}

/**
 * AI memprediksi sisa saldo di akhir bulan berdasarkan tren pengeluaran saat ini
 */
export async function predictMonthEnd(
  transactions: any[], 
  currentBalance: number,
  userContext?: UserContext
): Promise<string> {
  const instruction = buildSystemInstruction(userContext);
  const dataStr = transactions.map(t => `${t.date || t.created_at}: ${t.amount}`).join('\n');
  
  const prompt = `
    Berdasarkan data transaksi pengeluaran berikut:
    ${dataStr}

    Saldo saat ini: ${currentBalance}
    
    Tugas:
    1. Hitung rata-rata pengeluaran harian.
    2. Prediksi total pengeluaran sampai akhir bulan ini.
    3. Prediksi sisa saldo di akhir bulan.
    4. Berikan komentar singkat yang sangat personal (sesuai kepribadianmu) tentang prediksi ini.
    
    Berikan respon dalam teks naratif singkat yang menarik.
  `;

  try {
    const result = await callGeminiWithFallback(prompt, false, undefined, instruction);
    return result.response.text();
  } catch {
    return "Saya belum bisa memprediksi saldo akhir bulan, pastikan koneksi internet stabil.";
  }
}

/**
 * AI memberikan rekomendasi budget bulanan untuk tiap kategori
 */
export async function recommendBudgets(
  transactions: any[],
  monthlyIncome: number,
  userContext?: UserContext
): Promise<string> {
  const instruction = buildSystemInstruction(userContext);
  const categoryTotals = transactions.reduce((acc: any, t) => {
    const cat = t.category || 'Lainnya';
    acc[cat] = (acc[cat] || 0) + Number(t.amount);
    return acc;
  }, {});

  const prompt = `
    User memiliki pendapatan bulanan: ${monthlyIncome}
    Histori pengeluaran per kategori saat ini: ${JSON.stringify(categoryTotals)}
    
    Tugas:
    1. Analisis kategori mana yang terlalu boros.
    2. Berikan rekomendasi nominal budget bulanan yang ideal untuk 3-5 kategori utama agar user bisa tetap menabung.
    3. Berikan tips singkat cara mencapainya.
    
    Gunakan gaya bicaramu yang khas.
  `;

  try {
    const result = await callGeminiWithFallback(prompt, false, undefined, instruction);
    return result.response.text();
  } catch {
    return "Saat ini saya belum bisa memberikan rekomendasi budget. Coba lagi nanti.";
  }
}


/**
 * Search history with AI query parsing
 */
export interface SearchFilters {
  category?: string;
  startDate?: string;
  endDate?: string;
  type?: 'expense' | 'income' | 'all';
  keyword?: string;
}

export async function parseSearchQuery(inputText: string, context?: UserContext): Promise<SearchFilters | null> {
  if (!apiKey) {
    const q = inputText.toLowerCase();
    if (q.includes('makan')) return { category: 'Food' };
    if (q.includes('transport')) return { category: 'Transport' };
    return { keyword: inputText };
  }

  try {
    const prompt = `
      Analyze this user query for financial history search and extract filters as JSON.
      Query: "${inputText}"
      
      JSON format:
      {
        "category": "string",
        "startDate": "YYYY-MM-DD",
        "endDate": "YYYY-MM-DD",
        "type": "expense" | "income" | "all",
        "keyword": "string"
      }
      
      Rules:
      1. Kategori harus sesuai dengan data transaksi (e.g., Food, Transport, Utilities, Entertainment, Income).
      2. Gunakan format tanggal YYYY-MM-DD.
      3. Jika tidak ada filter, biarkan null.
      
      Return ONLY JSON.
    `;
    const result = await callGeminiWithFallback(prompt);
    const text = result.response.text();
    const jsonStr = text.replace(/```json|```/g, '').trim();
    return JSON.parse(jsonStr);
  } catch (error) {
    console.error('[AI] parseSearchQuery error:', error);
    return { keyword: inputText };
  }
}

export async function answerSearchQuery(query: string, results: any[], context?: UserContext): Promise<string> {
  const instruction = buildSystemInstruction(context);
  const prompt = `
    User bertanya: "${query}"
    Data transaksi yang ditemukan: ${JSON.stringify(results.slice(0, 10))}
    
    Tugas:
    1. Berikan jawaban yang membantu berdasarkan data di atas.
    2. Jika user bertanya "berapa total", hitunglah totalnya.
    3. Jika user bertanya "kapan terakhir", carilah tanggal terbarunya.
    4. Gunakan gaya bahasa asisten keuangan yang ramah.
  `;

  try {
    const result = await callGeminiWithFallback(prompt, false, undefined, instruction);
    return result.response.text();
  } catch (error) {
    console.error('[AI] answerSearchQuery error:', error);
    return `Saya menemukan ${results.length} transaksi yang sesuai dengan pencarian Anda.`;
  }
}

export function suggestActionsLocally(query: string, results?: any[]): AIAction[] {
  const actions: AIAction[] = [];
  const q = query.toLowerCase();

  if (q.includes('catat') || q.includes('tambah') || q.includes('beli') || q.includes('bayar')) {
    actions.push({
      id: 'add_tx',
      label: 'Tambah Transaksi',
      icon: 'plus',
      type: 'OPEN_SHEET',
      payload: {}
    });
  }

  if (q.includes('riwayat') || q.includes('history') || q.includes('cari')) {
    actions.push({
      id: 'view_history',
      label: 'Riwayat Lengkap',
      icon: 'list',
      type: 'NAVIGATE',
      payload: { screen: '/history' }
    });
  }

  if (results && results.length > 0) {
    actions.push({
      id: 'view_analytics',
      label: 'Analisis Budget',
      icon: 'award',
      type: 'NAVIGATE',
      payload: { screen: '/analytics' }
    });
  }

  return actions;
}
