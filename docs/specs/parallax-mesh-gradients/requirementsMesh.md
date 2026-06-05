# Requirements: Parallax Mesh Gradients

## 1. Pendahuluan
Aplikasi DuaSaku bertema futuristik gelap (*Darkmatter*) membutuhkan latar belakang dinamis yang premium. Fitur ini menggantikan latar belakang lingkaran static blur saat ini dengan Parallax Mesh Gradients yang mengambang lembut dan bergeser secara paralaks berdasarkan kemiringan sensor akselerometer perangkat Android.

## 2. Persyaratan Fungsional (Functional Requirements)
- **FR-1**: Latar belakang harus merender minimal 3-4 blob gradien berwarna cerah/neon yang menyebar lembut (Cyber Blue, Emerald Green, Crimson Red, Amber Gold).
- **FR-2**: Blob gradien harus bergerak secara asinkron secara terus-menerus (floating animation) dengan kecepatan lambat.
- **FR-3**: Posisi blob gradien harus bergeser sesuai dengan kemiringan HP Android yang dideteksi oleh sensor akselerometer.
- **FR-4**: Tiap blob gradien harus memiliki sensitivitas/koefisien pergeseran yang berbeda (efek kedalaman paralaks).
- **FR-5**: Fitur harus memiliki fallback otomatis ke animasi mengambang biasa jika sensor akselerometer tidak didukung oleh perangkat atau izin sensor ditolak oleh pengguna.

## 3. Batasan Teknis (Technical Constraints)
- **TC-1**: Rendering tidak boleh menurunkan FPS aplikasi di bawah 60 FPS pada perangkat Android spesifikasi rendah (low-end).
- **TC-2**: Wajib menggunakan `RepaintBoundary` untuk membungkus background agar tidak memicu build ulang visual halaman utama saat gradien bergerak.
- **TC-3**: Harus mematuhi setelan aksesibilitas perangkat (misal: mematikan animasi jika pengguna mengaktifkan mode *Reduce Motion*).

## 4. Kriteria Penerimaan (Acceptance Criteria)
- Blob gradien bergeser perlahan saat HP dimiringkan.
- Transisi rendering gradien berjalan sangat mulus tanpa patah-patah.
- Tidak ada memory leak yang ditimbulkan oleh aliran data sensor akselerometer (stream listener dibatalkan dengan benar saat widget di-dispose).
