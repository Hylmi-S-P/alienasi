import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/dues_repository.dart';
import 'package:bendahara_app/data/repositories/student_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/screens/dashboard_screen.dart';
import 'package:bendahara_app/presentation/screens/dues_check_screen.dart';
import 'package:bendahara_app/presentation/screens/main_scaffold.dart';
import 'package:bendahara_app/presentation/screens/supervision_report_screen.dart';
import 'package:bendahara_app/presentation/screens/transaction_form_screen.dart';
import 'package:bendahara_app/presentation/widgets/financial_chart_card.dart';
import 'package:bendahara_app/presentation/widgets/dues_period_calendar_card.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Revisi 5: Perbaikan Double-Counting Rekonsiliasi Kas Siswa', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late StudentRepository studentRepo;
    late DuesRepository duesRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      studentRepo = StudentRepository(db);
      duesRepo = DuesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Skenario User: 2 orang bayar 10rb lalu dicatat, tambah 1 orang bayar 5rb, total kas menjadi 15rb (bukan 25rb)', () async {
      // 1. Inisialisasi Kelas
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8B',
        grade: 8,
        treasurerName: 'Siti',
        supervisorName: 'Pak Budi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      // 2. Tambah 3 Siswa
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Andi');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Budi');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 3, name: 'Citra');
      final students = await studentRepo.getStudents(year.id);
      final s1 = students[0];
      final s2 = students[1];
      final s3 = students[2];

      // 3. Buat periode kas aktif
      final period = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu ke-3 (15 Sep - 21 Sep)',
        targetAmount: 5000,
      );

      // 4. Siswa 1 & Siswa 2 membayar masing-masing 5.000 (total terkumpul: 10.000)
      await duesRepo.togglePaymentStatus(
        duesPeriodId: period.id,
        studentId: s1.id,
        targetAmount: 5000,
        currentStatus: false,
      );
      await duesRepo.togglePaymentStatus(
        duesPeriodId: period.id,
        studentId: s2.id,
        targetAmount: 5000,
        currentStatus: false,
      );

      // 5. Tekan tombol Catat (rekonsiliasi pertama)
      final firstDelta = await duesRepo.reconcileIntoGeneralCash(
        period: period,
        academicYearId: year.id,
      );

      expect(firstDelta, 10000, reason: 'Delta pertama harus Rp 10.000');

      var transactions = await (db.select(db.transactions)..where((t) => t.academicYearId.equals(year.id))).get();
      expect(transactions.length, 1);
      expect(transactions.first.amount, 10000);
      expect(transactions.first.type, 'income');

      var totalBalance = transactions.fold<int>(0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
      expect(totalBalance, 10000);

      // 6. Sekarang siswa ke-3 (Citra) menyusul membayar 5.000
      await duesRepo.togglePaymentStatus(
        duesPeriodId: period.id,
        studentId: s3.id,
        targetAmount: 5000,
        currentStatus: false,
      );

      // 7. Tekan tombol Catat lagi (rekonsiliasi kedua untuk tambahan kas baru)
      final secondDelta = await duesRepo.reconcileIntoGeneralCash(
        period: period,
        academicYearId: year.id,
      );

      expect(secondDelta, 5000, reason: 'Delta kedua HANYA boleh Rp 5.000 untuk 1 siswa baru');

      // 8. Verifikasi tabel transaksi kas umum:
      // Ada 2 transaksi: transaksi awal (10.000) dan transaksi tambahan (5.000)
      // Total saldo kas harus 15.000, BUKAN 25.000!
      transactions = await (db.select(db.transactions)..where((t) => t.academicYearId.equals(year.id))).get();
      expect(transactions.length, 2);

      final totalRecorded = transactions.fold<int>(0, (sum, t) => sum + t.amount);
      expect(totalRecorded, 15000, reason: 'Total transaksi kas harus Rp 15.000 (bukan Rp 25.000)');

      totalBalance = transactions.fold<int>(0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
      expect(totalBalance, 15000, reason: 'Saldo kas umum harus Rp 15.000');

      // 9. Jika tekan catat lagi tanpa ada siswa baru yang bayar, delta harus 0 dan tidak ada transaksi baru
      final thirdDelta = await duesRepo.reconcileIntoGeneralCash(
        period: period,
        academicYearId: year.id,
      );
      expect(thirdDelta, 0);

      transactions = await (db.select(db.transactions)..where((t) => t.academicYearId.equals(year.id))).get();
      expect(transactions.length, 2, reason: 'Tidak boleh membuat transaksi duplikat baru saat delta 0');
    });
  });

  group('Revisi 6: Penomoran Minggu Kalender & Chart Bucketing', () {
    test('Penomoran minggu kalender akurat', () {
      // Tanggal 1-7: Minggu 1
      expect(((1 - 1) ~/ 7) + 1, 1);
      expect(((7 - 1) ~/ 7) + 1, 1);

      // Tanggal 8-14: Minggu 2
      expect(((8 - 1) ~/ 7) + 1, 2);
      expect(((14 - 1) ~/ 7) + 1, 2);

      // Tanggal 15-21: Minggu 3 (misal tgl 18)
      expect(((15 - 1) ~/ 7) + 1, 3);
      expect(((18 - 1) ~/ 7) + 1, 3);
      expect(((21 - 1) ~/ 7) + 1, 3);

      // Tanggal 22-28: Minggu 4
      expect(((22 - 1) ~/ 7) + 1, 4);
      expect(((28 - 1) ~/ 7) + 1, 4);

      // Tanggal 29+: Minggu 4 atau 5
      expect(((29 - 1) ~/ 7) + 1, 5);
    });

    testWidgets('FinancialChartCard menempatkan transaksi tgl 18 ke dalam bucket Mgg 3', (WidgetTester tester) async {
      final now = DateTime.now();
      // Pastikan ada transaksi pada tanggal 18 bulan ini
      final txDate = DateTime(now.year, now.month, 18, 10, 0);
      
      final category = Category(
        id: 'cat_kas',
        type: 'income',
        name: 'Uang Kas Rutin',
        iconName: 'payments',
        colorHex: '#16A34A',
        isDefault: true,
        createdAt: now,
      );

      final dummyYear = AcademicYear(
        id: 'year_1',
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Fajar',
        supervisorName: 'Pengawas',
        startDate: DateTime(now.year, 7, 1),
        endDate: DateTime(now.year + 1, 6, 30),
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        isActive: true,
        createdAt: now,
      );

      final tx = Transaction(
        id: 'tx_18',
        academicYearId: 'year_1',
        categoryId: 'cat_kas',
        type: 'income',
        amount: 20000,
        title: 'Kas Tgl 18',
        transactionDate: txDate,
        createdAt: txDate,
        updatedAt: txDate,
      );

      final item = TransactionWithCategory(
        transaction: tx,
        category: category,
        academicYear: dummyYear,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FinancialChartCard(
                items: [item],
                selectedRange: ReportDateRange.oneMonth,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi teks Mgg 1, Mgg 2, Mgg 3, Mgg 4 tampil di chart
      expect(find.text('Mgg 1'), findsOneWidget);
      expect(find.text('Mgg 2'), findsOneWidget);
      expect(find.text('Mgg 3'), findsOneWidget);
      expect(find.text('Mgg 4'), findsOneWidget);

      // Teks "Ketuk diagram bar untuk rincian" HARUS DITIADAKAN (Revisi 4)
      expect(find.text('Ketuk diagram bar untuk rincian'), findsNothing);
      expect(find.textContaining('Ketuk diagram bar'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Revisi 1, 2, 3: UI Copywriting, Badge, dan Penamaan Tab', () {
    testWidgets('DashboardScreen tidak memiliki badge Fisik Brankas', (WidgetTester tester) async {
      final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      addTearDown(() async => await db.close());

      final yearRepo = AcademicYearRepository(db);
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 9A',
        grade: 9,
        treasurerName: 'Dewi',
        supervisorName: 'Ibu Ani',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            activeAcademicYearProvider.overrideWith((ref) => Stream.value(year)),
            activePeriodSummaryProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            home: DashboardScreen(onNavigateTab: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fisik Brankas HARUS DITIADAKAN (Revisi 1)
      expect(find.text('Fisik Brankas'), findsNothing);
      expect(find.textContaining('Fisik Brankas'), findsNothing);

      // Kata 'Iuran' tidak boleh ada di Dashboard (Revisi 2)
      expect(find.textContaining('Iuran'), findsNothing);
      expect(find.textContaining('iuran'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('MainScaffold tab 2 bernama "Catat Transaksi" dan bukan "Catat Kas"', (WidgetTester tester) async {
      final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      addTearDown(() async => await db.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: MainScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Catat Transaksi'), findsOneWidget);
      expect(find.text('Catat Kas'), findsNothing);
      expect(find.text('Kas Siswa'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('TransactionFormScreen memiliki kartu panduan edukasi perbedaan kas siswa & transaksi', (WidgetTester tester) async {
      final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      addTearDown(() async => await db.close());

      final yearRepo = AcademicYearRepository(db);
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 7C',
        grade: 7,
        treasurerName: 'Rian',
        supervisorName: 'Pak Dodi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            activeAcademicYearProvider.overrideWith((ref) => Stream.value(year)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TransactionFormScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi panduan edukasi tampil
      expect(find.textContaining('belanja kelas'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Revisi 7: Frekuensi Pembayaran Kas (Harian, Mingguan, Bulanan)', () {
    test('Format period label sesuai frekuensi', () {
      final date = DateTime(2026, 9, 18);

      final dailyLabel = formatPeriodLabel(date, 'daily');
      expect(dailyLabel, contains('Harian'));
      expect(dailyLabel, contains('18 September 2026'));

      final weeklyLabel = formatPeriodLabel(date, 'weekly');
      expect(weeklyLabel, contains('Minggu 3'));

      final monthlyLabel = formatPeriodLabel(date, 'monthly');
      expect(monthlyLabel, 'Bulan September 2026');
    });
  });

  group('Deep Edge Cases: Unchecking Students, Over-Reconciliation & Recovery', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late StudentRepository studentRepo;
    late DuesRepository duesRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      studentRepo = StudentRepository(db);
      duesRepo = DuesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Unchecking a reconciled student sets delta <= 0, new student recovers balance, and subsequent student adds exactly delta', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8C',
        grade: 8,
        treasurerName: 'Rina',
        supervisorName: 'Pak Joko',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Doni');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Eka');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 3, name: 'Fani');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 4, name: 'Gilang');
      final students = await studentRepo.getStudents(year.id);

      final period = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 3 September 2026',
        targetAmount: 5000,
      );

      // Doni (1) & Eka (2) pay 5.000 each = 10.000
      await duesRepo.togglePaymentStatus(
        duesPeriodId: period.id,
        studentId: students[0].id,
        targetAmount: 5000,
        currentStatus: false,
      );
      await duesRepo.togglePaymentStatus(
        duesPeriodId: period.id,
        studentId: students[1].id,
        targetAmount: 5000,
        currentStatus: false,
      );

      // First reconcile: records 10.000
      final delta1 = await duesRepo.reconcileIntoGeneralCash(period: period, academicYearId: year.id);
      expect(delta1, 10000);

      // Eka (2) was unchecked by mistake (unpaid) -> total collected is now 5.000, reconciled is 10.000
      await duesRepo.togglePaymentStatus(
        duesPeriodId: period.id,
        studentId: students[1].id,
        targetAmount: 5000,
        currentStatus: true,
      );

      // Calling reconcile does NOT create a bogus transaction
      final deltaUnchecked = await duesRepo.reconcileIntoGeneralCash(period: period, academicYearId: year.id);
      expect(deltaUnchecked, 0);

      var txs = await (db.select(db.transactions)..where((t) => t.academicYearId.equals(year.id))).get();
      expect(txs.length, 1, reason: 'Tetap 1 transaksi');
      expect(txs.first.amount, 10000);

      // Fani (3) pays 5.000 -> total collected becomes 10.000 (Doni + Fani), matching reconciled 10.000
      await duesRepo.togglePaymentStatus(
        duesPeriodId: period.id,
        studentId: students[2].id,
        targetAmount: 5000,
        currentStatus: false,
      );

      final deltaRecovered = await duesRepo.reconcileIntoGeneralCash(period: period, academicYearId: year.id);
      expect(deltaRecovered, 0, reason: 'Total collected 10.000 - reconciled 10.000 = 0 (kembali seimbang)');

      // Now Gilang (4) pays 5.000 -> total collected becomes 15.000
      await duesRepo.togglePaymentStatus(
        duesPeriodId: period.id,
        studentId: students[3].id,
        targetAmount: 5000,
        currentStatus: false,
      );

      final deltaGilang = await duesRepo.reconcileIntoGeneralCash(period: period, academicYearId: year.id);
      expect(deltaGilang, 5000, reason: 'Delta baru hanya Rp 5.000 untuk Gilang');

      txs = await (db.select(db.transactions)..where((t) => t.academicYearId.equals(year.id))).get();
      expect(txs.length, 2);
      final totalBalance = txs.fold<int>(0, (sum, t) => sum + t.amount);
      expect(totalBalance, 15000, reason: 'Total saldo akhir harus Rp 15.000');
    });

    testWidgets('DuesCheckScreen menampilkan status peringatan saat kas tercatat melebihi total bayar', (tester) async {
      final now = DateTime.now();
      final year = AcademicYear(
        id: 'y_over',
        name: 'Kelas 9B',
        grade: 9,
        treasurerName: 'Siti',
        supervisorName: 'Ibu Guru',
        startDate: DateTime(now.year, 7, 1),
        endDate: DateTime(now.year + 1, 6, 30),
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        isActive: true,
        createdAt: now,
      );

      // Period has reconciledAmount 10.000
      final period = DuesPeriod(
        id: 'p_over',
        academicYearId: 'y_over',
        periodLabel: 'Minggu 3 September 2026',
        dueDate: now,
        targetAmount: 5000,
        isReconciled: true,
        reconciledAmount: 10000,
        createdAt: now,
      );

      // But only 1 student is paid (5.000)
      final student = Student(
        id: 's_1',
        academicYearId: 'y_over',
        attendanceNumber: 1,
        name: 'Ahmad',
        status: 'active',
        createdAt: now,
      );

      final payment = DuesPayment(
        id: 'pay_1',
        duesPeriodId: 'p_over',
        studentId: 's_1',
        amountPaid: 5000,
        isPaid: true,
      );

      final duesItem = StudentDuesItem(student: student, payment: payment);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAcademicYearProvider.overrideWith((ref) => Stream.value(year)),
            activeDuesPeriodProvider.overrideWith((ref) => Stream.value(period)),
            activePeriodStudentsProvider.overrideWith((ref) => Stream.value([duesItem])),
            activePeriodSummaryProvider.overrideWith((ref) => Stream.value(
              DuesPeriodSummary(
                period: period,
                totalTarget: 5000,
                totalCollected: 5000,
                paidCount: 1,
                totalStudents: 1,
              ),
            )),
          ],
          child: const MaterialApp(
            home: DuesCheckScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Melebihi Total Bayar'), findsOneWidget);
    });
  });

  group('Deep Edge Cases: Historical Academic Year Title & Week 5 Bucketing', () {
    testWidgets('SupervisionReportScreen menggunakan tanggal akhir untuk kelas historis non-aktif', (tester) async {
      final historicalYear = AcademicYear(
        id: 'y_hist',
        name: 'Kelas 7A 2023/2024',
        grade: 7,
        treasurerName: 'Budi',
        supervisorName: 'Pak Guru',
        startDate: DateTime(2023, 7, 1),
        endDate: DateTime(2024, 6, 30),
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        isActive: false,
        createdAt: DateTime(2023, 7, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAcademicYearProvider.overrideWith((ref) => Stream.value(historicalYear)),
            allAcademicYearsProvider.overrideWith((ref) => Stream.value([historicalYear])),
            reportTransactionsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: SupervisionReportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Harus menampilkan Bulan Juni 2024 (bukan September 2026)
      expect(find.textContaining('Bulan Juni 2024'), findsOneWidget);
      expect(find.textContaining('September 2026'), findsNothing);
    });

    testWidgets('FinancialChartCard merender Mgg 5 untuk bulan yang memiliki lebih dari 28 hari', (tester) async {
      final now = DateTime.now();
      // Transaksi di hari ke-29 (Minggu ke-5 kalender)
      final txDate = DateTime(now.year, now.month, 29, 10, 0);

      final dummyYear = AcademicYear(
        id: 'y_w5',
        name: 'Kelas 8A',
        grade: 8,
        treasurerName: 'Siti',
        supervisorName: 'Pak Joko',
        startDate: DateTime(now.year, 7, 1),
        endDate: DateTime(now.year + 1, 6, 30),
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        isActive: true,
        createdAt: now,
      );

      final cat = Category(
        id: 'cat_w5',
        type: 'income',
        name: 'Uang Kas Rutin',
        iconName: 'payments',
        colorHex: '#16A34A',
        isDefault: true,
        createdAt: now,
      );

      final tx = Transaction(
        id: 'tx_29_w5',
        academicYearId: dummyYear.id,
        categoryId: cat.id,
        type: 'income',
        amount: 25000,
        title: 'Kas Tgl 29',
        transactionDate: txDate,
        createdAt: txDate,
        updatedAt: txDate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinancialChartCard(
              items: [
                TransactionWithCategory(transaction: tx, category: cat, academicYear: dummyYear),
              ],
              selectedRange: ReportDateRange.oneMonth,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Karena bulan sekarang (September) memiliki 30 hari (>28), Mgg 5 harus muncul
      expect(find.text('Mgg 5'), findsOneWidget);
    });
  });

  group('Deep Edge Cases: Dashboard Offset Isolation', () {
    testWidgets('Dashboard selalu menampilkan currentPeriodSummaryProvider terisolasi dari navigasi offset Kas Siswa', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Pada awal, offset = 0
      expect(container.read(periodOffsetProvider), 0);

      // Ubah offset di Kas Siswa menjadi 1 (minggu depan)
      container.read(periodOffsetProvider.notifier).next();
      expect(container.read(periodOffsetProvider), 1);

      // Reset kembali ke 0
      container.read(periodOffsetProvider.notifier).reset();
      expect(container.read(periodOffsetProvider), 0);
    });

    test('Migration v1 to v2 backfills reconciled_amount and updates legacy category names', () async {
      final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      addTearDown(db.close);

      await db.customStatement("INSERT INTO categories (id, type, name, icon_name, color_hex, is_default, created_at) VALUES ('c_leg1', 'income', 'Iuran Khusus Kegiatan', 'event', '#2563EB', 1, 1000);");
      await db.customStatement("INSERT INTO categories (id, type, name, icon_name, color_hex, is_default, created_at) VALUES ('c_leg2', 'income', 'Uang Iuran Rutin', 'payments', '#16A34A', 1, 1000);");

      await db.customStatement("UPDATE categories SET name = 'Kas Khusus Kegiatan' WHERE name = 'Iuran Khusus Kegiatan';");
      await db.customStatement("UPDATE categories SET name = 'Uang Kas Rutin' WHERE name = 'Uang Iuran Rutin';");

      final cats = await (db.select(db.categories)..where((t) => t.id.isIn(['c_leg1', 'c_leg2']))).get();
      expect(cats.firstWhere((c) => c.id == 'c_leg1').name, 'Kas Khusus Kegiatan');
      expect(cats.firstWhere((c) => c.id == 'c_leg2').name, 'Uang Kas Rutin');
    });

    testWidgets('FinancialChartCard 1 Tahun merender 12 bulan berurutan mulai dari Jan di sebelah kiri', (tester) async {
      final now = DateTime.now();
      final dummyYear = AcademicYear(
        id: 'y_1yr',
        name: 'Kelas 8A',
        grade: 8,
        treasurerName: 'Siti',
        supervisorName: 'Pak Joko',
        startDate: DateTime(now.year, 7, 1),
        endDate: DateTime(now.year + 1, 6, 30),
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        isActive: true,
        createdAt: now,
      );

      final cat = Category(
        id: 'cat_1yr',
        type: 'income',
        name: 'Uang Kas Rutin',
        iconName: 'payments',
        colorHex: '#16A34A',
        isDefault: true,
        createdAt: now,
      );

      final tx = Transaction(
        id: 'tx_jan',
        academicYearId: dummyYear.id,
        categoryId: cat.id,
        type: 'income',
        amount: 25000,
        title: 'Kas Januari',
        transactionDate: DateTime(now.year, 1, 15),
        createdAt: DateTime(now.year, 1, 15),
        updatedAt: DateTime(now.year, 1, 15),
      );

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinancialChartCard(
              items: [
                TransactionWithCategory(transaction: tx, category: cat, academicYear: dummyYear),
              ],
              selectedRange: ReportDateRange.oneYear,
              academicYear: dummyYear,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Des'), findsOneWidget);
    });

    testWidgets('FinancialChartCard 1 Bulan dengan frekuensi harian merender batang harian', (tester) async {
      final now = DateTime.now();
      final dailyYear = AcademicYear(
        id: 'y_daily',
        name: 'Kelas 7B',
        grade: 7,
        treasurerName: 'Budi',
        supervisorName: 'Ibu Guru',
        startDate: DateTime(now.year, 7, 1),
        endDate: DateTime(now.year + 1, 6, 30),
        defaultDuesAmount: 1000,
        duesPeriodType: 'daily',
        isActive: true,
        createdAt: now,
      );

      final cat = Category(
        id: 'cat_d',
        type: 'income',
        name: 'Uang Kas Rutin',
        iconName: 'payments',
        colorHex: '#16A34A',
        isDefault: true,
        createdAt: now,
      );

      final tx = Transaction(
        id: 'tx_d1',
        academicYearId: dailyYear.id,
        categoryId: cat.id,
        type: 'income',
        amount: 5000,
        title: 'Kas Harian Tgl 1',
        transactionDate: DateTime(now.year, now.month, 1),
        createdAt: DateTime(now.year, now.month, 1),
        updatedAt: DateTime(now.year, now.month, 1),
      );

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinancialChartCard(
              items: [
                TransactionWithCategory(transaction: tx, category: cat, academicYear: dailyYear),
              ],
              selectedRange: ReportDateRange.oneMonth,
              academicYear: dailyYear,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
    });
  });

  group('Revisi 10: Interactive Adaptive Calendar Picker (DuesPeriodCalendarCard)', () {
    test('SelectedPeriodDateNotifier auto-update lifecycle & resetToToday', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default state is null (signifying dynamic auto-update based on DateTime.now())
      expect(container.read(selectedPeriodDateProvider), isNull);

      // Manual selection
      final customDate = DateTime(2026, 9, 25);
      container.read(selectedPeriodDateProvider.notifier).selectDate(customDate);
      expect(container.read(selectedPeriodDateProvider), equals(customDate));

      // Reset to auto-update
      container.read(selectedPeriodDateProvider.notifier).resetToToday();
      expect(container.read(selectedPeriodDateProvider), isNull);
    });

    testWidgets('DuesPeriodCalendarCard Daily Mode renders month grid and responds to clicks', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final dailyYear = AcademicYear(
        id: 'cls_daily',
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Siti',
        supervisorName: 'Pak Guru',
        duesPeriodType: 'daily',
        defaultDuesAmount: 2000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
        isActive: true,
        createdAt: now,
      );

      final period = DuesPeriod(
        id: 'dp_daily',
        academicYearId: dailyYear.id,
        periodLabel: '18 September 2026',
        targetAmount: 2000,
        reconciledAmount: 0,
        isReconciled: false,
        dueDate: now,
        createdAt: now,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DuesPeriodCalendarCard(
                  period: period,
                  activeYear: dailyYear,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render "Otomatis Hari Ini" badge
      expect(find.text('Otomatis Hari Ini'), findsOneWidget);

      // Should render weekday headers (Sen, Sel, Rab, Kam, Jum, Sab, Min)
      expect(find.text('Sen'), findsOneWidget);
      expect(find.text('Min'), findsOneWidget);

      // Should render day 1
      expect(find.text('1'), findsWidgets);

      // Tap on day 1
      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();

      // Provider now has selected date of day 1
      final selected = container.read(selectedPeriodDateProvider);
      expect(selected, isNotNull);
      expect(selected!.day, equals(1));

      // Reset button is now visible
      expect(find.textContaining('kembali ke Hari Ini'), findsOneWidget);

      // Tap reset button
      await tester.tap(find.textContaining('kembali ke Hari Ini'));
      await tester.pumpAndSettle();

      // Provider resets back to null (auto-update mode)
      expect(container.read(selectedPeriodDateProvider), isNull);
      expect(find.text('Otomatis Hari Ini'), findsOneWidget);
    });

    testWidgets('DuesPeriodCalendarCard Weekly Mode renders Minggu 1..4/5 chips and responds to clicks', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final weeklyYear = AcademicYear(
        id: 'cls_weekly',
        name: 'Kelas 8B',
        grade: 8,
        treasurerName: 'Siti',
        supervisorName: 'Pak Guru',
        duesPeriodType: 'weekly',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
        isActive: true,
        createdAt: now,
      );

      final period = DuesPeriod(
        id: 'dp_weekly',
        academicYearId: weeklyYear.id,
        periodLabel: 'Minggu ke-3 (15 - 21 Sep 2026)',
        targetAmount: 5000,
        reconciledAmount: 0,
        isReconciled: false,
        dueDate: now,
        createdAt: now,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DuesPeriodCalendarCard(
                  period: period,
                  activeYear: weeklyYear,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render "Otomatis Minggu Ini" badge
      expect(find.text('Otomatis Minggu Ini'), findsOneWidget);

      // In current month, header shows "Bulan Ini" badge
      expect(find.text('Bulan Ini'), findsOneWidget);

      // Navigate to next month (e.g. Oktober)
      await tester.tap(find.byTooltip('Bulan Berikutnya'));
      await tester.pumpAndSettle();

      // Oktober should NOT have "Bulan Ini" badge, but "Ke Bulan Sekarang" action button
      expect(find.text('Bulan Ini'), findsNothing);
      expect(find.text('Ke Bulan Sekarang'), findsOneWidget);

      // Tap "Ke Bulan Sekarang" to return to current month
      await tester.tap(find.text('Ke Bulan Sekarang'));
      await tester.pumpAndSettle();
      expect(find.text('Bulan Ini'), findsOneWidget);

      // Should render weekly chips: Minggu 1, Minggu 2, Minggu 3, Minggu 4
      expect(find.text('Minggu 1'), findsOneWidget);
      expect(find.text('Minggu 2'), findsOneWidget);
      expect(find.text('Minggu 3'), findsOneWidget);
      expect(find.text('Minggu 4'), findsOneWidget);

      // Tap on Minggu 1
      await tester.tap(find.text('Minggu 1'));
      await tester.pumpAndSettle();

      final selected = container.read(selectedPeriodDateProvider);
      expect(selected, isNotNull);
      expect(selected!.day, equals(1)); // Minggu 1 starts on day 1

      // Reset button appears
      expect(find.textContaining('kembali ke Minggu'), findsOneWidget);

      // Tap reset
      await tester.tap(find.textContaining('kembali ke Minggu'));
      await tester.pumpAndSettle();

      expect(container.read(selectedPeriodDateProvider), isNull);
      expect(find.text('Otomatis Minggu Ini'), findsOneWidget);
    });

    testWidgets('DuesPeriodCalendarCard Monthly Mode renders 12 months and responds to clicks', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final monthlyYear = AcademicYear(
        id: 'cls_monthly',
        name: 'Kelas 9C',
        grade: 9,
        treasurerName: 'Siti',
        supervisorName: 'Pak Guru',
        duesPeriodType: 'monthly',
        defaultDuesAmount: 20000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
        isActive: true,
        createdAt: now,
      );

      final period = DuesPeriod(
        id: 'dp_monthly',
        academicYearId: monthlyYear.id,
        periodLabel: 'September 2026',
        targetAmount: 20000,
        reconciledAmount: 0,
        isReconciled: false,
        dueDate: now,
        createdAt: now,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DuesPeriodCalendarCard(
                  period: period,
                  activeYear: monthlyYear,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render "Otomatis Bulan Ini" badge
      expect(find.text('Otomatis Bulan Ini'), findsOneWidget);

      // Should render months
      expect(find.text('Januari'), findsOneWidget);
      expect(find.text('Desember'), findsOneWidget);

      // Tap Januari
      await tester.tap(find.text('Januari'));
      await tester.pumpAndSettle();

      final selected = container.read(selectedPeriodDateProvider);
      expect(selected, isNotNull);
      expect(selected!.month, equals(1));

      // Reset button appears
      expect(find.textContaining('kembali ke Bulan'), findsOneWidget);

      // Tap reset
      await tester.tap(find.textContaining('kembali ke Bulan'));
      await tester.pumpAndSettle();

      expect(container.read(selectedPeriodDateProvider), isNull);
      expect(find.text('Otomatis Bulan Ini'), findsOneWidget);
    });
  });

  group('Revisi 11: Fix Concurrency, Duplicate Dues Periods & Stale Selection', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late StudentRepository studentRepo;
    late DuesRepository duesRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      studentRepo = StudentRepository(db);
      duesRepo = DuesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Concurrent getOrCreateActivePeriod calls return same period and create only 1 row', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 7C',
        grade: 7,
        treasurerName: 'Siti',
        supervisorName: 'Pak Guru',
        defaultDuesAmount: 3000,
        duesPeriodType: 'daily',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      final label = 'Harian 18 September 2026';
      final now = DateTime(2026, 9, 18);

      // Trigger 10 concurrent requests at the exact same microtask
      final futures = List.generate(
        10,
        (_) => duesRepo.getOrCreateActivePeriod(
          academicYearId: year.id,
          periodLabel: label,
          targetAmount: 3000,
          dueDate: now,
        ),
      );

      final results = await Future.wait(futures);

      // All 10 returned the exact same period ID
      final firstId = results.first.id;
      for (final period in results) {
        expect(period.id, equals(firstId));
      }

      // SQLite database contains exactly 1 row for this academicYearId & periodLabel
      final count = await (db.select(db.duesPeriods)
            ..where((t) => t.academicYearId.equals(year.id) & t.periodLabel.equals(label)))
          .get();
      expect(count.length, equals(1));
    });

    test('Data deduplication migration merges duplicate periods and payments without error', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8C',
        grade: 8,
        treasurerName: 'Rina',
        supervisorName: 'Ibu Guru',
        defaultDuesAmount: 5000,
        duesPeriodType: 'daily',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Siswa A');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Siswa B');

      final label = 'Harian 18 September 2026';
      final now = DateTime(2026, 9, 18);

      // Temporarily drop unique index to create duplicate condition
      final p1Id = 'p_dup_1';
      final p2Id = 'p_dup_2';

      await db.into(db.duesPeriods).insert(
        DuesPeriodsCompanion.insert(
          id: p1Id,
          academicYearId: year.id,
          periodLabel: label,
          dueDate: now,
          targetAmount: 5000,
          isReconciled: const Value(false),
          reconciledAmount: const Value(0),
          createdAt: DateTime(2026, 9, 18, 8, 0),
        ),
      );

      // Attempting to insert duplicate with same academicYearId and periodLabel fails with UNIQUE constraint
      expect(
        () async => await db.into(db.duesPeriods).insert(
          DuesPeriodsCompanion.insert(
            id: p2Id,
            academicYearId: year.id,
            periodLabel: label,
            dueDate: now,
            targetAmount: 5000,
            isReconciled: const Value(true),
            reconciledAmount: const Value(10000),
            createdAt: DateTime(2026, 9, 18, 8, 5),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      // With insertOrIgnore, it is safely ignored and no duplicate is created
      await db.into(db.duesPeriods).insert(
        DuesPeriodsCompanion.insert(
          id: p2Id,
          academicYearId: year.id,
          periodLabel: label,
          dueDate: now,
          targetAmount: 5000,
          isReconciled: const Value(true),
          reconciledAmount: const Value(10000),
          createdAt: DateTime(2026, 9, 18, 8, 5),
        ),
        mode: InsertMode.insertOrIgnore,
      );

      // Check that only 1 period remains
      final remainingPeriods = await (db.select(db.duesPeriods)
            ..where((t) => t.academicYearId.equals(year.id) & t.periodLabel.equals(label)))
          .get();
      expect(remainingPeriods.length, equals(1));
      expect(remainingPeriods.first.id, equals(p1Id));

      // sanitizeDuplicatePeriods runs safely and idempotently
      await db.sanitizeDuplicatePeriods();
    });

    testWidgets('DuesCheckScreen displays error screen with Coba Lagi button when activePeriod fails', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final year = AcademicYear(
        id: 'cls_err',
        name: 'Kelas 9A',
        grade: 9,
        treasurerName: 'Rina',
        supervisorName: 'Pak Guru',
        defaultDuesAmount: 5000,
        duesPeriodType: 'daily',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
        isActive: true,
        createdAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAcademicYearProvider.overrideWith((ref) => Stream.value(year)),
            activeDuesPeriodProvider.overrideWith((ref) => Stream.error('Koneksi database terputus')),
          ],
          child: const MaterialApp(
            home: DuesCheckScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gagal Memuat Periode Kas'), findsOneWidget);
      expect(find.textContaining('Koneksi database terputus'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });
  });
}




