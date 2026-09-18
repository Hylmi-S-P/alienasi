# DESIGN.md
# Spesifikasi Desain Antarmuka & Sistem Desain Bendahara v2

> **Instruksi untuk AI Agent Desainer**:
> Dokumen ini adalah panduan desain resmi (*Single Source of Truth*) untuk merancang UI/UX aplikasi mobile **Bendahara v2** (Figma, mockup, atau kode antarmuka Flutter).
> Proyek ini menerapkan filter kualitas **Anti-Slop (Mode: DURING)** secara ketat. Seluruh aturan larangan mutlak (*Hard Gate*), batas dosis dekorasi (*Purpose-Gate*), dan standar ketahanan tata letak mobile wajib dipatuhi tanpa pengecualian.

---

## 1. Design Read & Deklarasi Karakter

```
Reading this as: Aplikasi pencatatan kas kelas & audit orang tua untuk siswa SMP kelas 7 (Adik) dan Ibu (Supervisor), bergaya Tenang, Terstruktur, Jujur, dan Fungsional, dial ENERGY 1 / RHYTHM 1 / MOTION 1.
```

- **Dial ENERGY: 1 (Calm / Tenang)**
  - Suasana visual stabil dan tidak memicu kecemasan.
  - Bebas dari warna neon, gradien ungu-kebiruan acak, efek cahaya berpendar (*glow*), atau ornamen dekoratif tanpa fungsi.
  - Alasan: Pengguna adalah anak usia 12-13 tahun yang sedang memegang tanggung jawab uang nyata di sekolah. Antarmuka harus menghadirkan rasa tenang, fokus, dan percaya diri.
- **Dial RHYTHM: 1 (Uniform / Seragam & Terstruktur)**
  - Tata letak kartu, jarak antar-elemen, dan hierarki daftar disusun dengan kisi yang konsisten.
  - Alasan: Siswa tidak perlu menebak pola tata letak saat jam istirahat sekolah yang singkat.
- **Dial MOTION: 1 (Calm / Fungsional & Ringan)**
  - Transisi halaman menggunakan perpindahan standar sistem (*shared axis* atau *fade through* halus < 200ms).
  - Umpan balik sentuhan (*touch ripple*) langsung terasa saat tombol ditekan.
  - Dilarang: Efek melayang acak (*floating elements*), animasi memantul (*bounce*), atau paralaks berlebihan.

---

## 2. Aturan Keras Anti-Slop (Hard Gate Constraints)

Setiap desainer atau AI agent yang merancang antarmuka wajib mematuhi batasan berikut:

1. **R-02 (Larangan Em Dash)**:
   - Dilarang menggunakan karakter em dash (`—`) pada seluruh teks antarmuka, judul, tombol, maupun pesan notifikasi.
   - Gunakan tanda titik (`.`), koma (`,`), titik dua (`:`), tanda hubung biasa (`-`), atau tanda kurung `()`.
2. **R-03 (Responsivitas Mobile Mutlak)**:
   - Tidak boleh ada teks terpotong (*text clipping*) atau luapan horizontal (*horizontal overflow*).
   - Target sentuh (*touch target*) untuk setiap tombol dan elemen interaktif minimal **48 x 48 dp**.
   - Lebar layar acuan: 360dp s/d 412dp (standar ponsel Android) dan 375dp s/d 390dp (iPhone).
3. **R-08 (Larangan Panah Dekoratif pada Tombol)**:
   - Dilarang menaruh simbol panah (`→` atau `↗`) pada semua tombol secara seragam. Tombol aksi utama menggunakan teks kerja spesifik.
4. **R-11 (Larangan Bentuk Pil Berlebihan)**:
   - Dilarang membuat semua komponen berbentuk kapsul/pil (*pill shape*).
   - Radius sudut diatur secara konsisten: **12 dp** untuk kartu kontainer, **8 dp** untuk tombol dan kolom isian.
