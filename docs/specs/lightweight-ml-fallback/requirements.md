# Requirements: Lightweight ML Fallback (Level 2)

## 1. Pendahuluan
Mesin Smart Input pada DuaSaku membutuhkan performa tinggi dan keandalan penuh. Saat ini, model TFLite Level 3 (`duasaku_level3.tflite`) berjalan secara native. Namun, ada kalanya inisialisasi TFLite gagal atau mengalami *timeout* pada HP low-end. Fitur ini menambahkan mesin ML Level 2 berbasis statistik (seperti Naive Bayes atau Logistic Regression) dalam Dart murni sebagai cadangan instan.

## 2. Persyaratan Fungsional (Functional Requirements)
- **FR-1**: Harus mengklasifikasikan tipe transaksi (`income` vs `expense`) dengan akurat berdasarkan teks input.
- **FR-2**: Harus menebak kategori transaksi terdaftar (Makanan, Belanja, Tagihan, dll) berdasarkan kemunculan kata kunci berbobot.
- **FR-3**: Harus berjalan 100% di atas mesin Dart tanpa rely pada dynamic loading library biner native (`tflite_flutter`).
- **FR-4**: Harus terintegrasi secara transparan di dalam `SmartParserOrchestrator` sehingga jika Level 3 gagal, parser Level 2 langsung mengambil alih proses tebakan sebelum menyerahkan ke Level 1 (Regex/Fuzzy).

## 3. Batasan Teknis (Technical Constraints)
- **TC-1**: Latensi inferensi Level 2 wajib berada di bawah 5ms.
- **TC-2**: Ukuran berkas bobot model (weights dictionary) harus sangat kecil (< 500 KB) dan dimuat secara asinkron dari aset JSON atau tertulis langsung dalam kode Dart.
- **TC-3**: Pembagian token teks (tokenization) harus menggunakan logika yang selaras dengan `DartTokenizer` di `duasaku_level3.tflite` agar konsisten.

## 4. Kriteria Penerimaan (Acceptance Criteria)
- Ketika TFLite dimatikan atau gagal memuat, penguraian teks (seperti *"gajian masuk 5 juta"*) tetap mengembalikan tipe `income` dan kategori `Gaji` menggunakan tebakan Level 2 ML.
- Terbukti lewat unit test bahwa parser Level 2 dipanggil saat Level 3 melempar eksepsi.
