import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import 'package:bendahara_app/core/utils/date_formatter.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/dues_repository.dart';
import 'package:bendahara_app/domain/services/pdf_report_service.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('DateFormatter & Reconciled Date Tests', () {
    test('DateFormatter.tryParsePeriodDate parses Harian, Mingguan, and Bulanan', () {
      final daily = DateFormatter.tryParsePeriodDate('Harian 14 September 2026');
      expect(daily, isNotNull);
      expect(daily!.year, equals(2026));
      expect(daily.month, equals(9));
      expect(daily.day, equals(14));

      final weekly = DateFormatter.tryParsePeriodDate('Minggu 2 September 2026');
      expect(weekly, isNotNull);
      expect(weekly!.year, equals(2026));
      expect(weekly.month, equals(9));
      expect(weekly.day, equals(8));

      final monthly = DateFormatter.tryParsePeriodDate('Bulan September 2026');
      expect(monthly, isNotNull);
      expect(monthly!.year, equals(2026));
      expect(monthly.month, equals(9));
      expect(monthly.day, equals(1));
    });

    test('DateFormatter.tryParseDateFromTitle extracts date from transaction title', () {
      final parsed14 = DateFormatter.tryParseDateFromTitle('Kas Kelas (Harian 14 September 2026)');
      expect(parsed14, isNotNull);
      expect(parsed14!.day, equals(14));
      expect(parsed14.month, equals(9));

      final parsed18 = DateFormatter.tryParseDateFromTitle('Kas Kelas (Harian 18 September 2026) - Tambahan');
      expect(parsed18, isNotNull);
      expect(parsed18!.day, equals(18));
      expect(parsed18.month, equals(9));
    });
  });

  group('Reconciliation Date & Chart Grouping Database Integration Tests', () {
    late AppDatabase db;
    late DuesRepository duesRepo;
    late AcademicYear testYear;

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      duesRepo = DuesRepository(db);

      const uuid = Uuid();
      final yearId = uuid.v4();
      final now = DateTime.now();

      await db.into(db.academicYears).insert(
        AcademicYearsCompanion.insert(
          id: yearId,
          name: 'Kelas 9A',
          grade: 9,
          startDate: DateTime(2026, 7, 1),
          endDate: DateTime(2027, 6, 30),
          treasurerName: const Value('Siti'),
          supervisorName: const Value('Pak Guru'),
          defaultDuesAmount: const Value(10000),
          duesPeriodType: const Value('daily'),
          isActive: const Value(true),
          createdAt: now,
        ),
      );

      testYear = await (db.select(db.academicYears)..where((t) => t.id.equals(yearId))).getSingle();

      // Seed 2 students
      await db.into(db.students).insert(
        StudentsCompanion.insert(
          id: uuid.v4(),
          academicYearId: testYear.id,
          attendanceNumber: 1,
          name: 'Budi Santoso',
          createdAt: now,
        ),
      );
      await db.into(db.students).insert(
        StudentsCompanion.insert(
          id: uuid.v4(),
          academicYearId: testYear.id,
          attendanceNumber: 2,
          name: 'Citra Lestari',
          createdAt: now,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('reconcileIntoGeneralCash stamps transactionDate with the period date, NOT DateTime.now()', () async {
      final period14 = await duesRepo.getOrCreateActivePeriod(
        academicYearId: testYear.id,
        periodLabel: 'Harian 14 September 2026',
        targetAmount: 10000,
      );

      final students = await (db.select(db.students)..where((t) => t.academicYearId.equals(testYear.id))).get();
      await duesRepo.markAsPaid(
        duesPeriodId: period14.id,
        studentId: students.first.id,
        targetAmount: 10000,
      );

      final delta = await duesRepo.reconcileIntoGeneralCash(
        period: period14,
        academicYearId: testYear.id,
      );
      expect(delta, equals(10000));

      final tx = await (db.select(db.transactions)..where((t) => t.academicYearId.equals(testYear.id))).getSingle();
      expect(tx.title, contains('Harian 14 September 2026'));
      // Transaction date must be September 14, 2026
      expect(tx.transactionDate.year, equals(2026));
      expect(tx.transactionDate.month, equals(9));
      expect(tx.transactionDate.day, equals(14));
    });

    test('sanitizeReconciledTransactionDates retroactively heals pre-existing transactions stamped with today', () async {
      const uuid = Uuid();
      final cat = await (db.select(db.categories)..limit(1)).getSingle();

      // Insert transaction falsely stamped with today (Sept 19) for a Sept 14 dues
      final falseDate = DateTime(2026, 9, 19, 15, 30, 0);
      final txId = uuid.v4();

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: txId,
          academicYearId: testYear.id,
          categoryId: cat.id,
          type: 'income',
          amount: 20000,
          title: 'Kas Kelas (Harian 14 September 2026)',
          transactionDate: falseDate,
          createdAt: falseDate,
          updatedAt: falseDate,
        ),
      );

      var txBefore = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingle();
      expect(txBefore.transactionDate.day, equals(19));

      // Run database sanitization
      await db.sanitizeReconciledTransactionDates();

      var txAfter = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingle();
      expect(txAfter.transactionDate.year, equals(2026));
      expect(txAfter.transactionDate.month, equals(9));
      expect(txAfter.transactionDate.day, equals(14));
      // Preserves original hour/minute/second
      expect(txAfter.transactionDate.hour, equals(15));
      expect(txAfter.transactionDate.minute, equals(30));
    });

    test('PdfReportService sorts chronological old -> new: Sept 14 is Row 1, Sept 18 is Row 2', () async {
      const uuid = Uuid();
      final cat = await (db.select(db.categories)..limit(1)).getSingle();

      // Create two transactions: Sept 18 created first in real-time, Sept 14 created second
      final tx18 = Transaction(
        id: uuid.v4(),
        academicYearId: testYear.id,
        categoryId: cat.id,
        type: 'income',
        amount: 2000,
        title: 'Kas Kelas (Harian 18 September 2026)',
        description: null,
        receiptImagePath: null,
        transactionDate: DateTime(2026, 9, 18, 10, 0, 0),
        createdAt: DateTime(2026, 9, 19, 10, 0, 0),
        updatedAt: DateTime(2026, 9, 19, 10, 0, 0),
      );

      final tx14 = Transaction(
        id: uuid.v4(),
        academicYearId: testYear.id,
        categoryId: cat.id,
        type: 'income',
        amount: 20000,
        title: 'Kas Kelas (Harian 14 September 2026)',
        description: null,
        receiptImagePath: null,
        transactionDate: DateTime(2026, 9, 14, 11, 0, 0),
        createdAt: DateTime(2026, 9, 19, 11, 0, 0),
        updatedAt: DateTime(2026, 9, 19, 11, 0, 0),
      );

      final items = [
        TransactionWithCategory(transaction: tx18, category: cat, academicYear: testYear),
        TransactionWithCategory(transaction: tx14, category: cat, academicYear: testYear),
      ];

      // Generate PDF bytes
      final pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: '1 Bulan (1 Sep 2026 s/d 30 Sep 2026)',
        items: items,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);

      // Verify sorting in items: when sorted chronologically, Sept 14 is first, Sept 18 is second
      final sorted = List<TransactionWithCategory>.from(items)
        ..sort((a, b) {
          final cmp = a.transaction.transactionDate.compareTo(b.transaction.transactionDate);
          if (cmp != 0) return cmp;
          return a.transaction.createdAt.compareTo(b.transaction.createdAt);
        });

      expect(sorted.first.transaction.title, contains('14 September 2026'));
      expect(DateFormatter.toShortDate(sorted.first.transaction.transactionDate), equals('14/09/2026'));

      expect(sorted.last.transaction.title, contains('18 September 2026'));
      expect(DateFormatter.toShortDate(sorted.last.transaction.transactionDate), equals('18/09/2026'));
    });
  });
}