5. **R-13 & R-10 (Larangan Glow & Glassmorphism Berlebihan)**:
   - Dilarang menggunakan efek pendaran (*glow*) pada kartu, tombol, maupun badge.
   - Dilarang menggunakan efek blur kaca (*glassmorphism*) pada banyak elemen sekaligus. Latar kartu harus solid agar keterbacaan data maksimal.
6. **R-15 & R-16 (Copywriting Spesifik & Bebas Buzzword AI)**:
   - Dilarang menggunakan tombol klise: *Get Started*, *Explore*, *Learn More*, atau *Submit*.
   - Dilarang memakai kata promosi palsu: *Revolusioner*, *AI-Powered*, *Seamless*, *Canggih*, *Next Generation*.
   - Gunakan kata kerja nyata: *Simpan Pengeluaran*, *Catat Pembayaran*, *Bagikan Laporan ke Ibu*, *Unduh Berkas PDF*.
7. **R-25 (Standar Kontras WCAG AA)**:
   - Rasio kontras teks biasa terhadap latar belakang minimal **4.5:1**.
   - Rasio kontras teks besar/tebal minimal **3.0:1**.
8. **R-26 (Ketiadaan Kontrol Mati / No Dead Buttons)**:
   - Seluruh tombol, filter chip, dan navigasi harus memiliki fungsi nyata atau dialog konfirmasi yang jelas.
9. **R-27 (Tiga Status Wajib pada Setiap Tampilan Data)**:
   - Setiap layar yang menampilkan data wajib memiliki: **Status Kosong (Empty State)**, **Status Memuat (Loading State)**, dan **Status Galat (Error State)**.

---

## 3. Sistem Token Warna (Color Tokens)

Sistem warna dibatasi pada 2 warna inti netral + 1 warna primer sekolah + 1 warna aksen perhatian, ditambah warna fungsional kas masuk/keluar:

### 3.1 Mode Terang (Light Theme - Default)

| Token Warna | Nilai HEX | Peran & Alasan Desain | Rasio Kontras |
|---|---|---|---|
| `bg-canvas` | `#F8F9FA` | Latar belakang dasar aplikasi (off-white hangat). | Dasar |
| `bg-surface` | `#FFFFFF` | Latar kartu informasi dan modal dialog. | Dasar |
| `border-subtle` | `#E2E8F0` | Garis batas tipis pemisah kartu (1px solid). | - |
| `text-primary` | `#0F172A` | Teks judul dan angka saldo utama (Slate 900). | 16.1:1 di atas putih (Lolos AAA) |
| `text-secondary` | `#475569` | Teks keterangan, tanggal, dan nama siswa (Slate 600). | 5.8:1 di atas putih (Lolos AA) |
| `brand-primary` | `#1B4332` | Hijau Hutan Sekolah. Warna tombol utama dan header kas. | 9.3:1 terhadap teks putih (Lolos AAA) |
| `brand-primary-light` | `#E8F5E9` | Latar belakang penanda kas masuk atau status lunas. | - |
| `accent-warning` | `#D97706` | Ochre Hangat. Penanda tunggakan iuran yang butuh perhatian. | 4.6:1 di atas putih (Lolos AA) |
| `status-income` | `#16A34A` | Hijau Positif. Indikator uang kas masuk (+). | 4.8:1 di atas putih (Lolos AA) |
| `status-expense` | `#DC2626` | Merah Karmin. Indikator uang kas keluar (-). | 5.2:1 di atas putih (Lolos AA) |

### 3.2 Mode Gelap (Dark Theme)

