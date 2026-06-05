# Requirements Document

## Introduction

Fitur Smart Budget Alerts memberikan notifikasi proaktif kepada pengguna DuaSaku ketika pengeluaran mendekati atau melampaui batas budget yang telah dikonfigurasi. Fitur ini mencakup alert berbasis threshold (persentase penggunaan budget), prediksi pengeluaran berdasarkan tren spending dan recurring transactions, in-app notification center untuk riwayat alert, serta konfigurasi preferensi alert yang fleksibel per kategori. Integrasi dengan sistem budget tracking dan recurring transactions yang sudah ada memastikan akurasi prediksi dan relevansi notifikasi.

## Glossary

- **Alert_Engine**: Komponen yang mengevaluasi spending terhadap budget limits dan menghasilkan alert ketika threshold tercapai
- **Threshold**: Persentase penggunaan budget yang memicu alert (contoh: 50%, 75%, 90%, 100%)
- **Budget_Alert**: Notifikasi yang dihasilkan ketika spending mencapai atau melampaui threshold tertentu pada suatu budget
- **Prediction_Engine**: Komponen yang menghitung proyeksi pengeluaran berdasarkan rata-rata spending harian dan recurring transactions terjadwal
- **Projected_Overspend_Date**: Tanggal estimasi dimana pengeluaran diprediksi akan melampaui budget limit berdasarkan tren saat ini
- **Alert_Preference**: Konfigurasi pengguna untuk mengontrol threshold, kategori, dan waktu pengiriman alert
- **Quiet_Hours**: Rentang waktu dimana notifikasi push tidak dikirim ke pengguna
- **Alert_Center**: Layar in-app yang menampilkan riwayat semua budget alert yang pernah dikirim
- **Alert_Record**: Entry individual dalam Alert_Center yang mencatat tipe alert, kategori, timestamp, dan status baca
- **Spending_Rate**: Rata-rata pengeluaran harian pada suatu kategori, dihitung dari total spending dibagi jumlah hari yang telah berlalu dalam periode budget
- **Notification_Service**: Layanan flutter_local_notifications yang mengirim push notification ke device pengguna

## Requirements

### Requirement 1: Budget Threshold Alerts

**User Story:** Sebagai pengguna DuaSaku, saya ingin menerima notifikasi ketika pengeluaran saya mencapai persentase tertentu dari budget, sehingga saya dapat mengontrol pengeluaran sebelum melampaui batas.

#### Acceptance Criteria

1. WHEN total spending pada suatu kategori mencapai atau melampaui threshold yang dikonfigurasi, THE Alert_Engine SHALL menghasilkan Budget_Alert yang berisi nama kategori, persentase penggunaan aktual, dan sisa budget dalam mata uang Rupiah
2. THE Alert_Engine SHALL mendukung threshold default pada 50%, 75%, 90%, dan 100% dari budget limit per kategori
3. WHEN spending melampaui threshold 100%, THE Alert_Engine SHALL menghasilkan Budget_Alert bertipe "over-budget" yang berisi jumlah kelebihan pengeluaran dalam Rupiah
4. THE Alert_Engine SHALL mengevaluasi threshold setiap kali transaksi baru ditambahkan (baik manual maupun dari recurring transaction) pada kategori yang memiliki budget aktif
5. THE Alert_Engine SHALL menghasilkan maksimal satu alert per threshold per kategori per periode budget (tidak mengirim alert duplikat untuk threshold yang sama)
6. WHEN pengguna memiliki overall monthly budget (lintas kategori), THE Alert_Engine SHALL mengevaluasi threshold terhadap total pengeluaran bulanan selain evaluasi per kategori
7. WHEN transaksi dihapus atau diubah sehingga total spending turun di bawah threshold yang sebelumnya sudah di-trigger, THE Alert_Engine SHALL mereset status threshold tersebut di BudgetAlertThresholdStatus sehingga alert dapat dikirim kembali jika spending naik melewati threshold itu lagi

### Requirement 2: Spending Prediction Alerts

**User Story:** Sebagai pengguna DuaSaku, saya ingin menerima peringatan prediktif ketika tren pengeluaran saya menunjukkan kemungkinan melampaui budget, sehingga saya dapat menyesuaikan kebiasaan belanja lebih awal.

#### Acceptance Criteria

