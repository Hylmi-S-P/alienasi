# Product Requirements Document (PRD)
# Bendahara v2: Aplikasi Pencatatan Kas Kelas & Supervisi Orang Tua

## 1. Ringkasan Eksekutif
Bendahara v2 adalah aplikasi mobile berbasis Flutter (offline-first) yang dirancang khusus untuk membantu siswa SMP (dimulai dari kelas 7) dalam mengelola keuangan kas kelas secara rapi, akurat, dan transparan. Aplikasi ini dilengkapi fitur supervisi bagi orang tua/wali melalui ekspor laporan keuangan berkala (rentang 1 bulan, 3 bulan, 1 tahun, hingga seluruh rentang waktu). 

Aplikasi dirancang dengan arsitektur penyimpanan lokal tangguh (SQLite dengan mode Write-Ahead Logging) agar sanggup menampung ribuan transaksi selama minimal 6 tahun (dari kelas 7 SMP hingga kelas 12 SMA) tanpa penurunan performa atau risiko kehilangan data.

---

## 2. Latar Belakang & Masalah
- **Beban Bendahara Usia Sekolah**: Siswa SMP kelas 7 yang ditunjuk menjadi bendahara kelas sering mengalami kesulitan mencatat iuran harian/mingguan dan pengeluaran menggunakan buku tulis fisik, yang rentan hilang, robek, atau basah.
- **Kebutuhan Pengawasan Orang Tua**: Orang tua ingin memastikan anak mengelola amanah uang kelas dengan benar, transparan, dan tidak terjadi selisih kas yang membingungkan anak.
- **Keterbatasan Aplikasi Keuangan Umum**: Aplikasi akuntansi bisnis di pasaran terlalu rumit (istilah debit/kredit, jurnal penyesuaian, bagan akun), sarat iklan, atau mengandalkan server online pihak ketiga yang berisiko tutup sewaktu-waktu.

---

## 3. Profil Pengguna (User Persona)

### Persona 1: Adik (Bendahara Kelas - Siswa Kelas 7 SMP)
- **Karakteristik**: Usia 12-13 tahun, menggunakan smartphone Android/iOS, terbiasa dengan antarmuka simpel dan cepat.
- **Kebutuhan**:
  - Mencatat siapa saja teman sekelas yang sudah atau belum membayar uang kas mingguan dengan sekali sentuh.
  - Mencatat pengeluaran kelas (misal: beli spidol, fotokopi lembar tugas, sapu lidi, jenguk teman sakit) beserta foto nota fisik.
  - Mengetahui sisa saldo kas kelas saat ini secara akurat dan seketika.
- **Tantangan**: Tidak memahami istilah akuntansi rumit; butuh tombol yang jelas dan konfirmasi saat salah input.

### Persona 2: Ibu (Supervisor / Pengawas Keuangan)
- **Karakteristik**: Orang tua yang mengawasi akuntabilitas anak di rumah.
- **Kebutuhan**:
  - Melihat ringkasan kas kelas secara berkala tanpa harus mengambil alih perangkat anak seharian.
  - Menerima ekspor laporan berkala dalam format dokumen rapi (PDF/Excel) dengan rentang fleksibel (1 bulan, 3 bulan, 1 tahun, atau seluruh riwayat).
  - Melakukan pencocokan antara sisa uang tunai fisik di dompet kas dengan catatan aplikasi.

---

## 4. Ruang Lingkup & Kebutuhan Fungsional

### 4.1 Manajemen Periode Akademik & Kelas
- Pengguna dapat membuat wadah kelas/tahun ajaran (contoh: "Kelas 7A - 2026/2027", "Kelas 8A - 2027/2028").
- Data antar-tahun ajaran terisolasi rapi namun tetap dapat diakses dan diekspor dalam satu aplikasi.
- Perpindahan kelas tidak menghapus data historis kelas sebelumnya.

### 4.2 Manajemen Daftar Anggota Kelas
- Pengelolaan daftar nama siswa dan nomor absen.
- Status pembayaran kas per siswa per pertemuan/minggu (Centang cepat / Quick Check).
- Indikator tunggakan iuran per siswa yang mudah dipahami.

