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
import 'package:bendahara_app/presentation/screens/dues_check_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Centang Semua (Select All) Multi-Pick Quick Action Test', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late StudentRepository studentRepo;
    late DuesRepository duesRepo;
    late TransactionRepository txRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      studentRepo = StudentRepository(db);
      duesRepo = DuesRepository(db);
      txRepo = TransactionRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Tapping Centang Semua selects all unpaid students and toggles to Batal Pilih', (tester) async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 7B',
        grade: 7,
        treasurerName: 'Bendahara',
        supervisorName: 'Pengawas',
        defaultDuesAmount: 2000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      // Add 3 students
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Andi');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Bima');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 3, name: 'Citra');

      await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 1 Juli 2026',
        targetAmount: 2000,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
        ],
      );
      addTearDown(() => container.dispose());

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DuesCheckScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial State: Centang Semua (3) button should exist
      final selectAllBtn = find.byKey(const ValueKey('select_all_students_btn'));
      expect(selectAllBtn, findsOneWidget);
      expect(find.text('Centang Semua (3)'), findsOneWidget);
      expect(find.text('Simpan & Masukkan ke Kas Kelas (3 Siswa)'), findsNothing);

      // 2. Tap Centang Semua (3)
      await tester.tap(selectAllBtn);
      await tester.pumpAndSettle();

      // Button should now be 'Batal Pilih'
      expect(find.text('Batal Pilih'), findsOneWidget);
      // Bottom action button should show all 3 students selected
      expect(find.text('Simpan & Masukkan ke Kas Kelas (3 Siswa)'), findsOneWidget);

      // 3. Tap Batal Pilih
      await tester.tap(selectAllBtn);
      await tester.pumpAndSettle();

      // Button should revert to 'Centang Semua (3)'
      expect(find.text('Centang Semua (3)'), findsOneWidget);
      expect(find.text('Simpan & Masukkan ke Kas Kelas (3 Siswa)'), findsNothing);

      // 4. Test partial select: Select 1 student manually
      final andiTile = find.text('Andi');
      expect(andiTile, findsOneWidget);
      // Find the 'Belum' checkbox button for Andi
      final belumButtons = find.text('Belum');
      expect(belumButtons, findsNWidgets(3));
      await tester.tap(belumButtons.first);
      await tester.pumpAndSettle();

      // Now 1 student is selected:
      expect(find.text('Simpan & Masukkan ke Kas Kelas (1 Siswa)'), findsOneWidget);
      // The select all button still says Centang Semua (3) because not all 3 are selected
      expect(find.text('Centang Semua (3)'), findsOneWidget);

      // Tap Centang Semua to select all remaining
      await tester.tap(selectAllBtn);
      await tester.pumpAndSettle();

      // Now all 3 are selected!
      expect(find.text('Batal Pilih'), findsOneWidget);
      expect(find.text('Simpan & Masukkan ke Kas Kelas (3 Siswa)'), findsOneWidget);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Centang Semua is not shown when all students in view are paid', (tester) async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 7C',
        grade: 7,
        treasurerName: 'Bendahara',
        supervisorName: 'Pengawas',
        defaultDuesAmount: 2000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Dodi');

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
        ],
      );
      addTearDown(() => container.dispose());

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DuesCheckScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial: Centang Semua is visible for unpaid student Dodi
      final selectAllBtn = find.byKey(const ValueKey('select_all_students_btn'));
      expect(selectAllBtn, findsOneWidget);

      // Select Dodi via Centang Semua
      await tester.tap(selectAllBtn);
      await tester.pumpAndSettle();

      // Submit via bottom button
      final simpanButton = find.widgetWithText(ElevatedButton, 'Simpan & Masukkan ke Kas Kelas (1 Siswa)');
      expect(simpanButton, findsOneWidget);
      await tester.tap(simpanButton);
      await tester.pumpAndSettle();

      // Confirm Dialog 1
      expect(find.text('Konfirmasi Pembayaran Siswa'), findsOneWidget);
      await tester.tap(find.text('Ya, Sudah'));
      await tester.pumpAndSettle();

      // Confirm Dialog 2
      expect(find.text('Masukkan ke kas kelas?'), findsOneWidget);
      await tester.tap(find.text('Ya, Masukkan'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Since all students in the period are now paid (0 unpaid), Centang Semua button should not be shown
      expect(find.byKey(const ValueKey('select_all_students_btn')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
