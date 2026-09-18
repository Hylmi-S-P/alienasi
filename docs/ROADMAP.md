# Project Roadmap & Implementation Milestones
# Bendahara v2: Peta Jalan Pengembangan & Rencana Pelaksanaan

## 1. Ikhtisar Tahapan Pengembangan
Pengembangan Bendahara v2 dibagi ke dalam 6 fase terstruktur untuk memastikan fondasi ketahanan data kokoh sebelum antarmuka pengguna dibangun:

```
[Fase 1: Fondasi & Basis Data] 
       │
       ▼
[Fase 2: Manajemen Siswa & Iuran] 
       │
       ▼
[Fase 3: Pencatatan Transaksi & Nota] 
       │
       ▼
[Fase 4: Mesin Laporan & Supervisi Ibu] 
       │
       ▼
[Fase 5: Pencadangan & Keamanan] 
       │
       ▼
[Fase 6: Audit Kualitas & Uji Pengguna]
```

---

## 2. Rincian Fase & Deliverables

### Fase 1: Inisialisasi Proyek & Lapisan Penyimpanan Lokal Tangguh
- Inisialisasi struktur proyek Flutter dengan arsitektur bersih (*Clean Architecture*).
- Konfigurasi `drift` dan `sqlite3_flutter_libs` dengan mode `WAL` (*Write-Ahead Logging*) dan `PRAGMA foreign_keys = ON`.
- Pembuatan tabel-tabel utama: `academic_years`, `students`, `categories`, `transactions`, `dues_periods`, `dues_payments`.
- Penyusunan *Unit Test* untuk memastikan operasi baca-tulis SQLite berjalan tanpa eror dan integritas relasi terjaga.

### Fase 2: Modul Anggota Kelas & Pencatatan Iuran Mingguan Cepat
- Fitur pembuatan kelas dan tahun ajaran baru (misal: "Kelas 7A - 2026/2027").
- Fitur impor atau input cepat nama siswa dan nomor absen.
- Antarmuka *Quick Check* iuran mingguan (sekali ketuk untuk menandai lunas).
- Penghitungan otomatis akumulasi uang kas yang terkumpul dari seluruh siswa.

### Fase 3: Modul Arus Kas & Penyimpanan Foto Nota
- Formulir pencatatan kas masuk dan keluar dengan validasi ketat (mencegah nominal minus atau tak wajar).
- Pengelompokan kategori yang relevan untuk kebutuhan sekolah.
- Integrasi kamera dan galeri untuk foto nota fisik dengan kompresi lokal (maksimum 300KB per foto) guna menghemat memori perangkat.
- Daftar riwayat transaksi dengan filter pencarian dan pengelompokan tanggal.

### Fase 4: Modul Supervisi Ibu & Ekspor Laporan Multi-Rentang
- Layar Supervisi & Laporan dengan tombol preset:
  - 1 Bulan
  - 3 Bulan
  - 1 Tahun
  - Semua Rentang
  - Rentang Kustom
- Integrasi pustaka `pdf` dan `printing` untuk membuat dokumen PDF resmi siap cetak lengkap dengan tabel kas, ringkasan saldo, dan kolom tanda tangan (Bendahara, Ketua Kelas, Wali Kelas, Orang Tua).
- Ekspor spreadsheet `.csv` / `.xlsx` untuk audit tabel di komputer.
- Integrasi `share_plus` untuk berbagi langsung ke nomor WhatsApp Ibu.

### Fase 5: Pencadangan Mandiri & Penguncian Aplikasi
- Pembuatan modul arsip cadangan mandiri (`.bhz` / ZIP berisi berkas SQLite dan foto nota).
- Fitur pemulihan data (*restore*) jika berganti ponsel.
- Opsi penguncian aplikasi dengan PIN 4 digit atau sidik jari (`local_auth`) agar tidak sembarang dibuka teman sekelas.

### Fase 6: Pengujian, Audit Anti-Slop, dan Verifikasi Akhir
- Audit kepatuhan standar Anti-Slop (verifikasi kontras WCAG AA, ketiadaan tombol mati, ketiadaan tanda em dash pada teks antarmuka).
- Pengujian performa dengan *dummy dataset* 5.000 transaksi (simulasi pemakaian 6 tahun dari SMP hingga SMA).
- Uji keterbacaan dan kemudahan pakai (*Usability Testing*) bersama adik dan ibu.
