import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bendahara_app/core/utils/currency_formatter.dart';
import 'package:bendahara_app/core/utils/date_formatter.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/data/repositories/student_repository.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Formatters Test', () {
    test('CurrencyFormatter memformat Rupiah dengan akurat', () {
      expect(CurrencyFormatter.format(5000), 'Rp 5.000');
      expect(CurrencyFormatter.format(485000), 'Rp 485.000');
      expect(CurrencyFormatter.format(1000000), 'Rp 1.000.000');
      expect(CurrencyFormatter.formatWithSign(25000, 'income'), '+ Rp 25.000');
      expect(CurrencyFormatter.formatWithSign(15000, 'expense'), '- Rp 15.000');
    });

    test('DateFormatter memformat tanggal bahasa Indonesia', () {
      final date = DateTime(2026, 9, 18);
      expect(DateFormatter.toShortDate(date), '18/09/2026');
      expect(DateFormatter.toHumanDate(date), '18 September 2026');
    });
  });

  group('Database & Durability Test', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late TransactionRepository txRepo;
    late StudentRepository studentRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      txRepo = TransactionRepository(db);
      studentRepo = StudentRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Membuat kelas 7 pertama kali & verifikasi identifier', () async {
      final year7 = await yearRepo.createAcademicYear(
        name: 'Kelas 7B - SMP Negeri 1',
        grade: 7,
        treasurerName: 'Fajar',
        supervisorName: 'Ibu Rina',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      expect(year7.name, 'Kelas 7B - SMP Negeri 1');
      expect(year7.grade, 7);
      expect(year7.isActive, true);

      // Tambah siswa
      await studentRepo.addStudent(
        academicYearId: year7.id,
        attendanceNumber: 1,
        name: 'Ahmad Fauzi',
      );
      final students = await studentRepo.getStudents(year7.id);
      expect(students.length, 1);
      expect(students.first.name, 'Ahmad Fauzi');
    });

    test('Integritas Riwayat Historis saat naik ke kelas 8', () async {
      // 1. Kelas 7 awal
      final year7 = await yearRepo.createAcademicYear(
        name: 'Kelas 7B - SMP Negeri 1',
        grade: 7,
        treasurerName: 'Fajar',
        supervisorName: 'Ibu Rina',
        defaultDuesAmount: 5000,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      // Kategori dummy
      final catId = 'cat_1';
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: catId,
          type: 'income',
          name: 'Uang Kas Rutin',
          iconName: 'payments',
          colorHex: '#16A34A',
          createdAt: DateTime.now(),
        ),
      );

      // Catat transaksi kas kelas 7
      await txRepo.insertTransaction(
        academicYearId: year7.id,
        categoryId: catId,
        type: 'income',
        amount: 140000,
        title: 'Iuran Kas Minggu 1',
        transactionDate: DateTime(2026, 8, 1),
      );

      // 2. Naik kelas ke Kelas 8
      await yearRepo.advanceToNewGrade(
        newClassName: 'Kelas 8A - SMP Negeri 1',
        newGrade: 8,
        startDate: DateTime(2027, 7, 1),
        endDate: DateTime(2028, 6, 30),
      );

      // Verifikasi tahun aktif sekarang adalah Kelas 8
      final activeYear = await yearRepo.getActiveYear();
      expect(activeYear?.name, 'Kelas 8A - SMP Negeri 1');
      expect(activeYear?.grade, 8);

      // 3. Verifikasi kueri historis kelas 7: Data dan identifier nama tetap 'Kelas 7B - SMP Negeri 1'
      final historyTx = await txRepo.getTransactionsByRange(
        academicYearId: year7.id,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );

      expect(historyTx.length, 1);
      expect(historyTx.first.academicYear.name, 'Kelas 7B - SMP Negeri 1');
      expect(historyTx.first.transaction.amount, 140000);
      expect(historyTx.first.academicYear.id, year7.id);
    });
  });
}
