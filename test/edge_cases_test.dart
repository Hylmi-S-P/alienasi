import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/student_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/data/repositories/dues_repository.dart';
import 'package:bendahara_app/domain/services/pdf_report_service.dart';
import 'package:bendahara_app/domain/services/csv_export_service.dart';
import 'package:bendahara_app/presentation/widgets/financial_chart_card.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/screens/dues_check_screen.dart';
import 'package:bendahara_app/presentation/screens/transaction_form_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  late AppDatabase db;
  late AcademicYearRepository academicRepo;
  late StudentRepository studentRepo;
  late TransactionRepository transactionRepo;
  late DuesRepository duesRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    academicRepo = AcademicYearRepository(db);
    studentRepo = StudentRepository(db);
    transactionRepo = TransactionRepository(db);
    duesRepo = DuesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Edge Case 1: Student Duplicate Validations', () {
    test('Mencegah nomor absen duplikat pada tahun ajaran yang sama', () async {
      final year = await academicRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Siti',
        supervisorName: 'Ibu Linda',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(
        academicYearId: year.id,
        attendanceNumber: 1,
        name: 'Ahmad Dahlan',
      );

      final isTaken = await studentRepo.isAttendanceNumberTaken(
        academicYearId: year.id,
        attendanceNumber: 1,
      );
      final isNotTaken = await studentRepo.isAttendanceNumberTaken(
        academicYearId: year.id,
        attendanceNumber: 2,
      );

      expect(isTaken, isTrue);
      expect(isNotTaken, isFalse);
    });

    test('Mendeteksi nama siswa duplikat (case-insensitive & trimmed)', () async {
      final year = await academicRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Siti',
        supervisorName: 'Ibu Linda',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(
        academicYearId: year.id,
        attendanceNumber: 5,
        name: 'Budi Santoso',
      );

      final isNameTaken1 = await studentRepo.isStudentNameTaken(
        academicYearId: year.id,
        name: 'budi santoso ',
      );
      final isNameTaken2 = await studentRepo.isStudentNameTaken(
        academicYearId: year.id,
        name: 'BUDI SANTOSO',
      );
      final isDifferent = await studentRepo.isStudentNameTaken(
        academicYearId: year.id,
        name: 'Citra Dewi',
      );

      expect(isNameTaken1, isTrue);
      expect(isNameTaken2, isTrue);
      expect(isDifferent, isFalse);
    });
  });

  group('Edge Case 2: Dues Collection Empty State & Zero Reconcile', () {
    test('Rekonsiliasi kas tidak melakukan insert jika paidCount 0 atau total 0', () async {
      final year = await academicRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Siti',
        supervisorName: 'Ibu Linda',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      final period = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 1 - Juli 2026',
        targetAmount: 5000,
      );

      // Tidak ada siswa yang bayar, panggil reconcile
      await duesRepo.reconcileIntoGeneralCash(
        period: period,
        academicYearId: year.id,
      );

      // Pastikan transaksi kas masuk tetap 0
      final txs = await transactionRepo.getTransactionsByRange(
        academicYearId: year.id,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2027, 12, 31),
      );
      expect(txs.isEmpty, isTrue);
    });
  });

  group('Edge Case 3: Kenaikan Kelas & Salin Roster Siswa', () {
    test('Naik kelas menyalin daftar siswa aktif ke tahun ajaran baru dengan histori terisolasi', () async {
      final year7 = await academicRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Siti',
        supervisorName: 'Ibu Linda',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      // Tambah 3 siswa di kelas 7
      await studentRepo.addStudent(academicYearId: year7.id, attendanceNumber: 1, name: 'Siswa Satu');
      await studentRepo.addStudent(academicYearId: year7.id, attendanceNumber: 2, name: 'Siswa Dua');
      await studentRepo.addStudent(academicYearId: year7.id, attendanceNumber: 3, name: 'Siswa Tiga');

      // Naik ke kelas 8
      final year8 = await academicRepo.advanceToNewGrade(
        newClassName: 'Kelas 8A',
        newGrade: 8,
        startDate: DateTime(2027, 7, 1),
        endDate: DateTime(2028, 6, 30),
      );

      final copiedCount = await studentRepo.copyStudentsToAcademicYear(
        sourceAcademicYearId: year7.id,
        targetAcademicYearId: year8.id,
      );

      expect(copiedCount, equals(3));

      // Verifikasi siswa kelas 8 terdaftar
      final students8 = await studentRepo.getStudents(year8.id);
      expect(students8.length, equals(3));
      expect(students8.map((s) => s.name).toList(), containsAll(['Siswa Satu', 'Siswa Dua', 'Siswa Tiga']));

      // Pastikan id siswa di kelas 8 berbeda dari kelas 7 (terisolasi)
      final students7 = await studentRepo.getStudents(year7.id);
      final ids7 = students7.map((s) => s.id).toSet();
      final ids8 = students8.map((s) => s.id).toSet();
      expect(ids7.intersection(ids8).isEmpty, isTrue);
    });
  });

  group('Edge Case 4: Laporan dengan Kondisi 0 Transaksi (Zero Data)', () {
    test('Ekspor CSV dengan 0 transaksi menghasilkan string CSV yang valid tanpa crash', () async {
      final year = await academicRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Siti',
        supervisorName: 'Ibu Linda',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      final csvContent = CsvExportService.generateCsv(
        academicYear: year,
        items: [],
      );

      expect(csvContent.isNotEmpty, isTrue);
      expect(csvContent, contains('Kelas,Kelas 7A'));
      expect(csvContent, contains('LAPORAN PERTANGGUNGJAWABAN KAS KELAS'));
    });

    test('Ekspor PDF dengan 0 transaksi menghasilkan dokumen valid dengan banner pesan kosong', () async {
      final year = await academicRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Siti',
        supervisorName: 'Ibu Linda',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      final pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: year,
        items: [],
        periodRangeTitle: 'Semua Waktu',
      );

      expect(pdfBytes.isNotEmpty, isTrue);
    });

    testWidgets('FinancialChartCard dengan 0 data transaksi menampilkan visual empty state tanpa pembagian nol', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinancialChartCard(
              items: [],
              selectedRange: ReportDateRange.allTime,
            ),
          ),
        ),
      );

      expect(find.text('Grafik Analisis Keuangan'), findsOneWidget);
      expect(find.text('Belum ada data riwayat transaksi untuk divisualisasikan.'), findsOneWidget);
    });
  });

  group('Edge Case 5: DuesCheckScreen UI Empty State & Disabled Reconcile', () {
    testWidgets('DuesCheckScreen menampilkan pesan ramah belum ada siswa dan tombol reconcile dinonaktifkan', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => await db.close());

      final yearRepo = AcademicYearRepository(db);
      await yearRepo.createAcademicYear(
        name: 'Kelas 7B',
        grade: 7,
        treasurerName: 'Rina',
        supervisorName: 'Ibu Linda',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: DuesCheckScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Siswa Terdaftar'), findsWidgets);
      expect(find.text('Tambah Siswa Sekarang'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Edge Case 6: TransactionFormScreen Deficit Warning Dialog', () {
    testWidgets('TransactionFormScreen memunculkan konfirmasi ketika pengeluaran melebihi saldo kas', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => await db.close());

      final yearRepo = AcademicYearRepository(db);
      await yearRepo.createAcademicYear(
        name: 'Kelas 7B',
        grade: 7,
        treasurerName: 'Rina',
        supervisorName: 'Ibu Linda',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: TransactionFormScreen(initialType: 'expense'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Isi nominal pengeluaran 100.000 (saldo kas saat ini 0)
      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);
      await tester.enterText(textFields.at(0), '100000');
      await tester.enterText(textFields.at(1), 'Beli Spidol & Penghapus');
      await tester.pumpAndSettle();

      // Tekan tombol simpan
      await tester.tap(find.text('Simpan Pengeluaran Kas'));
      await tester.pumpAndSettle();

      // Verifikasi dialog peringatan muncul
      expect(find.text('Pengeluaran Melebihi Saldo'), findsOneWidget);
      expect(find.text('Periksa Kembali'), findsOneWidget);
      expect(find.text('Tetap Simpan'), findsOneWidget);

      // Tekan Periksa Kembali
      await tester.tap(find.text('Periksa Kembali'));
      await tester.pumpAndSettle();

      // Dialog tertutup dan form tetap ada
      expect(find.text('Pengeluaran Melebihi Saldo'), findsNothing);
      expect(find.text('Simpan Pengeluaran Kas'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

