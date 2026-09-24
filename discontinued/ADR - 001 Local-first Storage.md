---
type: adr
status: accepted
project: Bendehara Alien
created: 2026-08-08
updated: 2026-08-08
tags:
  - architecture
  - adr
---

# ADR - 001 Local-first Storage (tanpa backend)

## Context
Aplikasi kas kelas dipakai satu bendahara di satu perangkat, offline di kelas. Data sensitif tapi kecil (nama siswa + status bayar). Opsi backend (server + API + auth) menambah biaya, kompleksitas, dan titik gagal - bertentangan dengan prinsip "ringan & mudah maintenance". Data harus tetap akurat secara lokal.

## Decision
Menyimpan semua data di **SQLite lokal di perangkat** (via sqflite (Flutter)). Tidak ada server, tidak ada login, tidak ada sinkronisasi di MVP. Backup = export file JSON (fase 2, opsional). Skema DB diberi versi eksplisit (sqflite version + onUpgrade) dengan migrasi bertahap sejak awal.

## Alternatives Considered
- **Firebase / Supabase (cloud):** fitur sync & backup gratis, tapi: butuh akun, internet, kompleksitas auth, biaya ops jangka panjang, dan melanggar prinsip ringan. Ditunda sampai benar-benar butuh sync.
- **Spreadsheet (Excel/Sheets):** tanpa development, tapi tidak presisi (tanggal dobel mudah), tidak mobile-friendly, rawan salah edit.
- **File JSON lokal saja (tanpa DB):** simpel tapi query rekap & konsistensi (unique date) harus ditulis manual - SQLite lebih tepat.

## Consequences
- **Positif:** offline total, startup cepat, tanpa biaya server, tanpa dependency cloud, data privat di perangkat, maintenance minim.
- **Negatif:** data tidak otomatis dicadangkan; satu perangkat (jika HP hilang, data hilang) -> mitigasi: export/backup fase 2 + buku manual tetap cadangan selama MVP.
- **Negatif:** tidak ada akses dari perangkat lain -> diterima untuk MVP (PRD Non-Goals).

## Related Notes
- [[Docs/PRD - Bendehara Alien]]
- [[Docs/TRD - Bendehara Alien]]
- [[Docs/Backend Schema - Bendehara Alien]]

## Next Actions
- [ ] Review keputusan ini setelah 3 bulan pemakaian (perlu sync? perlu cloud?).