1. THE Prediction_Engine SHALL menghitung Spending_Rate berdasarkan total pengeluaran aktual pada kategori tersebut dibagi jumlah hari yang telah berlalu sejak awal periode budget
2. THE Prediction_Engine SHALL memperhitungkan recurring transactions terjadwal yang belum dieksekusi dalam sisa periode budget untuk meningkatkan akurasi proyeksi
3. WHEN Spending_Rate dikali sisa hari dalam periode budget ditambah spending aktual saat ini melebihi budget limit, THE Prediction_Engine SHALL menghasilkan alert prediktif yang berisi Projected_Overspend_Date dan estimasi jumlah kelebihan
4. THE Prediction_Engine SHALL menghitung ulang proyeksi setiap kali transaksi baru ditambahkan pada kategori yang memiliki budget aktif
5. THE Prediction_Engine SHALL hanya menghasilkan alert prediktif jika Projected_Overspend_Date berada dalam sisa periode budget saat ini
6. IF jumlah hari yang telah berlalu dalam periode budget kurang dari 3 hari, THEN THE Prediction_Engine SHALL tidak menghasilkan alert prediktif karena data belum cukup representatif

### Requirement 3: Alert Preferences dan Configuration

**User Story:** Sebagai pengguna DuaSaku, saya ingin mengkonfigurasi preferensi alert sesuai kebutuhan saya, sehingga saya hanya menerima notifikasi yang relevan pada waktu yang tepat.

#### Acceptance Criteria

1. THE Alert_Preference SHALL menyediakan opsi untuk mengaktifkan atau menonaktifkan alert per kategori budget secara individual
2. THE Alert_Preference SHALL menyediakan opsi untuk mengkustomisasi threshold per kategori dengan nilai minimum 10% dan maksimum 100%, dalam kelipatan 5%
3. THE Alert_Preference SHALL menyediakan opsi untuk mengaktifkan atau menonaktifkan prediction alerts secara terpisah dari threshold alerts
4. WHEN pengguna mengkonfigurasi Quiet_Hours dengan waktu mulai dan waktu selesai, THE Notification_Service SHALL menahan pengiriman push notification selama rentang waktu tersebut dan mengirimkannya segera setelah Quiet_Hours berakhir
5. THE Alert_Preference SHALL menyimpan konfigurasi default berupa: semua threshold aktif (50%, 75%, 90%, 100%), prediction alerts aktif, dan Quiet_Hours nonaktif, saat pengguna pertama kali menggunakan fitur
6. WHEN pengguna mengubah konfigurasi alert, THE Alert_Preference SHALL menyimpan perubahan ke database lokal dan menerapkannya secara langsung tanpa memerlukan restart aplikasi
7. THE Alert_Preference SHALL menyediakan opsi master toggle untuk menonaktifkan semua budget alerts sekaligus

### Requirement 4: In-App Alert Center

**User Story:** Sebagai pengguna DuaSaku, saya ingin melihat riwayat semua budget alert dalam satu tempat, sehingga saya dapat meninjau pola pengeluaran dan alert yang pernah diterima.

#### Acceptance Criteria

1. THE Alert_Center SHALL menampilkan daftar semua Alert_Record yang diurutkan berdasarkan timestamp terbaru (descending) dengan staggered fade-in animation menggunakan flutter_animate
2. THE Alert_Center SHALL menampilkan setiap Alert_Record dengan informasi: tipe alert (threshold/prediction/over-budget), nama kategori, pesan alert, timestamp, dan indikator status baca (read/unread)
3. WHEN pengguna membuka Alert_Center, THE Alert_Center SHALL menandai semua alert yang terlihat di viewport sebagai sudah dibaca
4. THE Alert_Center SHALL menampilkan badge counter pada ikon navigasi yang menunjukkan jumlah alert yang belum dibaca
5. WHEN daftar alert kosong, THE Alert_Center SHALL menampilkan empty state dengan animasi Lottie dan pesan informatif bahwa belum ada alert budget
6. WHEN pengguna menekan Alert_Record bertipe threshold atau over-budget, THE Alert_Center SHALL membuka layar budget detail untuk kategori terkait
7. WHEN pengguna menekan Alert_Record bertipe prediction, THE Alert_Center SHALL membuka layar budget detail untuk kategori terkait dengan informasi proyeksi yang ditampilkan
8. THE Alert_Center SHALL menyediakan opsi untuk menghapus alert individual dengan swipe gesture dan opsi "clear all" untuk menghapus semua alert yang sudah dibaca

### Requirement 5: Push Notification Delivery

**User Story:** Sebagai pengguna DuaSaku, saya ingin menerima push notification untuk budget alert, sehingga saya aware tentang status budget meskipun tidak sedang membuka aplikasi.

#### Acceptance Criteria

