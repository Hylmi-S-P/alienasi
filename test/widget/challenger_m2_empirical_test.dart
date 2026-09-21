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

  group('Milestone 2 Empirical Challenge Tests', () {
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
        name: 'Kelas 8B Unggulan',
        grade: 8,
        treasurerName: 'Zaskia Empirical',
        supervisorName: 'Ibu Pengawas',
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

    Widget buildTestApp(Widget home, {AcademicYear? customActiveYear, TextScaler? textScaler}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          activeAcademicYearProvider.overrideWith((ref) => Stream.value(customActiveYear ?? activeYear)),
        ],
        child: MaterialApp(
          builder: (context, child) {
            if (textScaler != null) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              );
            }
            return child!;
          },
          home: home,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // CHALLENGE 1: Regex, Special Characters, Unicode, Emojis in Search
    // -------------------------------------------------------------------------
    testWidgets('C1: Search handles regex characters, emojis, quotes, and SQL injection payloads safely', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catInc = incomeCategories.first;
      final catExp = expenseCategories.first;

      // Insert challenging titles
      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catInc.id,
        type: 'income',
        amount: 50000,
        title: 'Pengadaan [ATK] (Tahap 1)',
        description: 'Pembelian via kas kelas; saldo aman?',
        transactionDate: DateTime(2026, 8, 1),
      );

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExp.id,
        type: 'expense',
        amount: 75000,
        title: '🎉 Hadiah Lomba & Snack*',
        description: r'Kafé + Resto senilai $50 \ 100%',
        transactionDate: DateTime(2026, 8, 2),
      );

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catInc.id,
        type: 'income',
        amount: 100000,
        title: 'Sumbangan "Donatur Utama"',
        description: 'Tanda kutip \'tunggal\' dan ganda',
        transactionDate: DateTime(2026, 8, 3),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      expect(find.text('3 dari 3 Transaksi'), findsOneWidget);

      // Subtest 1.1: Square brackets regex meta-character '[' and ']'
      await tester.enterText(find.byType(TextField), '[ATK]');
      await tester.pumpAndSettle();
      expect(find.text('1 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Pengadaan [ATK] (Tahap 1)'), findsOneWidget);
      expect(find.text('🎉 Hadiah Lomba & Snack*'), findsNothing);

      // Subtest 1.2: Parentheses '(' and ')'
      await tester.enterText(find.byType(TextField), '(Tahap 1)');
      await tester.pumpAndSettle();
      expect(find.text('1 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Pengadaan [ATK] (Tahap 1)'), findsOneWidget);

      // Subtest 1.3: Emoji '🎉'
      await tester.enterText(find.byType(TextField), '🎉');
      await tester.pumpAndSettle();
      expect(find.text('1 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('🎉 Hadiah Lomba & Snack*'), findsOneWidget);

      // Subtest 1.4: Special chars: '*', '+', '\', '$', '%' in description
      await tester.enterText(find.byType(TextField), r'$50 \ 100%');
      await tester.pumpAndSettle();
      expect(find.text('1 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('🎉 Hadiah Lomba & Snack*'), findsOneWidget);

      // Subtest 1.5: Quotes in title
      await tester.enterText(find.byType(TextField), '"Donatur Utama"');
      await tester.pumpAndSettle();
      expect(find.text('1 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Sumbangan "Donatur Utama"'), findsOneWidget);

      // Subtest 1.6: SQL Injection attempt does not throw or leak
      await tester.enterText(find.byType(TextField), "' OR '1'='1");
      await tester.pumpAndSettle();
      expect(find.text('0 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Tidak Ada Transaksi Ditemukan'), findsOneWidget);

      // Subtest 1.7: Whitespace-only search input behaves as unfiltered
      await tester.enterText(find.byType(TextField), '     ');
      await tester.pumpAndSettle();
      expect(find.text('3 dari 3 Transaksi'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // -------------------------------------------------------------------------
    // CHALLENGE 2: Rapid Category Chip Switching & Combined Filter Mutation
    // -------------------------------------------------------------------------
    testWidgets('C2: Rapid category chip switching maintains strict state isolation and consistency', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catInc1 = incomeCategories.first;
      final catExp1 = expenseCategories.first;
      final catExp2 = expenseCategories.length > 1 ? expenseCategories[1] : expenseCategories.first;

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catInc1.id,
        type: 'income',
        amount: 80000,
        title: 'Iuran Kas Rutin',
        description: 'Setoran rutin siswa',
        transactionDate: DateTime(2026, 8, 1),
      );

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExp1.id,
        type: 'expense',
        amount: 30000,
        title: 'Spidol Whiteboard',
        description: 'Keperluan ATK kelas',
        transactionDate: DateTime(2026, 8, 2),
      );

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExp2.id,
        type: 'expense',
        amount: 45000,
        title: 'Konsumsi Rapat Wali',
        description: 'Snack kue dan teh',
        transactionDate: DateTime(2026, 8, 3),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      expect(find.text('3 dari 3 Transaksi'), findsOneWidget);

      // Step 2.1: Select 'Kas Keluar' chip first
      final kasKeluarChip = find.widgetWithText(ChoiceChip, 'Kas Keluar');
      await tester.tap(kasKeluarChip);
      await tester.pumpAndSettle();

      // Kas Keluar has 2 transactions
      expect(find.text('2 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Spidol Whiteboard'), findsOneWidget);
      expect(find.text('Konsumsi Rapat Wali'), findsOneWidget);
      expect(find.text('Iuran Kas Rutin'), findsNothing);

      // In Kas Keluar mode, only expense category chips are visible. Scroll horizontal bar to see specific chip if needed.
      final horizontalScrollable = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      );
      final exp1Chip = find.widgetWithText(ChoiceChip, catExp1.name);
      await tester.scrollUntilVisible(exp1Chip, 50, scrollable: horizontalScrollable);
      await tester.tap(exp1Chip);
      await tester.pumpAndSettle();

      // Now only 1 transaction (catExp1)
      expect(find.text('1 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Spidol Whiteboard'), findsOneWidget);
      expect(find.text('Konsumsi Rapat Wali'), findsNothing);

      // Step 2.2: Switch directly to 'Kas Masuk' chip while specific expense chip was active
      // Scroll back to start
      await tester.fling(horizontalScrollable, const Offset(500, 0), 1000);
      await tester.pumpAndSettle();

      final kasMasukChip = find.widgetWithText(ChoiceChip, 'Kas Masuk');
      await tester.tap(kasMasukChip);
      await tester.pumpAndSettle();

      // Only income transactions should be visible
      expect(find.text('1 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Iuran Kas Rutin'), findsOneWidget);
      expect(find.text('Spidol Whiteboard'), findsNothing);

      // Step 2.3: Toggle 'Kas Masuk' chip off (unselect by tapping again)
      await tester.tap(kasMasukChip);
      await tester.pumpAndSettle();

      // Should return to 'Semua' (all 3 transactions)
      expect(find.text('3 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Iuran Kas Rutin'), findsOneWidget);
      expect(find.text('Spidol Whiteboard'), findsOneWidget);
      expect(find.text('Konsumsi Rapat Wali'), findsOneWidget);

      // Step 2.4: Enter search keyword AND tap category chip simultaneously
      await tester.enterText(find.byType(TextField), 'Rapat');
      await tester.pumpAndSettle();
      expect(find.text('1 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Konsumsi Rapat Wali'), findsOneWidget);

      // Now tap 'Kas Masuk' chip -> query 'Rapat' under 'Kas Masuk' yields 0 results!
      await tester.tap(kasMasukChip);
      await tester.pumpAndSettle();
      expect(find.text('0 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Tidak Ada Transaksi Ditemukan'), findsOneWidget);

      // Clear search text via clear icon button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      // Now 'Kas Masuk' without query restores income items
      expect(find.text('1 dari 3 Transaksi'), findsOneWidget);
      expect(find.text('Iuran Kas Rutin'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // -------------------------------------------------------------------------
    // CHALLENGE 3: Dynamic Mutation Calculations Matrix (Negative, Zero, Huge)
    // -------------------------------------------------------------------------
    testWidgets('C3: Dynamic mutation summary card calculates exact figures for negative, zero, and huge balances', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catInc = incomeCategories.first;
      final catExp = expenseCategories.first;

      // Case 3.1: Expense heavily exceeds Income (Negative Selisih)
      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catInc.id,
        type: 'income',
        amount: 150000,
        title: 'Iuran Awal',
        transactionDate: DateTime(2026, 8, 1),
      );

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExp.id,
        type: 'expense',
        amount: 400000,
        title: 'Pembelian Seragam Paduan Suara',
        transactionDate: DateTime(2026, 8, 2),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      // Income = 150.000, Expense = 400.000, Net = -250.000
      expect(find.text('+Rp 150.000'), findsWidgets);
      expect(find.text('-Rp 400.000'), findsWidgets);
      expect(find.text('-Rp 250.000'), findsWidgets);

      // Case 3.2: Filter to ONLY expense
      await tester.tap(find.widgetWithText(ChoiceChip, 'Kas Keluar'));
      await tester.pumpAndSettle();

      // Income = 0, Expense = 400.000, Net = -400.000
      expect(find.text('+Rp 0'), findsOneWidget);
      expect(find.text('-Rp 400.000'), findsWidgets);
      expect(find.text('1 dari 2 Transaksi'), findsOneWidget);

      // Case 3.3: Insert huge transaction (hundreds of millions) to test math and formatting
      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catInc.id,
        type: 'income',
        amount: 125000000, // Rp 125.000.000
        title: 'Dana Hibah CSR Pendidikan',
        transactionDate: DateTime(2026, 8, 5),
      );

      // Return to 'Semua'
      await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
      await tester.pumpAndSettle();

      // Income = 125.150.000, Expense = 400.000, Net = +124.750.000
      expect(find.text('+Rp 125.150.000'), findsWidgets);
      expect(find.text('-Rp 400.000'), findsWidgets);
      expect(find.text('+Rp 124.750.000'), findsWidgets);
      expect(find.text('3 dari 3 Transaksi'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // -------------------------------------------------------------------------
    // CHALLENGE 4: Empty State & Reset Filter Contract
    // -------------------------------------------------------------------------
    testWidgets('C4: Empty state displays properly with and without active filters, Reset Filter clears all state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Case 4.1: Database has NO transactions at all
      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      expect(find.text('Tidak Ada Transaksi Ditemukan'), findsOneWidget);
      // Because no filter was typed or selected, Reset Filter button should NOT be rendered
      expect(find.text('Reset Filter'), findsNothing);
      expect(find.text('0 dari 0 Transaksi'), findsOneWidget);
      expect(find.text('+Rp 0'), findsWidgets);
      expect(find.text('-Rp 0'), findsWidgets);

      // Case 4.2: Insert 1 item, then apply filter that yields 0 results
      final catInc = incomeCategories.first;
      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catInc.id,
        type: 'income',
        amount: 20000,
        title: 'Iuran Wajib',
        transactionDate: DateTime(2026, 8, 10),
      );

      // Invalidate stream
      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      expect(find.text('1 dari 1 Transaksi'), findsOneWidget);
      expect(find.text('Iuran Wajib'), findsOneWidget);

      // Type unmatched query
      await tester.enterText(find.byType(TextField), 'kata_kunci_fiktif');
      await tester.pumpAndSettle();

      expect(find.text('Tidak Ada Transaksi Ditemukan'), findsOneWidget);
      // Now Reset Filter button MUST appear
      final resetBtn = find.text('Reset Filter');
      expect(resetBtn, findsOneWidget);

      // Tap Reset Filter
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      // Verify full state reset
      expect(find.text('1 dari 1 Transaksi'), findsOneWidget);
      expect(find.text('Iuran Wajib'), findsOneWidget);
      expect(find.text('Tidak Ada Transaksi Ditemukan'), findsNothing);

      // Verify TextField was also cleared
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // -------------------------------------------------------------------------
    // CHALLENGE 5: Narrow Viewport (320 logical px) Mobile Stress
    // -------------------------------------------------------------------------
    testWidgets('C5: Narrow mobile viewport (320 logical px width) renders backdated items, badges, and huge numbers without overflow', (tester) async {
      // Logical size: 320 x 640 (iPhone SE / compact Android phone)
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catInc = incomeCategories.first;

      // Insert backdated transaction with long title, huge amount, and receipt
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_stress_narrow',
          academicYearId: activeYear.id,
          categoryId: catInc.id,
          type: 'income',
          amount: 875000000, // Rp 875.000.000
          title: 'Pengembalian Dana Kegiatan Karyawisata Kelas VIII',
          receiptImagePath: const Value('/mock/receipt.jpg'),
          transactionDate: DateTime(2026, 7, 12, 9, 30),
          createdAt: DateTime(2026, 9, 20, 16, 45), // Backdated by 2 months
          updatedAt: DateTime(2026, 9, 20, 16, 45),
        ),
      );

      final originalOnError = FlutterError.onError;
      final overflowErrors = <String>[];
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          overflowErrors.add(details.exceptionAsString());
        } else {
          originalOnError?.call(details);
        }
      };

      try {
        await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      // Assert no overflow occurred
      expect(overflowErrors, isEmpty, reason: 'RenderFlex must not overflow on narrow viewports');

      // Verify Mundur and Ada Nota badges rendered
      expect(find.text('Mundur'), findsOneWidget);
      expect(find.text('Ada Nota'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // -------------------------------------------------------------------------
    // CHALLENGE 6: Dashboard Recent Activity Strict `createdAt DESC` Sorting
    // -------------------------------------------------------------------------
    testWidgets('C6: Dashboard recent activity sorts strictly by createdAt DESC across arbitrary physical dates', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catInc = incomeCategories.first;
      final catExp = expenseCategories.first;

      // Insert 5 transactions with intentionally conflicting physical dates vs creation timestamps:
      // Tx 1: Physical date in January (months ago), but created TODAY at 18:00 -> MUST be #1
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_1_january_input_now',
          academicYearId: activeYear.id,
          categoryId: catInc.id,
          type: 'income',
          amount: 10000,
          title: 'Kas Januari Diinput Hari Ini',
          transactionDate: DateTime(2026, 1, 15),
          createdAt: DateTime(2026, 9, 20, 18, 0),
          updatedAt: DateTime(2026, 9, 20, 18, 0),
        ),
      );

      // Tx 2: Physical date TODAY, but recorded 10 days ago -> MUST be #4
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_2_today_input_earlier',
          academicYearId: activeYear.id,
          categoryId: catExp.id,
          type: 'expense',
          amount: 20000,
          title: 'Belanja Tanggal Hari Ini Tapi Diinput Dulu',
          transactionDate: DateTime(2026, 9, 20),
          createdAt: DateTime(2026, 9, 10, 8, 0),
          updatedAt: DateTime(2026, 9, 10, 8, 0),
        ),
      );

      // Tx 3: Physical date in June, created TODAY at 17:59 (1 min before Tx 1) -> MUST be #2
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_3_june_input_today_1759',
          academicYearId: activeYear.id,
          categoryId: catInc.id,
          type: 'income',
          amount: 30000,
          title: 'Kas Juni Diinput 17:59',
          transactionDate: DateTime(2026, 6, 20),
          createdAt: DateTime(2026, 9, 20, 17, 59),
          updatedAt: DateTime(2026, 9, 20, 17, 59),
        ),
      );

      // Tx 4: Physical date in August, created 5 days ago -> MUST be #3
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_4_august_input_sep15',
          academicYearId: activeYear.id,
          categoryId: catExp.id,
          type: 'expense',
          amount: 40000,
          title: 'Kas Agustus Diinput Sep 15',
          transactionDate: DateTime(2026, 8, 25),
          createdAt: DateTime(2026, 9, 15, 12, 0),
          updatedAt: DateTime(2026, 9, 15, 12, 0),
        ),
      );

      // Tx 5: Oldest creation time (Sep 1) -> MUST be #5
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_5_oldest_record',
          academicYearId: activeYear.id,
          categoryId: catInc.id,
          type: 'income',
          amount: 50000,
          title: 'Kas Awal Diinput Sep 1',
          transactionDate: DateTime(2026, 7, 1),
          createdAt: DateTime(2026, 9, 1, 10, 0),
          updatedAt: DateTime(2026, 9, 1, 10, 0),
        ),
      );

      await tester.pumpWidget(buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      final itemFinders = find.byType(TransactionListItem);
      expect(itemFinders, findsNWidgets(5));

      // Verify exact order matching createdAt DESC:
      // Position 0: Tx 1 (createdAt 2026-09-20 18:00)
      final item0 = tester.widget<TransactionListItem>(itemFinders.at(0));
      expect(item0.item.transaction.id, equals('tx_1_january_input_now'));

      // Position 1: Tx 3 (createdAt 2026-09-20 17:59)
      final item1 = tester.widget<TransactionListItem>(itemFinders.at(1));
      expect(item1.item.transaction.id, equals('tx_3_june_input_today_1759'));

      // Position 2: Tx 4 (createdAt 2026-09-15 12:00)
      final item2 = tester.widget<TransactionListItem>(itemFinders.at(2));
      expect(item2.item.transaction.id, equals('tx_4_august_input_sep15'));

      // Position 3: Tx 2 (createdAt 2026-09-10 08:00)
      final item3 = tester.widget<TransactionListItem>(itemFinders.at(3));
      expect(item3.item.transaction.id, equals('tx_2_today_input_earlier'));

      // Position 4: Tx 5 (createdAt 2026-09-01 10:00)
      final item4 = tester.widget<TransactionListItem>(itemFinders.at(4));
      expect(item4.item.transaction.id, equals('tx_5_oldest_record'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // -------------------------------------------------------------------------
    // CHALLENGE 7: Dual Timestamp Boundary Matrix in List Item and Dialog
    // -------------------------------------------------------------------------
    testWidgets('C7: Dual timestamp formatting detects midnight and month boundaries and dialog displays backdated badge', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catInc = incomeCategories.first;
      final catExp = expenseCategories.first;

      // Case 7.1: Midnight / month boundary (July 31 23:59 vs August 1 00:01)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_midnight_boundary',
          academicYearId: activeYear.id,
          categoryId: catExp.id,
          type: 'expense',
          amount: 15000,
          title: 'Transaksi Batas Tengah Malam',
          transactionDate: DateTime(2026, 7, 31, 23, 59),
          createdAt: DateTime(2026, 8, 1, 0, 1),
          updatedAt: DateTime(2026, 8, 1, 0, 1),
        ),
      );

      // Case 7.2: Same day, morning vs night (NOT backdated)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_sameday_nonbackdate',
          academicYearId: activeYear.id,
          categoryId: catInc.id,
          type: 'income',
          amount: 25000,
          title: 'Transaksi Hari Sama Pagi Malam',
          transactionDate: DateTime(2026, 9, 20, 7, 30),
          createdAt: DateTime(2026, 9, 20, 21, 45),
          updatedAt: DateTime(2026, 9, 20, 21, 45),
        ),
      );

      await tester.pumpWidget(buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      // Case 7.1 must show Mundur badge and dual date
      expect(find.text('Mundur'), findsOneWidget);
      expect(find.textContaining('Tanggal: 31 Juli 2026 • Dicatat: 1 Agustus 2026'), findsOneWidget);

      // Case 7.2 must NOT show dual date, only single date
      expect(find.text('20 September 2026'), findsOneWidget);

      // Open detail dialog of backdated transaction
      await tester.tap(find.text('Transaksi Batas Tengah Malam'));
      await tester.pumpAndSettle();

      expect(find.text('Pencatatan Kas Mundur (Backdated)'), findsOneWidget);
      expect(find.text('Tanggal Transaksi: '), findsOneWidget);
      expect(find.text('Waktu Pencatatan: '), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      // Open detail dialog of same-day transaction
      await tester.tap(find.text('Transaksi Hari Sama Pagi Malam'));
      await tester.pumpAndSettle();

      expect(find.text('Pencatatan Kas Mundur (Backdated)'), findsNothing);
      expect(find.text('Tanggal: '), findsOneWidget);
      expect(find.text('Waktu Pencatatan: '), findsNothing);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // -------------------------------------------------------------------------
    // CHALLENGE 8: Dynamic Mutation Summary under Accessibility Text Scaling
    // -------------------------------------------------------------------------
    testWidgets('C8: Dynamic mutation summary card and header row under accessibility text scaling (1.3x)', (tester) async {
      // Small phone: 360 x 640 logical px with 1.3x text scaling (accessibility large font)
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catInc = incomeCategories.first;
      final catExp = expenseCategories.first;

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catInc.id,
        type: 'income',
        amount: 2500000,
        title: 'Pemasukan Kas Siswa',
        transactionDate: DateTime(2026, 8, 1),
      );

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExp.id,
        type: 'expense',
        amount: 1500000,
        title: 'Pengeluaran Lomba Futsal',
        transactionDate: DateTime(2026, 8, 2),
      );

      final originalOnError = FlutterError.onError;
      final overflowErrors = <String>[];
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          overflowErrors.add(details.exceptionAsString());
        } else {
          originalOnError?.call(details);
        }
      };

      try {
        await tester.pumpWidget(buildTestApp(
          AllTransactionsScreen(academicYear: activeYear),
          textScaler: const TextScaler.linear(1.3),
        ));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      // Assert no overflow occurred
      expect(overflowErrors, isEmpty, reason: 'Summary card header must not overflow under accessibility text scaling');

      // Verify numbers and summary metrics
      expect(find.text('+Rp 2.500.000'), findsWidgets);
      expect(find.text('-Rp 1.500.000'), findsWidgets);
      expect(find.text('+Rp 1.000.000'), findsWidgets);
      expect(find.text('2 dari 2 Transaksi'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
