---
type: trd
project: Bendehara Alien
status: draft
created: 2026-08-08
updated: 2026-08-08
tags:
  - trd
  - technical
  - planning
---

# TRD - Bendehara Alien

## Technical Overview
Aplikasi mobile **local-first**: semua data di SQLite di perangkat, tanpa server, tanpa login. Satu pengguna (bendahara kelas). Prioritas utama: **ringan** (jalan mulus di HP kelas menengah), **mudah maintenance** (kode sederhana, sedikit dependensi), dan presisi data (tanggal & rupiah integer).

## Architecture
- **Lapisan:** UI (widgets/screens) -> State (Provider) -> Repository -> SQLite (sqflite). Satu arah, tanpa arsitektur berat.
- **Navigation:** Navigator sederhana: 4 tab (bottom nav) + halaman detail. Tanpa deep linking di MVP.
- **Offline-first:** tidak ada request jaringan sama sekali di MVP. Internet tidak diperlukan.
- **Prinsip maintenance:**
  - Sedikit dependensi -> setiap package baru harus dibenarkan (inti: sqflite, provider, intl, path_provider).
  - Logika bisnis (rekap, tunggakan) dipisah ke fungsi murni (pure Dart) yang mudah di-unit-test.
  - Konvensi penamaan & struktur folder sederhana dan konsisten (1 folder per fitur).
  - Skema DB versi eksplisit (sqflite `version` + `onUpgrade`) -> migrasi bertahap.

## Tech Stack
- Frontend: **Flutter (Dart)** - Android first; iOS dimungkinkan nanti (kode sama).
- Backend: tidak ada (lokal)
- Database: **sqflite** (SQLite)
- State management: **Provider** (ringan, resmi dari tim Flutter)
- Hosting: tidak ada (APK diinstall langsung)
- Tools: Flutter SDK 3.x + Android SDK (Android Studio atau cmdline-tools) + JDK 17; Git

## System Components
- **Screens (Flutter):** DashboardHariIni, DaftarSiswa, ProfilSiswa, Riwayat, DetailHari, Pengaturan, FormSiswa.
- **Providers/Controllers:** StudentController, KasPeriodController, PaymentController, SettingController.
- **Repositories:** StudentRepo, KasPeriodRepo, PaymentRepo, SettingRepo (berbasis sqflite).
- **Domain logic (fungsi murni Dart):** hitungRingkasanHari, hitungRekapBulan, hitungTunggakan, validasiTanggal, formatRupiah.
- **Storage:** SQLite db `bendehara.db` (path: path_provider -> getDatabasesPath).

## API / Integration Notes
- Tidak ada integrasi eksternal di MVP.
- Fase 2 (opsional): export/import JSON via share (share_plus) untuk backup.

## Data Model Summary
4 tabel: `Student`, `KasPeriod`, `Payment`, `AppSetting`. Detail di Backend Schema. Titik penting:
- Rupiah = INTEGER (anti float error).
- Tanggal = TEXT 'YYYY-MM-DD' lokal, UNIQUE per periode.
- Soft-delete siswa.

## Security Considerations
- Authentication: tidak ada (aplikasi lokal single-user).
- Authorization: tidak ada (perangkat pemilik).
- Secrets: tidak ada API key / token di MVP.
- Data privacy: data hanya di perangkat; tidak dikirim ke mana pun. Fase backup: user memilih sendiri file export-nya.

## Performance Considerations
- **Ringan:** target cold start < 2 detik di HP kelas menengah (release build).
- Ukuran APK kecil: hindari package berat (charts, animasi, font custom, image processing). Flutter release APK dasar ~15-20 MB - wajar.
- Daftar siswa 20-50 baris -> ListView.builder (lazy) + `const` constructors, hindari rebuild berlebih.
- Query di-index (Payment.period_id, Payment.student_id, KasPeriod.date).
- Tanpa jaringan = tanpa latensi.
- Rekap bulanan dihitung on-the-fly (data kecil) - tidak perlu precompute.
- Mode release (bukan debug) saat dipakai nyata.

## Testing Strategy
- Unit test (flutter test) untuk fungsi murni: rekap, tunggakan, validasi tanggal, format rupiah.
- Uji migrasi DB (v1 -> v2) di test (sqflite_common_ffi untuk test di PC).
- Manual test di perangkat: skenario Happy Path, edge cases (tanggal dobel, edit masa lalu).
- (Opsional) widget test untuk layar utama.

## Deployment Strategy
- MVP: `flutter build apk --release` -> kirim APK ke HP adek -> install.
- Update: build APK baru, install ulang (data SQLite tetap, karena skema stabil + migrasi).
- Versi skema DB dijaga kompatibel ke depan (onUpgrade, bukan reset).

## Technical Risks
| Risk | Mitigation |
| --- | --- |
| Flutter/Android toolchain update memaksa perubahan | Pin versi Flutter; evaluasi update tiap 6 bulan; maintenance rutin terjadwal |
| HP hilang -> data hilang | Fase 2: export/backup JSON; edukasi user |
| Package pihak ketiga mati | Minimalkan package; inti pakai yang resmi (sqflite resmi komunitas Flutter) |
| Jam HP salah -> tanggal salah | Validasi tanggal & konfirmasi saat berbeda dari hari ini |
| Kompleksitas bertambah diam-diam | Aturan: fitur baru harus lewat PRD; logika murni diuji |
| Gradle/build lambat di mesin | Build release hanya saat rilis; develop pakai flutter run (hot reload) |

## Related Notes
- [[Docs/PRD - Bendehara Alien]]
- [[Docs/Backend Schema - Bendehara Alien]]
- [[Docs/ADR - 001 Local-first Storage]]
- [[Docs/Implementation Plan - Bendehara Alien]]
- [[Docs/Setup Guide - Flutter (Bendehara Alien)]]
