# Parental Supervision & Multi-Range Export Specification
# Bendahara v2: Spesifikasi Modul Pemantauan Ibu & Ekspor Laporan

## 1. Konsep & Alur Kerja Supervisi Orang Tua
Salah satu pilar utama Bendahara v2 adalah memberikan ketenangan pikiran kepada orang tua (Ibu) bahwa amanah kas kelas yang dipegang oleh adik berjalan secara jujur, akurat, dan rapi.

```
+--------------------------------------------------------------+
|                    PENGGUNAAN DI SEKOLAH                     |
|  Adik mencatat iuran teman & pengeluaran kelas secara lokal  |
|  (100% Offline di kelas, tanpa internet, cepat & aman)       |
+--------------------------------------------------------------+
                               |
                               v
+--------------------------------------------------------------+
|                     SUPERVISI DI RUMAH                       |
|  1. Adik & Ibu membuka menu "Laporan & Supervisi"            |
|  2. Memilih rentang waktu evaluasi (1 Bulan / 3 Bulan / dsb) |
|  3. Aplikasi menampilkan Ringkasan Audit Kas & Selisih Fisik |
+--------------------------------------------------------------+
                               |
                               v
+--------------------------------------------------------------+
|                        AKSI EKSPOR                           |
|  - Klik "Bagikan Laporan PDF ke WhatsApp Ibu"                |
|  - Berkas PDF resmi langsung tersimpan di chat WhatsApp Ibu  |
|  - Ekspor berkas Excel/CSV untuk rekap di komputer (opsional)|
+--------------------------------------------------------------+
```

---

## 2. Logika Rentang Waktu Laporan (Date Range Logic)

Aplikasi menyediakan empat tombol rentang preset ditambah satu pemilih rentang manual:

### 2.1 Rentang 1 Bulan (Evaluasi Bulanan)
- **Cakupan**: 30 hari kalender terakhir atau bulan kalender berjalan (misal: 1 s/d 30 September).
- **Tujuan**: Laporan rutin bulanan yang diserahkan ke wali kelas dan dicek Ibu setiap akhir bulan.
- **Isi Utama**: Rekap kas mingguan masuk dari teman sekelas dan pembelian barang rutin kelas (spidol, spon penghapus, isi ulang galon).

### 2.2 Rentang 3 Bulan (Evaluasi Triwulan / Tengah Semester)
- **Cakupan**: 90 hari kalender terakhir atau 1 triwulan kalender berjalan.
- **Tujuan**: Evaluasi tengah semester (PTS). Memastikan tidak ada tunggakan iuran siswa yang menumpuk menjelang ujian tengah semester.
- **Isi Utama**: Analisis tren pengeluaran kelas dan daftar siswa yang masih memiliki tunggakan kas.

### 2.3 Rentang 1 Tahun (Evaluasi Kenaikan Kelas)
- **Cakupan**: 1 tahun ajaran akademik penuh (1 Juli tahun berjalan sampai 30 Juni tahun berikutnya).
- **Tujuan**: Pertanggungjawaban akhir tahun ajaran saat pembagian rapor / kenaikan kelas.
- **Isi Utama**: Saldo awal tahun, total pemasukan setahun, total pengeluaran setahun, sisa saldo kas yang akan diserahterimakan atau dialihkan ke kelas berikutnya.

### 2.4 Semua Rentang (Arsip Komprehensif Seumur Hidup)
- **Cakupan**: Dari transaksi paling pertama di kelas 7 SMP hingga transaksi terkini (dapat mencakup hingga kelas 9 SMP atau kelas 12 SMA).
- **Tujuan**: Bukti rekam jejak integritas jangka panjang adik selama menjadi bendahara sekolah.
- **Isi Utama**: Ringkasan multi-tahun, statistik total uang yang pernah dikelola, dan pengelompokan per tahun ajaran.

