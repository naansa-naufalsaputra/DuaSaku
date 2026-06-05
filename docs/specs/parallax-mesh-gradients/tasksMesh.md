# Tasks: Parallax Mesh Gradients

## Daftar Checklist Pengerjaan

- [ ] **Task 2.1**: Tambah dependensi `sensors_plus` ke `pubspec.yaml`
  - *Skill*: `mobile-design`, `clean-code`
  - *Kriteria Verifikasi*: Jalankan `flutter pub get` berhasil terpasang tanpa konflik versi SDK.
- [ ] **Task 2.2**: Konversi `PremiumBackground` menjadi `ConsumerStatefulWidget`
  - *Skill*: `mobile-design`
  - *Kriteria Verifikasi*: Kode ter-compile dengan benar tanpa mengubah tampilan saat ini.
- [ ] **Task 2.3**: Integrasi aliran data sensor akselerometer dengan Low-Pass Filter
  - *Skill*: `mobile-design`, `clean-code`
  - *Kriteria Verifikasi*: Data sensor ter-log dengan halus di console debug Android tanpa penumpukan data (*memory leak*).
- [ ] **Task 2.4**: Tambahkan blob ketiga dan terapkan rumus posisi paralaks
  - *Skill*: `mobile-design`
  - *Kriteria Verifikasi*: Blob bergerak mengikuti kemiringan HP/emulator Android dengan kecepatan dan arah yang berbeda.
- [ ] **Task 2.5**: Pasang mekanisme fallback jika sensor tidak tersedia
  - *Skill*: `mobile-design`
  - *Kriteria Verifikasi*: Aplikasi tidak crash di emulator yang tidak memiliki sensor akselerometer aktif (blobs tetap mengambang lambat menggunakan fallback animasi biasa).
