# Requirements Document

## Introduction

Fitur Export/Import Data memungkinkan pengguna DuaSaku untuk mengekspor data keuangan dalam format CSV (laporan selektif per tipe data dengan filter tanggal) dan JSON (full backup seluruh database untuk restore). Fitur ini juga mendukung import/restore dari file JSON yang diekspor oleh DuaSaku sendiri. Sharing file hasil export dilakukan melalui Share Sheet native (share_plus) sehingga pengguna dapat langsung mengirim ke WhatsApp, Email, atau menyimpan ke Google Drive tanpa perlu mencari file di file manager. Untuk MVP ini, import hanya mendukung file yang dihasilkan oleh DuaSaku — tidak mendukung import dari bank statement atau aplikasi lain.

## Glossary

- **Export_Engine**: Komponen yang mengambil data dari Drift database dan menghasilkan file output dalam format CSV atau JSON
- **Import_Engine**: Komponen yang membaca file JSON backup DuaSaku, memvalidasi struktur dan integritas data, lalu merestorasi ke database lokal
- **CSV_Report**: File CSV yang berisi data selektif (satu tipe data tertentu) dengan filter tanggal opsional, ditujukan untuk dibaca manusia atau diproses di spreadsheet
- **JSON_Backup**: File JSON yang berisi seluruh data database DuaSaku tanpa filter, termasuk metadata versi dan relasi antar tabel, ditujukan untuk full backup dan restore
- **Share_Sheet**: Native sharing dialog (iOS/Android) yang dipanggil melalui share_plus package untuk membagikan file ke aplikasi lain
- **Data_Type**: Kategori data yang dapat diekspor secara selektif dalam format CSV: Transactions, Wallets, Categories, Budgets, Recurring Transactions, Goals, Goal Deposits, Budget Alerts
- **Date_Range_Filter**: Filter rentang tanggal yang diterapkan pada CSV export, mendukung preset (This Month, Last Month, Last 3 Months) dan Custom Range
- **Backup_Metadata**: Informasi header dalam file JSON backup yang mencakup versi aplikasi, versi schema database, timestamp export, dan device identifier
- **Export_Screen**: Layar UI utama untuk mengkonfigurasi dan menjalankan export data
- **Import_Confirmation_Screen**: Layar UI yang menampilkan preview data dari file backup sebelum pengguna mengkonfirmasi restore

## Requirements

### Requirement 1: CSV Export dengan Seleksi Tipe Data

**User Story:** Sebagai pengguna DuaSaku, saya ingin mengekspor data keuangan tertentu dalam format CSV, sehingga saya dapat membuka dan menganalisis data di Excel atau Google Sheets.

#### Acceptance Criteria

1. THE Export_Screen SHALL menampilkan daftar Data_Type yang tersedia untuk CSV export dengan checkbox seleksi: Transactions, Wallets, Categories, Budgets, Recurring Transactions, Goals, Goal Deposits, Budget Alerts
2. WHEN pengguna memilih satu atau lebih Data_Type dan menekan tombol export, THE Export_Engine SHALL menghasilkan satu file CSV per Data_Type yang dipilih
3. THE Export_Engine SHALL menyertakan header row pada setiap file CSV yang berisi nama kolom sesuai dengan field tabel database
4. WHEN Data_Type yang dipilih adalah Transactions, THE Export_Engine SHALL menyertakan nama wallet dan nama kategori (resolved dari ID) sebagai kolom tambahan agar CSV dapat dibaca tanpa referensi tabel lain
5. THE Export_Engine SHALL menggunakan encoding UTF-8 dengan BOM (Byte Order Mark) pada file CSV agar karakter non-ASCII (nama kategori Indonesia) ditampilkan dengan benar di Excel
6. IF pengguna tidak memilih satupun Data_Type, THEN THE Export_Screen SHALL menonaktifkan tombol export dan menampilkan pesan bahwa minimal satu tipe data harus dipilih
7. WHEN multiple Data_Type dipilih, THE Export_Engine SHALL mengemas semua file CSV ke dalam satu file ZIP sebelum dibagikan melalui Share_Sheet

