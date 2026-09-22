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

  group('Challenger M3-2 Empirical Adversarial Suite: PDF Enhancements', () {
    late AcademicYear testYear;
    late Category incomeCategory;
    late Category expenseCategory;
    late pw.Font fontRegular;
    late pw.Font fontBold;
    late pw.Font fontSemiBold;

    setUpAll(() async {
      final fonts = await PdfReportService.loadReportFonts();
      fontRegular = fonts.regular;
      fontBold = fonts.bold;
      fontSemiBold = fonts.semiBold;
    });

    setUp(() {
      testYear = AcademicYear(
        id: 'year_adversarial_test',
        name: 'Kelas 8B Unggulan',
        grade: 8,
        treasurerName: 'Bendahara Uji',
        supervisorName: 'Wali Kelas Uji',
        defaultDuesAmount: 2000,
        duesPeriodType: 'daily',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

      incomeCategory = Category(
        id: 'cat_in_adv',
        name: 'Kas Masuk Mingguan',
        type: 'income',
        iconName: 'savings',
        colorHex: '#16A34A',
        isDefault: true,
        createdAt: DateTime(2026, 7, 1),
      );

      expenseCategory = Category(
        id: 'cat_ex_adv',
        name: 'Pengeluaran Tak Terduga',
        type: 'expense',
        iconName: 'receipt_long',
        colorHex: '#DC2626',
        isDefault: true,
        createdAt: DateTime(2026, 7, 1),
      );
    });

    // =========================================================================
    // PILLAR 1: BACKWARD COMPATIBILITY (studentArrears == null / omitted)
    // =========================================================================
    group('Pillar 1: Backward Compatibility (studentArrears == null)', () {
      test('1.1 Omitted studentArrears generates valid PDF bytes without throwing', () async {
        final items = [
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_bc_1',
              academicYearId: testYear.id,
              categoryId: incomeCategory.id,
              type: 'income',
              amount: 50000,
              title: 'Kas Reguler',
              transactionDate: DateTime(2026, 7, 5),
              createdAt: DateTime(2026, 7, 5),
              updatedAt: DateTime(2026, 7, 5),
            ),
            category: incomeCategory,
            academicYear: testYear,
          ),
        ];

        // Intentionally omit studentArrears argument (legacy caller signature)
        final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
          academicYear: testYear,
          periodRangeTitle: '1 Bulan (Juli 2026)',
          items: items,
        );

        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(300));
        // Verify PDF Magic Header: %PDF-
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      });

      test('1.2 Explicit studentArrears == null on multi-month items generates valid PDF', () async {
        final items = [
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_bc_m1',
              academicYearId: testYear.id,
              categoryId: incomeCategory.id,
              type: 'income',
              amount: 75000,
              title: 'Kas Juli',
              transactionDate: DateTime(2026, 7, 10),
              createdAt: DateTime(2026, 7, 10),
              updatedAt: DateTime(2026, 7, 10),
            ),
            category: incomeCategory,
            academicYear: testYear,
          ),
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_bc_m2',
              academicYearId: testYear.id,
              categoryId: expenseCategory.id,
              type: 'expense',
              amount: 25000,
              title: 'Beli Buku Agustus',
              transactionDate: DateTime(2026, 8, 12),
              createdAt: DateTime(2026, 8, 12),
              updatedAt: DateTime(2026, 8, 12),
            ),
            category: expenseCategory,
            academicYear: testYear,
          ),
        ];

        final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
          academicYear: testYear,
          periodRangeTitle: '2 Bulan',
          items: items,
          studentArrears: null, // explicitly null
        );

        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(500));
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      });

      test('1.3 Explicit studentArrears == null with empty transactions list', () async {
        final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
          academicYear: testYear,
          periodRangeTitle: 'Kosong',
          items: [],
          studentArrears: null,
        );

        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(300));
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      });
    });

    // =========================================================================
    // PILLAR 2: EMPTY ITEMS (items == []) COMBINED WITH STUDENT ARREARS
    // =========================================================================
    group('Pillar 2: Empty Transactions List Combined with Student Arrears', () {
      test('2.1 items == [] with active student arrears renders notice and arrears audit table', () async {
        final arrears = [
          const StudentArrearsReportItem(
            studentNumber: 1,
            studentName: 'Zaki Putra',
            unpaidPeriodRangeText: 'Dari 1 Juli s.d. 5 Juli 2026',
            unpaidPeriodsCount: 5,
            duesRate: 2000,
            totalArrearsAmount: 10000,
            rateDescription: 'Rp2.000 / hari',
          ),
          const StudentArrearsReportItem(
            studentNumber: 3,
            studentName: 'Siti Rahma',
            unpaidPeriodRangeText: 'Dari 10 Juli s.d. 12 Juli 2026',
            unpaidPeriodsCount: 3,
            duesRate: 2000,
            totalArrearsAmount: 6000,
            rateDescription: 'Rp2.000 / hari',
          ),
        ];

        // 0 transactions recorded, but 2 students have arrears
        final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
          academicYear: testYear,
          periodRangeTitle: 'Periode Awal Tahun',
          items: [],
          studentArrears: arrears,
        );

        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(500));
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));

        // Check transaction section builder for empty items
        final txWidgets = PdfReportService.buildTransactionSection(
          sortedItems: [],
          totalIncome: 0,
          totalExpense: 0,
          finalBalance: 0,
          fontRegular: fontRegular,
          fontBold: fontBold,
          fontSemiBold: fontSemiBold,
        );

        expect(txWidgets.length, equals(3));
        expect(txWidgets[2], isA<pw.Container>());
        final emptyContainer = txWidgets[2] as pw.Container;
        final emptyText = emptyContainer.child as pw.Text;
        expect(
          emptyText.text.toPlainText(),
          contains('Tidak ada catatan transaksi pada rentang waktu ini.'),
        );
      });

      test('2.2 items == [] with studentArrears == [] renders Nihil Tunggakan badge', () async {
        final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
          academicYear: testYear,
          periodRangeTitle: 'Periode Libur Panjang',
          items: [],
          studentArrears: [],
        );

        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(500));
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));

        // Verify arrears audit section renders Nihil badge
        final arrearsWidgets = PdfReportService.buildArrearsAuditSection(
          academicYear: testYear,
          arrearsItems: [],
          fontRegular: fontRegular,
          fontBold: fontBold,
          fontSemiBold: fontSemiBold,
        );

        // Must not contain any Table widget
        expect(arrearsWidgets.any((w) => w is pw.Table), isFalse);

        // Must contain the verified green badge container
        final hasBadge = arrearsWidgets.any((w) {
          if (w is pw.Container && w.decoration is pw.BoxDecoration) {
            final deco = w.decoration as pw.BoxDecoration;
            return deco.color == PdfColor.fromHex('#F0FDF4');
          }
          return false;
        });
        expect(hasBadge, isTrue);
      });
    });

    // =========================================================================
    // PILLAR 3: LARGE CURRENCY AMOUNTS & CELL WRAP STRESS
    // =========================================================================
    group('Pillar 3: Large Currency Amounts (Rp 1.000.000.000+ to Trillions)', () {
      test('3.1 Multi-billion transactions (Rp 1.500.000.000) format and render cleanly', () async {
        const largeIncome = 2500000000; // Rp 2,500,000,000 (2.5 Miliar)
        const largeExpense = 1500000000; // Rp 1,500,000,000 (1.5 Miliar)

        final items = [
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_huge_1',
              academicYearId: testYear.id,
              categoryId: incomeCategory.id,
              type: 'income',
              amount: largeIncome,
              title: 'Dana Hibah Pembangunan Gedung Sekolah',
              transactionDate: DateTime(2026, 7, 10),
              createdAt: DateTime(2026, 7, 10),
              updatedAt: DateTime(2026, 7, 10),
            ),
            category: incomeCategory,
            academicYear: testYear,
          ),
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_huge_2',
              academicYearId: testYear.id,
              categoryId: expenseCategory.id,
              type: 'expense',
              amount: largeExpense,
              title: 'Pengadaan Meubeler dan Laboratorium Komputer',
              transactionDate: DateTime(2026, 7, 20),
              createdAt: DateTime(2026, 7, 20),
              updatedAt: DateTime(2026, 7, 20),
            ),
            category: expenseCategory,
            academicYear: testYear,
          ),
        ];

        final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
          academicYear: testYear,
          periodRangeTitle: 'Tahun Anggaran Besar',
          items: items,
          studentArrears: [],
        );

        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(500));
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      });

      test('3.2 Extreme 12-digit currency amounts (Rp 999.999.999.999) in expense cells', () {
        const extremeAmount = 999999999999; // Nearly 1 Triliun

        final cell = PdfReportService.buildExpenseCell(
          amount: extremeAmount,
          fontBold: fontBold,
        ) as pw.Container;

        final childText = cell.child as pw.Text;
        final formattedText = childText.text.toPlainText();
        expect(formattedText, equals(CurrencyFormatter.format(extremeAmount)));
        expect(formattedText, contains('999.999.999.999'));

        final span = childText.text as pw.TextSpan;
        expect(span.style?.color, equals(PdfColor.fromHex('#DC2626')));
      });

      test('3.3 Extreme multi-billion arrears amounts compile into PDF without layout overflow', () async {
        final arrears = [
          const StudentArrearsReportItem(
            studentNumber: 1,
            studentName: 'Siswa Beasiswa Khusus',
            unpaidPeriodRangeText: 'Januari 2026 s.d. Desember 2026 (12 Bulan)',
            unpaidPeriodsCount: 12,
            duesRate: 150000000, // Rp 150.000.000 / bulan
            totalArrearsAmount: 1800000000, // Rp 1.800.000.000
            rateDescription: 'Rp150.000.000 / bulan',
          ),
          const StudentArrearsReportItem(
            studentNumber: 2,
            studentName: 'Siswa Program Akselerasi',
            unpaidPeriodRangeText: 'Juli 2026 s.d. Desember 2026 (6 Bulan)',
            unpaidPeriodsCount: 6,
            duesRate: 200000000, // Rp 200.000.000 / bulan
            totalArrearsAmount: 1200000000, // Rp 1.200.000.000
            rateDescription: 'Rp200.000.000 / bulan',
          ),
        ];

        final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
          academicYear: testYear,
          periodRangeTitle: 'Audit Tunggakan Skala Besar',
          items: [],
          studentArrears: arrears,
        );

        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(500));
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      });

      test('3.4 Extreme negative finalBalance handles without error', () async {
        final items = [
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_neg_1',
              academicYearId: testYear.id,
              categoryId: expenseCategory.id,
              type: 'expense',
              amount: 5000000, // Defisit Rp 5.000.000
              title: 'Talangan Biaya Darurat Lomba',
              transactionDate: DateTime(2026, 7, 15),
              createdAt: DateTime(2026, 7, 15),
              updatedAt: DateTime(2026, 7, 15),
            ),
            category: expenseCategory,
            academicYear: testYear,
          ),
        ];

        final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
          academicYear: testYear,
          periodRangeTitle: 'Periode Saldo Minus',
          items: items,
          studentArrears: null,
        );

        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(300));
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      });
    });

    // =========================================================================
    // PILLAR 4: CONTRAST RED COLOR FIDELITY & VISUAL STYLING
    // =========================================================================
    group('Pillar 4: Contrast Red Color Fidelity & Visual Styling', () {
      test('4.1 buildExpenseCell adheres strictly to #DC2626 font, #FEF2F2 bg, #FECACA border', () {
        final cell = PdfReportService.buildExpenseCell(
          amount: 85000,
          fontBold: fontBold,
        ) as pw.Container;

        expect(cell.decoration, isA<pw.BoxDecoration>());
        final deco = cell.decoration as pw.BoxDecoration;
        expect(deco.color, equals(PdfColor.fromHex('#FEF2F2')));
        expect(deco.borderRadius, isNotNull);
        expect(deco.borderRadius.toString(), equals(pw.BorderRadius.circular(3).toString()));

        final border = deco.border;
        expect(border, isNotNull);
        expect(border!.top.color, equals(PdfColor.fromHex('#FECACA')));
        expect(border.top.width, equals(0.5));

        final textChild = cell.child as pw.Text;
        expect(textChild.textAlign, equals(pw.TextAlign.right));
        final span = textChild.text as pw.TextSpan;
        expect(span.style?.color, equals(PdfColor.fromHex('#DC2626')));
        expect(span.style?.fontSize, equals(8));
        expect(span.style?.font, equals(fontBold));
      });

      test('4.2 buildIncomeCell adheres strictly to #16A34A font color', () {
        final cell = PdfReportService.buildIncomeCell(
          amount: 120000,
          fontRegular: fontRegular,
        ) as pw.Text;

        expect(cell.textAlign, equals(pw.TextAlign.right));
        final span = cell.text as pw.TextSpan;
        expect(span.style?.color, equals(PdfColor.fromHex('#16A34A')));
        expect(span.style?.fontSize, equals(8));
        expect(span.style?.font, equals(fontRegular));
      });

      test('4.3 Multi-month table renders red expense cell in Kas Keluar and summary row', () {
        final txExpense = TransactionWithCategory(
          transaction: Transaction(
            id: 'tx_jul_ex',
            academicYearId: testYear.id,
            categoryId: expenseCategory.id,
            type: 'expense',
            amount: 30000,
            title: 'Beli Sapu Kelas',
            transactionDate: DateTime(2026, 7, 5),
            createdAt: DateTime(2026, 7, 5),
            updatedAt: DateTime(2026, 7, 5),
          ),
          category: expenseCategory,
          academicYear: testYear,
        );

        final txIncome = TransactionWithCategory(
          transaction: Transaction(
            id: 'tx_aug_in',
            academicYearId: testYear.id,
            categoryId: incomeCategory.id,
            type: 'income',
            amount: 50000,
            title: 'Iuran Agustus',
            transactionDate: DateTime(2026, 8, 1),
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1),
          ),
          category: incomeCategory,
          academicYear: testYear,
        );

        final widgets = PdfReportService.buildTransactionSection(
          sortedItems: [txExpense, txIncome],
          totalIncome: 50000,
          totalExpense: 30000,
          finalBalance: 20000,
          fontRegular: fontRegular,
          fontBold: fontBold,
          fontSemiBold: fontSemiBold,
        );

        // Multi-month: Title, SizedBox, Month1Header, Month1Table, Month2Header, Month2Table
        expect(widgets.length, equals(6));

        // Inspect July table (Index 3)
        expect(widgets[3], isA<pw.Table>());
        // Inspect August table (Index 5)
        expect(widgets[5], isA<pw.Table>());
      });

      test('4.4 Arrears table Total Tunggakan cells and footer use #DC2626 and #FEF2F2', () {
        final arrears = [
          const StudentArrearsReportItem(
            studentNumber: 5,
            studentName: 'Budi Santoso',
            unpaidPeriodRangeText: '14 Juli s.d. 18 Juli',
            unpaidPeriodsCount: 5,
            duesRate: 2000,
            totalArrearsAmount: 10000,
            rateDescription: 'Rp2.000 / hari',
          ),
        ];

        final sectionWidgets = PdfReportService.buildArrearsAuditSection(
          academicYear: testYear,
          arrearsItems: arrears,
          fontRegular: fontRegular,
          fontBold: fontBold,
          fontSemiBold: fontSemiBold,
        );

        // Locate status badge in header row
        final headerRow = sectionWidgets.firstWhere((w) => w is pw.Row) as pw.Row;
        final badgeContainer = headerRow.children.last as pw.Container;
        final badgeDeco = badgeContainer.decoration as pw.BoxDecoration;
        expect(badgeDeco.color, equals(PdfColor.fromHex('#FEE2E2')));
        expect(badgeDeco.border?.top.color, equals(PdfColor.fromHex('#FECACA')));

        final badgeText = badgeContainer.child as pw.Text;
        expect(badgeText.text.toPlainText(), equals('1 SISWA MENUNGGAK'));
        final badgeSpan = badgeText.text as pw.TextSpan;
        expect(badgeSpan.style?.color, equals(PdfColor.fromHex('#B91C1C')));

        // Verify table existence
        final table = sectionWidgets.firstWhere((w) => w is pw.Table) as pw.Table;
        expect(table, isNotNull);
      });
    });

    // =========================================================================
    // PILLAR 5: LARGE-SCALE STRESS HARNESS (100 TRANSACTIONS, 50 STUDENTS)
    // =========================================================================
    group('Pillar 5: Large-Scale Stress Harness', () {
      test('5.1 100 transactions across 12 calendar months with empty arrears compiles cleanly', () async {
        final List<TransactionWithCategory> largeTxList = [];
        for (var i = 1; i <= 100; i++) {
          final month = ((i - 1) % 12) + 1;
          final isInc = i % 3 != 0;
          largeTxList.add(
            TransactionWithCategory(
              transaction: Transaction(
                id: 'tx_stress_$i',
                academicYearId: testYear.id,
                categoryId: isInc ? incomeCategory.id : expenseCategory.id,
                type: isInc ? 'income' : 'expense',
                amount: isInc ? 25000 * i : 10000 * i,
                title: 'Transaksi Uji Skala $i',
                transactionDate: DateTime(2026, month, (i % 28) + 1),
                createdAt: DateTime(2026, month, (i % 28) + 1, 10, i % 60),
                updatedAt: DateTime(2026, month, (i % 28) + 1, 10, i % 60),
              ),
              category: isInc ? incomeCategory : expenseCategory,
              academicYear: testYear,
            ),
          );
        }

        final stopwatch = Stopwatch()..start();
        final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
          academicYear: testYear,
          periodRangeTitle: 'Audit 100 Transaksi Multi-Bulan',
          items: largeTxList,
          studentArrears: [],
        );
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(3000));
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      });

      test('5.2 20 student arrears items with empty transactions list compiles cleanly', () async {
        final List<StudentArrearsReportItem> arrearsList = [];
        for (var s = 1; s <= 20; s++) {
          arrearsList.add(
            StudentArrearsReportItem(
              studentNumber: s,
              studentName: 'Siswa Uji $s',
              unpaidPeriodRangeText: 'Dari $s Juli s.d. ${s + 3} Juli 2026',
              unpaidPeriodsCount: 3,
              duesRate: 2000,
              totalArrearsAmount: 6000,
              rateDescription: 'Rp2.000 / hari',
            ),
          );
        }

        final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
          academicYear: testYear,
          periodRangeTitle: 'Audit 20 Siswa Menunggak',
          items: [],
          studentArrears: arrearsList,
        );

        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(1000));
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      });

      test('5.3 40 student arrears items (exceeding single page height) paginates without crash', () async {
        // Verify that 25, 30, 32, 35, 40 arrears items all generate successfully without PdfTooBigPageException
        for (int count in [25, 30, 32, 35, 40]) {
          final List<StudentArrearsReportItem> arrearsList = [];
          for (var s = 1; s <= count; s++) {
            arrearsList.add(
              StudentArrearsReportItem(
                studentNumber: s,
                studentName: 'Siswa Uji $s',
                unpaidPeriodRangeText: 'Dari $s Juli s.d. ${s + 5} Juli 2026',
                unpaidPeriodsCount: 5,
                duesRate: 2000,
                totalArrearsAmount: 10000,
                rateDescription: 'Rp2.000 / hari',
              ),
            );
          }

          final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
            academicYear: testYear,
            periodRangeTitle: 'Audit $count Siswa Menunggak',
            items: [],
            studentArrears: arrearsList,
          );

          expect(pdfBytes, isNotNull);
          expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
        }
      });

      test('5.4 Mitigation Proof: TableHelper unnested from pw.Column handles 50+ students without crash', () async {
        final List<StudentArrearsReportItem> arrearsList = [];
        for (var s = 1; s <= 50; s++) {
          arrearsList.add(
            StudentArrearsReportItem(
              studentNumber: s,
              studentName: 'Siswa Uji $s',
              unpaidPeriodRangeText: 'Dari $s Juli s.d. ${s + 5} Juli 2026',
              unpaidPeriodsCount: 5,
              duesRate: 2000,
              totalArrearsAmount: 10000,
              rateDescription: 'Rp2.000 / hari',
            ),
          );
        }

        // Simulating the fix: Direct MultiPage children instead of wrapping in pw.Column
        final testDoc = pw.Document();

        testDoc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (context) => [
              pw.Text('Header Rekapitulasi Tunggakan'),
              pw.SizedBox(height: 8),
              // Direct table, NOT wrapped in pw.Column
              pw.TableHelper.fromTextArray(
                headers: const ['No', 'Nama Siswa', 'Periode', 'Tarif', 'Total'],
                data: arrearsList.map((i) => [
                  '${i.studentNumber}',
                  i.studentName,
                  i.unpaidPeriodRangeText,
                  '${i.duesRate}',
                  '${i.totalArrearsAmount}',
                ]).toList(),
              ),
            ],
          ),
        );

        final bytes = await testDoc.save();
        expect(bytes, isNotNull);
        expect(bytes.length, greaterThan(1000));
        // Successfully generated multiple pages without PdfTooBigPageException!
      });
    });
  });
}
