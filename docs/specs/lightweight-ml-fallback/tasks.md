# Tasks: Lightweight ML Fallback (Level 2)

## Daftar Checklist Pengerjaan

- [ ] **Task 3.1**: Definisikan berkas kosakata dan bobot model (`lightweight_ml_weights.dart`)
  - *Skill*: `clean-code`
  - *Kriteria Verifikasi*: Bobot intent dan kategori mencakup kata-kata dari `metadata.json` yang paling umum.
- [ ] **Task 3.2**: Buat kelas `LightweightMlParserService` murni Dart yang mengimplementasikan `TransactionParserServiceInterface`
  - *Skill*: `clean-code`
  - *Kriteria Verifikasi*: Menerapkan kalkulasi pembobotan kata-kata (Naive Bayes bag-of-words) dan mengembalikan `ParsedTransaction`.
- [ ] **Task 3.3**: Tambahkan unit test di `test/services/lightweight_ml_parser_test.dart`
  - *Skill*: `testing-patterns`, `tdd-workflow`
  - *Kriteria Verifikasi*: Jalankan `flutter test test/services/lightweight_ml_parser_test.dart` dan semua pengujian klasifikasi terbukti berhasil.
- [ ] **Task 3.4**: Integrasikan `LightweightMlParserService` ke `SmartParserOrchestrator`
  - *Skill*: `clean-code`
  - *Kriteria Verifikasi*: Saat Level 3 melempar eksepsi, parser Level 2 dieksekusi dan mengembalikan tebakan kategori/intent dengan benar.
