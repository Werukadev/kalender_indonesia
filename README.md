# Kalender Indonesia

Aplikasi kalender Indonesia berbasis Flutter yang menampilkan hari libur nasional, cuti bersama, hari besar nasional, dan hari besar internasional secara lengkap dan real-time.

---

## Fitur

- Kalender bulanan interaktif dengan navigasi geser (swipe)
- Data hari libur dari API `cal.weruka.dev`
- **Dukungan offline** — data otomatis tersimpan di cache dan tetap bisa dibuka tanpa koneksi
- Filter jenis hari: Libur Nasional, Cuti Bersama, Hari Besar Nasional, Hari Besar Internasional
- 8 pilihan tema warna (Classic Brown, Sage Green, Olive Green, dst.)
- Mode gelap / terang / sistem
- Pengaturan ukuran teks dan ketebalan huruf
- Tampilan responsif untuk Android, iOS, dan Web

---

## Spesifikasi

| Komponen | Versi |
|---|---|
| Flutter | 3.41.6 (stable) |
| Dart | 3.11.4 |
| Android min SDK | 21 (Android 5.0) |
| iOS min | 12.0 |

### Dependensi utama

| Package | Versi | Fungsi |
|---|---|---|
| `provider` | ^6.1.2 | State management |
| `shared_preferences` | ^2.3.3 | Penyimpanan pengaturan & cache offline |
| `http` | ^1.2.0 | Fetch data dari API |
| `intl` | ^0.19.0 | Format tanggal bahasa Indonesia |
| `package_info_plus` | ^8.0.0 | Baca versi aplikasi |
| `url_launcher` | ^6.3.0 | Buka URL di browser |

---

## Prasyarat

Pastikan sudah terinstal:

- [Flutter SDK 3.x](https://docs.flutter.dev/get-started/install) (minimal 3.10)
- [Git](https://git-scm.com/downloads)
- [Visual Studio Code](https://code.visualstudio.com/) dengan ekstensi:
  - **Flutter** (dart-code.flutter)
  - **Dart** (dart-code.dart-code)

Untuk build Android tambahan:
- Android Studio / Android SDK (API 21+)
- Java 17

---

## Clone & Jalankan

### 1. Clone repositori

```bash
git clone https://github.com/Werukadev/kalender_indonesia.git
cd kalender_indonesia
```

### 2. Install dependensi

```bash
flutter pub get
```

### 3. Buka di VS Code

```bash
code .
```

Atau buka VS Code → **File → Open Folder** → pilih folder `kalender_indonesia`.

### 4. Jalankan aplikasi

**Via VS Code:**

1. Buka file `lib/main.dart`
2. Pilih device target di status bar bawah (emulator, simulator, atau perangkat fisik)
3. Tekan **F5** atau klik **Run → Start Debugging**

**Via terminal:**

```bash
# Lihat daftar device yang tersedia
flutter devices

# Jalankan di device tertentu
flutter run -d <device-id>

# Contoh: jalankan di Chrome (web)
flutter run -d chrome

# Contoh: jalankan di emulator Android
flutter run -d emulator-5554
```

---

## Build Rilis

```bash
# Android APK
flutter build apk --release

# Android App Bundle (untuk Play Store)
flutter build appbundle --release

# iOS (perlu Mac + Xcode)
flutter build ios --release

# Web
flutter build web --release
```

---

## Struktur Proyek

```
lib/
├── data/
│   └── theme_presets.dart       # Daftar 8 preset tema warna
├── models/
│   ├── holiday.dart             # Model data hari libur
│   └── theme_preset.dart        # Model preset tema
├── providers/
│   └── settings_provider.dart   # State pengaturan (tema, teks, filter)
├── screens/
│   ├── home_screen.dart         # Halaman utama kalender
│   └── settings_screen.dart     # Halaman pengaturan
├── services/
│   └── api_service.dart         # Fetch API + cache offline
├── widgets/
│   ├── about_app_dialog.dart    # Dialog About
│   ├── event_list.dart          # Daftar event hari terpilih
│   └── month_calendar.dart      # Grid kalender bulanan
└── main.dart
```

---

## Sumber Data API

Data hari libur diambil dari:

```
https://cal.weruka.dev/api/holidays?year={year}&month={month}
```

---

## Lisensi

&copy; 2024 [weruka.dev](https://www.weruka.dev). All rights reserved.
