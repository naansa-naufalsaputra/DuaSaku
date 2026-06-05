# Design: Lightweight ML Fallback (Level 2)

## 1. Algoritma Penggolongan (Classification Algorithm)
Kita akan mengimplementasikan model Naive Bayes sederhana (Multinomial Naive Bayes bag-of-words) menggunakan Dart murni. Model ini akan memproses kata-kata hasil tokenisasi dan menghitung skor probabilitas untuk tiap kelas:

### A. Intent (Tipe Transaksi)
$$\text{Score}(\text{Intent}) = \sum_{w \in \text{words}} \text{Weight}_{\text{intent}}(w)$$
- Jika $\text{Score} > 0.5$, transaksi diklasifikasikan sebagai `income`.
- Jika $\text{Score} \le 0.5$, transaksi diklasifikasikan sebagai `expense`.

### B. Kategori (Category)
Untuk tiap kategori $C$:
$$\text{Score}(C) = \sum_{w \in \text{words}} \text{Weight}_{C}(w)$$
Kategori dengan skor tertinggi ($\text{argmax}$) akan dipilih. Jika semua skor bernilai 0, sistem akan menggunakan kategori *default* berdasarkan tipe transaksi.

## 2. Struktur Data Bobot (Weights Dictionary)
Bobot akan didefinisikan secara statis di dalam berkas Dart murni untuk menghindari I/O overhead pemuatan berkas JSON dari disk:
```dart
const Map<String, double> intentWeights = {
  'gaji': 1.0,
  'cuan': 0.8,
  'dapet': 0.8,
  'masuk': 0.9,
  'transferan': 0.9,
  'beli': -0.8,
  'bayar': -0.9,
  'jajan': -0.7,
  // ...
};

const Map<String, Map<String, double>> categoryWeights = {
  'Makanan': {
    'makan': 1.0,
    'bakso': 0.9,
    'kopi': 0.8,
    'warteg': 0.9,
    'sate': 0.9,
  },
  'Transportasi': {
    'ojek': 1.0,
    'grab': 0.8,
    'gojek': 0.8,
    'bensin': 0.9,
    'kereta': 0.9,
  },
  // ...
};
```

## 3. Alur Fallback di SmartParserOrchestrator
```
                       [Input Text]
                            │
                  [SmartParserOrchestrator]
                            │
               Try Level 3 (TFLite Model) ─── Sukses? ───► [Hasil TFLite]
                            │ Gagal / Timeout
                            ▼
               Try Level 2 (Lightweight ML) ── Sukses? ───► [Hasil Level 2]
                            │ Gagal / Timeout
                            ▼
               Try Level 1 (Regex/Fuzzy) ────────────────► [Hasil Level 1]
```
