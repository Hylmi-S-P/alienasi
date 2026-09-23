# Audit Bug & Edge Case — Bendahara Kelas v2

Dihasilkan: sesi audit penuh atas 41 file `.dart` di `lib/` (14.271 baris, `HEAD = b44f712`).
Metode: pembacaan baris-per-baris + verifikasi silang terhadap test suite (`test/`).

> Status per file ditandai: **[FIXED]** di-commit sesi ini, **[OPEN]** belum diperbaiki.

---

## A. Bug Tingkat Tinggi (pengaruh ke data / akurasi keuangan)

### A1. [FIXED] Fallback kategori rekonsiliasi tanpa filter `type`
- **File:** `lib/data/repositories/dues_repository.dart` (fungsi `reconcileIntoGeneralCash`)
- **Gejala:** Jika pengguna me-rename kategori "Uang Kas Rutin" lewat *Kelola Kategori* (dialog mengizinkan rename), `incomeCategory` menjadi `null` lalu fallback mengambil `(await _db.select(_db.categories).get()).first.id` — kategori pertama **tanpa filter `type == 'income'`** dan tanpa `orderBy`. Transaksi kas masuk hasil rekonsiliasi bisa tercatat dengan kategori pengeluaran → salah di buku kas, filter UI, dan laporan.
- **Perbaikan (sesi ini):** Query fallback kini dibatasi `type == 'income'` dan diurutkan `createdAt ASC` (kategori bawaan pertama). Jika tidak ada kategori income sama sekali, dilempar `StateError` yang jelas.

### A2. [FIXED] Grafik "1 Tahun" menjumlahkan lintas tahun kalender
- **File:** `lib/presentation/widgets/financial_chart_card.dart` (`_groupTransactionsIntoBuckets`, case `oneYear`)
- **Gejala:** Filter lama hanya mengecek `dt.month == targetMonthNum`. Untuk rentang yang melintasi tahun (misal "1 Tahun" = 15 Jan 2025 s.d. 15 Jan 2026), transaksi **Jan 2025 dan Jan 2026 keduanya dijumlah ke batang "Jan"** → grafik ganda-hitung.
- **Perbaikan (sesi ini):** Tambah kondisi `dt.year == refDate.year`, sehingga batang merepresentasikan tahun referensi saja (tahun terkini / tahun transaksi terbaru jika seluruh data historis).
- **Catatan test:** `test/revisions_v2_test.dart:668-727` hanya memverifikasi label bulan (tidak memverifikasi agregat), sehingga perbaikan ini tidak merusak test.

### A3. [OPEN] Tarif tunggakan tidak konsisten dengan deteksi lunas
- **File:** `lib/domain/services/dues_arrears_service.dart:295-297, 324-325`
- **Gejala:** Status lunas dilihat dari `payment.amountPaid >= period.targetAmount` (tarif **periode**), tetapi nominal tunggakan dihitung memakai `academicYear.defaultDuesAmount` (tarif **tahun ajaran**). Jika tarif kas naik di tengah periode (misal 2.000 → 5.000), siswa yang membayar sesuai tarif lama dianggap lunas oleh cek satu tetapi tunggakannya dihitung pakai tarif baru → laporan audit terlalu besar.
- **Rekomendasi:** Hitung `totalArrearsAmount` sebagai `Σ period.targetAmount` per periode tertunggak, bukan `unpaidCount × defaultDuesAmount`.

### A4. [OPEN] Minggu ke-5 "melorot" ke tanggal 28
- **File:** `lib/core/utils/date_formatter.dart` (`tryParsePeriodDate`, cabang weekly) + `lib/data/repositories/dues_repository.dart:105-118`
- **Gejala:** Label dibuat dengan `weekNumber = ((day-1) ~/ 7) + 1`, sehingga tanggal 29–31 = "Minggu 5". Parse balik: `((5-1)*7+1).clamp(1,28)` = **28**. `_getOrCreateActivePeriodInternal` aktif menimpa `dueDate` bila beda hari → periode yang dibuat tanggal 29/30/31 di-rewrite ke 28. Kalender menandai minggu yang salah; urutan/rentang periode bergeser.
- **Rekomendasi:** Sertakan tanggal eksplisit pada label minggu ke-5 (misal `Minggu 5 (29 Sep - 30 Sep)`), atau jangan menimpa `dueDate` jika perbedaannya hanya artefak clamp.

