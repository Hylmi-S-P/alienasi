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
import 'package:bendahara_app/presentation/screens/dashboard_screen.dart';
import 'package:bendahara_app/presentation/widgets/transaction_list_item.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('DashboardScreen Recent Activity & Dual Timestamp Tests', () {
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
        name: 'Kelas 9A',
        grade: 9,
        treasurerName: 'Nadia',
        supervisorName: 'Pak Wahyu',
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

    testWidgets('1. Section header is renamed to "Riwayat Pencatatan Terkini"', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Riwayat Pencatatan Terkini'), findsOneWidget);
      expect(find.text('Transaksi Terbaru'), findsNothing);
      expect(find.text('Lihat Semua'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('2. Tapping "Lihat Semua" in Dashboard navigates to AllTransactionsScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome.id,
        type: 'income',
        amount: 20000,
        title: 'Kas Awal Kelas',
        transactionDate: DateTime(2026, 7, 10),
      );

      await tester.pumpWidget(buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      final seeAllBtn = find.text('Lihat Semua');
      expect(seeAllBtn, findsOneWidget);

      await tester.tap(seeAllBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AllTransactionsScreen), findsOneWidget);
      expect(find.text('Semua Riwayat Transaksi'), findsOneWidget);
      expect(find.text('Kas Awal Kelas'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('3. Backdated transaction appears at the top due to createdAt DESC sorting', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;
      final catExpense = expenseCategories.first;

      // Transaction 1: Physical date in August, recorded earlier
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_old_record',
          academicYearId: activeYear.id,
          categoryId: catExpense.id,
          type: 'expense',
          amount: 25000,
          title: 'Belanja Spidol Agustus',
          transactionDate: DateTime(2026, 8, 20),
          createdAt: DateTime(2026, 8, 20, 10, 0),
          updatedAt: DateTime(2026, 8, 20, 10, 0),
        ),
      );

      // Transaction 2: Backdated transaction (physical date in July, but recorded TODAY in September)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_backdated_record',
          academicYearId: activeYear.id,
          categoryId: catIncome.id,
          type: 'income',
          amount: 50000,
          title: 'Kas Mundur Bulan Juli',
          transactionDate: DateTime(2026, 7, 5),
          createdAt: DateTime(2026, 9, 20, 14, 0), // Newest recording time
          updatedAt: DateTime(2026, 9, 20, 14, 0),
        ),
      );

      await tester.pumpWidget(buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      // Find all TransactionListItem widgets
      final itemFinders = find.byType(TransactionListItem);
      expect(itemFinders, findsNWidgets(2));

      // The first TransactionListItem must be the backdated one because createdAt is newest
      final firstItem = tester.widget<TransactionListItem>(itemFinders.first);
      expect(firstItem.item.transaction.title, equals('Kas Mundur Bulan Juli'));
      expect(firstItem.item.transaction.id, equals('tx_backdated_record'));

      final secondItem = tester.widget<TransactionListItem>(itemFinders.at(1));
      expect(secondItem.item.transaction.title, equals('Belanja Spidol Agustus'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('4. Dual timestamp display shows both dates & Mundur badge on backdated transactions', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;
      final catExpense = expenseCategories.first;

      // Backdated transaction: physical date 14 Jul 2026, recorded 20 Sep 2026
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_backdate_test',
          academicYearId: activeYear.id,
          categoryId: catIncome.id,
          type: 'income',
          amount: 75000,
          title: 'Iuran Susulan Juli',
          transactionDate: DateTime(2026, 7, 14, 8, 30),
          createdAt: DateTime(2026, 9, 20, 15, 0),
          updatedAt: DateTime(2026, 9, 20, 15, 0),
        ),
      );

      // Normal transaction: same day 20 Sep 2026
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_normal_test',
          academicYearId: activeYear.id,
          categoryId: catExpense.id,
          type: 'expense',
          amount: 10000,
          title: 'Beli Penghapus',
          transactionDate: DateTime(2026, 9, 20, 9, 0),
          createdAt: DateTime(2026, 9, 20, 9, 0),
          updatedAt: DateTime(2026, 9, 20, 9, 0),
        ),
      );

      await tester.pumpWidget(buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      // 1. Check tile display for backdated transaction
      expect(find.text('Mundur'), findsOneWidget);
      expect(find.textContaining('Tanggal: 14 Juli 2026 • Dicatat: 20 September 2026'), findsOneWidget);

      // 2. Tap backdated transaction to open detail dialog
      await tester.tap(find.text('Iuran Susulan Juli'));
      await tester.pumpAndSettle();

      // Detail dialog displays both physical date and recording timestamp with badge
      expect(find.text('Tanggal Transaksi: '), findsOneWidget);
      expect(find.text('Waktu Pencatatan: '), findsOneWidget);
      expect(find.text('Pencatatan Kas Mundur (Backdated)'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      // 3. Tap normal transaction
      await tester.tap(find.text('Beli Penghapus'));
      await tester.pumpAndSettle();

      // Detail dialog displays single 'Tanggal' and no backdated badge
      expect(find.text('Tanggal: '), findsOneWidget);
      expect(find.text('Waktu Pencatatan: '), findsNothing);
      expect(find.text('Pencatatan Kas Mundur (Backdated)'), findsNothing);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