### Requirement 2: Date Range Filter untuk CSV Export

**User Story:** Sebagai pengguna DuaSaku, saya ingin memfilter data berdasarkan rentang tanggal saat export CSV, sehingga saya hanya mendapatkan data pada periode yang saya butuhkan.

#### Acceptance Criteria

1. THE Export_Screen SHALL menampilkan Date_Range_Filter dengan opsi preset: This Month, Last Month, Last 3 Months, This Year, dan Custom Range
2. WHEN pengguna memilih Custom Range, THE Export_Screen SHALL menampilkan date picker untuk memilih tanggal mulai dan tanggal selesai
3. THE Export_Engine SHALL menerapkan Date_Range_Filter berdasarkan kolom tanggal yang relevan pada setiap Data_Type: field `date` untuk Transactions, field `createdAt` untuk Wallets, Categories, Budgets, Goals, Goal Deposits, Recurring Transactions, dan Budget Alerts
4. WHEN Date_Range_Filter diterapkan pada Transactions, THE Export_Engine SHALL hanya menyertakan transaksi yang field `date`-nya berada dalam rentang tanggal yang dipilih (inklusif kedua ujung)
5. IF pengguna tidak memilih Date_Range_Filter (memilih opsi "All Time"), THEN THE Export_Engine SHALL mengekspor seluruh data tanpa filter tanggal
6. THE Export_Screen SHALL menampilkan Date_Range_Filter default berupa "This Month" saat pertama kali dibuka

### Requirement 3: JSON Full Backup Export

**User Story:** Sebagai pengguna DuaSaku, saya ingin membuat full backup seluruh data dalam format JSON, sehingga saya dapat merestorasi data jika berganti device atau terjadi kehilangan data.

#### Acceptance Criteria

1. WHEN pengguna memilih opsi "Full Backup (JSON)", THE Export_Engine SHALL mengekspor seluruh data dari semua tabel database tanpa filter tanggal: Wallets, Categories, Transactions, Budgets, Recurring Transactions, Recurring Execution Logs, Goals, Goal Deposits, Budget Alerts, Budget Alert Preferences, Budget Alert Threshold Status
2. THE Export_Engine SHALL menyertakan Backup_Metadata pada root level JSON yang berisi: appVersion (versi aplikasi), schemaVersion (versi schema Drift database saat ini), exportedAt (timestamp ISO 8601), dan deviceId (identifier device)
3. THE Export_Engine SHALL mempertahankan semua relasi antar tabel dengan menyimpan foreign key values (walletId, categoryId, goalId) secara eksplisit dalam setiap record
4. THE Export_Engine SHALL menghasilkan file JSON dengan nama format "duasaku_backup_{YYYY-MM-DD_HHmmss}.json"
5. THE Export_Engine SHALL menyertakan field "exportedBy" dengan nilai "duasaku" pada Backup_Metadata sebagai identifier bahwa file dihasilkan oleh aplikasi DuaSaku
6. THE Export_Screen SHALL menyembunyikan Date_Range_Filter dan Data_Type selector ketika mode "Full Backup (JSON)" dipilih, dan menampilkan informasi bahwa seluruh data akan di-backup
7. THE Export_Engine SHALL menjalankan proses serialization JSON di background isolate (menggunakan `Isolate.run` atau `compute`) agar UI tidak freeze dan animasi loading tetap mulus selama proses export berlangsung
8. WHEN pengguna memilih "Full Backup (JSON)", THE Export_Screen SHALL menampilkan peringatan keamanan (Security Warning) bahwa file backup tidak dienkripsi dan berisi data finansial sensitif yang harus disimpan di tempat yang aman, sebelum proses export dimulai

### Requirement 4: JSON Import/Restore

**User Story:** Sebagai pengguna DuaSaku, saya ingin merestorasi data dari file JSON backup yang pernah saya buat, sehingga saya dapat memulihkan data di device baru atau setelah reinstall.

#### Acceptance Criteria

