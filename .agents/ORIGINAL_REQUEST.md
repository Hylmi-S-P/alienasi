# Original User Request

## Initial Request — 2026-09-20T13:03:54Z

Enhance the Flutter class treasury application (`Bendahara Kelas`) with a dedicated full transaction history screen with search and category filtering, dashboard recent recording activity sorted by creation timestamp (`createdAt DESC`), monthly-partitioned PDF financial statements with highlighted red expense rows, a dedicated student dues arrears audit sheet with period ranges and amounts, and an activity-driven holiday rule for daily dues (weekends strictly excluded; weekdays with zero collections automatically treated as holidays).

Working directory: D:\project\bendehara v2
Integrity mode: development

## Requirements

### R1. Halaman Khusus Semua Riwayat Transaksi (AllTransactionsScreen)
- Menyediakan tombol navigasi jelas pada tab Laporan (misalnya *"Lihat Semua Riwayat (N Transaksi) >"*) untuk membuka halaman khusus baru (`AllTransactionsScreen`).
- Halaman ini memuat seluruh riwayat transaksi tanpa batas pemotongan 10 data.
- Dilengkapi dengan fitur:
  - Bilah pencarian (*search bar*) langsung untuk memfilter transaksi berdasarkan judul dan deskripsi.
  - Filter chip kategori (Semua, Kas Masuk, Kas Keluar, atau per kategori spesifik).
  - Tampilan ringkasan total mutasi hasil filter pencarian secara dinamis.

### R2. Dashboard "Riwayat Pencatatan Terkini" (Urutan Input Sistem `createdAt DESC`)
- Mengubah logika dan tampilan kartu aktivitas di Dashboard dari sekadar filter tanggal transaksi menjadi **"Riwayat Pencatatan Terkini"** (*Recent Recording Activity*).
- Diurutkan berdasarkan waktu input bendahara (`ORDER BY createdAt DESC`), sehingga aksi pencatatan apa pun yang baru saja dilakukan bendahara (termasuk pencatatan kas mundur / *backdated* seperti input kas bulan Juli di waktu sekarang) langsung muncul di urutan paling atas Dashboard.
- Menampilkan informasi tanggal transaksi fisik dan tanggal pencatatan secara transparan jika berbeda.

### R3. Laporan PDF Terpartisi Bulanan & Sorotan Pengeluaran Merah
- Memperbarui format tabel pada generator laporan PDF (`PdfReportService`):
  - Jika laporan mencakup rentang transaksi lebih dari satu bulan atau multi-bulan, transaksi dikelompokkan secara rapi per sekat bulan kalender (contoh tajuk pemisah: `BULAN JULI 2026`, `BULAN AGUSTUS 2026`, dst.) sehingga pembacaan tidak sesak dan nyaman diaudit.
  - Setiap baris mutasi pengeluaran kas wajib diberi sorotan visual warna merah (*red highlight* pada teks nominal atau badge jenis transaksi) agar langsung terlihat oleh wali kelas dan wali murid.

### R4. Halaman / Bagian Audit Khusus Rincian Tunggakan Kas Siswa
- Menambahkan halaman atau seksi khusus pada berkas ekspor PDF untuk **Rekapitulasi Tunggakan Kas Siswa**:
  - Daftar hanya siswa yang belum melunasi kewajiban kasnya (nomor absen dan nama siswa).
  - Rincian rentang periode yang belum dibayar (misal: *"Dari 14 Juli s.d. 18 Juli"* untuk harian, atau *"Minggu 2 Juli s.d. Minggu 4 Juli"* untuk mingguan).
  - Keterangan tarif kas per periode (misal: `Rp2.000 / hari` atau `Rp5.000 / minggu`).
  - Total nominal tunggakan per siswa yang bersangkutan.
  - Baris ringkasan total akumulasi kas kelas yang belum tertagih.

### R5. Aturan Bebas Kas Akhir Pekan & Hari Libur Khusus Kas Harian Siswa
- **Khusus Kas Harian Siswa (Dues)**:
  - **Sabtu & Minggu**: Ditetapkan secara mutlak sebagai **Hari Libur Bebas Kas Siswa**. Sistem tidak membebankan tagihan kas harian ataupun mencatat tunggakan siswa pada hari Sabtu dan Minggu.
  - **Tanggal Merah / Libur Sekolah (Senin s.d. Jumat)**: Menggunakan logika otomatis berbasis aktivitas. Jika ada minimal 1 siswa dicatat membayar kas, hari tersebut dianggap hari efektif kas. Jika 0 pencatatan, hari tersebut otomatis diakui sebagai hari libur bebas kas siswa tanpa membebani tunggakan.
- **Transaksi Bebas / Kas Umum Kelas Tetap 100% Aktif Kapan Saja**:
  - Aturan hari libur di atas **hanya berlaku untuk penarikan kas harian siswa**.
  - Pencatatan transaksi umum (pemasukan sumbangan/bazar, pengeluaran belanja ATK, konsumsi lomba di akhir pekan/hari Minggu, dll.) **tetap dapat dicatat kapan saja (termasuk hari Sabtu, Minggu, dan tanggal merah) dan tetap dihitung 100% ke dalam mutasi saldo kas kelas secara penuh**.

## Acceptance Criteria

### Riwayat Transaksi & Dashboard
- [ ] Tersedia tombol di tab Laporan yang membuka `AllTransactionsScreen`.
- [ ] Pengguna dapat mencari transaksi berdasarkan kata kunci pada judul/keterangan secara langsung.
- [ ] Pengguna dapat memfilter riwayat transaksi berdasarkan jenis (Masuk / Keluar) dan kategori.
- [ ] Transaksi yang dicatat mundur (*backdated*) langsung muncul di daftar kartu aktivitas terkini Dashboard berkat pengurutan `createdAt DESC`.

### Format Laporan PDF
- [ ] Laporan PDF membagi tabel mutasi kas berdasarkan bulan transaksi dengan sub-header bulan yang rapi.
- [ ] Baris kas keluar pada tabel PDF disorot dengan warna merah kontras.
- [ ] Terdapat seksi atau halaman audit khusus rekap tunggakan siswa yang memuat rentang waktu belum bayar, tarif kas aktif, dan total kewajiban per siswa.

### Aturan Hari Libur Kas Harian & Fleksibilitas Transaksi Umum
- [ ] Hari Sabtu dan Minggu tidak memiliki tagihan kas harian dan tidak masuk dalam daftar tunggakan siswa.
- [ ] Hari kerja (Senin-Jumat) yang memiliki 0 catatan pembayaran kas tidak dianggap sebagai tunggakan (diakui sebagai hari libur bebas kas).
- [ ] Transaksi umum pemasukan dan pengeluaran kas kelas tetap dapat dicatat di hari apa pun (termasuk hari Sabtu, Minggu, atau tanggal merah) dan tetap dihitung 100% ke dalam mutasi saldo kas kelas.

### Kualitas Kode, Pengujian, & Kompilasi
- [ ] Analisis statis `flutter analyze` menghasilkan 0 error dan 0 warning.
- [ ] Seluruh unit test & widget test (`flutter test`) lulus 100%.
- [ ] Berkas APK Release (`Bendahara-Kelas-Release.apk`) berhasil dikompilasi dengan kenaikan `versionCode` untuk in-place update langsung tanpa uninstall.