### 4.3 Pencatatan Transaksi (Uang Masuk & Uang Keluar)
- Formulir sederhana: Jenis (Masuk/Keluar), Nominal, Kategori, Keterangan, Tanggal, dan Lampiran Foto Nota (opsional).
- Kategori default yang relevan untuk sekolah:
  - *Pemasukan*: Uang Kas Rutin, Iuran Khusus (Jenguk Teman/Lomba), Sisa Kembalian, Donasi/Kas Awal.
  - *Pengeluaran*: Alat Kebersihan, Perlengkapan Belajar, Konsumsi Kelas, Santunan Teman, Dekorasi Kelas.
- Validasi nominal: Pencegahan salah ketik angka minus atau nol berlebih.
- Riwayat transaksi dengan filter tanggal, pencarian kata kunci, dan penanda status validasi.

### 4.4 Dashboard Ringkasan Finansial
- Tampilan saldo terkini (Total Kas Masuk, Total Kas Keluar, Sisa Saldo).
- Rekap iuran pekan berjalan.
- Daftar 5 transaksi terakhir.

### 4.5 Modul Supervisi Orang Tua & Ekspor Laporan
- Opsi filter periode laporan:
  1. **1 Bulan Terakhir** (Laporan bulanan untuk wali kelas dan orang tua).
  2. **3 Bulan Terakhir** (Laporan triwulan / tengah semester).
  3. **1 Tahun Penuh** (Laporan tahun ajaran / kenaikan kelas).
  4. **Semua Rentang** (Arsip komprehensif seluruh masa jabatan).
  5. **Rentang Khusus (Custom Date)** jika dibutuhkan tanggal tertentu.
- Format Ekspor:
  - **PDF Siap Cetak/Kirim**: Memuat header resmi kelas, nama bendahara, ringkasan saldo, tabel arus kas, dan kolom tanda tangan (Bendahara, Ketua Kelas, Mengetahui Orang Tua/Wali Kelas).
  - **Excel / CSV**: Untuk rekap tabel lanjutan jika orang tua ingin memeriksa di laptop.
- Pengiriman Cepat: Bagikan langsung melalui sistem berbagi perangkat (WhatsApp, Email, Google Drive, Print).

### 4.6 Pencadangan & Pemulihan (Backup & Restore)
- Ekspor berkas cadangan terenkripsi/zip berisi database dan foto nota ke memori lokal atau Google Drive.
- Fitur pemulihan data jika ponsel anak berganti baru saat naik kelas.

---

## 5. Kebutuhan Non-Fungsional

### 5.1 Daya Tahan & Ketahanan Data 6 Tahun (Scalability & Durability)
- **Kapasitas**: Mampu menampung 5.000+ transaksi tanpa lag (rata-rata 10 transaksi/minggu x 52 minggu x 6 tahun = ~3.120 transaksi).
- **Integritas Penyimpanan**: Menggunakan SQLite dengan SQLite WAL (Write-Ahead Logging) dan Foreign Key ON untuk mencegah kerusakan data akibat aplikasi ditutup mendadak.
- **Offline-First Mutlak**: Beroperasi 100% tanpa internet di sekolah. Tidak ada ketergantungan pada server pihak ketiga yang bisa mati.

### 5.2 Antarmuka & Aksesibilitas (Sesuai Standar Anti-Slop)
- Bebas dari elemen visual tanpa tujuan (tanpa gradien ungu generik, tanpa efek glow berlebihan).
- Target sentuh tombol minimal 48 x 48 dp untuk jemari remaja.
- Kontras teks memenuhi standar WCAG AA (rasio minimal 4.5:1).
- Bahasa pengantar natural bahasa Indonesia yang baku namun ramah (tanpa istilah akuntansi membingungkan).

### 5.3 Keamanan Data
- Opsi PIN/Biometrik sederhana agar teman sekelas tidak iseng mengubah angka catatan kas.
- Mode supervisor dengan PIN terpisah (opsional, jika orang tua menghendaki kunci pengaturan ekspor/arsip).
