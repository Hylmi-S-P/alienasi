import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/dues_repository.dart';
import 'package:bendahara_app/data/repositories/student_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/domain/services/backup_restore_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('BackupRestoreService Tests', () {
    late AppDatabase db1;
    late AppDatabase db2;

    setUp(() {
      db1 = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      db2 = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    });

    tearDown(() async {
      await db1.close();
      await db2.close();
    });

    test('Full Roundtrip: Backup from db1 -> Parse preview -> Restore into db2 preserves 100% data', () async {
      final yearRepo = AcademicYearRepository(db1);
      final studentRepo = StudentRepository(db1);
      final duesRepo = DuesRepository(db1);
      final txRepo = TransactionRepository(db1);

      // 1. Setup sample data in db1
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8B Unggulan',
        grade: 8,
        treasurerName: 'Nadia Rahma',
        supervisorName: 'Pak Wali Kelas',
        defaultDuesAmount: 4000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Andi');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Bima');

      final students = await studentRepo.getStudents(year.id);
      final andi = students.firstWhere((s) => s.name == 'Andi');
      final bima = students.firstWhere((s) => s.name == 'Bima');

      final period = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 1 Juli 2026',
        targetAmount: 4000,
      );

      await duesRepo.markAsPaid(
        duesPeriodId: period.id,
        studentId: andi.id,
        targetAmount: 4000,
      );

      final categories = await db1.select(db1.categories).get();
      final catPemasukan = categories.firstWhere((c) => c.type == 'income');
      final catPengeluaran = categories.firstWhere((c) => c.type == 'expense');

      await txRepo.insertTransaction(
        academicYearId: year.id,
        categoryId: catPemasukan.id,
        title: 'Kas Rutin Awal',
        amount: 80000,
        type: 'income',
        transactionDate: DateTime(2026, 7, 2),
      );

      await txRepo.insertTransaction(
        academicYearId: year.id,
        categoryId: catPengeluaran.id,
        title: 'Beli Sapu & Pel',
        amount: 30000,
        type: 'expense',
        transactionDate: DateTime(2026, 7, 5),
      );

      // 2. Export Backup JSON
      final jsonString = await BackupRestoreService.createBackupJson(
        db: db1,
        academicYearId: year.id,
      );

      expect(jsonString, isNotEmpty);
      expect(jsonString, contains('Kelas 8B Unggulan'));
      expect(jsonString, contains('Andi'));
      expect(jsonString, contains('Bima'));

      // 3. Parse and Preview Verification
      final preview = BackupRestoreService.parseAndPreview(jsonString);
      expect(preview.academicYearName, 'Kelas 8B Unggulan');
      expect(preview.schoolYear, '2026/2027');
      expect(preview.treasurerName, 'Nadia Rahma');
      expect(preview.studentsCount, 2);
      expect(preview.transactionsCount, 2);
      expect(preview.periodsCount, 1);
      expect(preview.totalBalance, 50000); // 80.000 - 30.000

      // 4. Restore into empty db2
      await BackupRestoreService.restoreFromBackupJson(
        db: db2,
        jsonString: jsonString,
      );

      // 5. Verify data in db2
      final restoredYear = await (db2.select(db2.academicYears)..where((t) => t.id.equals(year.id))).getSingleOrNull();
      expect(restoredYear, isNotNull);
      expect(restoredYear!.name, 'Kelas 8B Unggulan');
      expect(restoredYear.treasurerName, 'Nadia Rahma');

      final restoredStudents = await (db2.select(db2.students)..where((t) => t.academicYearId.equals(year.id))).get();
      expect(restoredStudents.length, 2);
      expect(restoredStudents.map((s) => s.name), containsAll(['Andi', 'Bima']));

      final restoredTxs = await (db2.select(db2.transactions)..where((t) => t.academicYearId.equals(year.id))).get();
      expect(restoredTxs.length, 2);

      final restoredPayments = await (db2.select(db2.duesPayments)..where((t) => t.duesPeriodId.equals(period.id))).get();
      expect(restoredPayments.length, 2);
      final andiPayment = restoredPayments.firstWhere((p) => p.studentId == andi.id);
      expect(andiPayment.isPaid, isTrue);
      expect(andiPayment.amountPaid, 4000);

      final bimaPayment = restoredPayments.firstWhere((p) => p.studentId == bima.id);
      expect(bimaPayment.isPaid, isFalse);
      expect(bimaPayment.amountPaid, 0);
    });

    test('Validation: Rejects invalid JSON or foreign backup file', () async {
      expect(
        () => BackupRestoreService.parseAndPreview('{"invalid": true}'),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => BackupRestoreService.parseAndPreview('not a json string'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
