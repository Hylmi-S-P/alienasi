import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:bendahara_app/core/constants/app_colors.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/dues_repository.dart';
import 'package:bendahara_app/data/repositories/student_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/screens/dialogs/edit_student_dialog.dart';
import 'package:bendahara_app/presentation/screens/main_scaffold.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Edit, Delete Student & Swipe Navigation Tests', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late StudentRepository studentRepo;
    late DuesRepository duesRepo;
    late TransactionRepository txRepo;

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      studentRepo = StudentRepository(db);
      duesRepo = DuesRepository(db);
      txRepo = TransactionRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Repository: updateStudent updates attendance number and name, validations work', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8A',
        grade: 8,
        treasurerName: 'Siti',
        supervisorName: 'Pak Budi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Ahmad');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Bambang');

      final students = await studentRepo.getStudents(year.id);
      final s1 = students.firstWhere((s) => s.attendanceNumber == 1);

      // Verify isAttendanceNumberTakenExcluding
      expect(
        await studentRepo.isAttendanceNumberTakenExcluding(
          academicYearId: year.id,
          attendanceNumber: 2,
          excludeStudentId: s1.id,
        ),
        isTrue, // Number 2 is taken by s2
      );
      expect(
        await studentRepo.isAttendanceNumberTakenExcluding(
          academicYearId: year.id,
          attendanceNumber: 1,
          excludeStudentId: s1.id,
        ),
        isFalse, // Number 1 is s1's own number, not taken by another
      );
      expect(
        await studentRepo.isAttendanceNumberTakenExcluding(
          academicYearId: year.id,
          attendanceNumber: 3,
          excludeStudentId: s1.id,
        ),
        isFalse, // Number 3 is free
      );

      // Perform update
      await studentRepo.updateStudent(
        studentId: s1.id,
        attendanceNumber: 3,
        name: 'Ahmad Dahlan',
      );

      final updatedStudents = await studentRepo.getStudents(year.id);
      final updatedS1 = updatedStudents.firstWhere((s) => s.id == s1.id);
      expect(updatedS1.attendanceNumber, equals(3));
      expect(updatedS1.name, equals('Ahmad Dahlan'));
    });

    test('2. Repository: deleteStudent hard-deletes student with 0 payments', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8A',
        grade: 8,
        treasurerName: 'Siti',
        supervisorName: 'Pak Budi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Murid Salah Input');
      final studentsBefore = await studentRepo.getStudents(year.id);
      expect(studentsBefore.length, equals(1));

      final deletedStudent = studentsBefore.first;
      final wasHardDeleted = await studentRepo.deleteStudent(studentId: deletedStudent.id);

      expect(wasHardDeleted, isTrue);
      final studentsAfter = await studentRepo.getStudents(year.id);
      expect(studentsAfter.isEmpty, isTrue);
    });

    test('3. Repository: deleteStudent soft-deletes student with > 0 payments and preserves cash history', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8A',
        grade: 8,
        treasurerName: 'Siti',
        supervisorName: 'Pak Budi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Budi Pindah');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Siswa Tetap');

      final period = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 1 September 2026',
        dueDate: DateTime(2026, 9, 7),
        targetAmount: 5000,
      );

      final students = await studentRepo.getStudents(year.id);
      final budi = students.firstWhere((s) => s.attendanceNumber == 1);

      // Budi pays in period 1
      await duesRepo.markAsPaid(duesPeriodId: period.id, studentId: budi.id, targetAmount: 5000);
      expect(await studentRepo.getStudentPaidTotal(budi.id), equals(5000));

      // Now Budi is deleted / transferred
      final wasHardDeleted = await studentRepo.deleteStudent(studentId: budi.id);
      expect(wasHardDeleted, isFalse); // Soft-deleted to protect accounting integrity!

      // Active students list excludes Budi
      final activeStudents = await studentRepo.getStudents(year.id, onlyActive: true);
      expect(activeStudents.length, equals(1));
      expect(activeStudents.first.name, equals('Siswa Tetap'));

      // In period 1 where Budi paid, watchStudentDuesList STILL includes Budi's payment
      final duesListPeriod1 = await duesRepo.watchStudentDuesList(academicYearId: year.id, duesPeriodId: period.id).first;
      expect(duesListPeriod1.length, equals(2));
      final budiDues = duesListPeriod1.firstWhere((i) => i.student.id == budi.id);
      expect(budiDues.isPaid, isTrue);
      expect(budiDues.amountPaid, equals(5000));

      // In a new period 2, Budi does NOT appear
      final period2 = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 2 September 2026',
        dueDate: DateTime(2026, 9, 14),
        targetAmount: 5000,
      );
      final duesListPeriod2 = await duesRepo.watchStudentDuesList(academicYearId: year.id, duesPeriodId: period2.id).first;
      expect(duesListPeriod2.length, equals(1));
      expect(duesListPeriod2.first.student.name, equals('Siswa Tetap'));
    });

    testWidgets('4. Widget: EditStudentDialog edits student attendance number and name', (tester) async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8A',
        grade: 8,
        treasurerName: 'Siti',
        supervisorName: 'Pak Budi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Nama Salah');
      final students = await studentRepo.getStudents(year.id);
      final student = students.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            academicYearRepoProvider.overrideWithValue(yearRepo),
            studentRepoProvider.overrideWithValue(studentRepo),
            duesRepoProvider.overrideWithValue(duesRepo),
            transactionRepoProvider.overrideWithValue(txRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => EditStudentDialog.show(context, student: student, academicYearId: year.id),
                  child: const Text('Buka Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Data Siswa'), findsOneWidget);
      expect(find.text('Nama Salah'), findsOneWidget);

      // Edit name to 'Nama Benar'
      await tester.enterText(find.widgetWithText(TextFormField, 'Nama Lengkap Siswa'), 'Nama Benar');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nomor Absen'), '5');
      await tester.pumpAndSettle();

      // Tap Simpan Perubahan
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      // Verify in DB
      final updatedStudents = await studentRepo.getStudents(year.id);
      expect(updatedStudents.first.name, equals('Nama Benar'));
      expect(updatedStudents.first.attendanceNumber, equals(5));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('5. Widget: MainScaffold PageView allows horizontal swipe between tabs and keeps state alive', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await yearRepo.createAcademicYear(
        name: 'Kelas 8A',
        grade: 8,
        treasurerName: 'Siti',
        supervisorName: 'Pak Budi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            academicYearRepoProvider.overrideWithValue(yearRepo),
            studentRepoProvider.overrideWithValue(studentRepo),
            duesRepoProvider.overrideWithValue(duesRepo),
            transactionRepoProvider.overrideWithValue(txRepo),
          ],
          child: const MaterialApp(
            home: MainScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially on Dashboard (Tab 0)
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Kas Siswa'), findsWidgets);

      // Tap 'Kas Siswa' tab inside NavigationBar (unselected tabs use outlined icons)
      await tester.tap(
        find.byWidgetPredicate((w) =>
            w is Icon &&
            w.icon == Icons.fact_check_outlined &&
            w.color == AppColors.textSecondary),
      );
      await tester.pumpAndSettle();

      // Verify Kas Siswa appbar is visible
      expect(find.widgetWithText(AppBar, 'Kas Siswa'), findsOneWidget);

      // Drag to swipe to Catat Transaksi (drag from right to left)
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Catat Transaksi is now active
      expect(find.widgetWithText(AppBar, 'Catat Uang Keluar'), findsOneWidget);

      // Drag to swipe back to Kas Siswa (drag from left to right)
      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pumpAndSettle();

      // Kas Siswa is active again
      expect(find.widgetWithText(AppBar, 'Kas Siswa'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
