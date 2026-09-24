---
type: prd
project: Bendehara Alien
status: draft
created: 2026-08-08
updated: 2026-08-08
tags:
  - prd
  - planning
---

# PRD - Bendehara Alien

## Overview
Aplikasi mobile sederhana untuk bendahara kelas mencatat uang kas harian: daftar siswa, status bayar per hari (sudah/belum), nominal terkumpul, dan riwayat pembayaran per siswa. Aplikasi bekerja penuh offline di satu perangkat.

## Problem
- Pencatatan manual (buku tulis) rawan salah: tanggal terlewat/dobel, nominal keliru, nama terlewat.
- Sulit menjawab cepat: "siapa yang belum bayar hari ini?", "total kas bulan ini berapa?".
- Tidak ada riwayat per siswa: berapa kali anak belum membayar (tunggakan) tidak terlihat.
- Periode (hari/tanggal) tidak presisi: uang & waktu bisa salah catat.

## Target Users
- Bendahara kelas (adek user, usia ±13-16 tahun) - pengguna utama & satu-satunya di MVP.
- (Future) Guru/wali kelas - akses lihat rekap, tanpa edit.

## Goals
- Mencatat pembayaran uang kas **per hari** (periode = tanggal) dengan presisi: tanggal benar, tidak dobel, bisa diedit.
- Menandai per siswa: **sudah bayar / belum bayar** dengan 1 ketukan.
- Rekap otomatis: per hari (X dari Y siswa, total Rp), per bulan, per siswa (riwayat + tunggakan).
- Data aman tersimpan lokal di perangkat (offline, tanpa internet).

## Non-Goals (MVP)
- Tidak ada login, akun, atau sinkronisasi cloud / multi-perangkat.
- Tidak ada pembayaran online (e-wallet/bank).
- Tidak ada multi-kelas / multi-bendahara.
- Tidak ada laporan PDF/print (future).
- Tidak ada notifikasi pengingat (future).

## Core Features
- [x] Manajemen siswa: tambah siswa (nama wajib, NIS/no. urut & foto opsional), edit, arsipkan (hapus lunak agar riwayat aman).
- [x] Profil siswa: data siswa + riwayat pembayaran per tanggal + total tunggakan.
- [x] Input kas harian: pilih tanggal, atur nominal per siswa (default dari pengaturan), toggle bayar/belum per siswa, simpan.
- [x] Periode presisi: tanggal unik (tidak bisa dobel), periode masa lalu bisa dibuka/diedit, tanggal masa depan diblokir dengan peringatan.
- [x] Beranda: ringkasan hari ini + bulan ini + aksi cepat ke Kas/Catatan/Anak.
- [x] Riwayat & rekap dengan rentang: Minggu, Bulan, 3 Bulan, 1 Tahun (+ detail per hari, riwayat per siswa).
- [x] Pengaturan: nominal kas default per hari, nama kelas, tahun ajaran.

## User Stories
- Sebagai bendahara, saya ingin menambah siswa baru beserta profilnya, agar data kelas lengkap.
- Sebagai bendahara, saya ingin membuka tanggal hari ini dan mengetuk setiap siswa yang sudah bayar, agar cepat mencatat.
- Sebagai bendahara, saya ingin melihat siapa yang belum bayar hari ini, agar bisa menagih.
- Sebagai bendahara, saya ingin melihat rekap bulan ini (total terkumpul, siapa sering telat), agar laporan ke wali kelas mudah.
- Sebagai bendahara, saya ingin mengoreksi tanggal kemarin (misal lupa mencatat), agar catatan tetap akurat.

## Success Metrics
- 0 kesalahan tanggal/nominal dalam 1 bulan pemakaian (diverifikasi vs buku manual).
- Waktu mencatat satu hari < 2 menit.
- Data tidak hilang saat app ditutup/di-restart (persistensi SQLite).

## Assumptions
- Satu kelas, satu bendahara, satu perangkat.
- Nominal uang kas sama untuk semua siswa per hari, bisa diubah per hari (default dari pengaturan).
- Pembayaran tunai di kelas.
- Jumlah siswa per kelas 20-50 (performa mudah).
- Nama app: "Bendehara Alien" (bisa diganti).

## Risks
- HP hilang/rusak → data hilang. Mitigasi MVP: tombol export/backup JSON (fase 2); catatan manual tetap ada sebagai cadangan.
- Salah ketuk (tandai bayar padahal belum) → butuh undo / bisa diedit kapan saja.
- Siswa pindah/keluar → arsipkan, bukan hapus permanen.
- Tanggal salah karena jam HP salah → validasi & konfirmasi sebelum simpan jika tanggal ≠ hari ini.

## Open Questions
- [x] Tech stack final → **Flutter** (diputuskan 2026-08-08, user)
- [ ] Nominal kas bisa berbeda antar siswa? (asumsi MVP: sama; override per siswa = future)
- [ ] Perlu foto profil siswa? (asumsi MVP: opsional)
- [ ] Perlu export/backup di MVP? (proposal: fase 2)
- [ ] Nama aplikasi final: "Bendehara Alien" atau diganti?

## Related Notes
- [[../Project - Bendehara Alien]]
- [[Docs/TRD - Bendehara Alien]]
- [[Docs/App Flow - Bendehara Alien]]
- [[Docs/Backend Schema - Bendehara Alien]]
- [[Docs/UI UX Design Concept - Bendehara Alien]]
- [[Docs/ADR - 001 Local-first Storage]]
