# 📚 Panduan Lengkap: Build & E2E Testing DuaSaku

Dokumen ini berisi panduan langkah-demi-langkah untuk membangun (build) aplikasi DuaSaku menjadi APK dan menjalankan pengujian otomatis menggunakan Maestro.

---

## 🛠️ I. Persiapan Perangkat & Akun
Sebelum memulai, pastikan hal-hal berikut sudah siap:
1.  **HP Android**: Aktifkan *Developer Options* dan *USB Debugging*.
2.  **Kabel Data**: Sambungkan HP ke komputer.
3.  **ADB (Android Debug Bridge)**: Pastikan terinstal. Cek dengan:
    ```bash
    adb devices
    ```
4.  **Akun Expo**: Pastikan Anda sudah login ke Expo CLI (`npx expo login`).

---

## 📦 II. Membangun (Build) APK

### 1. Build via EAS Cloud (Rekomendasi)
Gunakan ini jika Anda ingin Expo yang mengerjakan proses kompilasi di server mereka. Hasilnya adalah link download APK.
*   **Perintah:**
    ```bash
    eas build -p android --profile preview
    ```
*   **Proses:** Tunggu hingga selesai, lalu scan QR Code yang muncul atau klik link download untuk mendapatkan file APK.
*   **Keuntungan:** Tidak membebani RAM komputer Anda dan tidak butuh setup Android Studio yang rumit.

### 2. Build Lokal (Development)
Gunakan ini untuk pengembangan cepat langsung ke HP yang tersambung.
*   **Perintah:**
    ```bash
    npx expo run:android
    ```
*   **Catatan:** Memerlukan Android SDK dan Java terinstal di komputer Anda.

---

## 🦅 III. Setup & Menjalankan Maestro (E2E)

### 1. Instalasi Maestro CLI
Jika belum terinstal, jalankan perintah ini di **Git Bash**:
```bash
curl -fsSL "https://get.maestro.mobile.dev" | bash
```
*Tutup dan buka kembali terminal setelah instalasi.*

### 2. Menyiapkan Data Uji (Seeding)
Sebelum menjalankan tes, kita harus memastikan database memiliki data yang bersih dan seragam.
*   **Perintah:**
    ```bash
    node e2e/scripts/seed_db.js
    ```
*   **Fungsi:** Script ini akan menghapus data lama dan memasukkan data dummy (Gaji & Sewa) untuk user `test@duasaku.com`.

### 3. Menjalankan Pengujian Otomatis
Setelah aplikasi terinstal di HP dan database sudah di-seed, jalankan tesnya:

*   **Menjalankan SEMUA tes sekaligus:**
    ```bash
    maestro test e2e/
    ```
*   **Menjalankan satu fitur spesifik (misal: Tambah Transaksi):**
    ```bash
    maestro test e2e/add_transaction.yaml
    ```
*   **Menjalankan Full Audit (Urutan Terstruktur):**
    ```bash
    maestro test e2e/full_audit.yaml
    ```

---

## 🎨 IV. Maestro Studio & Cloud

### 1. Maestro Studio (Debugging Visual)
Jika tes Anda gagal dan ingin tahu penyebabnya secara visual:
1.  Jalankan: `maestro studio`
2.  Buka `http://localhost:9999` di browser.
3.  Klik elemen di layar HP (yang tampil di browser) untuk melihat ID atau membuat perintah baru secara otomatis.

### 2. Maestro Cloud (Free Tier)
Gunakan ini untuk mencoba aplikasi di berbagai jenis HP di server Maestro.
1.  Dapatkan API Key dari [console.mobile.dev](https://console.mobile.dev).
2.  Upload APK Anda:
    ```bash
    maestro cloud --apiKey <KUNCI_ANDA> <NAMA_FILE.apk> e2e/
    ```

---

## ❓ V. Troubleshooting (Masalah Umum)

*   **Error: `maestro: command not found`**
    *   Solusi: Tambahkan path secara manual atau buka terminal baru. Jalankan `export PATH="$PATH":"$HOME/.maestro/bin"` di Git Bash.
*   **Error: `RLS Policy Violation` saat seeding**
    *   Solusi: Pastikan `EXPO_PUBLIC_SUPABASE_SERVICE_ROLE_KEY` ada di file `.env`.
*   **Error: `Install dependencies build phase` gagal di EAS**
    *   Solusi: Saya sudah menambahkan `NPM_CONFIG_LEGACY_PEER_DEPS: "true"` di file `eas.json`. Coba build ulang.

---
💡 **Tips**: Selalu jalankan `node e2e/scripts/seed_db.js` sebelum memulai sesi testing agar hasil pengujian Anda selalu konsisten dan dapat dipercaya.
