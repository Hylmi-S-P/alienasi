import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uuid/uuid.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/dues_repository.dart';
import 'package:bendahara_app/data/repositories/student_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/screens/dues_check_screen.dart';
import 'package:bendahara_app/presentation/widgets/dues_period_calendar_card.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Dues Concurrency, Deduplication & State Leakage Tests', () {
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

    test('1. Concurrent getOrCreateActivePeriod calls resolve to the exact same period instance', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8A',
        grade: 8,
        treasurerName: 'Lina',
        supervisorName: 'Pak Hadi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'daily',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Siswa A');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Siswa B');

      // Invoke 5 concurrent calls with the exact same academicYearId and periodLabel
      final futures = List.generate(5, (_) => duesRepo.getOrCreateActivePeriod(
            academicYearId: year.id,
            periodLabel: 'Harian 18 September 2026',
            targetAmount: 5000,
            dueDate: DateTime(2026, 9, 18),
          ));

      final results = await Future.wait(futures);

      // Verify all 5 received the exact same period ID
      final firstId = results.first.id;
      for (final p in results) {
        expect(p.id, equals(firstId));
      }

      // Verify exactly 1 row exists in SQLite
      final rows = await (db.select(db.duesPeriods)
            ..where((t) => t.academicYearId.equals(year.id) & t.periodLabel.equals('Harian 18 September 2026')))
          .get();
      expect(rows.length, equals(1));
    });

    test('2. Schema uniqueKeys prevents inserting duplicate period with same academicYearId and periodLabel', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8B',
        grade: 8,
        treasurerName: 'Deni',
        supervisorName: 'Bu Nur',
        defaultDuesAmount: 5000,
        duesPeriodType: 'daily',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      const uuid = Uuid();
      await db.into(db.duesPeriods).insert(
        DuesPeriodsCompanion.insert(
          id: uuid.v4(),
          academicYearId: year.id,
          periodLabel: 'Harian 17 September 2026',
          dueDate: DateTime(2026, 9, 17),
          targetAmount: 5000,
          createdAt: DateTime.now(),
        ),
      );

      // Attempting to insert duplicate with same academicYearId and periodLabel throws SqliteException
      expect(
        () async => await db.into(db.duesPeriods).insert(
          DuesPeriodsCompanion.insert(
            id: uuid.v4(),
            academicYearId: year.id,
            periodLabel: 'Harian 17 September 2026',
            dueDate: DateTime(2026, 9, 17),
            targetAmount: 5000,
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('3. Database deduplication routine cleans legacy duplicates, merges payments, and creates unique index', () async {
      // Create a raw SQLite executor simulating a pre-existing legacy database with no table-level UNIQUE constraint
      final rawSqlite = sql.sqlite3.openInMemory();
      
      // Setup legacy schema without UNIQUE on dues_periods
      rawSqlite.execute('''
        CREATE TABLE academic_years (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          grade INTEGER NOT NULL,
          treasurer_name TEXT,
          supervisor_name TEXT,
          default_dues_amount INTEGER NOT NULL DEFAULT 5000,
          dues_period_type TEXT NOT NULL DEFAULT 'weekly',
          start_date INTEGER NOT NULL,
          end_date INTEGER NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE students (
          id TEXT NOT NULL PRIMARY KEY,
          academic_year_id TEXT NOT NULL,
          attendance_number INTEGER NOT NULL,
          name TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'active',
          created_at INTEGER NOT NULL
        );
        CREATE TABLE categories (
          id TEXT NOT NULL PRIMARY KEY,
          type TEXT NOT NULL,
          name TEXT NOT NULL,
          icon_name TEXT NOT NULL,
          color_hex TEXT NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE transactions (
          id TEXT NOT NULL PRIMARY KEY,
          academic_year_id TEXT NOT NULL,
          type TEXT NOT NULL,
          amount INTEGER NOT NULL,
          transaction_date INTEGER NOT NULL,
          category_id TEXT NOT NULL,
          description TEXT,
          image_path TEXT,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE dues_periods (
          id TEXT NOT NULL PRIMARY KEY,
          academic_year_id TEXT NOT NULL,
          period_label TEXT NOT NULL,
          due_date INTEGER NOT NULL,
          target_amount INTEGER NOT NULL,
          is_reconciled INTEGER NOT NULL DEFAULT 0,
          reconciled_amount INTEGER NOT NULL DEFAULT 0,
          transaction_id TEXT,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE dues_payments (
          id TEXT NOT NULL PRIMARY KEY,
          dues_period_id TEXT NOT NULL,
          student_id TEXT NOT NULL,
          amount_paid INTEGER NOT NULL DEFAULT 0,
          is_paid INTEGER NOT NULL DEFAULT 0,
          paid_at INTEGER,
          notes TEXT,
          UNIQUE(dues_period_id, student_id)
        );
      ''');

      const uuid = Uuid();
      final yearId = uuid.v4();
      final s1Id = uuid.v4();
      final s2Id = uuid.v4();
      final p1Id = uuid.v4();
      final p2Id = uuid.v4();

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Seed year and 2 students
      rawSqlite.execute("INSERT INTO academic_years VALUES ('$yearId', 'Kelas 8C', 8, 'Tono', 'Pak Joko', 5000, 'daily', $nowMs, $nowMs, 1, $nowMs);");
      rawSqlite.execute("INSERT INTO students VALUES ('$s1Id', '$yearId', 1, 'Andi', 'active', $nowMs);");
      rawSqlite.execute("INSERT INTO students VALUES ('$s2Id', '$yearId', 2, 'Budi', 'active', $nowMs);");

      // Insert 2 legacy duplicate rows for "Harian 15 September 2026"
      // P1: Older, unreconciled
      rawSqlite.execute("INSERT INTO dues_periods VALUES ('$p1Id', '$yearId', 'Harian 15 September 2026', $nowMs, 5000, 0, 0, NULL, 1000);");
      // P2: Newer, reconciled with 5000
      rawSqlite.execute("INSERT INTO dues_periods VALUES ('$p2Id', '$yearId', 'Harian 15 September 2026', $nowMs, 5000, 1, 5000, NULL, 2000);");

      // P1 has Andi unpaid
      rawSqlite.execute("INSERT INTO dues_payments VALUES ('${uuid.v4()}', '$p1Id', '$s1Id', 0, 0, NULL, NULL);");
      // P2 has Andi paid 5000, Budi unpaid
      rawSqlite.execute("INSERT INTO dues_payments VALUES ('${uuid.v4()}', '$p2Id', '$s1Id', 5000, 1, $nowMs, NULL);");
      rawSqlite.execute("INSERT INTO dues_payments VALUES ('${uuid.v4()}', '$p2Id', '$s2Id', 0, 0, NULL, NULL);");

      // Now attach AppDatabase to this existing database!
      // This will run beforeOpen: _sanitizeDuplicatePeriods() and CREATE UNIQUE INDEX!
      final legacyAppDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.opened(rawSqlite)));
      final legacyDuesRepo = DuesRepository(legacyAppDb);

      // Verify via dues repository defensive getOrCreateActivePeriod that it works and duplicates are cleaned
      final period = await legacyDuesRepo.getOrCreateActivePeriod(
        academicYearId: yearId,
        periodLabel: 'Harian 15 September 2026',
        targetAmount: 5000,
      );
      expect(period, isNotNull);

      // Verify that exactly 1 period row remains in the database
      final remainingPeriods = await (legacyAppDb.select(legacyAppDb.duesPeriods)
            ..where((t) => t.academicYearId.equals(yearId) & t.periodLabel.equals('Harian 15 September 2026')))
          .get();
      expect(remainingPeriods.length, equals(1));
      
      final primary = remainingPeriods.first;
      expect(primary.isReconciled, isTrue);
      expect(primary.reconciledAmount, equals(5000));

      // Verify Andi's payment was merged as paid 5000 in the primary period
      final payments = await (legacyAppDb.select(legacyAppDb.duesPayments)
            ..where((t) => t.duesPeriodId.equals(primary.id)))
          .get();
      expect(payments.length, equals(2));
      final andiPayment = payments.firstWhere((p) => p.studentId == s1Id);
      expect(andiPayment.isPaid, isTrue);
      expect(andiPayment.amountPaid, equals(5000));

      await legacyAppDb.close();
    });

    testWidgets('4. Switching period dates clears selection and does not leak checked state', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8D',
        grade: 8,
        treasurerName: 'Mira',
        supervisorName: 'Pak Dodi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'daily',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Siti');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Riko');
      final students = await studentRepo.getStudents(year.id);

      final label17 = formatPeriodLabel(DateTime(2026, 9, 17), 'daily');
      final label18 = formatPeriodLabel(DateTime(2026, 9, 18), 'daily');

      // Create period 17 September: Siti is paid
      final p17 = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: label17,
        targetAmount: 5000,
        dueDate: DateTime(2026, 9, 17),
      );
      await duesRepo.markAsPaid(
        duesPeriodId: p17.id,
        studentId: students[0].id,
        targetAmount: 5000,
      );

      // Create period 18 September: Siti is unpaid
      final p18 = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: label18,
        targetAmount: 5000,
        dueDate: DateTime(2026, 9, 18),
      );
      expect(p18, isNotNull);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          transactionRepoProvider.overrideWithValue(TransactionRepository(db)),
        ],
      );
      addTearDown(container.dispose);

      // Start on 17 September
      container.read(selectedPeriodDateProvider.notifier).selectDate(DateTime(2026, 9, 17));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DuesCheckScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify date 17 is showing and Siti has Lunas badge
      expect(find.text(label17), findsOneWidget);
      expect(find.text('Lunas (1)'), findsOneWidget);

      // Switch to 18 September
      container.read(selectedPeriodDateProvider.notifier).selectDate(DateTime(2026, 9, 18));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify date 18 is showing and Siti is NOT Lunas (Belum Bayar (2))
      expect(find.text(label18), findsOneWidget);
      expect(find.text('Belum Bayar (2)'), findsOneWidget);
    });

    testWidgets('5. DuesPeriodCalendarCard chevron steps ±1 day when on a custom selected date', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8E',
        grade: 8,
        treasurerName: 'Bayu',
        supervisorName: 'Bu Mega',
        defaultDuesAmount: 5000,
        duesPeriodType: 'daily',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          transactionRepoProvider.overrideWithValue(TransactionRepository(db)),
        ],
      );
      addTearDown(container.dispose);

      // Set initial custom date to 17 September 2026
      container.read(selectedPeriodDateProvider.notifier).selectDate(DateTime(2026, 9, 17));

      final period17 = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Harian 17 September 2026',
        targetAmount: 5000,
        dueDate: DateTime(2026, 9, 17),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DuesPeriodCalendarCard(
                period: period17,
                activeYear: year,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Periode Sebelumnya (chevron left)
      final prevChevron = find.byTooltip('Periode Sebelumnya');
      expect(prevChevron, findsOneWidget);
      await tester.tap(prevChevron);
      await tester.pumpAndSettle();

      // Verify custom date stepped back to 16 September (NOT jumping back to today)
      final dateAfterPrev = container.read(selectedPeriodDateProvider);
      expect(dateAfterPrev, isNotNull);
      expect(dateAfterPrev!.year, equals(2026));
      expect(dateAfterPrev.month, equals(9));
      expect(dateAfterPrev.day, equals(16));

      // Tap Periode Berikutnya (chevron right)
      final nextChevron = find.byTooltip('Periode Berikutnya');
      expect(nextChevron, findsOneWidget);
      await tester.tap(nextChevron);
      await tester.pumpAndSettle();

      // Verify custom date stepped forward to 17 September
      final dateAfterNext = container.read(selectedPeriodDateProvider);
      expect(dateAfterNext, isNotNull);
      expect(dateAfterNext!.year, equals(2026));
      expect(dateAfterNext.month, equals(9));
      expect(dateAfterNext.day, equals(17));
    });
  });
}
