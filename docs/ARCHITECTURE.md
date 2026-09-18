# System Architecture & Technical Specification
# Bendahara v2: Arsitektur Aplikasi & Rekayasa Ketahanan Data

## 1. Ikhtisar Arsitektur
Bendahara v2 mengadopsi pola **Clean Architecture (Layered)** yang digabungkan dengan prinsip **Offline-First Reactive**. Seluruh data disimpan dan diproses secara lokal di perangkat ponsel siswa, menjamin operasional penuh tanpa jaringan internet sekolah serta menjaga integritas pembukuan selama rentang waktu 6 tahun (SMP hingga SMA).

```
+-------------------------------------------------------------+
|                     PRESENTATION LAYER                      |
|  - UI Screens (Dashboard, Transaksi, Kas Mingguan, Laporan) |
|  - State Notifiers / Controllers (Riverpod / BLoC)          |
|  - Validasi Input & Pencegahan Human Error                  |
+-------------------------------------------------------------+
                              |
+-------------------------------------------------------------+
|                        DOMAIN LAYER                         |
|  - Core Entities (Kelas, Siswa, Transaksi, IuranMingguan)   |
|  - Use Cases / Services (HitungSaldo, EksporLaporan, dsb)   |
|  - Aturan Bisnis Pembukuan Sekolah                          |
+-------------------------------------------------------------+
                              |
+-------------------------------------------------------------+
|                         DATA LAYER                          |
|  - Repositori Konkret (TransactionRepository, etc)          |
|  - Drift DAO & Query Engine (Type-safe SQLite)              |
|  - File Storage Service (Foto Bukti Nota & Berkas PDF)      |
|  - Backup / Restore Service (Zip Engine + Checksum)         |
+-------------------------------------------------------------+
                              |
+-------------------------------------------------------------+
|                     PERSISTENCE / OS                        |
|  - SQLite3 Engine (WAL Mode, Foreign Key Enforcement)       |
|  - File System (Local App Documents Directory)              |
|  - OS Share Sheet (WhatsApp, Email, Drive, Print)           |
+-------------------------------------------------------------+
```

---

## 2. Pemilihan Teknologi (Technology Stack)

| Komponen | Pilihan Teknologi | Rationale & Alasan Pemilihan |
|---|---|---|
| **Framework** | Flutter 3.47+ / Dart 3.13+ | Ekosistem cross-platform stabil, rendering 60-120 fps mulus, akses native langsung tanpa jembatan web view. |
| **State Management** | Flutter Riverpod | Type-safe, reaktif, mudah diuji (*unit testing*), tanpa boilerplate berlebih, lifecycle terkelola rapi. |
| **Local Database Engine** | SQLite via **Drift** (`sqlite3_flutter_libs`) | Menyediakan abstraksi type-safe penuh di Dart, auto-migrasi skema versi, query reactive stream, dan performa tinggi untuk ribuan data. |
| **Document Generator** | `pdf` + `printing` | Rendering PDF vektor presisi, siap cetak atau dibagikan ke WhatsApp tanpa memerlukan koneksi server. |
| **Spreadsheet Engine** | `csv` + `excel` | Ekspor tabel raw data untuk dibuka di Microsoft Excel atau Google Sheets oleh orang tua. |
| **Penyimpanan Berkas** | `path_provider` + kompresi lokal | Menyimpan foto nota/struk secara lokal dengan kompresi terstandar (maks 300KB per foto) agar hemat penyimpanan ponsel. |
| **Pencadangan (Backup)** | `archive` (Zip Engine) | Mengemas berkas database SQLite dan folder gambar menjadi satu berkas cadangan berekstensi `.bhz` (Bendahara Archive) terverifikasi SHA-256. |
| **Keamanan Perangkat** | `local_auth` / `flutter_secure_storage` | Autentikasi biometrik (sidik jari/wajah) atau PIN 4 angka untuk melindungi catatan dari teman kelas yang usil. |

---

## 3. Strategi Ketahanan Data 6 Tahun (Durability & Scalability Strategy)

Untuk memastikan aplikasi tidak melambat dan data tidak rusak dari kelas 7 SMP sampai lulus SMA:

### 3.1 Konfigurasi Mesin SQLite Tangguh
- **WAL Mode (Write-Ahead Logging)**:
  ```sql
  PRAGMA journal_mode = WAL;
  ```
  Memungkinkan pembacaan (*read*) dan penulisan (*write*) berjalan simultan tanpa saling mengunci (*non-blocking concurrency*), serta melindungi basis data dari korupsi jika ponsel tiba-tiba mati atau kehabisan baterai saat menulis data.
- **Integritas Relasional Keras**:
  ```sql
  PRAGMA foreign_keys = ON;
  PRAGMA synchronous = NORMAL;
  ```
  Menolak transaksi tanpa relasi yang sah, mencegah terciptanya *orphan records*.
- **Indexing Strategis**:
  Index dipasang pada kolom pencarian utama: `academic_year_id`, `transaction_date`, `category_id`, dan `student_id`.

### 3.2 Isolasi Periode Akademik (Academic Year Partitioning)
- Seluruh tabel transaksi dan iuran mingguan mengacu pada `academic_year_id`.
- Saat siswa naik kelas (misal dari Kelas 7A ke Kelas 8A), sistem tidak menghapus data lama. Sistem mengarsipkan periode sebelumnya dan membuka lembaran periode baru.
- Query default hanya memuat data tahun ajaran aktif, sehingga query tetap secepat kilat (*sub-10ms*) walau sudah tersimpan riwayat bertahun-tahun.
- Modul laporan menyediakan opsi lintas tahun ajaran untuk melihat seluruh arsip ("Semua Rentang").

### 3.3 Penanganan Foto Nota
- Foto nota tidak disimpan sebagai BLOB di database SQLite (mencegah database membengkak).
- Foto disimpan di subdirektori terisolasi `app_docs/receipts/YYYY-MM/` dengan nama berkas UUID.
- Di database, hanya path relatif yang disimpan.
- Jika foto nota dihapus oleh pengguna, berkas fisik ikut dibersihkan (*garbage collection*).

---

## 4. Pola Aliran Data (Data Flow Pattern)

### 4.1 Pencatatan Transaksi Baru
1. Pengguna memasukkan data transaksi di form (`TransactionFormScreen`).
2. Controller melakukan sanitasi dan validasi (nominal > 0, tanggal valid, kategori terdaftar).
3. Controller memanggil `TransactionRepository.insertTransaction()`.
4. Drift mengeksekusi insert di SQLite di dalam blok transaksi atomik (`database.transaction()`).
5. Drift Stream memicu pembaruan reaktif ke UI Dashboard dan Riwayat seketika.

### 4.2 Pembuatan Laporan PDF Supervisi
1. Pengguna/Orang tua memilih rentang waktu (1 Bulan, 3 Bulan, 1 Tahun, atau Semua Rentang).
2. `ReportService` menarik data transaksi dan iuran sesuai rentang dari database lokal.
3. `ReportService` menghitung total kas masuk, total kas keluar, saldo akhir, dan rekap partisipasi siswa.
4. `PdfGenerator` merangkai dokumen PDF berbasis vektor standar dokumen resmi.
5. Berkas PDF disimpan sementara di direktori *cache* dan dipanggilkan antarmuka berbagi OS (`share_plus`) untuk dikirim langsung ke nomor WhatsApp orang tua atau disimpan ke Google Drive.
