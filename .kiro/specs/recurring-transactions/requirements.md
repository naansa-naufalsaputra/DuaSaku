# Requirements Document

## Introduction

Fitur Recurring Transactions memungkinkan pengguna DuaSaku untuk mengatur transaksi berulang (gaji bulanan, tagihan listrik, langganan streaming, dll.) yang secara otomatis dieksekusi sesuai jadwal. Fitur ini menggunakan infrastruktur workmanager yang sudah ada untuk scheduling di background, dan menyediakan UI yang indah dengan animasi interaktif untuk pengelolaan transaksi berulang.

## Glossary

- **Recurring_Transaction**: Template transaksi yang dijadwalkan untuk dieksekusi secara berulang pada interval tertentu (harian, mingguan, bulanan, tahunan)
- **Execution**: Proses pembuatan transaksi aktual dari template Recurring_Transaction pada waktu yang dijadwalkan
- **Execution_Log**: Catatan historis setiap kali Recurring_Transaction berhasil dieksekusi, termasuk timestamp dan status
- **Frequency**: Interval pengulangan transaksi (daily, weekly, monthly, yearly) dengan dukungan custom interval
- **Catch_Up_Logic**: Mekanisme untuk mengeksekusi transaksi yang terlewat karena device mati atau kondisi lain yang mencegah eksekusi tepat waktu
- **Scheduler**: Komponen background yang menggunakan workmanager untuk memeriksa dan mengeksekusi Recurring_Transaction yang jatuh tempo
- **Notification_Service**: Layanan flutter_local_notifications yang mengirim notifikasi terkait eksekusi transaksi berulang
- **Dashboard_Widget**: Komponen UI di halaman utama yang menampilkan ringkasan transaksi berulang mendatang
- **Deep_Link_Handler**: Komponen routing yang menangani navigasi via URI scheme `duasaku://recurring_transactions`

## Requirements

### Requirement 1: Pembuatan Recurring Transaction

**User Story:** Sebagai pengguna DuaSaku, saya ingin membuat transaksi berulang dengan detail lengkap, sehingga transaksi rutin saya otomatis tercatat tanpa input manual berulang.

#### Acceptance Criteria

1. WHEN pengguna mengisi form pembuatan recurring transaction dengan amount, category, wallet, type (income/expense), frequency, dan start date, THE Recurring_Transaction SHALL menyimpan template transaksi ke database lokal dan menjadwalkan eksekusi pertama sesuai start date
2. WHERE pengguna memilih custom interval (contoh: setiap 2 minggu, setiap 3 bulan), THE Recurring_Transaction SHALL menerima dan menyimpan nilai interval kustom dengan nilai minimum 1 dan maksimum 365 untuk daily, 52 untuk weekly, 12 untuk monthly, dan 10 untuk yearly
3. WHERE pengguna mengisi end date, THE Recurring_Transaction SHALL menghentikan eksekusi otomatis setelah end date tercapai
4. IF pengguna tidak mengisi end date, THEN THE Recurring_Transaction SHALL terus mengeksekusi tanpa batas waktu sampai dihentikan secara manual oleh pengguna
5. WHEN pengguna menekan tombol preview sebelum konfirmasi, THE Recurring_Transaction SHALL menampilkan daftar 5 tanggal eksekusi mendatang berdasarkan frequency dan start date yang dipilih
6. IF amount yang diisi bernilai kurang dari 0.01 atau lebih dari 999,999,999.99, THEN THE Recurring_Transaction SHALL menampilkan pesan error validasi dan mencegah penyimpanan
7. IF wallet yang dipilih tidak valid atau telah dihapus, THEN THE Recurring_Transaction SHALL menampilkan pesan error dan mencegah penyimpanan
8. IF category yang dipilih tidak valid atau telah dihapus, THEN THE Recurring_Transaction SHALL menampilkan pesan error validasi dan mencegah penyimpanan
9. IF start date yang dipilih adalah tanggal di masa lalu, THEN THE Recurring_Transaction SHALL menampilkan pesan error validasi dan mencegah penyimpanan

### Requirement 2: Scheduling dan Eksekusi Background

**User Story:** Sebagai pengguna DuaSaku, saya ingin transaksi berulang dieksekusi otomatis di background, sehingga catatan keuangan saya selalu up-to-date tanpa perlu membuka aplikasi.

#### Acceptance Criteria