1. WHEN pengguna memilih file JSON untuk import, THE Import_Engine SHALL memvalidasi bahwa file memiliki field Backup_Metadata dengan "exportedBy" bernilai "duasaku"
2. IF file yang dipilih tidak memiliki Backup_Metadata atau "exportedBy" bukan "duasaku", THEN THE Import_Engine SHALL menolak file dan menampilkan pesan error bahwa hanya file backup DuaSaku yang didukung
3. WHEN file valid terdeteksi, THE Import_Confirmation_Screen SHALL menampilkan ringkasan data yang akan di-restore: jumlah wallets, categories, transactions, budgets, goals, recurring transactions, dan budget alerts yang terdapat dalam file
4. THE Import_Confirmation_Screen SHALL menampilkan peringatan bahwa proses restore akan menggantikan seluruh data yang ada saat ini (destructive operation)
5. WHEN pengguna mengkonfirmasi restore, THE Import_Engine SHALL menghapus seluruh data existing di semua tabel dan memasukkan data dari file backup dalam satu database transaction
6. THE Import_Engine SHALL menjalankan proses deserialization (parsing JSON) dan validasi data di background isolate (menggunakan `Isolate.run` atau `compute`) agar UI tidak freeze dan progress indicator tetap berjalan mulus selama proses import berlangsung
7. IF schemaVersion dalam file backup tidak sama persis (strict match) dengan schemaVersion aplikasi saat ini, THEN THE Import_Engine SHALL menolak import — jika backup_schema > current_app_schema, tampilkan pesan "Silakan update aplikasi DuaSaku Anda terlebih dahulu"; jika backup_schema < current_app_schema, tampilkan pesan "File backup ini dibuat dengan versi DuaSaku yang lebih lama dan tidak kompatibel dengan versi saat ini"
8. WHEN proses restore selesai berhasil, THE Import_Engine SHALL menampilkan pesan sukses dengan ringkasan jumlah data yang berhasil di-restore
9. WHEN proses restore selesai berhasil, THE Import_Engine SHALL memaksa pembaruan UI dengan meng-invalidate seluruh root Riverpod providers (atau me-restart state aplikasi) agar data baru langsung terefleksi tanpa perlu menutup aplikasi

### Requirement 5: Validasi dan Error Handling Import

**User Story:** Sebagai pengguna DuaSaku, saya ingin mendapatkan pesan error yang jelas jika file import corrupt atau tidak valid, sehingga saya tahu apa yang salah dan bagaimana mengatasinya.

#### Acceptance Criteria

1. IF file JSON tidak dapat di-parse (malformed JSON), THEN THE Import_Engine SHALL menampilkan pesan error "File backup rusak atau tidak valid. Pastikan file tidak dimodifikasi secara manual."
2. IF file JSON valid tetapi data di dalamnya memiliki foreign key references yang tidak konsisten (misalnya transaction mereferensi walletId yang tidak ada dalam data wallets), THEN THE Import_Engine SHALL menampilkan pesan error yang menyebutkan tabel dan record yang bermasalah
3. IF proses restore gagal di tengah jalan (database transaction error), THEN THE Import_Engine SHALL melakukan rollback seluruh operasi sehingga data sebelumnya tetap utuh
4. WHEN file yang dipilih bukan berformat JSON (misalnya CSV atau file lain), THE Import_Engine SHALL menampilkan pesan error bahwa hanya file JSON backup DuaSaku yang dapat di-import
5. IF ukuran file backup melebihi 50MB, THEN THE Import_Engine SHALL menampilkan pesan peringatan tentang ukuran file besar dan meminta konfirmasi tambahan sebelum melanjutkan
6. THE Import_Engine SHALL memvalidasi bahwa setiap record dalam file backup memiliki semua required fields sesuai schema, dan melaporkan field yang hilang jika ditemukan

### Requirement 6: Share Sheet Integration

**User Story:** Sebagai pengguna DuaSaku, saya ingin langsung membagikan file export melalui Share Sheet, sehingga saya dapat mengirim ke WhatsApp, Email, atau menyimpan ke cloud storage tanpa mencari file di file manager.

