import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/student_repository.dart';
import 'package:bendahara_app/data/repositories/dues_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/screens/all_transactions_screen.dart';
import 'package:bendahara_app/presentation/screens/supervision_report_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('AllTransactionsScreen Widget Tests', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late TransactionRepository txRepo;
    late StudentRepository studentRepo;
    late DuesRepository duesRepo;
    late AcademicYear activeYear;
    late List<Category> incomeCategories;
    late List<Category> expenseCategories;

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      txRepo = TransactionRepository(db);
      studentRepo = StudentRepository(db);
      duesRepo = DuesRepository(db);

      activeYear = await yearRepo.createAcademicYear(
        name: 'Kelas 8B',
        grade: 8,
        treasurerName: 'Zaskia',
        supervisorName: 'Ibu Guru',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      incomeCategories = await txRepo.getCategoriesByType('income');
      expenseCategories = await txRepo.getCategoriesByType('expense');
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildTestApp(Widget home) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
        ],
        child: MaterialApp(
          home: home,
        ),
      );
    }

    testWidgets('1. Displays full list without 10-item cap (15 transactions rendered)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;
      final catExpense = expenseCategories.first;

      // Insert 15 transactions
      for (int i = 1; i <= 15; i++) {
        final isIncome = i % 2 == 1;
        await txRepo.insertTransaction(
          academicYearId: activeYear.id,
          categoryId: isIncome ? catIncome.id : catExpense.id,
          type: isIncome ? 'income' : 'expense',
          amount: 10000 * i,
          title: 'Transaksi Item #$i',
          description: 'Keterangan transaksi ke-$i',
          transactionDate: DateTime(2026, 8, i),
        );
      }

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      // Screen title and subtitle
      expect(find.text('Semua Riwayat Transaksi'), findsOneWidget);
      expect(find.text('Kelas 8B'), findsOneWidget);

      // Verify count in summary card shows 15 transactions
      expect(find.text('15 dari 15 Transaksi'), findsOneWidget);

      // Transactions are ordered by transactionDate DESC, so #15 is at top, #1 is at bottom
      expect(find.text('Transaksi Item #15'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Transaksi Item #1'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Transaksi Item #1'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('2. Search bar filters by title & description in real time with clear button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;
      final catExpense = expenseCategories.first;

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome.id,
        type: 'income',
        amount: 50000,
        title: 'Sumbangan Seragam Olahraga',
        description: 'Bantuan dari alumni',
        transactionDate: DateTime(2026, 8, 10),
      );

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExpense.id,
        type: 'expense',
        amount: 25000,
        title: 'Beli Kertas HVS',
        description: 'Untuk lembar ujian harian semester',
        transactionDate: DateTime(2026, 8, 11),
      );

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExpense.id,
        type: 'expense',
        amount: 15000,
        title: 'Konsumsi Rapat Pengurus',
        description: 'Snack rapat bendahara dan sekretaris',
        transactionDate: DateTime(2026, 8, 12),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      expect(find.text('3 dari 3 Transaksi'), findsOneWidget);

      // Search by title
      await tester.enterText(find.byType(TextField), 'Seragam');
      await tester.pumpAndSettle();

      expect(find.text('1 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Sumbangan Seragam Olahraga'), findsOneWidget);
      expect(find.text('Beli Kertas HVS'), findsNothing);
      expect(find.text('Konsumsi Rapat Pengurus'), findsNothing);

      // Search by description
      await tester.enterText(find.byType(TextField), 'semester');
      await tester.pumpAndSettle();

      expect(find.text('1 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Beli Kertas HVS'), findsOneWidget);
      expect(find.text('Sumbangan Seragam Olahraga'), findsNothing);

      // Clear button restores full list
      final clearButton = find.byIcon(Icons.clear_rounded);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.text('3 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Sumbangan Seragam Olahraga'), findsOneWidget);
      expect(find.text('Beli Kertas HVS'), findsOneWidget);
      expect(find.text('Konsumsi Rapat Pengurus'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('3. Horizontal category choice chips filter by type and specific category', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome1 = incomeCategories.first;
      final catExpense1 = expenseCategories.first;

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome1.id,
        type: 'income',
        amount: 100000,
        title: 'Iuran Kas Rutin Minggu 1',
        transactionDate: DateTime(2026, 8, 1),
      );

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExpense1.id,
        type: 'expense',
        amount: 30000,
        title: 'Beli Spidol Whiteboard',
        transactionDate: DateTime(2026, 8, 2),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      expect(find.text('2 dari 2 Transaksi'), findsOneWidget);

      // Tap 'Kas Masuk' choice chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Kas Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('1 dari 2 Transaksi'), findsOneWidget);
      expect(find.text('Iuran Kas Rutin Minggu 1'), findsOneWidget);
      expect(find.text('Beli Spidol Whiteboard'), findsNothing);

      // Tap 'Kas Keluar' choice chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Kas Keluar'));
      await tester.pumpAndSettle();

      expect(find.text('1 dari 2 Transaksi'), findsOneWidget);
      expect(find.text('Beli Spidol Whiteboard'), findsOneWidget);
      expect(find.text('Iuran Kas Rutin Minggu 1'), findsNothing);

      // Tap 'Semua' choice chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
      await tester.pumpAndSettle();

      expect(find.text('2 dari 2 Transaksi'), findsOneWidget);
      expect(find.text('Iuran Kas Rutin Minggu 1'), findsOneWidget);
      expect(find.text('Beli Spidol Whiteboard'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('4. Dynamic mutations summary card updates live on filtering', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;
      final catExpense = expenseCategories.first;

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome.id,
        type: 'income',
        amount: 150000,
        title: 'Pemasukan Kas Utama',
        transactionDate: DateTime(2026, 8, 1),
      );

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExpense.id,
        type: 'expense',
        amount: 50000,
        title: 'Pengeluaran ATK Lomba',
        transactionDate: DateTime(2026, 8, 2),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      // Initial Summary: Income = 150.000, Expense = 50.000, Net = +100.000
      expect(find.text('+Rp 150.000'), findsWidgets);
      expect(find.text('-Rp 50.000'), findsWidgets);
      expect(find.text('+Rp 100.000'), findsWidgets);

      // Filter by typing 'Lomba'
      await tester.enterText(find.byType(TextField), 'Lomba');
      await tester.pumpAndSettle();

      // Now only expense is shown: Income = 0, Expense = 50.000, Net = -50.000
      expect(find.text('+Rp 0'), findsOneWidget);
      expect(find.text('-Rp 50.000'), findsWidgets);
      expect(find.text('1 dari 2 Transaksi'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('5. Displays clean empty state and Reset Filter button works', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome.id,
        type: 'income',
        amount: 50000,
        title: 'Kas Rutin Siswa',
        transactionDate: DateTime(2026, 8, 1),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      // Enter query with zero matches
      await tester.enterText(find.byType(TextField), 'tidak_ada_hasil_xyz');
      await tester.pumpAndSettle();

      expect(find.text('Tidak Ada Transaksi Ditemukan'), findsOneWidget);
      expect(find.text('Reset Filter'), findsOneWidget);

      // Tap 'Reset Filter'
      await tester.tap(find.text('Reset Filter'));
      await tester.pumpAndSettle();

      expect(find.text('Kas Rutin Siswa'), findsOneWidget);
      expect(find.text('Tidak Ada Transaksi Ditemukan'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('6. SupervisionReportScreen Section 5 banner navigates to AllTransactionsScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome.id,
        type: 'income',
        amount: 25000,
        title: 'Iuran Kebersihan',
        transactionDate: DateTime(2026, 8, 15),
      );

      await tester.pumpWidget(buildTestApp(const SupervisionReportScreen()));
      await tester.pumpAndSettle();

      // Scroll to Section 5
      final bannerFinder = find.textContaining('Lihat Semua Riwayat');
      await tester.scrollUntilVisible(
        bannerFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(bannerFinder, findsOneWidget);

      // Tap navigation banner
      await tester.tap(bannerFinder);
      await tester.pumpAndSettle();

      // Verify AllTransactionsScreen is pushed
      expect(find.byType(AllTransactionsScreen), findsOneWidget);
      expect(find.text('Semua Riwayat Transaksi'), findsOneWidget);
      expect(find.text('Iuran Kebersihan'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
