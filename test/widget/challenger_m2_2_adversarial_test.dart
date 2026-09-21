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
import 'package:bendahara_app/presentation/screens/supervision_report_screen.dart';
import 'package:bendahara_app/presentation/widgets/transaction_list_item.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Challenger M2 Adversarial Stress Tests', () {
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
        name: 'Kelas 9B Unggulan',
        grade: 9,
        treasurerName: 'Siti Bendahara',
        supervisorName: 'Bapak Pembimbing',
        defaultDuesAmount: 4000,
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

    Widget buildTestApp(Widget home, {List<dynamic> extraOverrides = const []}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          ...extraOverrides.cast(),
        ],
        child: MaterialApp(
          home: home,
        ),
      );
    }

    // =========================================================================
    // SECTION 1: NAVIGATION PUSH/POP STRESS TESTS
    // =========================================================================

    testWidgets('AdvNav 1: Rapid 10-cycle push/pop between Dashboard and AllTransactionsScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Insert at least 1 transaction so Dashboard renders correctly
      final catIncome = incomeCategories.first;
      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome.id,
        type: 'income',
        amount: 25000,
        title: 'Kas Pembuka',
        transactionDate: DateTime(2026, 8, 1),
      );

      await tester.pumpWidget(buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      for (int cycle = 1; cycle <= 10; cycle++) {
        // Find and tap 'Lihat Semua'
        final seeAllFinder = find.text('Lihat Semua');
        expect(seeAllFinder, findsOneWidget, reason: 'Cycle $cycle: "Lihat Semua" should exist on Dashboard');
        await tester.tap(seeAllFinder);
        await tester.pumpAndSettle();

        // Verify AllTransactionsScreen is pushed
        expect(find.byType(AllTransactionsScreen), findsOneWidget, reason: 'Cycle $cycle: AllTransactionsScreen pushed');
        expect(find.text('Semua Riwayat Transaksi'), findsOneWidget);

        // Tap BackButton
        final backBtnFinder = find.byType(BackButton);
        expect(backBtnFinder, findsOneWidget, reason: 'Cycle $cycle: BackButton should exist on AllTransactionsScreen');
        await tester.tap(backBtnFinder);
        await tester.pumpAndSettle();

        // Verify back on DashboardScreen
        expect(find.byType(AllTransactionsScreen), findsNothing, reason: 'Cycle $cycle: AllTransactionsScreen popped');
        expect(find.byType(DashboardScreen), findsOneWidget, reason: 'Cycle $cycle: Returned to DashboardScreen');
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AdvNav 2: SupervisionReport -> AllTransactions -> Detail Dialog -> Pop cycles', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;
      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome.id,
        type: 'income',
        amount: 30000,
        title: 'Iuran Praktikum Lab',
        transactionDate: DateTime(2026, 8, 15),
      );

      await tester.pumpWidget(buildTestApp(const SupervisionReportScreen()));
      await tester.pumpAndSettle();

      for (int cycle = 1; cycle <= 3; cycle++) {
        // Scroll to Section 5 banner
        final bannerFinder = find.textContaining('Lihat Semua Riwayat');
        await tester.scrollUntilVisible(bannerFinder, 300, scrollable: find.byType(Scrollable).first);
        expect(bannerFinder, findsOneWidget);

        // Tap banner to push AllTransactionsScreen
        await tester.tap(bannerFinder);
        await tester.pumpAndSettle();
        expect(find.byType(AllTransactionsScreen), findsOneWidget);

        // Tap transaction item to open Dialog
        final itemFinder = find.text('Iuran Praktikum Lab');
        expect(itemFinder, findsOneWidget);
        await tester.tap(itemFinder);
        await tester.pumpAndSettle();

        // Dialog should be open
        expect(find.text('PEMASUKAN KAS'), findsOneWidget);
        expect(find.text('Tutup'), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();
        expect(find.text('PEMASUKAN KAS'), findsNothing);

        // Pop AllTransactionsScreen
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(AllTransactionsScreen), findsNothing);
        expect(find.byType(SupervisionReportScreen), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AdvNav 3: AllTransactionsScreen with null academicYear and null activeYear pops cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Create a test harness with a button that pushes AllTransactionsScreen with null active year
      final harness = Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => const AllTransactionsScreen(academicYear: null),
                  ),
                );
              },
              child: const Text('Open All Tx'),
            ),
          ),
        ),
      );

      // Override activeAcademicYearProvider to emit null
      await tester.pumpWidget(
        buildTestApp(
          harness,
          extraOverrides: [
            activeAcademicYearProvider.overrideWith((ref) => Stream.value(null)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap button to push
      await tester.tap(find.text('Open All Tx'));
      await tester.pumpAndSettle();

      // Should show empty state message with BackButton
      expect(find.text('Kelas belum aktif atau belum dipilih.'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      // Tap BackButton and verify clean pop
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Open All Tx'), findsOneWidget);
      expect(find.text('Kelas belum aktif atau belum dipilih.'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AdvNav 4: State isolation across push/pop entries', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;
      final catExpense = expenseCategories.first;

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome.id,
        type: 'income',
        amount: 20000,
        title: 'Kas Buku Panduan',
        transactionDate: DateTime(2026, 8, 1),
      );
      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExpense.id,
        type: 'expense',
        amount: 15000,
        title: 'Beli Lakban',
        transactionDate: DateTime(2026, 8, 2),
      );

      await tester.pumpWidget(buildTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      // 1. Enter AllTransactionsScreen
      await tester.tap(find.text('Lihat Semua'));
      await tester.pumpAndSettle();

      // Filter by 'Buku'
      await tester.enterText(find.byType(TextField), 'Buku');
      await tester.pumpAndSettle();
      expect(find.text('1 dari 2 Transaksi'), findsOneWidget);
      expect(find.text('Kas Buku Panduan'), findsOneWidget);
      expect(find.text('Beli Lakban'), findsNothing);

      // Select 'Kas Masuk' chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Kas Masuk'));
      await tester.pumpAndSettle();

      // Pop back to Dashboard
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // 2. Re-enter AllTransactionsScreen
      await tester.tap(find.text('Lihat Semua'));
      await tester.pumpAndSettle();

      // Verifies state is fresh (both items visible, search field empty)
      expect(find.text('2 dari 2 Transaksi'), findsOneWidget);
      expect(find.text('Kas Buku Panduan'), findsOneWidget);
      expect(find.text('Beli Lakban'), findsOneWidget);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // =========================================================================
    // SECTION 2: LAYOUT RESPONSIVENESS & OVERFLOW STRESS TESTS
    // =========================================================================

    testWidgets('AdvLayout 1: 320px narrow screen (iPhone SE 1st gen) zero overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;
      final catExpense = expenseCategories.first;

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome.id,
        type: 'income',
        amount: 2500000,
        title: 'Pemasukan Kas Sponsorship Lomba Futsal Antar Sekolah',
        description: 'Sponsorship dari PT Maju Bersama untuk jersey tim',
        transactionDate: DateTime(2026, 8, 1),
      );
      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExpense.id,
        type: 'expense',
        amount: 1750000,
        title: 'Pengeluaran Konsumsi dan P3K Pertandingan Final',
        description: 'Makan siang 20 porsi dan obat spray pereda nyeri otot',
        transactionDate: DateTime(2026, 8, 2),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      // On 320px screens, the single-string dual timestamp inside Wrap in TransactionListItem
      // exceeds available width and overflows RenderFlex by 145px.
      expect(err, isNull, reason: 'Zero overflow on 320px screen (Fails if subtitle or summary card overflows)');

      // Verify Summary card elements rendered cleanly
      expect(find.text('Ringkasan Mutasi'), findsOneWidget);
      expect(find.text('2 dari 2 Transaksi'), findsOneWidget);
      expect(find.text('+Rp 2.500.000'), findsOneWidget);
      expect(find.text('-Rp 1.750.000'), findsOneWidget);
      expect(find.text('+Rp 750.000'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AdvLayout 2: 280px ultra-narrow & extreme nominal values zero overflow', (tester) async {
      tester.view.physicalSize = const Size(280, 653);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;
      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome.id,
        type: 'income',
        amount: 999999999, // 999 million
        title: 'Dana Hibah Sangat Besar Sekali Dari Donatur Terkenal Kelas 9B',
        transactionDate: DateTime(2026, 8, 1),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero overflow on 280px ultra-narrow screen');

      // Summary card should fit without horizontal overflow thanks to FittedBox
      expect(find.text('+Rp 999.999.999'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AdvLayout 3: High accessibility text scale (1.5x) zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;
      final catExpense = expenseCategories.first;

      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catIncome.id,
        type: 'income',
        amount: 150000,
        title: 'Iuran Semester Gasal',
        transactionDate: DateTime(2026, 8, 1),
      );
      await txRepo.insertTransaction(
        academicYearId: activeYear.id,
        categoryId: catExpense.id,
        type: 'expense',
        amount: 45000,
        title: 'Fotokopi Modul',
        transactionDate: DateTime(2026, 8, 2),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 720),
            textScaler: TextScaler.linear(1.5),
          ),
          child: buildTestApp(AllTransactionsScreen(academicYear: activeYear)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero overflow on 1.5x text scale');
      expect(find.text('Ringkasan Mutasi'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AdvLayout 4: Constrained landscape height with virtual keyboard open', (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(640, 360),
            viewInsets: EdgeInsets.only(bottom: 160), // Keyboard simulated
          ),
          child: buildTestApp(AllTransactionsScreen(academicYear: activeYear)),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger empty state
      await tester.enterText(find.byType(TextField), 'pencarian_tidak_ada_123');
      await tester.pumpAndSettle();

      // Verify empty state is displayed and scrollable without RenderFlex overflow
      expect(tester.takeException(), isNull, reason: 'Zero overflow when keyboard is open');
      expect(find.text('Tidak Ada Transaksi Ditemukan'), findsOneWidget);
      expect(find.text('Reset Filter'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    // =========================================================================
    // SECTION 3: BACKDATED DUAL TIMESTAMP EDGE CASES
    // =========================================================================

    testWidgets('AdvTimestamp 1: Same calendar day, different hours (08:30 vs 22:45) is NOT backdated', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;

      // Same calendar day: 2026-09-20
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_sameday_diff_hours',
          academicYearId: activeYear.id,
          categoryId: catIncome.id,
          type: 'income',
          amount: 50000,
          title: 'Kas Pagi Dicatat Malam',
          transactionDate: DateTime(2026, 9, 20, 8, 30),
          createdAt: DateTime(2026, 9, 20, 22, 45),
          updatedAt: DateTime(2026, 9, 20, 22, 45),
        ),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      // 1. Transaction tile check:
      // "Mundur" badge must NOT appear
      expect(find.text('Mundur'), findsNothing);
      // Subtitle should show single date format, NOT "Tanggal: ... • Dicatat: ..."
      expect(find.textContaining('Dicatat:'), findsNothing);
      expect(find.text('20 September 2026'), findsOneWidget);

      // 2. Detail Dialog check:
      await tester.tap(find.text('Kas Pagi Dicatat Malam'));
      await tester.pumpAndSettle();

      // Detail dialog should show 'Tanggal: ' and NOT 'Waktu Pencatatan: '
      expect(find.text('Tanggal: '), findsOneWidget);
      expect(find.text('Waktu Pencatatan: '), findsNothing);
      expect(find.text('Pencatatan Kas Mundur (Backdated)'), findsNothing);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AdvTimestamp 2: Exact identical timestamp is NOT backdated', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catExpense = expenseCategories.first;
      final exactTime = DateTime(2026, 8, 10, 14, 0, 0);

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_exact_identical_ts',
          academicYearId: activeYear.id,
          categoryId: catExpense.id,
          type: 'expense',
          amount: 20000,
          title: 'Belanja Tinta Spidol',
          transactionDate: exactTime,
          createdAt: exactTime,
          updatedAt: exactTime,
        ),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      expect(find.text('Mundur'), findsNothing);
      expect(find.textContaining('Dicatat:'), findsNothing);
      expect(find.text('10 Agustus 2026'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AdvTimestamp 3: Month boundary transition (31 Aug 23:59:59 vs 1 Sep 00:00:01) IS backdated', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_month_boundary',
          academicYearId: activeYear.id,
          categoryId: catIncome.id,
          type: 'income',
          amount: 80000,
          title: 'Kas Tutup Buku Agustus',
          transactionDate: DateTime(2026, 8, 31, 23, 59, 59),
          createdAt: DateTime(2026, 9, 1, 0, 0, 1),
          updatedAt: DateTime(2026, 9, 1, 0, 0, 1),
        ),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      // "Mundur" badge MUST be displayed
      expect(find.text('Mundur'), findsOneWidget);
      expect(find.textContaining('Tanggal: 31 Agustus 2026 • Dicatat: 1 September 2026'), findsOneWidget);

      // Open Dialog and check
      await tester.tap(find.text('Kas Tutup Buku Agustus'));
      await tester.pumpAndSettle();

      expect(find.text('Tanggal Transaksi: '), findsOneWidget);
      expect(find.text('Waktu Pencatatan: '), findsOneWidget);
      expect(find.text('Pencatatan Kas Mundur (Backdated)'), findsOneWidget);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AdvTimestamp 4: Future-dated transaction renders without error', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catIncome = incomeCategories.first;

      // Future dated: tx date is 25 Dec 2026, recorded today 20 Sep 2026
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_future_dated',
          academicYearId: activeYear.id,
          categoryId: catIncome.id,
          type: 'income',
          amount: 100000,
          title: 'Uang Muka Sewa Bus Wisata',
          transactionDate: DateTime(2026, 12, 25, 10, 0),
          createdAt: DateTime(2026, 9, 20, 10, 0),
          updatedAt: DateTime(2026, 9, 20, 10, 0),
        ),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Mundur'), findsOneWidget);
      expect(find.textContaining('Tanggal: 25 Desember 2026 • Dicatat: 20 September 2026'), findsOneWidget);

      // Open Dialog
      await tester.tap(find.text('Uang Muka Sewa Bus Wisata'));
      await tester.pumpAndSettle();

      expect(find.text('Tanggal Transaksi: '), findsOneWidget);
      expect(find.text('Waktu Pencatatan: '), findsOneWidget);
      expect(find.text('Pencatatan Kas Mundur (Backdated)'), findsOneWidget);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AdvTimestamp 5: Extreme metadata strings and missing receipt in Detail Dialog', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catExpense = expenseCategories.first;

      final veryLongTitle = 'P'.padRight(200, 'a');
      final veryLongDescription = 'Catatan rincian belanja perlengkapan: ' * 10;
      const nonExistentPath = '/data/user/0/com.example/files/missing_receipt_12345.jpg';

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_extreme_dialog',
          academicYearId: activeYear.id,
          categoryId: catExpense.id,
          type: 'expense',
          amount: 75000,
          title: veryLongTitle,
          description: Value(veryLongDescription),
          receiptImagePath: const Value(nonExistentPath),
          transactionDate: DateTime(2026, 7, 10, 9, 0),
          createdAt: DateTime(2026, 9, 20, 15, 30),
          updatedAt: DateTime(2026, 9, 20, 15, 30),
        ),
      );

      await tester.pumpWidget(buildTestApp(AllTransactionsScreen(academicYear: activeYear)));
      await tester.pumpAndSettle();

      // Tap to open detail dialog
      await tester.tap(find.byType(TransactionListItem));
      await tester.pumpAndSettle();

      // Verify dialog renders without overflow
      expect(tester.takeException(), isNull);
      expect(find.text('PENGELUARAN KAS'), findsOneWidget);
      expect(find.text('Pencatatan Kas Mundur (Backdated)'), findsOneWidget);
      expect(find.text('Foto tersimpan: $nonExistentPath'), findsOneWidget);

      // Verify close button dismisses cleanly
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      expect(find.text('PENGELUARAN KAS'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