| Token Warna | Nilai HEX | Peran & Alasan Desain | Rasio Kontras |
|---|---|---|---|
| `bg-canvas` | `#121418` | Latar arang gelap yang nyaman di mata malam hari. | Dasar |
| `bg-surface` | `#1E232B` | Latar kartu informasi terangkat (*elevated surface*). | Dasar |
| `border-subtle` | `#2D3748` | Garis batas kartu mode gelap. | - |
| `text-primary` | `#F8FAFC` | Teks utama putih lembut (bukan putih mentah silau). | 14.2:1 di atas surface (Lolos AAA) |
| `text-secondary` | `#94A3B8` | Teks pendukung abu-abu terang. | 6.5:1 di atas surface (Lolos AA) |
| `brand-primary` | `#2D6A4F` | Penyesuaian hijau sekolah untuk latar gelap. | 5.1:1 terhadap teks putih (Lolos AA) |
| `status-income` | `#4ADE80` | Hijau terang ramah kontras gelap. | 8.2:1 di atas surface (Lolos AAA) |
| `status-expense` | `#F87171` | Merah karmin terang ramah kontras gelap. | 6.9:1 di atas surface (Lolos AAA) |

---

## 4. Tipografi & Skala Teks

Font keluarga utama: **Plus Jakarta Sans** (Alternatif sistem: Roboto pada Android, SF Pro pada iOS).

| Peran Tipografi | Ukuran (sp) | Ketebalan | Line Height | Keterangan Penggunaan |
|---|---|---|---|---|
| **Display / Saldo Utama** | 28 sp | Bold (700) | 36 sp | Angka total saldo kas di Dashboard (angka tabular). |
| **Title / Judul Layar** | 20 sp | Semi-Bold (600) | 28 sp | Header halaman (misal: "Catat Uang Keluar"). |
| **Headline / Sub-judul** | 16 sp | Semi-Bold (600) | 24 sp | Judul seksi kartu dan nama siswa di daftar absen. |
| **Body / Teks Isi** | 14 sp | Regular (400) | 20 sp | Teks deskripsi transaksi, catatan, dan form input. |
| **Label / Tombol** | 14 sp | Semi-Bold (600) | 20 sp | Label tombol aksi (*Button text*). |
| **Caption / Metadata** | 12 sp | Medium (500) | 16 sp | Tanggal transaksi, status badge, nomor absen. |

---

## 5. Spesifikasi Layar Utama (Core Screens)

### Layar 1: Dashboard Kas Kelas (Home Screen)
- **Fokus Utama**: Kartu Saldo Kas Kelas yang besar dan tegas di bagian atas layar.
- **Komponen**:
  1. *Header Kelas*: Teks ringkas "Kelas 7A - 2026/2027", tombol ganti tahun ajaran/kelas, dan tombol menu profil/kunci.
  2. *Kartu Saldo Terpadu*:
     - Saldo Saat Ini: Angka besar (contoh: `Rp 485.000`).
     - Dua kotak perbandingan: Kas Masuk Bulan Ini (`Rp 650.000`) dan Kas Keluar Bulan Ini (`Rp 165.000`).
  3. *Aksi Cepat (Quick Action Row)*:
     - Tombol 1: `+ Uang Masuk` (Latar hijau lembut, ikon panah masuk bawah).
     - Tombol 2: `- Uang Keluar` (Latar merah lembut, ikon panah keluar atas).
     - Tombol 3: `Centang Iuran` (Latar slate lembut, ikon daftar centang).
  4. *Kartu Ringkasan Iuran Pekan Berjalan*:
     - Progres bar iuran minggu aktif (contoh: "28 dari 32 siswa sudah bayar").
  5. *Daftar 5 Transaksi Terakhir*:
     - Baris transaksi memuat: Ikon kategori, Judul transaksi, Tanggal, dan Nominal (+/-).
     - Tautan di bawah daftar: `Lihat Semua Riwayat Transaksi`.

### Layar 2: Pencatatan Iuran Siswa (Quick-Check Screen)
- **Tujuan**: Membantu adik mencatat siapa saja teman sekelas yang sudah bayar iuran mingguan secara cepat saat jam istirahat.
- **Komponen**:
  1. *Pemilih Minggu*: Tombol pindah minggu (contoh: `< Minggu 2 September 2026 >`).
  2. *Status Pengumpulan*: "Terkumpul: Rp 140.000 / Rp 160.000 (Target Rp 5.000/siswa)".
  3. *Daftar Siswa (Scrollable List)*:
     - Tinggi baris: **56 dp**.
     - Kolom kiri: Kotak nomor absen (1, 2, 3...) dan Nama Siswa (contoh: "Ahmad Fauzi").
     - Kolom kanan: Tombol toggle centang besar (48 x 48 dp).
       - Jika belum bayar: Kotak garis abu-abu dengan label `Belum`.
       - Jika sudah bayar: Kotak hijau penuh dengan ikon centang putih dan label `Lunas (Rp 5.000)`.
  4. *Tombol Aksi Bawah*: `Simpan & Perbarui Kas Kelas`.

