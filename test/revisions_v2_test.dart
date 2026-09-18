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
import 'package:bendahara_app/presentation/screens/main_scaffold.dart';
import 'package:bendahara_app/presentation/screens/transaction_form_screen.dart';
import 'package:bendahara_app/presentation/widgets/financial_chart_card.dart';

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
}