### A5. [FIXED] `createAcademicYear` tidak atomik
- **File:** `lib/data/repositories/academic_year_repository.dart`
- **Gejala:** Deaktivasi tahun aktif lama (`UPDATE ... isActive=false`) dan `INSERT` tahun baru **tidak dalam satu transaksi**. Jika insert gagal (disk penuh, dsb.), aplikasi terjebak tanpa tahun aktif → semua layar kosong dan onboarding tidak otomatis muncul kembali.
- **Perbaikan (sesi ini):** Kedua operasi dibungkus dalam `_db.transaction(...)`.

### A6. [OPEN] `DuesPeriodSummary.totalTarget` menggelembung untuk periode lama
- **File:** `lib/data/repositories/dues_repository.dart:207-232` (`watchPeriodSummary`)
- **Gejala:** `watchStudentDuesList` menyisihkan siswa non-aktif yang *belum* lunas, tetapi `totalTarget = totalStudents × targetAmount` menghitung **semua siswa yang tampil** (termasuk siswa non-aktif yang sudah lunas). Setelah siswa dikeluarkan di tengah jalan, target periode lama yang sudah lunas ikut digelembungkan → prosentase koleksi tampak lebih rendah dari kenyataan.
- **Rekomendasi:** Hitung `totalTarget` sebagai `Σ (targetAmount)` hanya untuk siswa yang memang masih *tertagih* pada periode tersebut, atau simpan snapshot `targetStudentCount` per periode.

### A7. [OPEN] Ekspor PDF/Excel/CSV bisa dibuat dari snapshot kosong
- **File:** `lib/presentation/screens/supervision_report_screen.dart:156, 208, 239`
- **Gejala:** Ketiga handler ekspor memakai `ref.read(reportTransactionsProvider).value ?? []`. Jika stream masih loading saat tombol ditekan, laporan dibuat dari list kosong tanpa peringatan — pengguna bisa membagikan PDF "nihil" yang terlihat sah (ringkasan TOTAL 0, halaman rapi).
- **Rekomendasi:** Blokir ekspor saat `reportTransactionsProvider` masih `isLoading`, atau tunggu `future` sampai selesai sebelum generate.

---

## B. Bug/Edge Case Tingkat Menengah

### B1. [OPEN] Foto nota bisa tersimpan ke `Directory.systemTemp`
- **File:** `lib/domain/services/receipt_storage_service.dart:34-36`
- Jika `warmUpCache()` gagal (izin storage, emulator awal), `_appDocsDir` jatuh ke `Directory.systemTemp`. Foto nota "permanen" disimpan di temp yang bisa dibersihkan OS kapan saja → lampiran laporan PDF hilang diam-diam.
- **Rekomendasi:** Saat cache belum siap, kembalikan `null` dari `writeReceiptBytes` dan tampilkan pesan error ke pengguna, jangan simpan ke temp.

### B2. [OPEN] File foto lama jadi sampah setelah restore
- **File:** `lib/domain/services/backup_restore_service.dart:379-405`
- Restore menulis foto dengan UUID baru lalu mengubah `receipt_image_path` transaksi. File lama tidak dihapus, dan `garbageCollectUnreferenced` **tidak pernah dipanggil dari mana pun** (0 pemanggil di codebase). Direktori receipts membengkak tanpa batas. Selain itu, `AppDatabase.clearAllData()` (Akhiri Jabatan) hanya membersihkan tabel DB — **tidak** membersihkan file nota lama.
- **Rekomendasi:** (a) Panggil `garbageCollectUnreferenced({})` setelah `clearAllData()`. (b) Jalankan GC berkala dengan referensi dari seluruh tabel.

### B3. [OPEN] Ekspor menghasilkan nama file yang bisa bertabrakan dengan karakter non-ASCII
- **File:** `lib/domain/services/backup_restore_service.dart`, `end_term_dialog.dart`, `supervision_report_screen.dart`
- `cleanName = name.replaceAll(RegExp(r'[^\w\s]+'), '')` menghapus tanda baca tetapi mempertahankan spasi → diubah ke underscore. Aman untuk sebagian besar kasus. Namun nama kelas seperti `Kelas 7A - SMP Negeri 1` menghasilkan `Kelas_7A__SMP_Negeri_1` (double underscore). Bukan bug kritis, hanya estetika nama berkas.