1. WHEN waktu eksekusi terjadwal tiba, THE Scheduler SHALL membuat transaksi baru di tabel Transactions berdasarkan template Recurring_Transaction dan mencatat eksekusi di Execution_Log dengan status "success"
2. WHEN device tidak aktif pada waktu eksekusi terjadwal dan kemudian aktif kembali, THE Scheduler SHALL menjalankan Catch_Up_Logic untuk mengeksekusi semua transaksi yang terlewat secara berurutan (kronologis dari yang paling lama) dengan maksimum 90 eksekusi per recurring transaction per sesi catch-up
3. WHILE Recurring_Transaction dalam status paused, THE Scheduler SHALL melewatkan eksekusi terjadwal tanpa membuat transaksi baru, dan Catch_Up_Logic SHALL tidak mengeksekusi transaksi yang seharusnya terjadi selama periode paused
4. WHEN eksekusi berhasil, THE Scheduler SHALL memperbarui field next_execution_date pada Recurring_Transaction ke tanggal eksekusi berikutnya berdasarkan frequency dan custom interval yang dikonfigurasi
5. WHEN end date telah tercapai setelah eksekusi terakhir, THE Scheduler SHALL mengubah status Recurring_Transaction menjadi completed dan menghentikan penjadwalan
6. THE Scheduler SHALL menggunakan infrastruktur workmanager yang sudah ada dengan periodic task minimum 15 menit sesuai batasan Android WorkManager
7. IF eksekusi gagal karena error database, THEN THE Scheduler SHALL mencatat kegagalan di Execution_Log dengan status "failed" dan melakukan retry pada cycle berikutnya dengan maksimum 3 kali retry berturut-turut per recurring transaction sebelum mengubah status menjadi paused
8. IF eksekusi gagal karena error selain database (data tidak valid, wallet terhapus, atau kategori tidak ditemukan), THEN THE Scheduler SHALL mencatat kegagalan di Execution_Log dengan status "failed" dan mengubah status Recurring_Transaction menjadi paused tanpa retry

### Requirement 3: Manajemen UI Recurring Transactions

**User Story:** Sebagai pengguna DuaSaku, saya ingin mengelola transaksi berulang melalui antarmuka yang indah dan interaktif, sehingga saya dapat dengan mudah melihat, mengubah, dan mengontrol semua transaksi berulang saya.

#### Acceptance Criteria

1. THE Recurring_Transaction SHALL menampilkan daftar semua recurring transactions dalam layar khusus dengan staggered fade-in dan slide-up animation menggunakan flutter_animate
2. WHEN daftar recurring transactions kosong, THE Recurring_Transaction SHALL menampilkan empty state dengan animasi Lottie yang berisi pesan bahwa belum ada transaksi berulang dan tombol call-to-action untuk membuat transaksi berulang pertama
3. THE Recurring_Transaction SHALL menampilkan setiap item dengan informasi: tanggal eksekusi berikutnya, badge frequency, amount dengan warna hijau (colorScheme.primary variant) untuk income dan merah (colorScheme.error variant) untuk expense, serta indikator status berupa badge yang menunjukkan active, paused, atau completed
4. WHEN pengguna melakukan swipe ke kanan pada item, THE Recurring_Transaction SHALL menampilkan aksi pause (jika status active) atau resume (jika status paused) dengan animasi transisi berdurasi 200-300ms menggunakan easeOutCubic curve
5. WHEN pengguna melakukan swipe ke kiri pada item, THE Recurring_Transaction SHALL menampilkan aksi delete dengan konfirmasi dialog yang memuat pesan konfirmasi penghapusan
6. IF pengguna mengkonfirmasi penghapusan pada dialog delete, THEN THE Recurring_Transaction SHALL menghapus item dari daftar dengan fade-out animation dan menampilkan snackbar konfirmasi penghapusan
7. IF pengguna membatalkan penghapusan pada dialog delete, THEN THE Recurring_Transaction SHALL menutup dialog dan mengembalikan item ke posisi semula tanpa perubahan
8. WHEN pengguna menekan tombol tambah, THE Recurring_Transaction SHALL menampilkan bottom sheet dengan flow step-by-step untuk pembuatan recurring transaction baru
9. THE Recurring_Transaction SHALL menampilkan animated progress ring pada setiap item yang menunjukkan proporsi hari tersisa terhadap total interval (ring penuh = awal interval, ring kosong = hari eksekusi), dan menampilkan label jumlah hari tersisa di tengah ring
10. WHEN pengguna menekan toggle pause/resume, THE Recurring_Transaction SHALL memberikan haptic feedback (light impact) dan mengubah status dengan animasi transisi berdurasi 200-300ms
11. WHILE data sedang dimuat dari database, THE Recurring_Transaction SHALL menampilkan shimmer loading state sebagai placeholder yang menyerupai layout final daftar item
12. WHEN pengguna menekan item recurring transaction, THE Recurring_Transaction SHALL membuka detail view dengan hero transition yang menampilkan visual timeline berisi maksimal 5 eksekusi sebelumnya dan 5 eksekusi mendatang

