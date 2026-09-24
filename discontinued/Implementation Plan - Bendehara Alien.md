---
type: implementation-plan
project: Bendehara Alien
status: draft
created: 2026-08-08
updated: 2026-08-08
tags:
  - implementation-plan
  - planning
---

# Implementation Plan - Bendehara Alien

## Objective
Menghasilkan MVP aplikasi kas kelas yang ringan, akurat, dan mudah dirawat, siap dipakai bendahara kelas di HP Android. **Stack final: Flutter.**

## Scope
- In scope: manajemen siswa, input kas harian (periode presisi), riwayat & rekap, pengaturan, persistensi SQLite.
- Out of scope: login, cloud/sync, pembayaran online, laporan PDF, multi-kelas (lihat PRD Non-Goals).

## Milestones

| Milestone | Goal | Status |
| --- | --- | --- |
| M0 ✅ | Install Flutter SDK + Android toolchain (Setup Guide) | done |
| M1 ✅ | Setup project Flutter + skema DB v1 + navigasi 4 tab | done |
| M2 ✅ | CRUD siswa (tambah/edit/arsip) + profil | done |
| M3 ✅ | Input kas harian (periode per tanggal, toggle bayar, ringkasan hari) | done |
| M4 ✅ | Riwayat bulanan + detail hari + rekap per siswa & tunggakan | done |
| M5 ✅ | Pengaturan + validasi & polish + unit test inti | done |
| M6 | Build APK release, install di HP adek, uji pemakaian nyata 1 minggu | not-started |

## Task Breakdown

**M0 ✅ - Toolchain (blocking)**
- [x] Install Flutter SDK (extract ke D:\tools\flutter) + tambah PATH
- [x] Install Android toolchain (cmdline-tools + JDK 17 Temurin, tanpa Android Studio)
- [x] `flutter doctor` hijau (Flutter 3.44.9, Android SDK 36) + license diterima
- [x] Device: pakai MuMu Player (user install sendiri) - adb connect 127.0.0.1:16384

**M1 🔄 - Setup project**
- [x] `flutter create bendehara_app --org com.bendehara` (scaffold + flutter test lulus)
- [x] Tambah dependensi: sqflite, path_provider, provider, intl (terinstall)
- [x] Skema DB v1 (4 tabel: Student, KasPeriod, Payment, AppSetting) + migrasi onUpgrade
- [x] Bottom navigation 4 tab (Hari Ini | Siswa | Riwayat | Pengaturan)

**M2 - Siswa**
- [x] Screen DaftarSiswa + FormSiswa (tambah/edit)
- [x] Soft-delete (arsip) + konfirmasi hapus
- [x] Screen ProfilSiswa (data + riwayat per tanggal + tunggakan)

**M3 - Kas harian**
- [x] DashboardHariIni: ringkasan + list siswa + toggle bayar
- [x] Pilih tanggal (kalender + panah prev/next) + blokir tanggal masa depan
- [x] Pembuatan periode otomatis saat pertama dibuka (date UNIQUE)
- [x] Edit nominal per hari

**M4 - Riwayat & rekap**
- [x] Screen Riwayat (navigasi bulan + ringkasan per hari)
- [x] Screen DetailHari (edit status masa lalu)
- [x] Riwayat per siswa + hitung tunggakan
- [x] Fungsi murni rekap + unit test (14/14 lulus)

**M5 - Pengaturan & polish**
- [x] Screen Pengaturan (nominal default, nama kelas, tahun ajaran)
- [x] Validasi input (nama wajib, nominal >= 0, tanggal valid)
- [x] Empty/error/loading states + snackbar
- [x] Aksesibilitas (target sentuh 48dp, label teks) + review

**M6 - Rilis**
- [ ] `flutter build apk --release` (sedang berjalan)
- [ ] Install di HP adek, jalankan skenario Happy Path + edge cases
- [ ] Uji pemakaian nyata 1 minggu + catat feedback

## Dependencies
- M0 ✅ selesai (Flutter SDK + toolchain) sebelum M1 🔄 - blocking.
- HP Android adek untuk tes (USB saat develop, APK saat rilis).
- (Optional) Akun Google/WhatsApp untuk kirim APK.

## Validation Plan
- [ ] Unit test: rekap bulanan vs hitung manual, tunggakan, validasi tanggal dobel, format rupiah
- [ ] Manual: catat 1 minggu di app vs buku manual -> total harus sama persis
- [ ] Build/deploy check: APK terinstall & data bertahan setelah restart/update app
- [ ] Performa: cold start < 2 detik di HP target; scroll 50 siswa mulus

## Risks And Mitigations

| Risk | Mitigation |
| --- | --- |
| Setup Flutter gagal/lambat di Windows | Ikuti Setup Guide; flutter doctor sebagai penunjuk; minta bantuan bila error |
| Data hilang (HP rusak/hilang) | Backup manual fase 2; selama MVP, buku manual tetap cadangan |
| Skema berubah di tengah | Migrasi bertahap sejak awal (onUpgrade) |
| Fitur merembet (scope creep) | Semua tambahan lewat PRD & milestone baru |
| Maintenance berat | Package minimal; logika murni di-test; review kode tiap milestone |

## Handover Checkpoints
- [ ] Handover setelah M1 🔄 (setup & skema).
- [ ] Handover setelah M3 (inti fungsional).
- [ ] Handover setelah M6 (rilis + feedback).

## Related Notes
- [[Docs/PRD - Bendehara Alien]]
- [[Docs/TRD - Bendehara Alien]]
- [[Docs/Backend Schema - Bendehara Alien]]
- [[Docs/Setup Guide - Flutter (Bendehara Alien)]]
- [[../Project - Bendehara Alien]]
