/**
 * CategoryIntelligence — Auto-mapping for transactions.
 * Maps keywords in titles/notes to specific financial categories.
 */

export type TransactionCategory = 
  | 'Food' 
  | 'Transport' 
  | 'Entertainment' 
  | 'Utilities' 
  | 'Shopping' 
  | 'Income' 
  | 'Health'
  | 'Education'
  | 'Social'
  | 'Hobby'
  | 'Gift'
  | 'Subscription'
  | 'Pet'
  | 'Maintenance'
  | 'Debt'
  | 'Charity'
  | 'Investment'
  | 'Other';

const KEYWORD_MAP: Record<string, TransactionCategory> = {
  // Food & Drink
  'gofood': 'Food',
  'grabfood': 'Food',
  'mcdonald': 'Food',
  'kfc': 'Food',
  'starbucks': 'Food',
  'kopi': 'Food',
  'warung': 'Food',
  'restoran': 'Food',
  'makan': 'Food',
  'kuliner': 'Food',
  
  // Transport
  'gojek': 'Transport',
  'grab': 'Transport',
  'uber': 'Transport',
  'pertamina': 'Transport',
  'bensin': 'Transport',
  'parkir': 'Transport',
  'toll': 'Transport',
  'kereta': 'Transport',
  'ojek': 'Transport',
  
  // Shopping
  'shopee': 'Shopping',
  'tokopedia': 'Shopping',
  'lazada': 'Shopping',
  'alfamart': 'Shopping',
  'indomaret': 'Shopping',
  'supermarket': 'Shopping',
  'mall': 'Shopping',
  'baju': 'Shopping',
  'sepatu': 'Shopping',
  
  // Utilities
  'pln': 'Utilities',
  'listrik': 'Utilities',
  'pdam': 'Utilities',
  'air': 'Utilities',
  'internet': 'Utilities',
  'indihome': 'Utilities',
  'pulsa': 'Utilities',
  'kuota': 'Utilities',
  
  // Entertainment
  'bioskop': 'Entertainment',
  'nonton': 'Entertainment',
  'top up game': 'Hobby',
  
  // Income
  'gaji': 'Income',
  'salary': 'Income',
  'bonus': 'Income',
  'transfer masuk': 'Income',
  'deviden': 'Income',

  // Education
  'kursus': 'Education',
  'sekolah': 'Education',
  'kuliah': 'Education',
  'buku': 'Education',
  'udemy': 'Education',

  // Social
  'zakat': 'Social',
  'infaq': 'Social',
  'sedekah': 'Social',
  'kondangan': 'Social',
  'patungan': 'Social',

  // Hobby
  'game': 'Hobby',
  'steam': 'Hobby',
  'top up': 'Hobby',
  'hobi': 'Hobby',
  'mainan': 'Hobby',

  // Subscription
  'netflix': 'Subscription',
  'spotify': 'Subscription',
  'youtube premium': 'Subscription',
  'langganan': 'Subscription',

  // Pet
  'kucing': 'Pet',
  'anjing': 'Pet',
  'whiskas': 'Pet',
  'pet shop': 'Pet',
};

// Pre-compile Regex for performance (O(1) search logic instead of O(n) loop)
const CATEGORY_REGEX = new RegExp(`\\b(${Object.keys(KEYWORD_MAP).join('|')})\\b`, 'i');

/**
 * Predicts the category based on text input.
 * Optimized with pre-compiled regex for high-performance matching.
 */
export function predictCategory(text: string): TransactionCategory {
  const match = text.match(CATEGORY_REGEX);
  if (match) {
    const keyword = match[0].toLowerCase();
    return KEYWORD_MAP[keyword] || 'Other';
  }
  
  return 'Other';
}

/**
 * Gets emoji for a category.
 */
export const CATEGORY_EMOJI: Record<string, string> = {
  Food: '🍔',
  Transport: '🚗',
  Entertainment: '🎬',
  Utilities: '💡',
  Shopping: '🛍️',
  Income: '💰',
  Health: '🏥',
  Education: '📚',
  Social: '🤝',
  Hobby: '🎮',
  Gift: '🎁',
  Subscription: '💳',
  Pet: '🐾',
  Maintenance: '🛠️',
  Debt: '💸',
  Charity: '🧡',
  Investment: '📈',
  Other: '📦',
};
