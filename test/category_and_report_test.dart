import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/domain/services/pdf_report_service.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/widgets/financial_chart_card.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Category Management & Retention Rules', () {
    late AppDatabase db;
    late TransactionRepository txRepo;
    late AcademicYearRepository yearRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      txRepo = TransactionRepository(db);
      yearRepo = AcademicYearRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Bendahara dapat membuat kategori baru', () async {
      final created = await txRepo.createCategory(
        name: 'Sumbangan Buku Perpustakaan',
        type: 'income',
        colorHex: '#16A34A',
      );

      expect(created.name, 'Sumbangan Buku Perpustakaan');
      expect(created.type, 'income');
      expect(created.isDefault, false);

      final incomeCats = await txRepo.getCategoriesByType('income');
      expect(incomeCats.any((c) => c.name == 'Sumbangan Buku Perpustakaan'), isTrue);
    });

    test('Bendahara dapat mengedit nama kategori', () async {
      final created = await txRepo.createCategory(
        name: 'Fotokopi Awal',
        type: 'expense',
      );

      await txRepo.updateCategoryName(
        id: created.id,
        newName: 'Fotokopi & Modul Soal',
      );

      final cats = await txRepo.getCategoriesByType('expense');
      final updated = cats.firstWhere((c) => c.id == created.id);
      expect(updated.name, 'Fotokopi & Modul Soal');
    });

    test('Aturan Minimal 1 Kategori: Tidak bisa menghapus jika hanya ada 1 kategori', () async {
      // Kurangi kategori expense yang sudah di-seed otomatis sampai hanya tersisa 1 kategori
      final initialExpenses = await txRepo.getCategoriesByType('expense');
      for (var i = 0; i < initialExpenses.length - 1; i++) {
        await txRepo.deleteCategory(id: initialExpenses[i].id, type: 'expense');
      }

      final lastOne = (await txRepo.getCategoriesByType('expense')).single;

      // Mencoba menghapus kategori terakhir harus gagal dengan StateError
      expect(
        () async => await txRepo.deleteCategory(id: lastOne.id, type: 'expense'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Minimal harus ada 1 kategori yang dipertahankan'),
        )),
      );

      // Verifikasi kategori terakhir masih ada
      final cats = await txRepo.getCategoriesByType('expense');
      expect(cats.length, 1);
    });

    test('Bendahara dapat menghapus kategori jika > 1, dan transaksi dipindahkan ke kategori fallback', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Adik',
        supervisorName: 'Ibu',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      // Kurangi kategori expense sampai tersisa tepat 1 kategori sebagai baseline
      final initialExpenses = await txRepo.getCategoriesByType('expense');
      for (var i = 0; i < initialExpenses.length - 1; i++) {
        await txRepo.deleteCategory(id: initialExpenses[i].id, type: 'expense');
      }
      final fallbackCat = (await txRepo.getCategoriesByType('expense')).single;

      // Buat kategori kedua untuk diuji penghapusannya
      final catToDelete = await txRepo.createCategory(name: 'Alat Tulis Tambahan', type: 'expense');

      // Masukkan transaksi dengan catToDelete
      await txRepo.insertTransaction(
        academicYearId: year.id,
        categoryId: catToDelete.id,
        type: 'expense',
        amount: 25000,
        title: 'Beli Spidol Baru',
        transactionDate: DateTime(2026, 9, 1),
      );

      // Hapus catToDelete
      await txRepo.deleteCategory(id: catToDelete.id, type: 'expense');

      // Verifikasi catToDelete terhapus dan tersisa 1 kategori
      final remainingCats = await txRepo.getCategoriesByType('expense');
      expect(remainingCats.length, 1);
      expect(remainingCats.first.id, fallbackCat.id);

      // Verifikasi transaksi tidak hilang dan telah dialihkan ke fallbackCat
      final txs = await txRepo.getTransactionsByRange(
        academicYearId: year.id,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 10, 1),
      );
      expect(txs.length, 1);
      expect(txs.first.category.id, fallbackCat.id);
      expect(txs.first.transaction.amount, 25000);
    });

    test('deleteCategory mendeteksi type otomatis jika parameter type tidak diisi', () async {
      final initialExpenses = await txRepo.getCategoriesByType('expense');
      final cat = await txRepo.createCategory(name: 'Kategori Uji Auto Detect', type: 'expense');
      expect((await txRepo.getCategoriesByType('expense')).length, initialExpenses.length + 1);

      // Panggil deleteCategory tanpa menyertakan parameter type
      await txRepo.deleteCategory(id: cat.id);
      expect((await txRepo.getCategoriesByType('expense')).length, initialExpenses.length);
    });
  });

  group('PDF Report Service Test', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late TransactionRepository txRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      txRepo = TransactionRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('PDF Report terbentuk tanpa error tanpa header badge resmi dan tanpa tanda tangan', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 7A - SMP Negeri 1',
        grade: 7,
        treasurerName: 'Fajar',
        supervisorName: 'Ibu Rina',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      final cat = await txRepo.createCategory(name: 'Uang Kas', type: 'income');
      await txRepo.insertTransaction(
        academicYearId: year.id,
        categoryId: cat.id,
        type: 'income',
        amount: 100000,
        title: 'Iuran Kas',
        transactionDate: DateTime(2026, 9, 1),
      );

      final items = await txRepo.getTransactionsByRange(
        academicYearId: year.id,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 10, 1),
      );

      final pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: year,
        periodRangeTitle: '1 Bulan Terakhir',
        items: items,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(100));
      // PDF standard magic number '%PDF-'
      expect(pdfBytes[0], 0x25); // %
      expect(pdfBytes[1], 0x50); // P
      expect(pdfBytes[2], 0x44); // D
      expect(pdfBytes[3], 0x46); // F
    });
  });

  group('Academic Year Stream & Dropdown Resilience', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('watchAllYears memancarkan pembaruan saat kelas baru ditambahkan', () async {
      final stream = yearRepo.watchAllYears();

      expect(
        stream,
        emitsInOrder([
          isEmpty,
          hasLength(1),
          hasLength(2),
        ]),
      );

      await yearRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Fajar',
        supervisorName: 'Ibu',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await yearRepo.createAcademicYear(
        name: 'Kelas 8A',
        grade: 8,
        treasurerName: 'Fajar',
        supervisorName: 'Ibu',
        defaultDuesAmount: 5000,
        startDate: DateTime(2027, 7, 1),
        endDate: DateTime(2028, 6, 30),
      );
    });
  });

  group('Financial Chart & Historical Date Range Tests', () {
    testWidgets('FinancialChartCard mencakup transaksi hari ke-29 dan ke-30 tanpa terpotong', (tester) async {
      final now = DateTime.now();
      final year = AcademicYear(
        id: 'year_chart_test',
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Fajar',
        supervisorName: 'Pengawas',
        startDate: DateTime(now.year, 1, 1),
        endDate: DateTime(now.year, 12, 31),
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        isActive: true,
        createdAt: now,
      );
      final cat = Category(
        id: 'cat_chart',
        type: 'expense',
        name: 'Konsumsi',
        iconName: 'fastfood',
        colorHex: '#DC2626',
        isDefault: false,
        createdAt: now,
      );

      // Transaksi 29 hari yang lalu
      final tx29DaysAgo = Transaction(
        id: 'tx_29',
        academicYearId: year.id,
        categoryId: cat.id,
        type: 'expense',
        amount: 35000,
        title: 'Beli Kue',
        transactionDate: now.subtract(const Duration(days: 29)),
        createdAt: now,
        updatedAt: now,
      );

      final items = [
        TransactionWithCategory(transaction: tx29DaysAgo, category: cat, academicYear: year),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinancialChartCard(
              items: items,
              selectedRange: ReportDateRange.oneMonth,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pastikan chart me-render bar Mgg 1 dan nominal terakumulasi di arus kas bersih
      expect(find.text('Mgg 1'), findsOneWidget);
      expect(find.text('-Rp 35.000 (Defisit)'), findsOneWidget);
    });

    testWidgets('FinancialChartCard memvisualisasikan data historis masa lalu dengan benar', (tester) async {
      final pastDate = DateTime(2024, 5, 10);
      final pastYear = AcademicYear(
        id: 'year_past',
        name: 'Kelas 7A - 2024',
        grade: 7,
        treasurerName: 'Fajar',
        supervisorName: 'Pengawas',
        startDate: DateTime(2023, 7, 1),
        endDate: DateTime(2024, 6, 30),
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        isActive: false,
        createdAt: pastDate,
      );
      final cat = Category(
        id: 'cat_past',
        type: 'income',
        name: 'Uang Kas',
        iconName: 'payments',
        colorHex: '#16A34A',
        isDefault: false,
        createdAt: pastDate,
      );

      final pastTx = Transaction(
        id: 'tx_past_1',
        academicYearId: pastYear.id,
        categoryId: cat.id,
        type: 'income',
        amount: 150000,
        title: 'Iuran Kas 2024',
        transactionDate: pastDate,
        createdAt: pastDate,
        updatedAt: pastDate,
      );

      final items = [
        TransactionWithCategory(transaction: pastTx, category: cat, academicYear: pastYear),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinancialChartCard(
              items: items,
              selectedRange: ReportDateRange.oneMonth,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi bar dan saldo surplus ditampilkan untuk data historis
      expect(find.text('+Rp 150.000 (Surplus)'), findsOneWidget);
    });

    testWidgets('FinancialChartCard dapat menampilkan komposisi kategori Pemasukan dan Pengeluaran', (tester) async {
      final now = DateTime.now();
      final year = AcademicYear(
        id: 'year_cat_test',
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Fajar',
        supervisorName: 'Pengawas',
        startDate: DateTime(now.year, 1, 1),
        endDate: DateTime(now.year, 12, 31),
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        isActive: true,
        createdAt: now,
      );
      final catIncome = Category(
        id: 'cat_inc',
        type: 'income',
        name: 'Uang Kas Rutin',
        iconName: 'payments',
        colorHex: '#16A34A',
        isDefault: true,
        createdAt: now,
      );
      final catExpense = Category(
        id: 'cat_exp',
        type: 'expense',
        name: 'Beli ATK',
        iconName: 'shopping_bag',
        colorHex: '#DC2626',
        isDefault: true,
        createdAt: now,
      );

      final items = [
        TransactionWithCategory(
          transaction: Transaction(
            id: 'tx_inc_1',
            academicYearId: year.id,
            categoryId: catIncome.id,
            type: 'income',
            amount: 80000,
            title: 'Kas Rutin Siswa',
            transactionDate: now,
            createdAt: now,
            updatedAt: now,
          ),
          category: catIncome,
          academicYear: year,
        ),
        TransactionWithCategory(
          transaction: Transaction(
            id: 'tx_exp_1',
            academicYearId: year.id,
            categoryId: catExpense.id,
            type: 'expense',
            amount: 30000,
            title: 'Beli Spidol Papan',
            transactionDate: now,
            createdAt: now,
            updatedAt: now,
          ),
          category: catExpense,
          academicYear: year,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FinancialChartCard(
                items: items,
                selectedRange: ReportDateRange.oneMonth,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Beralih ke mode Kategori
      await tester.tap(find.text('Kategori'));
      await tester.pumpAndSettle();

      // Mode awal adalah Alokasi Pengeluaran
      expect(find.text('Alokasi Pengeluaran'), findsOneWidget);
      expect(find.text('Beli ATK'), findsOneWidget);

      // Ketuk toggle Masuk untuk beralih ke Sumber Pemasukan
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Sumber Pemasukan'), findsOneWidget);
      expect(find.text('Uang Kas Rutin'), findsOneWidget);
    });
  });

  group('Robustness & Bug Fix Verification', () {
    late AppDatabase db;
    late TransactionRepository txRepo;
    late AcademicYearRepository yearRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      txRepo = TransactionRepository(db);
      yearRepo = AcademicYearRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('deleteCategory dengan ID yang tidak ada kembali aman tanpa StateError', () async {
      // Tidak boleh melempar exception ketika menghapus id yang tidak ada
      await expectLater(
        txRepo.deleteCategory(id: 'non_existent_category_id'),
        completes,
      );
    });

    test('updateCategoryName memungkinkan pengubahan kapitalisasi huruf (casing)', () async {
      final cat = await txRepo.createCategory(name: 'fotokopi', type: 'expense');
      expect(cat.name, 'fotokopi');

      await txRepo.updateCategoryName(id: cat.id, newName: 'Fotokopi');
      final updated = (await txRepo.getCategoriesByType('expense')).firstWhere((c) => c.id == cat.id);
      expect(updated.name, 'Fotokopi');
    });

    test('updateAcademicYear memperbarui kelas yang sudah ada tanpa de-aktivasi', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Adik',
        supervisorName: 'Ibu',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await yearRepo.updateAcademicYear(
        id: year.id,
        name: 'Kelas 7A Unggulan',
        grade: 7,
        treasurerName: 'Adik Fajar',
        supervisorName: 'Ibu Rina',
        defaultDuesAmount: 7000,
      );

      final active = await yearRepo.getActiveYear();
      expect(active?.id, year.id);
      expect(active?.name, 'Kelas 7A Unggulan');
      expect(active?.treasurerName, 'Adik Fajar');
      expect(active?.defaultDuesAmount, 7000);
      expect(active?.isActive, true);

      final all = await yearRepo.getAllYears();
      expect(all.length, 1);
    });
  });
}
