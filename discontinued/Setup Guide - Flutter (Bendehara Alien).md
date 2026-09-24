---
type: setup-guide
platform: android
tool: flutter
status: draft
created: 2026-08-08
updated: 2026-08-08
tags:
  - setup
  - template
---

# Setup Guide - Flutter (Bendehara Alien)

## Purpose
Menyiapkan environment development Bendehara Alien (Flutter + Dart + SQLite) di Windows, lalu menjalankan di HP Android (USB saat develop, APK saat rilis).

## Prerequisites
- Windows 10/11 64-bit.
- Disk kosong ~3-4 GB (Flutter SDK + Android toolchain).
- HP Android + kabel USB data (untuk develop & tes).
- (Opsional) Akun Google untuk install APK langsung, atau kirim file APK via WhatsApp/file manager.

## Install / Setup Steps

```powershell
# 1. Install Flutter SDK
#    Download stable Windows zip dari https://docs.flutter.dev/get-started/install/windows
#    Extract ke: D:\tools\flutter   (jangan di Program Files - butuh izin admin)

# 2. Tambahkan Flutter ke PATH (System Environment Variables)
#    PATH += D:\tools\flutter\bin
#    Buka terminal BARU setelahnya

# 3. Install Android toolchain (pilih salah satu):
#    A) Android Studio (paling mudah, resmi) -> https://developer.android.com/studio
#       Install lalu: File > Settings > Languages & Frameworks > Android SDK
#       (centang: Android SDK Platform 34+, Android SDK Build-Tools, Android SDK Platform-Tools)
#    B) Ringan (tanpa IDE, CLI only):
#       Install JDK 17+ + Android cmdline-tools, lalu:
#       sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# 4. Cek kesehatan environment
flutter doctor
flutter doctor --android-licenses   # terima semua lisensi (ketik y)

# 5. Buat project
cd "D:\project\bendehara alien"
flutter create bendehara_app --org com.bendehara --project-name bendehara_app
cd bendehara_app

# 6. Tambah dependensi inti
flutter pub add sqflite path_provider provider intl

# 7. Siapkan HP: Settings > Developer options > USB debugging ON
#    (Aktifkan Developer options: Settings > About > ketuk "Build number" 7x)

# 8. Jalankan di HP (kabel USB terhubung)
flutter devices          # pastikan HP terdeteksi
flutter run              # hot reload: tekan r / hot restart: tekan R
```

## Verification

```powershell
flutter doctor                # semua checklist hijau (kecuali yang memang tidak dipakai)
flutter devices               # HP Android muncul
flutter test                  # unit test hijau (setelah test ditulis)
flutter build apk --release   # APK: build\app\outputs\flutter-apk\app-release.apk
```

## Troubleshooting
- **HP tidak terdeteksi:** pastikan USB debugging ON, kabel data (bukan charge-only), coba port lain; di HP pilih "Izinkan debugging" saat prompt.
- **flutter doctor error Android licenses:** jalankan `flutter doctor --android-licenses` lalu `y`.
- **Gradle download lambat / gagal:** cek koneksi; ulangi `flutter build` (Gradle resume download).
- **Hot reload tidak merespons:** tekan R (hot restart) atau `q` lalu `flutter run` lagi.
- **APK tidak bisa install di HP:** izinkan "Install unknown apps" untuk file manager/WhatsApp di pengaturan HP.

## Related Notes
- [[Docs/TRD - Bendehara Alien]]
- [[Docs/Implementation Plan - Bendehara Alien]]
- [[../Project - Bendehara Alien]]
