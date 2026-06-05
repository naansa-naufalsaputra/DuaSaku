# Product Requirement Document (PRD) - DuaSaku (Flutter Edition)

## 1. Pendahuluan & Visi Produk

DuaSaku adalah aplikasi manajemen keuangan pribadi pintar (Smart Personal Finance Assistant) berbasis mobile yang dirancang untuk membantu pengguna—khususnya mahasiswa dan profesional muda—mengelola arus kas (_cashflow_), melacak pengeluaran secara instan melalui AI, dan membangun kebiasaan finansial yang sehat melalui pendekatan gamifikasi.

Dengan beralih ke **Flutter**, DuaSaku bertujuan memberikan performa antarmuka yang sangat mulus (60/120 FPS), konsistensi visual 100% lintas platform (Android & iOS), serta pengalaman pengembangan yang lebih terstruktur menggunakan ekosistem Dart.

---

## 2. Profil Pengguna Tertarget (User Persona)

- **Karakteristik:** Mahasiswa atau _first-jobber_ (usia 18–25 tahun) yang memiliki mobilitas tinggi, aktif menggunakan smartphone, sering jajan/belanja di merchant lokal, namun sering lupa mencatat pengeluaran secara manual.
- **Pain Points:** \* Malas mengetik detail transaksi secara manual (nominal, kategori, catatan).
  - Sering kehilangan struk belanjaan fisik (minimarket/cafe).
  - Menginginkan saran keuangan yang praktis, santai, dan tidak menggurui.

---

## 3. Cakupan Fitur Utama (Core Features)

### F01: Smart Input Transaction Parsing (Teks & Audio)

- **Deskripsi:** Pengguna dapat mengetik satu kalimat acak (atau mengirim rekaman audio suara) untuk mencatat transaksi.
- **Alur Kerja:** Teks dikirim ke Supabase Edge Function `parse-transaction`, diproses oleh Gemini 1.5 Flash, dan dikembalikan ke aplikasi dalam format JSON bersih untuk langsung disimpan ke database.
- **Contoh Input:** _"Tadi malam makan benkatsu bareng temen habis 75 ribu pakai dompet jago"_ otomatis terekstrak menjadi: `{ "type": "expense", "amount": 75000, "category": "Food", "wallet": "Jago", "notes": "Makan benkatsu bareng temen" }`.

### F02: Hyper-Personalized Financial Insights & Advice

- **Deskripsi:** Tab khusus yang menganalisis 20 transaksi terbaru pengguna dan memberikan 3 saran keuangan santai khas anak muda berbasis profil finansial.
- **Kustomisasi:** AI membaca kolom `financial_goal` di database pengguna (misal: "mau beli laptop LOQ baru") sehingga saran finansial yang keluar menjadi sangat personal.
- **Performa:** Menggunakan mekanisme caching lokal selama 2 jam agar tidak terjadi pemborosan kuota API Gemini.

### F03: AI Receipt Scanner (Vision AI)

- **Deskripsi:** Pengguna dapat mengambil foto struk belanjaan fisik secara langsung melalui kamera smartphone.
- **Alur Kerja:** Gambar dikonversi menjadi format Base64, dikirim ke backend Edge Function `scan-receipt`, dianalisis oleh kapabilitas multimodal Gemini Vision, dan diekstrak menjadi draf transaksi siap simpan.

### F04: Otomatisasi Tagihan Berulang (_Recurring Transactions_)

- **Deskripsi:** Pencatatan otomatis untuk pengeluaran rutin berulang (seperti bayar kos, langganan Spotify, atau tagihan internet WiFi).
- **Mekanisme:** Berjalan secara backend menggunakan Supabase _pg_cron_ atau otomatisasi terjadwal tanpa membebani performa aplikasi klien.

### F05: Sistem Streak & Gamifikasi (`duasaku-gamification`)

- **Deskripsi:** Menjaga retensi pengguna agar rajin mencatat keuangan harian dengan memberikan indikator _streak_ (api menyala) dan draf _badge_ pencapaian tertentu jika berhasil mempertahankan kondisi _Safe-to-Spend_ tetap hijau.

---

## 4. Kebutuhan Non-Fungsional (Non-Functional Requirements)

1.  **Keamanan Data:** Seluruh API Key (Gemini & Supabase Service Role) tidak boleh ada di kode aplikasi Flutter. Akses ke Edge Function wajib menggunakan JWT (JSON Web Token) user yang sah.
2.  **Kecepatan Rendering:** UI wajib menggunakan rendering engine Flutter terbaru (Impeller) untuk memastikan transisi layar bebas dari _jank_ atau patah-patah.
3.  **Toleransi Jaringan (Offline Capability):** Aplikasi harus tetap bisa dibuka dan menampilkan data terakhir yang tersimpan di memori lokal (cache) meskipun koneksi internet terputus.
4.  **Batas Waktu (Timeout Handling):** Pemanggilan AI dibatasi maksimal 10 detik. Jika melebihi, sistem wajib mengembalikan kendali ke UI dengan pesan error yang elegan agar aplikasi tidak menggantung.
