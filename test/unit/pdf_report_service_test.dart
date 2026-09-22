import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:bendahara_app/core/utils/currency_formatter.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/domain/services/dues_arrears_service.dart';
import 'package:bendahara_app/domain/services/pdf_report_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('PdfReportService - Monthly Partitioning, Expense Highlights & Arrears Audit', () {
    late AcademicYear testYear;
    late Category incomeCategory;
    late Category expenseCategory;
    late pw.Font fontRegular;
    late pw.Font fontBold;
    late pw.Font fontSemiBold;

    setUpAll(() async {
      // Font dimuat dari aset aplikasi (bukan unduhan jaringan) agar test
      // dan CI tetap berjalan tanpa koneksi internet.
      final fonts = await PdfReportService.loadReportFonts();
      fontRegular = fonts.regular;
      fontBold = fonts.bold;
      fontSemiBold = fonts.semiBold;
    });

    setUp(() {
      testYear = AcademicYear(
        id: 'year_2026_test',
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Siti Bendahara',
        supervisorName: 'Pak Wali Kelas',
        defaultDuesAmount: 2000,
        duesPeriodType: 'daily',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

      incomeCategory = Category(
        id: 'cat_kas_masuk',
        name: 'Uang Kas Harian',
        type: 'income',
        iconName: 'payments',
        colorHex: '#16A34A',
        isDefault: true,
        createdAt: DateTime(2026, 7, 1),
      );

      expenseCategory = Category(
        id: 'cat_atk',
        name: 'Belanja ATK Kelas',
        type: 'expense',
        iconName: 'shopping_cart',
        colorHex: '#DC2626',
        isDefault: true,
        createdAt: DateTime(2026, 7, 1),
      );
    });

    // =========================================================================
    // 1. MONTHLY PARTITIONING TESTS
    // =========================================================================
    test('1. getMonthHeaderTitle produces correct Indonesian uppercase month headers', () {
      expect(
        PdfReportService.getMonthHeaderTitle(DateTime(2026, 7, 1)),
        equals('BULAN JULI 2026'),
      );
      expect(
        PdfReportService.getMonthHeaderTitle(DateTime(2026, 8, 15)),
        equals('BULAN AGUSTUS 2026'),
      );
      expect(
        PdfReportService.getMonthHeaderTitle(DateTime(2026, 9, 30)),
        equals('BULAN SEPTEMBER 2026'),
      );
      expect(
        PdfReportService.getMonthHeaderTitle(DateTime(2026, 12, 1)),
        equals('BULAN DESEMBER 2026'),
      );
      expect(
        PdfReportService.getMonthHeaderTitle(DateTime(2027, 1, 10)),
        equals('BULAN JANUARI 2027'),
      );
    });

    test('2. groupTransactionsByMonth groups multi-month transactions chronologically', () {
      final txJuly1 = TransactionWithCategory(
        transaction: Transaction(
          id: 'tx_jul_1',
          academicYearId: testYear.id,
          categoryId: incomeCategory.id,
          type: 'income',
          amount: 50000,
          title: 'Kas Minggu 1 Juli',
          transactionDate: DateTime(2026, 7, 10),
          createdAt: DateTime(2026, 7, 10),
          updatedAt: DateTime(2026, 7, 10),
        ),
        category: incomeCategory,
        academicYear: testYear,
      );

      final txJuly2 = TransactionWithCategory(
        transaction: Transaction(
          id: 'tx_jul_2',
          academicYearId: testYear.id,
          categoryId: expenseCategory.id,
          type: 'expense',
          amount: 15000,
          title: 'Beli Spidol Juli',
          transactionDate: DateTime(2026, 7, 20),
          createdAt: DateTime(2026, 7, 20),
          updatedAt: DateTime(2026, 7, 20),
        ),
        category: expenseCategory,
        academicYear: testYear,
      );

      final txAug1 = TransactionWithCategory(
        transaction: Transaction(
          id: 'tx_aug_1',
          academicYearId: testYear.id,
          categoryId: incomeCategory.id,
          type: 'income',
          amount: 60000,
          title: 'Kas Minggu 1 Agustus',
          transactionDate: DateTime(2026, 8, 5),
          createdAt: DateTime(2026, 8, 5),
          updatedAt: DateTime(2026, 8, 5),
        ),
        category: incomeCategory,
        academicYear: testYear,
      );

      final txSept1 = TransactionWithCategory(
        transaction: Transaction(
          id: 'tx_sep_1',
          academicYearId: testYear.id,
          categoryId: expenseCategory.id,
          type: 'expense',
          amount: 25000,
          title: 'Beli Penghapus September',
          transactionDate: DateTime(2026, 9, 2),
          createdAt: DateTime(2026, 9, 2),
          updatedAt: DateTime(2026, 9, 2),
        ),
        category: expenseCategory,
        academicYear: testYear,
      );

      final sortedItems = [txJuly1, txJuly2, txAug1, txSept1];
      final monthGroups = PdfReportService.groupTransactionsByMonth(sortedItems);

      expect(monthGroups.length, equals(3));
      final keys = monthGroups.keys.toList();
      expect(keys[0], equals(DateTime(2026, 7)));
      expect(keys[1], equals(DateTime(2026, 8)));
      expect(keys[2], equals(DateTime(2026, 9)));

      expect(monthGroups[DateTime(2026, 7)]!.length, equals(2));
      expect(monthGroups[DateTime(2026, 8)]!.length, equals(1));
      expect(monthGroups[DateTime(2026, 9)]!.length, equals(1));
    });

    test('3. buildTransactionSection creates partition subheaders and tables when multi-month', () {
      final txJuly = TransactionWithCategory(
        transaction: Transaction(
          id: 'tx_jul',
          academicYearId: testYear.id,
          categoryId: incomeCategory.id,
          type: 'income',
          amount: 50000,
          title: 'Kas Juli',
          transactionDate: DateTime(2026, 7, 15),
          createdAt: DateTime(2026, 7, 15),
          updatedAt: DateTime(2026, 7, 15),
        ),
        category: incomeCategory,
        academicYear: testYear,
      );

      final txAug = TransactionWithCategory(
        transaction: Transaction(
          id: 'tx_aug',
          academicYearId: testYear.id,
          categoryId: expenseCategory.id,
          type: 'expense',
          amount: 20000,
          title: 'ATK Agustus',
          transactionDate: DateTime(2026, 8, 10),
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
        category: expenseCategory,
        academicYear: testYear,
      );

      final widgets = PdfReportService.buildTransactionSection(
        sortedItems: [txJuly, txAug],
        totalIncome: 50000,
        totalExpense: 20000,
        finalBalance: 30000,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      // Section title + SizedBox + (Container subheader + Table) for July + (Container subheader + Table) for Aug
      expect(widgets.length, equals(6));
      expect(widgets[0], isA<pw.Text>()); // 'Rincian Transaksi Kas Kelas'
      expect(widgets[1], isA<pw.SizedBox>());
      expect(widgets[2], isA<pw.Container>()); // Subheader BULAN JULI 2026
      expect(widgets[3], isA<pw.Table>()); // Table July
      expect(widgets[4], isA<pw.Container>()); // Subheader BULAN AGUSTUS 2026
      expect(widgets[5], isA<pw.Table>()); // Table August
    });

    test('4. buildTransactionSection does not create partition subheaders when single month', () {
      final txJuly1 = TransactionWithCategory(
        transaction: Transaction(
          id: 'tx_jul_1',
          academicYearId: testYear.id,
          categoryId: incomeCategory.id,
          type: 'income',
          amount: 25000,
          title: 'Kas 1',
          transactionDate: DateTime(2026, 7, 5),
          createdAt: DateTime(2026, 7, 5),
          updatedAt: DateTime(2026, 7, 5),
        ),
        category: incomeCategory,
        academicYear: testYear,
      );

      final txJuly2 = TransactionWithCategory(
        transaction: Transaction(
          id: 'tx_jul_2',
          academicYearId: testYear.id,
          categoryId: incomeCategory.id,
          type: 'income',
          amount: 25000,
          title: 'Kas 2',
          transactionDate: DateTime(2026, 7, 12),
          createdAt: DateTime(2026, 7, 12),
          updatedAt: DateTime(2026, 7, 12),
        ),
        category: incomeCategory,
        academicYear: testYear,
      );

      final widgets = PdfReportService.buildTransactionSection(
        sortedItems: [txJuly1, txJuly2],
        totalIncome: 50000,
        totalExpense: 0,
        finalBalance: 50000,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      // Section title + SizedBox + single Table (no month subheaders)
      expect(widgets.length, equals(3));
      expect(widgets[0], isA<pw.Text>());
      expect(widgets[1], isA<pw.SizedBox>());
      expect(widgets[2], isA<pw.Table>());
    });

    test('5. buildTransactionSection handles empty items list cleanly', () {
      final widgets = PdfReportService.buildTransactionSection(
        sortedItems: [],
        totalIncome: 0,
        totalExpense: 0,
        finalBalance: 0,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      expect(widgets.length, equals(3));
      expect(widgets[0], isA<pw.Text>());
      expect(widgets[1], isA<pw.SizedBox>());
      expect(widgets[2], isA<pw.Container>()); // Empty state notice
    });

    // =========================================================================
    // 2. RED EXPENSE STYLING TESTS
    // =========================================================================
    test('6. buildExpenseCell generates red font and red background tint container', () {
      final cell = PdfReportService.buildExpenseCell(
        amount: 45000,
        fontBold: fontBold,
      ) as pw.Container;

      expect(cell.decoration, isA<pw.BoxDecoration>());
      final deco = cell.decoration as pw.BoxDecoration;
      expect(deco.color, equals(PdfColor.fromHex('#FEF2F2')));

      final childText = cell.child as pw.Text;
      expect(childText.text.toPlainText(), equals(CurrencyFormatter.format(45000)));
      final span = childText.text as pw.TextSpan;
      expect(span.style?.color, equals(PdfColor.fromHex('#DC2626')));
      expect(span.style?.font, equals(fontBold));
      expect(span.style?.fontSize, equals(8));
    });

    test('7. buildIncomeCell generates green font text', () {
      final cell = PdfReportService.buildIncomeCell(
        amount: 80000,
        fontRegular: fontRegular,
      ) as pw.Text;

      expect(cell.text.toPlainText(), equals(CurrencyFormatter.format(80000)));
      final span = cell.text as pw.TextSpan;
      expect(span.style?.color, equals(PdfColor.fromHex('#16A34A')));
      expect(span.style?.fontSize, equals(8));
    });

    // =========================================================================
    // 3. STUDENT ARREARS AUDIT SECTION TESTS
    // =========================================================================
    test('8. buildArrearsAuditSection generates audit table with arrears data and summary total', () {
      final arrears = [
        const StudentArrearsReportItem(
          studentNumber: 1,
          studentName: 'Ahmad Fauzi',
          unpaidPeriodRangeText: 'Dari 14 Juli s.d. 18 Juli 2026',
          unpaidPeriodsCount: 5,
          duesRate: 2000,
          totalArrearsAmount: 10000,
          rateDescription: 'Rp2.000 / hari',
        ),
        const StudentArrearsReportItem(
          studentNumber: 4,
          studentName: 'Dewi Lestari',
          unpaidPeriodRangeText: '20 Juli 2026 s.d. 22 Juli 2026',
          unpaidPeriodsCount: 3,
          duesRate: 2000,
          totalArrearsAmount: 6000,
          rateDescription: 'Rp2.000 / hari',
        ),
      ];

      final auditWidgets = PdfReportService.buildArrearsAuditSection(
        academicYear: testYear,
        arrearsItems: arrears,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      expect(auditWidgets, isA<List<pw.Widget>>());
      expect(auditWidgets, isNotEmpty);
      // Contains the title row, description subtitle, and Table
      final hasTable = auditWidgets.any((w) => w is pw.Table);
      expect(hasTable, isTrue);
    });

    test('9. buildArrearsAuditSection generates Nihil Tunggakan badge when arrears list is empty', () {
      final auditWidgets = PdfReportService.buildArrearsAuditSection(
        academicYear: testYear,
        arrearsItems: [],
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      expect(auditWidgets, isA<List<pw.Widget>>());
      expect(auditWidgets, isNotEmpty);
      // When empty, there should be NO Table, but a verified badge Container
      final hasTable = auditWidgets.any((w) => w is pw.Table);
      expect(hasTable, isFalse);

      final hasBadgeContainer = auditWidgets.any((w) {
        if (w is pw.Container) {
          final deco = w.decoration;
          if (deco is pw.BoxDecoration && deco.color == PdfColor.fromHex('#F0FDF4')) {
            return true;
          }
        }
        return false;
      });
      expect(hasBadgeContainer, isTrue);
    });

    // =========================================================================
    // 4. FULL PDF GENERATION INTEGRATION TESTS
    // =========================================================================
    test('10. generateReportPdf generates valid PDF with multi-month partitioning and student arrears', () async {
      final items = [
        TransactionWithCategory(
          transaction: Transaction(
            id: 'tx_1',
            academicYearId: testYear.id,
            categoryId: incomeCategory.id,
            type: 'income',
            amount: 100000,
            title: 'Kas Kelas Juli',
            transactionDate: DateTime(2026, 7, 14),
            createdAt: DateTime(2026, 7, 14),
            updatedAt: DateTime(2026, 7, 14),
          ),
          category: incomeCategory,
          academicYear: testYear,
        ),
        TransactionWithCategory(
          transaction: Transaction(
            id: 'tx_2',
            academicYearId: testYear.id,
            categoryId: expenseCategory.id,
            type: 'expense',
            amount: 35000,
            title: 'Beli ATK Kelas Juli',
            transactionDate: DateTime(2026, 7, 25),
            createdAt: DateTime(2026, 7, 25),
            updatedAt: DateTime(2026, 7, 25),
          ),
          category: expenseCategory,
          academicYear: testYear,
        ),
        TransactionWithCategory(
          transaction: Transaction(
            id: 'tx_3',
            academicYearId: testYear.id,
            categoryId: incomeCategory.id,
            type: 'income',
            amount: 80000,
            title: 'Kas Kelas Agustus',
            transactionDate: DateTime(2026, 8, 5),
            createdAt: DateTime(2026, 8, 5),
            updatedAt: DateTime(2026, 8, 5),
          ),
          category: incomeCategory,
          academicYear: testYear,
        ),
      ];

      final studentArrears = [
        const StudentArrearsReportItem(
          studentNumber: 2,
          studentName: 'Budi Santoso',
          unpaidPeriodRangeText: 'Dari 14 Juli s.d. 18 Juli 2026',
          unpaidPeriodsCount: 5,
          duesRate: 2000,
          totalArrearsAmount: 10000,
          rateDescription: 'Rp2.000 / hari',
        ),
      ];

      final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: '3 Bulan (Triwulan)',
        items: items,
        studentArrears: studentArrears,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(500));
      // Standard PDF magic header: %PDF-
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
    });

    test('11. generateReportPdf generates valid PDF with zero arrears (Nihil Tunggakan)', () async {
      final items = [
        TransactionWithCategory(
          transaction: Transaction(
            id: 'tx_1',
            academicYearId: testYear.id,
            categoryId: incomeCategory.id,
            type: 'income',
            amount: 50000,
            title: 'Kas Kelas September',
            transactionDate: DateTime(2026, 9, 10),
            createdAt: DateTime(2026, 9, 10),
            updatedAt: DateTime(2026, 9, 10),
          ),
          category: incomeCategory,
          academicYear: testYear,
        ),
      ];

      final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: '1 Bulan (1 Sep 2026 s/d 30 Sep 2026)',
        items: items,
        studentArrears: [], // Nihil Tunggakan
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(500));
      expect(pdfBytes[0], equals(0x25));
      expect(pdfBytes[1], equals(0x50));
      expect(pdfBytes[2], equals(0x44));
      expect(pdfBytes[3], equals(0x46));
    });

    test('12. Backward Compatibility: generateReportPdf succeeds without studentArrears parameter', () async {
      final items = [
        TransactionWithCategory(
          transaction: Transaction(
            id: 'tx_compat',
            academicYearId: testYear.id,
            categoryId: incomeCategory.id,
            type: 'income',
            amount: 30000,
            title: 'Uang Kas Mandiri',
            transactionDate: DateTime(2026, 9, 1),
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
          category: incomeCategory,
          academicYear: testYear,
        ),
      ];

      // Call without studentArrears (omitted)
      final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: '1 Bulan',
        items: items,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
    });

    test('13. Pagination: 35+ students in arrears paginate properly across multiple pages without throwing PdfTooBigPageException', () async {
      final largeArrears = <StudentArrearsReportItem>[];
      for (var s = 1; s <= 40; s++) {
        largeArrears.add(
          StudentArrearsReportItem(
            studentNumber: s,
            studentName: 'Siswa Uji $s',
            unpaidPeriodRangeText: 'Dari 1 Juli s.d. ${s + 5} Juli 2026',
            unpaidPeriodsCount: 5,
            duesRate: 2000,
            totalArrearsAmount: 10000,
            rateDescription: 'Rp2.000 / hari',
          ),
        );
      }

      final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: 'Audit Tunggakan 40 Siswa',
        items: [],
        studentArrears: largeArrears,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
    });
  });
}