#### Acceptance Criteria

1. WHEN export selesai (baik CSV maupun JSON), THE Export_Engine SHALL langsung membuka Share_Sheet native dengan file hasil export sebagai attachment
2. THE Export_Engine SHALL menyimpan file export ke temporary directory sebelum membuka Share_Sheet, dan membersihkan file temporary setelah sharing selesai atau dibatalkan
3. WHEN file yang di-share adalah CSV (atau ZIP berisi multiple CSV), THE Share_Sheet SHALL menampilkan MIME type "text/csv" (atau "application/zip" untuk multiple files) agar aplikasi penerima mengenali tipe file dengan benar
4. WHEN file yang di-share adalah JSON backup, THE Share_Sheet SHALL menampilkan MIME type "application/json"
5. IF Share_Sheet gagal dibuka (misalnya tidak ada aplikasi yang mendukung), THEN THE Export_Engine SHALL menampilkan opsi fallback untuk menyimpan file ke Downloads folder device

### Requirement 7: Export/Import UI Screens

**User Story:** Sebagai pengguna DuaSaku, saya ingin antarmuka export/import yang intuitif dan konsisten dengan design system aplikasi, sehingga saya dapat melakukan backup dan export dengan mudah.

#### Acceptance Criteria

1. THE Export_Screen SHALL menampilkan dua mode utama sebagai tab atau segmented control: "CSV Report" dan "Full Backup (JSON)"
2. THE Export_Screen SHALL menampilkan progress indicator (linear progress bar) selama proses export berlangsung dengan informasi tabel yang sedang diproses
3. WHEN proses export berlangsung, THE Export_Screen SHALL menonaktifkan tombol export dan navigasi back untuk mencegah interupsi
4. THE Import_Confirmation_Screen SHALL menampilkan data summary dalam card layout yang menunjukkan ikon dan jumlah record per tipe data
5. THE Import_Confirmation_Screen SHALL menampilkan tombol "Cancel" dan "Restore" dengan tombol Restore berwarna destructive (merah) untuk menekankan bahwa operasi ini menggantikan data existing
6. WHEN proses import berlangsung, THE Import_Confirmation_Screen SHALL menampilkan progress indicator dengan persentase dan nama tabel yang sedang di-restore
7. THE Export_Screen SHALL mengikuti Liquid Glass design system: menggunakan glassmorphism card dengan border, border radius 16px, dan warna dari Theme.of(context).colorScheme
8. IF proses export atau import memakan waktu lebih dari 2 detik, THEN THE Export_Screen SHALL menampilkan estimasi waktu tersisa berdasarkan progress saat ini

### Requirement 8: JSON Backup Serialization Round-Trip

**User Story:** Sebagai developer DuaSaku, saya ingin memastikan bahwa proses serialization dan deserialization backup JSON menghasilkan data yang identik, sehingga tidak ada data loss saat backup dan restore.

#### Acceptance Criteria

1. FOR ALL valid database states, exporting ke JSON kemudian importing kembali SHALL menghasilkan database state yang equivalent dengan state sebelum export (round-trip property)
2. THE Export_Engine SHALL menggunakan format ISO 8601 untuk semua field DateTime agar tidak terjadi ambiguitas timezone saat parsing
3. THE Export_Engine SHALL menyimpan nilai numerik (amount, balance, targetAmount) dengan presisi penuh tanpa pembulatan
4. FOR ALL valid Backup_Metadata objects, serializing ke JSON kemudian deserializing kembali SHALL menghasilkan objek yang equivalent (round-trip property)
5. THE Import_Engine SHALL mempertahankan urutan insertion yang menghormati foreign key constraints: Wallets dan Categories terlebih dahulu, kemudian Transactions, Budgets, Goals, Recurring Transactions, lalu tabel-tabel dependent lainnya (Goal Deposits, Recurring Execution Logs, Budget Alerts, Budget Alert Preferences, Budget Alert Threshold Status)
