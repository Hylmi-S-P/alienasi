import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/domain/services/excel_report_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('ExcelReportService .xlsx Binary Export Tests', () {
    test('generateExcel produces valid .xlsx bytes with styled sheets and accurate totals', () {
      final academicYear = AcademicYear(
        id: 'ay-1',
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Siti Bendahara',
        supervisorName: 'Ibu Guru Pengawas',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

      final catKas = Category(
        id: 'cat-1',
        name: 'Uang Kas Rutin',
        type: 'income',
        iconName: 'receipt',
        colorHex: '#16A34A',
        isDefault: true,
        createdAt: DateTime(2026, 7, 1),
      );

      final catATK = Category(
        id: 'cat-2',
        name: 'Alat Tulis Kelas',
        type: 'expense',
        iconName: 'edit',
        colorHex: '#DC2626',
        isDefault: true,
        createdAt: DateTime(2026, 7, 1),
      );

      final items = [
        TransactionWithCategory(
          transaction: Transaction(
            id: 'tx-1',
            academicYearId: 'ay-1',
            categoryId: 'cat-1',
            title: 'Kas Minggu 1 Juli',
            amount: 50000,
            type: 'income',
            transactionDate: DateTime(2026, 7, 5),
            receiptImagePath: null,
            description: null,
            createdAt: DateTime(2026, 7, 5, 10, 0),
            updatedAt: DateTime(2026, 7, 5, 10, 0),
          ),
          category: catKas,
          academicYear: academicYear,
        ),
        TransactionWithCategory(
          transaction: Transaction(
            id: 'tx-2',
            academicYearId: 'ay-1',
            categoryId: 'cat-2',
            title: 'Beli Spidol & Penghapus',
            amount: 15000,
            type: 'expense',
            transactionDate: DateTime(2026, 7, 8),
            receiptImagePath: 'receipt_spidol.jpg',
            description: 'Nota toko buku',
            createdAt: DateTime(2026, 7, 8, 14, 0),
            updatedAt: DateTime(2026, 7, 8, 14, 0),
          ),
          category: catATK,
          academicYear: academicYear,
        ),
      ];

      final studentSummaries = [
        const StudentDuesReportSummary(attendanceNumber: 1, name: 'Ahmad', totalPaid: 50000, isAllPaid: true),
        const StudentDuesReportSummary(attendanceNumber: 2, name: 'Budi', totalPaid: 25000, isAllPaid: false),
      ];

      final Uint8List bytes = ExcelReportService.generateExcel(
        academicYear: academicYear,
        items: items,
        studentSummaries: studentSummaries,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));

      // Decode bytes back using Excel.decodeBytes to verify valid .xlsx structure
      final decodedExcel = Excel.decodeBytes(bytes);
      expect(decodedExcel.sheets.containsKey('Buku Kas Umum'), isTrue);
      expect(decodedExcel.sheets.containsKey('Rekap Kas Siswa'), isTrue);

      final kasSheet = decodedExcel['Buku Kas Umum'];
      // Verify Title Banner
      final bannerCell = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      expect(bannerCell.value.toString(), contains('LAPORAN PERTANGGUNGJAWABAN KAS KELAS'));

      // Verify Column Headers at Row 8
      final headerCol0 = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 8));
      expect(headerCol0.value.toString(), equals('No'));

      final headerCol4 = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 8));
      expect(headerCol4.value.toString(), equals('Kas Masuk (Rp)'));

      // Verify Row 9: First Transaction (tx-1)
      final tx1Ket = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 9));
      expect(tx1Ket.value.toString(), equals('Kas Minggu 1 Juli'));

      final tx1Masuk = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 9));
      expect(tx1Masuk.value.toString(), equals('50000'));

      // Verify Row 10: Second Transaction (tx-2)
      final tx2Keluar = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 10));
      expect(tx2Keluar.value.toString(), equals('15000'));

      final tx2Nota = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 10));
      expect(tx2Nota.value.toString(), equals('Ada Nota'));

      // Verify Summary Row at Row 11: Total
      final totalLabel = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 11));
      expect(totalLabel.value.toString(), equals('TOTAL'));

      final totalMasuk = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 11));
      expect(totalMasuk.value.toString(), equals('50000'));

      final totalKeluar = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 11));
      expect(totalKeluar.value.toString(), equals('15000'));

      final finalSaldo = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 11));
      expect(finalSaldo.value.toString(), equals('35000')); // 50000 - 15000

      // Verify Sheet 2: Rekap Kas Siswa
      final siswaSheet = decodedExcel['Rekap Kas Siswa'];
      final ahmadCell = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3));
      expect(ahmadCell.value.toString(), equals('Ahmad'));

      final ahmadStatus = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 3));
      expect(ahmadStatus.value.toString(), equals('Lunas'));

      final budiStatus = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 4));
      expect(budiStatus.value.toString(), equals('Belum Lunas'));
    });
  });
}