### 2.5 Rentang Kustom (Custom Range)
- **Cakupan**: Tanggal awal (*start date*) dan tanggal akhir (*end date*) bebas ditentukan pengguna.
- **Tujuan**: Untuk keperluan khusus seperti kegiatan pentas seni (pensi), kegiatan karya wisata (study tour), atau bazar kelas.

---

## 3. Tata Letak & Anatomi Dokumen PDF Resmi

Dokumen PDF disusun dengan gaya tata kelola sekolah yang formal, rapi, dan bersih:

### 3.1 Header Dokumen
- Logo / Teks Lembaga: `LAPORAN PERTANGGUNGJAWABAN KAS KELAS`
- Identitas Kelas: `Kelas 7A | SMP Negeri X`
- Periode: `1 September 2026 s/d 30 September 2026 (Rentang: 1 Bulan)`
- Bendahara: `[Nama Adik]` | Tanggal Cetak: `DD/MM/YYYY, HH:mm WIB`

### 3.2 Kotak Ringkasan Eksekutif (Executive Summary Box)
Empat kotak metrik berdampingan dengan kontras tinggi:
1. **Total Pemasukan**: `Rp X.XXX.000` (Warna Hijau Daun)
2. **Total Pengeluaran**: `Rp X.XXX.000` (Warna Merah Karmin)
3. **Sisa Saldo Kas Tunai**: `Rp X.XXX.000` (Tebal, Warna Hitam/Biru Tua)
4. **Kepatuhan Iuran**: `92% Siswa Lunas` (Warna Aksen Amber)

### 3.3 Tabel Rincian Arus Kas
Tabel bergaris tipis dengan latar belang-selang abu-abu muda (*zebra striping*) agar mudah ditelusuri baris per baris:
- Kolom: `No` | `Tanggal` | `Kategori` | `Keterangan` | `Masuk (Rp)` | `Keluar (Rp)` | `Saldo (Rp)`
- Baris Total di bagian akhir tabel.

### 3.4 Lampiran Lembar Bukti Foto Nota (Opsional - Toggle Aktif)
Jika diaktifkan, halaman berikutnya menampilkan matriks foto nota fisik yang telah diambil adik saat mencatat pengeluaran:
- Setiap foto diberi label tanggal, judul pengeluaran, dan nominal.
- Memberikan transparansi mutlak kepada Ibu dan wali kelas bahwa belanja kelas benar-benar riil.

### 3.5 Kolom Tanda Tangan & Pengesahan
Bagian bawah laporan memuat 3-4 kolom tanda tangan:
1. **Bendahara Kelas**: `[Nama Adik]`
2. **Ketua Kelas**: `( ........................ )`
3. **Mengetahui (Wali Kelas)**: `( ........................ )`
4. **Mengetahui (Orang Tua / Ibu)**: `( ........................ )`

---

## 4. Format Ekspor Spreadsheet (Excel / CSV)
Selain PDF, aplikasi menyediakan ekspor tabel mentah berformat `.csv` (Comma Separated Values) dan `.xlsx` berisi:
- Lembar 1: Riwayat Transaksi Lengkap (Tanggal, Tipe, Kategori, Nominal, Deskripsi).
- Lembar 2: Matriks Iuran Siswa (Nama Siswa, Absen, Minggu 1, Minggu 2, Minggu 3, Minggu 4, Total Bayar, Sisa Tunggakan).
- Berkas dapat langsung dibuka di Microsoft Excel, Google Sheets, atau WPS Office ponsel.

---

## 5. Saluran Distribusi (Sharing Channels)
Ekspor menggunakan antarmuka berbagi bawaan perangkat (*System Share Sheet*):
- **WhatsApp**: Mengirim langsung berkas PDF atau CSV ke nomor kontak Ibu, grup kelas, atau wali kelas.
- **Google Drive / Penyimpanan Lokal**: Menyimpan salinan arsip digital secara mandiri.
- **Cetak Langsung (WiFi / Bluetooth Printer)**: Mencetak dokumen fisik jika sekolah membutuhkan laporan bertanda tangan basah di atas kertas.