### Requirement 4: Notifikasi Recurring Transaction

**User Story:** Sebagai pengguna DuaSaku, saya ingin menerima notifikasi terkait transaksi berulang, sehingga saya selalu aware tentang eksekusi yang akan datang dan hasilnya.

#### Acceptance Criteria

1. WHERE pengguna mengaktifkan notifikasi reminder, THE Notification_Service SHALL mengirim notifikasi pada waktu yang dikonfigurasi (1 hari sebelum pada pukul 09:00 waktu lokal, atau hari yang sama pada pukul 08:00 waktu lokal) sebelum eksekusi terjadwal, berisi nama transaksi dan tanggal eksekusi
2. WHEN eksekusi recurring transaction berhasil, THE Notification_Service SHALL mengirim notifikasi konfirmasi yang berisi nama transaksi, amount, dan wallet tujuan dalam waktu maksimal 5 detik setelah eksekusi selesai
3. IF eksekusi gagal, THEN THE Notification_Service SHALL mengirim notifikasi kegagalan yang berisi nama transaksi dan kategori error yang terjadi (database error, wallet tidak valid, atau kategori tidak ditemukan)
4. THE Notification_Service SHALL menggunakan flutter_local_notifications untuk semua notifikasi recurring transaction
5. WHEN pengguna menekan notifikasi recurring transaction, THE Notification_Service SHALL membuka layar detail recurring transaction terkait menggunakan Deep_Link_Handler
6. IF pengguna menekan notifikasi recurring transaction yang terkait dengan recurring transaction yang sudah dihapus, THEN THE Notification_Service SHALL membuka layar daftar recurring transactions dan menampilkan pesan bahwa transaksi tidak lagi tersedia

### Requirement 5: Integrasi dengan Fitur Existing

**User Story:** Sebagai pengguna DuaSaku, saya ingin transaksi berulang terintegrasi dengan fitur-fitur yang sudah ada, sehingga data keuangan saya konsisten dan terhubung di seluruh aplikasi.

#### Acceptance Criteria

1. WHEN Scheduler mengeksekusi recurring transaction, THE Recurring_Transaction SHALL membuat entry di tabel Transactions dengan field badge bertuliskan "recurring" yang ditampilkan sebagai label pada item transaksi di layar riwayat transaksi
2. THE Dashboard_Widget SHALL menampilkan maksimal 5 recurring transactions terdekat yang akan dieksekusi dalam 7 hari ke depan di halaman utama, diurutkan berdasarkan tanggal eksekusi terdekat (ascending), dengan menampilkan nama transaksi, amount, dan tanggal eksekusi terjadwal per item
3. IF tidak ada recurring transaction yang terjadwal dalam 7 hari ke depan, THEN THE Dashboard_Widget SHALL menyembunyikan section recurring transactions dari halaman utama
4. WHEN recurring transaction bertipe expense dieksekusi, THE Recurring_Transaction SHALL menambahkan amount tersebut ke total pengeluaran aktual pada budget tracking untuk kategori dan bulan yang sesuai dengan tanggal eksekusi
5. IF recurring transaction bertipe expense dieksekusi dan tidak ada budget yang dikonfigurasi untuk kategori tersebut pada bulan berjalan, THEN THE Recurring_Transaction SHALL tetap membuat transaksi tanpa mempengaruhi budget tracking
6. WHEN pengguna mengakses deep link `duasaku://recurring_transactions`, THE Deep_Link_Handler SHALL membuka layar daftar recurring transactions
7. WHEN pengguna menghapus recurring transaction, THE Recurring_Transaction SHALL mempertahankan semua transaksi historis yang sudah dieksekusi sebelumnya di tabel Transactions tanpa perubahan pada field manapun

### Requirement 6: UI/UX Excellence dengan Animasi

**User Story:** Sebagai pengguna DuaSaku, saya ingin pengalaman visual yang premium dan responsif saat mengelola transaksi berulang, sehingga interaksi terasa menyenangkan dan modern.

#### Acceptance Criteria

