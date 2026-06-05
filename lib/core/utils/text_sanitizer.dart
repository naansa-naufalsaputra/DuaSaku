class TextSanitizer {
  /// Words indicating income intent.
  static const Set<String> _incomeTriggers = {
    'gaji',
    'bonus',
    'dikasih',
    'transferan',
    'refund',
    'pemasukan',
    'sampingan',
    'cuan',
    'dapat',
    'terima',
    'dividen',
    'upah',
    'salary',
    'transfer masuk',
    'dapat uang',
    'income',
    'receh',
    'untung',
  };

  /// Words indicating expense intent.
  static const Set<String> _expenseTriggers = {
    'beli',
    'bayar',
    'jajan',
    'tagihan',
    'langganan',
    'pengeluaran',
    'ongkos',
    'sewa',
    'belanja',
    'makan',
    'minum',
    'kopi',
    'donasi',
    'sedekah',
  };

  /// Words to strip out to improve fuzzy matching performance.
  static const Set<String> _stopWords = {
    'di',
    'ke',
    'dari',
    'buat',
    'untuk',
    'hari',
    'ini',
    'pada',
    'dengan',
    'saya',
    'aku',
    'dan',
    'atau',
    'yang',
    'ada',
    'adalah',
    'tadi',
    'kemarin',
    'besok',
    'lalu',
    'habis',
    'sebesar',
    'sebanyak',
    'nominal',
  };

  /// Colloquial synonyms mapped to standard English category names in DuaSaku seed.
  static const Map<String, String> _categorySynonyms = {
    // Transport
    'bensin': 'Transport',
    'pertalite': 'Transport',
    'pertamax': 'Transport',
    'gojek': 'Transport',
    'grab': 'Transport',
    'ojek': 'Transport',
    'parkir': 'Transport',
    'bus': 'Transport',
    'kereta': 'Transport',
    'tiket': 'Transport',
    'mrt': 'Transport',
    'lrt': 'Transport',
    'taksi': 'Transport',
    'angkot': 'Transport',
    'tol': 'Transport',

    // Food
    'nasi': 'Food',
    'makan': 'Food',
    'kopi': 'Food',
    'bakso': 'Food',
    'indomie': 'Food',
    'jajan': 'Food',
    'resto': 'Food',
    'minum': 'Food',
    'sate': 'Food',
    'soto': 'Food',
    'roti': 'Food',
    'snack': 'Food',
    'cemilan': 'Food',
    'warteg': 'Food',
    'cafe': 'Food',
    'teh': 'Food',
    'susu': 'Food',
    'warung': 'Food',

    // Bills
    'listrik': 'Bills',
    'pln': 'Bills',
    'wifi': 'Bills',
    'pulsa': 'Bills',
    'kuota': 'Bills',
    'kos': 'Bills',
    'kontrakan': 'Bills',
    'air': 'Bills',
    'pdam': 'Bills',
    'asuransi': 'Bills',
    'netflix': 'Bills',
    'spotify': 'Bills',
    'bpjs': 'Bills',
    'indihome': 'Bills',

    // Shopping
    'baju': 'Shopping',
    'kaos': 'Shopping',
    'celana': 'Shopping',
    'sepatu': 'Shopping',
    'tas': 'Shopping',
    'skincare': 'Shopping',
    'makeup': 'Shopping',
    'sabun': 'Shopping',
    'shampoo': 'Shopping',
    'odol': 'Shopping',
    'detergen': 'Shopping',
    'minimarket': 'Shopping',
    'supermarket': 'Shopping',
    'tokopedia': 'Shopping',
    'shopee': 'Shopping',
    'indomaret': 'Shopping',
    'alfamart': 'Shopping',

    // Entertainment
    'nonton': 'Entertainment',
    'bioskop': 'Entertainment',
    'game': 'Entertainment',
    'topup': 'Entertainment',
    'liburan': 'Entertainment',
    'hotel': 'Entertainment',
    'wisata': 'Entertainment',
    'karaoke': 'Entertainment',
    'konser': 'Entertainment',

    // Salary
    'gaji': 'Salary',
    'bonus': 'Salary',
    'salary': 'Salary',
    'sampingan': 'Salary',
  };

  /// Category equivalents for cross-language/synonym mapping.
  static const Map<String, Set<String>> categoryEquivalents = {
    'Food': {'food', 'makanan', 'makan', 'mamin'},
    'Transport': {'transport', 'transportasi', 'perjalanan', 'kendaraan'},
    'Bills': {'bills', 'tagihan', 'utilitas', 'pulsa'},
    'Shopping': {'shopping', 'belanja'},
    'Salary': {'salary', 'gaji', 'pendapatan', 'pemasukan'},
    'Entertainment': {'entertainment', 'hiburan', 'rekreasi'},
  };

  /// Sanitizes the input string.
  static String sanitize(String input) {
    if (input.isEmpty) return '';

    // Convert to lowercase
    String cleaned = input.toLowerCase();

    // Remove punctuation & special characters (keep alphanumeric and spaces)
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), ' ');

    // Split into words, filter empty or stop words, and rejoin
    final List<String> words = cleaned
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && !_stopWords.contains(word))
        .toList();

    return words.join(' ');
  }

  /// Determines the transaction intent type ('income' or 'expense') based on keyword matching.
  /// Defaults to 'expense'.
  static String determineIntent(String sanitizedText) {
    if (sanitizedText.isEmpty) return 'expense';

    int incomeCount = 0;
    int expenseCount = 0;

    // Scan for substring matches of triggers (handles both single words and phrases like 'transfer masuk')
    for (final trigger in _incomeTriggers) {
      if (sanitizedText.contains(trigger)) {
        incomeCount++;
      }
    }
    for (final trigger in _expenseTriggers) {
      if (sanitizedText.contains(trigger)) {
        expenseCount++;
      }
    }

    if (incomeCount > expenseCount) {
      return 'income';
    } else if (expenseCount > incomeCount) {
      return 'expense';
    }

    return 'expense';
  }

  /// Checks if any word (or substring) in the sanitized text matches a predefined synonym keyword.
  /// Returns the corresponding standard Category Name if a match is found, otherwise returns null.
  static String? mapToCategorySynonym(String sanitizedText) {
    if (sanitizedText.isEmpty) return null;

    final List<String> words = sanitizedText.split(' ');

    // 1. Direct word-by-word match (higher precision)
    for (final word in words) {
      if (_categorySynonyms.containsKey(word)) {
        return _categorySynonyms[word];
      }
    }

    // 2. Substring match fallback (for compound words like "alat tulis" or concatenated phrases)
    for (final entry in _categorySynonyms.entries) {
      if (sanitizedText.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Sanitizes transaction notes by collapsing extra whitespaces,
  /// trimming, and converting to Sentence case (only the first letter
  /// of the entire string is capitalized).
  static String prettifyNotes(String input) {
    final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }
}