1. WHEN Alert_Engine atau Prediction_Engine menghasilkan alert baru, THE Notification_Service SHALL mengirim push notification menggunakan flutter_local_notifications dengan judul yang berisi nama kategori dan body yang berisi pesan alert
2. WHILE Quiet_Hours aktif, THE Notification_Service SHALL menyimpan notifikasi dalam antrian. WHEN Quiet_Hours berakhir, IF jumlah notifikasi dalam antrian lebih dari 3, THEN THE Notification_Service SHALL mengirim satu notifikasi summary bertipe ringkasan ("Anda memiliki N budget alert baru") dengan action yang membuka Alert_Center. IF jumlah notifikasi dalam antrian 3 atau kurang, THEN THE Notification_Service SHALL mengirimkannya secara individual dengan interval 10 detik antar notifikasi
3. WHEN pengguna menekan push notification budget alert, THE Notification_Service SHALL membuka Alert_Center dan menampilkan Alert_Record terkait
4. THE Notification_Service SHALL menggunakan channel notifikasi terpisah bernama "Budget Alerts" dengan prioritas high untuk semua budget alert notifications
5. IF pengguna telah menonaktifkan master toggle alerts, THEN THE Notification_Service SHALL tidak mengirim push notification apapun terkait budget alerts

### Requirement 6: Integrasi dengan Budget System Existing

**User Story:** Sebagai pengguna DuaSaku, saya ingin smart budget alerts terintegrasi dengan sistem budget yang sudah ada, sehingga alert akurat berdasarkan data spending aktual.

#### Acceptance Criteria

1. WHEN transaksi baru bertipe expense ditambahkan (manual atau dari recurring transaction), THE Alert_Engine SHALL mengambil data budget aktif untuk kategori dan bulan yang sesuai dari BudgetRepository dan mengevaluasi semua threshold
2. THE Alert_Engine SHALL menggunakan data spending aktual dari TransactionRepository yang sudah ada untuk menghitung total pengeluaran per kategori per bulan
3. WHEN periode budget baru dimulai (awal bulan baru), THE Alert_Engine SHALL mereset status alert untuk semua threshold pada semua kategori sehingga alert dapat dikirim kembali pada periode baru
4. IF kategori transaksi tidak memiliki budget yang dikonfigurasi untuk bulan berjalan, THEN THE Alert_Engine SHALL melewatkan evaluasi threshold untuk kategori tersebut tanpa menghasilkan error
5. WHEN recurring transaction dieksekusi oleh Scheduler, THE Alert_Engine SHALL memperlakukan transaksi tersebut sama seperti transaksi manual untuk evaluasi threshold
6. WHEN transaksi bertipe expense dihapus atau di-update (perubahan amount atau kategori), THE Alert_Engine SHALL mengevaluasi ulang total spending terhadap semua threshold untuk kategori yang terpengaruh dan mereset threshold status sesuai Requirement 1.7

### Requirement 7: Data Model dan Persistence

**User Story:** Sebagai developer DuaSaku, saya ingin data model yang robust untuk smart budget alerts, sehingga alert history dan preferences tersimpan dengan benar.

#### Acceptance Criteria

1. THE Alert_Record SHALL menyimpan data di tabel Drift baru `BudgetAlerts` dengan kolom: id, userId, categoryId, alertType (threshold/prediction/over_budget), thresholdValue, actualPercentage, message, isRead, createdAt
2. THE Alert_Preference SHALL menyimpan data di tabel Drift baru `BudgetAlertPreferences` dengan kolom: id, userId, categoryId (nullable untuk global settings), isEnabled, thresholds (JSON encoded list of integers), predictionsEnabled, quietHoursStart (nullable), quietHoursEnd (nullable)
3. THE Alert_Engine SHALL menyimpan status threshold yang sudah di-trigger di tabel Drift baru `BudgetAlertThresholdStatus` dengan kolom: id, userId, categoryId, budgetMonth, thresholdValue, triggeredAt
4. WHEN tabel baru ditambahkan, THE Smart_Budget_Alerts SHALL menaikkan schemaVersion dan menambahkan migration step yang sesuai dengan guard `if (from < N)`
5. THE Smart_Budget_Alerts SHALL membuat index pada kolom userId dan createdAt di tabel BudgetAlerts untuk performa query
6. FOR ALL valid Alert_Record objects, serializing ke JSON kemudian deserializing kembali SHALL menghasilkan objek yang equivalent (round-trip property)
7. FOR ALL valid Alert_Preference objects, serializing ke JSON kemudian deserializing kembali SHALL menghasilkan objek yang equivalent (round-trip property)