### Layar 3: Formulir Transaksi Kas (Uang Masuk / Keluar)
- **Tujuan**: Mencatat pengeluaran belanja kelas atau kas masuk khusus secara jelas.
- **Komponen**:
  1. *Pemilih Jenis Transaksi*: Tab ganti sederhana `[ Uang Masuk ]` dan `[ Uang Keluar ]`.
  2. *Input Nominal Uang*: Bidang input dengan font angka 24sp tebal dengan awalan tetap `Rp`. Terdapat tombol bantuan cepat nominal sekolah: `+5.000`, `+10.000`, `+20.000`, `+50.000`.
  3. *Pemilih Kategori*: Chip pilihan kategori nyata kebutuhan sekolah (Spidol & Alat Tulis, Kebersihan Kelas, Jenguk Teman Sakit, Fotokopi Tugas, Kas Rutin).
  4. *Judul & Keterangan*: Kolom teks untuk rincian (contoh: "Beli 2 spidol hitam & 1 penghapus papan").
  5. *Lampiran Bukti Nota*:
     - Kotak foto ukuran 80 x 80 dp.
     - Jika belum ada foto: Tombol dengan ikon kamera `Foto Nota Fisik`.
     - Jika sudah ada: Tampilan thumbnail foto dengan tombol silang hapus foto.
  6. *Tombol Simpan*: Tombol penuh di bawah layar dengan label `Simpan Transaksi Kas`.

### Layar 4: Supervisi Ibu & Ekspor Laporan Keuangan
- **Tujuan**: Tempat Ibu memeriksa pembukuan adik dan mengekspor dokumen pertanggungjawaban resmi.
- **Komponen**:
  1. *Pemilih Rentang Waktu (Filter Bar)*:
     - 4 tombol preset: `1 Bulan` | `3 Bulan` | `1 Tahun` | `Semua` | `Kustom`.
     - Tombol yang aktif berwarna hijau sekolah pekat (`#1B4332`), tombol tidak aktif berwarna latar abu-abu netral.
  2. *Ringkasan Audit Periode Terpilih*:
     - Rentang Tanggal: `1 September 2026 - 30 September 2026`
     - Total Pemasukan: `Rp 650.000`
     - Total Pengeluaran: `Rp 165.000`
     - Sisa Saldo: `Rp 485.000`
     - Tingkat Kepatuhan: `94% Siswa Tertib Bayar`
  3. *Daftar Item Arus Kas*:
     - Tabel ringkas berisi seluruh catatan pada rentang yang dipilih.
  4. *Tombol Aksi Utama Ekspor*:
     - Tombol 1 (Primer): `Bagikan Laporan PDF ke WhatsApp` (Membuka dialog kirim dokumen langsung).
     - Tombol 2 (Sekunder): `Preview Dokumen PDF` (Melihat tampilan lembar cetak sebelum dikirim).
     - Tombol 3 (Tersier/Teks): `Unduh Berkas Excel (CSV)`.

---

## 6. Anatomi Tata Letak Dokumen PDF Resmi

Ketika tombol ekspor ditekan, mesin laporan menghasilkan dokumen PDF format A4 tegak (*portrait*) dengan struktur:

```
+-------------------------------------------------------------------+
|  LAPORAN PERTANGGUNGJAWABAN KAS KELAS                             |
|  SMP NEGERI X - KELAS 7A (TAHUN AJARAN 2026/2027)                 |
|  Periode: 1 September 2026 s/d 30 September 2026 (Rentang: 1 Bulan) |
+-------------------------------------------------------------------+
|  RINGKASAN AUDIT KEUANGAN:                                        |
|  - Total Kas Masuk : Rp 650.000       - Sisa Saldo Tunai: Rp 485.000 |
|  - Total Kas Keluar: Rp 165.000       - Persentase Lunas: 94% Siswa  |
+-------------------------------------------------------------------+
|  TABEL ARUS KAS KELAS                                             |
|  No | Tanggal    | Kategori    | Keterangan          | Masuk   | Keluar  |
|  1  | 02/09/2026 | Uang Kas    | Iuran Minggu Ke-1   | 140.000 | -       |
|  2  | 05/09/2026 | Alat Tulis  | Beli 2 Spidol Papan | -       | 25.000  |
|  3  | 09/09/2026 | Uang Kas    | Iuran Minggu Ke-2   | 150.000 | -       |
|  4  | 14/09/2026 | Kebersihan  | Sapu & Pengki Kelas | -       | 40.000  |
|  ...                                                              |
+-------------------------------------------------------------------+
|  KOLOM PENGESAHAN & TANDA TANGAN:                                 |
|                                                                   |
|   Bendahara Kelas        Ketua Kelas          Mengetahui Orang Tua |
|                                                                   |
|   ( [Nama Adik] )     ( ............... )       ( Ibu Pengawas )  |
+-------------------------------------------------------------------+
```

---

## 7. Kamus Bahasa & Copywriting Antarmuka

| Konteks Layar | Teks Baku yang Digunakan | Kata Terlarang (AI Slop / Jargon) |
|---|---|---|
| Dashboard | "Kas Kelas", "Uang Masuk", "Uang Keluar", "Sisa Saldo" | "Cashflow", "Debet", "Kredit", "Neraca Saldo" |
| Status Iuran | "Lunas", "Belum Bayar", "Tunggakan" | "Piutang", "Default", "Outstanding Invoice" |
| Tombol Form | "Simpan Transaksi", "Perbarui Catatan" | "Submit", "Proses", "Kirim Sekarang" |
| Tombol Ekspor | "Bagikan Laporan PDF ke WhatsApp Ibu", "Unduh Berkas Excel" | "Ekspor Dokumen Canggih", "Generate Analytics" |
| Status Kosong Transaksi | "Belum ada catatan transaksi pada rentang ini. Tekan tombol tambah di bawah untuk mulai mencatat." | "Tidak ada data ditemukan", "Data null" |
| Status Galat | "Gagal memuat catatan kas. Periksa kembali penyimpanan ponsel Anda." | "Internal Server Error 500", "Fatal Crash" |

---

## 8. Daftar Periksa untuk AI Agent Desainer (Delivery Gate Checklist)

Sebelum AI Agent menyatakan rancangan desain selesai, wajib memeriksa butir berikut:

- [ ] Apakah tidak ada tanda em dash (`—`) pada seluruh teks desain? *(R-02)*
- [ ] Apakah seluruh target sentuh tombol memiliki ukuran minimal 48 x 48 dp? *(R-03)*
- [ ] Apakah tidak ada gradien ungu-kebiruan acak atau efek glow yang menumpuk? *(R-01, R-13)*
- [ ] Apakah radius sudut konsisten (12dp untuk kartu, 8dp untuk tombol)? *(R-11)*
- [ ] Apakah rasio kontras teks memenuhi standar minimum WCAG AA (>= 4.5:1)? *(R-25)*
- [ ] Apakah setiap layar telah dilengkapi rancangan untuk Status Kosong (*Empty State*) dan Status Memuat (*Loading State*)? *(R-27)*
- [ ] Apakah tombol aksi menggunakan teks spesifik dan relevan (bukan *Get Started* atau *Explore*)? *(R-15)*
- [ ] Apakah rancangan memiliki tema terang dan gelap yang keduanya terbaca jelas? *(R-21, R-34)*
- [ ] Apakah tata letak sudah diuji pada lebar layar smartphone 360dp tanpa ada elemen yang terpotong? *(R-03)*
