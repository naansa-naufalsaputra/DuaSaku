# Design: Parallax Mesh Gradients

## 1. Arsitektur Komponen
Kita akan meningkatkan rancangan `PremiumBackground` yang ada saat ini di [premium_background.dart](file:///c:/Codingg/duasaku_app/lib/core/theme/premium_background.dart).

```
[Screen Root]
   └── [RepaintBoundary]
          └── [PremiumBackground (ConsumerStatefulWidget)]
                 ├── Base Background Color (AnimatedContainer)
                 ├── Blob 1 (Positioned + AnimatedContainer) [Sensitivitas: 1.0]
                 ├── Blob 2 (Positioned + AnimatedContainer) [Sensitivitas: -1.5]
                 ├── Blob 3 (Positioned + AnimatedContainer) [Sensitivitas: 0.7] (Tambahan Baru)
                 └── BackdropFilter (ImageFilter.blur)
```

## 2. Aliran Data Sensor (Sensor Data Pipeline)
1. **Sensors Listener**: `sensors_plus` memancarkan event `AccelerometerEvent` secara berkala.
2. **Low-Pass Filter**: Untuk mencegah getaran (*jitter*) sensor, kita akan menerapkan rumus *low-pass filter* sederhana:
   $$\text{smoothedValue} = \text{smoothedValue} \times (1 - \alpha) + \text{newValue} \times \alpha$$
   (dengan $\alpha \approx 0.1$ untuk pergerakan yang sangat halus).
3. **Offset Calculation**:
   - `offset1 = Offset(accelX * 15, accelY * 15)`
   - `offset2 = Offset(accelX * -25, accelY * -25)`
   - `offset3 = Offset(accelX * 8, accelY * -12)`
4. **State Update**: Nilai offset ini akan diperbarui dalam state widget lokal (`setState`) atau dikontrol langsung menggunakan `ValueNotifier` untuk meminimalkan beban rebuild.

## 3. Rencana Integrasi State Management
- Latar belakang ini bersikap mandiri (*self-contained*) di tingkat UI, sehingga tidak memerlukan Riverpod state global untuk koordinat sensornya.
- Dependensi status tema global tetap di-watch menggunakan `themeNotifierProvider` untuk menyesuaikan warna dasar dan warna blob gradien secara dinamis.