1. THE Recurring_Transaction SHALL menggunakan flutter_animate untuk stagger animation pada list items dengan delay 50ms antar item dan efek fadeIn + slideY
2. THE Recurring_Transaction SHALL menampilkan animasi Lottie untuk empty state dan konfirmasi sukses pembuatan recurring transaction baru
3. WHEN pengguna berpindah dari list ke detail view, THE Recurring_Transaction SHALL menggunakan hero transition yang smooth pada card element
4. THE Recurring_Transaction SHALL menampilkan animated frequency selector menggunakan custom wheel/carousel picker saat pembuatan recurring transaction
5. WHEN pengguna melakukan tap pada toggle atau action button, THE Recurring_Transaction SHALL memberikan haptic feedback (light impact)
6. THE Recurring_Transaction SHALL menampilkan card dengan color coding: hijau (colorScheme.primary variant) untuk income dan merah (colorScheme.error variant) untuk expense
7. THE Recurring_Transaction SHALL menampilkan micro-interaction berupa scale bounce effect pada setiap tap di item card
8. WHILE navigasi ke layar recurring transactions, THE Recurring_Transaction SHALL menampilkan shimmer loading placeholder yang sesuai dengan layout final

### Requirement 7: Data Model dan Persistence

**User Story:** Sebagai developer DuaSaku, saya ingin data model yang robust untuk recurring transactions, sehingga data tersimpan dengan benar dan mendukung semua fitur scheduling.

#### Acceptance Criteria

1. THE Recurring_Transaction SHALL menyimpan data di tabel Drift baru `RecurringTransactions` dengan kolom: id, userId, walletId, categoryId, amount, type, frequency, customInterval, startDate, endDate, nextExecutionDate, status, notes, dan createdAt
2. THE Execution_Log SHALL menyimpan data di tabel Drift baru `RecurringExecutionLogs` dengan kolom: id, recurringTransactionId (foreign key), executedAt, status, dan transactionId (foreign key ke Transactions)
3. WHEN tabel baru ditambahkan, THE Recurring_Transaction SHALL menaikkan schemaVersion dari 4 ke 5 dan menambahkan migration step dengan guard `if (from < 5)`
4. THE Recurring_Transaction SHALL membuat index pada kolom userId dan nextExecutionDate di tabel RecurringTransactions untuk performa query
5. THE Recurring_Transaction SHALL menggunakan foreign key reference ke tabel Wallets dan Categories yang sudah ada

### Requirement 8: Correctness dan Reliability

**User Story:** Sebagai pengguna DuaSaku, saya ingin transaksi berulang bekerja dengan benar dan reliable, sehingga tidak ada transaksi duplikat, terlewat, atau data yang inkonsisten.

#### Acceptance Criteria

1. THE Scheduler SHALL mengeksekusi setiap recurring transaction tepat satu kali per interval terjadwal tanpa duplikasi
2. WHILE Recurring_Transaction dalam status paused, THE Scheduler SHALL memastikan tidak ada eksekusi yang terjadi
3. WHEN pengguna menghapus recurring transaction, THE Recurring_Transaction SHALL mempertahankan semua transaksi historis di tabel Transactions tanpa perubahan
4. WHEN eksekusi berhasil, THE Recurring_Transaction SHALL memastikan next_execution_date selalu berada di masa depan relatif terhadap last_execution_date
5. IF dua cycle Scheduler berjalan bersamaan, THEN THE Scheduler SHALL menggunakan mekanisme locking untuk mencegah eksekusi duplikat pada recurring transaction yang sama
6. FOR ALL valid Recurring_Transaction objects, parsing frequency dan custom interval kemudian menghitung next execution date kemudian parsing kembali SHALL menghasilkan objek yang equivalent (round-trip property)

### Requirement 9: Edit dan Update Recurring Transaction

**User Story:** Sebagai pengguna DuaSaku, saya ingin mengubah detail transaksi berulang yang sudah ada, sehingga saya dapat menyesuaikan jika ada perubahan nominal atau jadwal.

#### Acceptance Criteria

1. WHEN pengguna membuka form edit recurring transaction, THE Recurring_Transaction SHALL menampilkan semua field yang sudah terisi dengan nilai saat ini
2. WHEN pengguna mengubah amount atau detail lain dan menyimpan, THE Recurring_Transaction SHALL memperbarui template tanpa mempengaruhi transaksi historis yang sudah dieksekusi
3. WHEN pengguna mengubah frequency atau start date, THE Recurring_Transaction SHALL menghitung ulang next_execution_date berdasarkan parameter baru
4. IF pengguna mengubah end date menjadi tanggal yang sudah lewat, THEN THE Recurring_Transaction SHALL mengubah status menjadi completed dan menghentikan penjadwalan
