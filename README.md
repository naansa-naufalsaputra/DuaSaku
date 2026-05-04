# 🌸 DuaSaku — Your Smart Financial Companion

[![Expo](https://img.shields.io/badge/Expo-SDK%2052-000020?style=for-the-badge&logo=expo&logoColor=white)](https://expo.dev/)
[![React Native](https://img.shields.io/badge/React_Native-0.76-61DAFB?style=for-the-badge&logo=react&logoColor=black)](https://reactnative.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com/)
[![Gemini](https://img.shields.io/badge/Google_Gemini-AI-4285F4?style=for-the-badge&logo=googlegemini&logoColor=white)](https://deepmind.google/technologies/gemini/)

**DuaSaku** adalah aplikasi manajemen keuangan cerdas berbasis **AI (Artificial Intelligence)** yang dirancang untuk membantu Anda melacak transaksi, mengelola anggaran, dan mendapatkan wawasan keuangan secara otomatis dan intuitif.

---

## ✨ Fitur Utama

- 🧠 **AI Financial Advisor**: Konsultasi keuangan real-time menggunakan Google Gemini 1.5.
- 🎙️ **Voice & Smart Input**: Catat transaksi hanya dengan suara atau teks natural (Natural Language Processing).
- 📊 **Interactive Insights**: Dashboard analitik premium dengan grafik interaktif untuk memantau pengeluaran.
- 📱 **Background Notification Sync**: Sinkronisasi otomatis dari notifikasi bank/e-wallet (BCA, Livin, GoPay, dll).
- 🔐 **Biometric Security**: Perlindungan akses aplikasi dengan Fingerprint atau FaceID.
- 🌐 **Offline First**: Tetap berfungsi tanpa internet dengan sinkronisasi otomatis saat kembali online (MMKV Storage).
- 🏆 **Gamification**: Skor kesehatan keuangan dan badges untuk memotivasi kebiasaan menabung.

---

## 🛠️ Tech Stack

- **Framework**: [Expo SDK 52](https://expo.dev/) & React Native.
- **Styling**: [NativeWind v4](https://www.nativewind.dev/) (Tailwind CSS for React Native).
- **Backend**: [Supabase](https://supabase.com/) (Authentication, PostgreSQL, Realtime).
- **Intelligence**: Google Gemini 1.5 API & Local Regex Parsing.
- **Persistence**: [MMKV](https://github.com/mrousavy/react-native-mmkv) (High-performance key-value storage).
- **Animations**: Lottie & React Native Reanimated.

---

## 🚀 Memulai (Setup Lokal)

### Prasyarat
- Node.js v20+
- Expo Go (untuk testing di HP) atau Android Studio Emulator.
- Akun Supabase & Google AI Studio (API Key).

### Instalasi
1. Clone repository:
   ```bash
   git clone https://github.com/naansa-naufalsaputra/DuaSaku.git
   cd DuaSaku
   ```
2. Instal dependencies:
   ```bash
   npm install
   ```
3. Setup Environment Variables:
   Buat file `.env` di root folder dan isi dengan kredensial Anda:
   ```env
   EXPO_PUBLIC_SUPABASE_URL=your_supabase_url
   EXPO_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
   EXPO_PUBLIC_GEMINI_API_KEY=your_gemini_api_key
   ```
4. Jalankan aplikasi:
   ```bash
   npm run start
   ```

---

## 📦 Build & Deployment

Aplikasi ini mendukung build mandiri (Self-hosted CI/CD) tanpa antrean server EAS:
- Gunakan GitHub Actions **"Build Android APK (Fast)"** untuk menghasilkan file APK secara instan di tab Actions repository Anda.

---

## 📝 Lisensi
Aplikasi ini dikembangkan oleh **Naufal Saputra**. Seluruh hak cipta dilindungi.

---
*Dibuat dengan ❤️ untuk masa depan finansial yang lebih baik.*