### B4. [OPEN] Nomor absen fallback diam-diam ke default
- **File:** `lib/presentation/screens/dialogs/new_student_dialog.dart:53`
- `int.tryParse(_numberController.text) ?? widget.defaultAttendanceNumber` — jika pengguna paste teks non-numerik (keyboard numerik Android hanya *saran*, bukan jaminan), nilai fallback ke `allItems.length + 1` tanpa pesan error. Siswa tersimpan dengan absen salah.
- **Rekomendasi:** Tambahkan `inputFormatters: [FilteringTextInputFormatter.digitsOnly]` pada field nomor absen.

### B5. [OPEN] Restore tidak meng-invalidate seluruh state provider
- **File:** `lib/presentation/screens/dialogs/backup_restore_dialog.dart:290-296` vs `end_term_dialog.dart:358-367`
- `end_term_dialog._finishAndProceedToOnboarding` membersihkan `selectedReportYearIdProvider` dan `periodOffsetProvider`, tetapi `_executeRestore` tidak. Pengguna yang sedang melihat arsip tahun lama lalu me-restore tahun itu akan melihat data kacau dari state basi.
- **Rekomendasi:** Samakan daftar invalidate antara restore dan end-term.

### B6. [OPEN] `allTime` pada grafik tidak benar-benar "seluruh arsip"
- **File:** `lib/presentation/widgets/financial_chart_card.dart:636-682` + `lib/presentation/providers/app_providers.dart:291-391`
- Label rentang adalah "Semua Tahun (Seluruh Arsip)" tetapi data berasal dari `reportTransactionsProvider` yang terikat satu `academicYearId` (tahun aktif atau yang dipilih). Grafik menjanjikan arsip lintas kelas, tetapi hanya menampilkan kelas terpilih.
- **Rekomendasi:** Ubah label menjadi "Seluruh Riwayat Kelas Ini", atau buat query lintas tahun ajaran.

### B7. [OPEN] `Navigator.pop` lalu `push` dari context dialog
- **File:** `lib/presentation/screens/all_transactions_screen.dart:36-50`
- `_openEditTransaction` memanggil `Navigator.of(context).pop()` untuk menutup dialog detail, lalu langsung `push` dari `context` yang sama. Keduanya dijadwalkan pada frame yang sama; di sebagian versi Flutter ini memicu "Looking up a deactivated widget's ancestor". 
- **Rekomendasi:** Jadikan `async`, tambahkan `if (!mounted) return;` setelah pop, lalu push dengan `context` layar (bukan context dialog).

---

## C. Catatan yang Diverifikasi Bukan Bug

- **`pdf_report_service` fixed column width** — `pw.TableHelper.fromTextArray` auto-wrap teks panjang; tidak ada risiko overflow kolom. *(Menarik kembali dugaan sementara #17.)*
- **Validasi tahun ajaran** — `class_setup_dialog.dart:249-262` memeriksa format `YYYY/YYYY` dan `end > start`, tetapi memang tidak mencegah rentang > 1 tahun (misal 2026/2028). Ini **pilihan desain** yang memungkinkan kelas akselerasi, bukan bug.
- **`togglePaymentStatus` vs `markBatchAsPaid`** — UI tab Kas Siswa hanya memakai jalur batch + reconcile; `togglePaymentStatus` tidak terpanggil dari layar mana pun. Bukan bug, tetapi dead code yang layak dipangkas.
- **Tidak ada pemanggil `garbageCollectUnreferenced`** — dikonfirmasi via grep (hanya definisi di `receipt_storage_service.dart:171`).

---

## D. Rencana Tindak Lanjut yang Disarankan

Prioritas perbaikan berikutnya (estimasi kecil, dampak besar):
1. **A3** — hitung tunggakan per `period.targetAmount`.
2. **A7** — blokir ekspor saat provider loading.
3. **B2** — integrasikan `garbageCollectUnreferenced` ke `clearAllData`.
4. **A4** — stabilkan label minggu ke-5 agar round-trip parse tidak menggeser tanggal.
