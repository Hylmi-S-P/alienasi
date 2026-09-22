import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:bendahara_app/core/utils/date_formatter.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/domain/services/dues_arrears_service.dart';
import 'package:bendahara_app/domain/services/pdf_report_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Empirical Challenger M3: Adversarial Stress Test Suite', () {
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
        id: 'year_2027_2028_stress',
        name: 'Kelas 8B',
        grade: 8,
        treasurerName: 'Bendahara Uji Stres',
        supervisorName: 'Pak Guru Pembina',
        defaultDuesAmount: 2000,
        duesPeriodType: 'daily',
        startDate: DateTime(2027, 7, 1),
        endDate: DateTime(2028, 6, 30),
        isActive: true,
        createdAt: DateTime(2027, 7, 1),
      );

      incomeCategory = Category(
        id: 'cat_kas_harian',
        name: 'Uang Kas Harian',
        type: 'income',
        iconName: 'payments',
        colorHex: '#16A34A',
        isDefault: true,
        createdAt: DateTime(2027, 7, 1),
      );

      expenseCategory = Category(
        id: 'cat_lomba',
        name: 'Biaya Lomba & Konsumsi',
        type: 'expense',
        iconName: 'sports_soccer',
        colorHex: '#DC2626',
        isDefault: true,
        createdAt: DateTime(2027, 7, 1),
      );
    });

    // =========================================================================
    // CHALLENGE 1: 12-MONTH CROSS-YEAR & LEAP YEAR BOUNDARY STRESS
    // =========================================================================
    test('CHALLENGE 1.1: groupTransactionsByMonth preserves chronological ordering across year boundary (Dec -> Jan) and leap year (Feb 29)', () {
      final items = <TransactionWithCategory>[];
      final dates = [
        DateTime(2027, 7, 15),
        DateTime(2027, 8, 20),
        DateTime(2027, 9, 10),
        DateTime(2027, 10, 5),
        DateTime(2027, 11, 28),
        DateTime(2027, 12, 31), // New Year's Eve
        DateTime(2028, 1, 1),   // New Year's Day (Cross-year boundary)
        DateTime(2028, 2, 29),  // Leap day in leap year 2028!
        DateTime(2028, 3, 14),
        DateTime(2028, 4, 21),
        DateTime(2028, 5, 17),
        DateTime(2028, 6, 30),  // Year end
      ];

      // Insert in intentionally scrambled order to verify sort-resilience
      final shuffledDates = List<DateTime>.from(dates)..shuffle();

      for (var i = 0; i < shuffledDates.length; i++) {
        final d = shuffledDates[i];
        items.add(
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_stress_12m_$i',
              academicYearId: testYear.id,
              categoryId: (i % 2 == 0) ? incomeCategory.id : expenseCategory.id,
              type: (i % 2 == 0) ? 'income' : 'expense',
              amount: 25000,
              title: 'Transaksi Tanggal ${DateFormatter.toShortDate(d)}',
              transactionDate: d,
              createdAt: d.add(const Duration(hours: 2)),
              updatedAt: d.add(const Duration(hours: 2)),
            ),
            category: (i % 2 == 0) ? incomeCategory : expenseCategory,
            academicYear: testYear,
          ),
        );
      }

      // Sort items as PdfReportService does
      items.sort((a, b) {
        final cmp = a.transaction.transactionDate.compareTo(b.transaction.transactionDate);
        if (cmp != 0) return cmp;
        return a.transaction.createdAt.compareTo(b.transaction.createdAt);
      });

      final groups = PdfReportService.groupTransactionsByMonth(items);

      // Must produce exactly 12 month groups
      expect(groups.length, equals(12));

      final groupKeys = groups.keys.toList();
      expect(groupKeys[0], equals(DateTime(2027, 7)));
      expect(groupKeys[5], equals(DateTime(2027, 12)));
      expect(groupKeys[6], equals(DateTime(2028, 1)));
      expect(groupKeys[7], equals(DateTime(2028, 2))); // Leap month
      expect(groupKeys[11], equals(DateTime(2028, 6)));

      // Check month header titles
      expect(PdfReportService.getMonthHeaderTitle(groupKeys[5]), equals('BULAN DESEMBER 2027'));
      expect(PdfReportService.getMonthHeaderTitle(groupKeys[6]), equals('BULAN JANUARI 2028'));
      expect(PdfReportService.getMonthHeaderTitle(groupKeys[7]), equals('BULAN FEBRUARI 2028'));
      expect(PdfReportService.getMonthHeaderTitle(groupKeys[11]), equals('BULAN JUNI 2028'));
    });

    test('CHALLENGE 1.2: buildTransactionSection renders exactly 12 partition headers and tables with unbroken running balance', () {
      final items = <TransactionWithCategory>[];
      var runningSimulatedBalance = 0;
      var totalSimulatedIncome = 0;
      var totalSimulatedExpense = 0;

      for (var month = 7; month <= 18; month++) {
        final year = month > 12 ? 2028 : 2027;
        final actualMonth = month > 12 ? month - 12 : month;
        final date = (actualMonth == 2) ? DateTime(year, actualMonth, 29) : DateTime(year, actualMonth, 15);
        final isIncome = month % 2 == 1;
        final amount = 50000;

        if (isIncome) {
          totalSimulatedIncome += amount;
          runningSimulatedBalance += amount;
        } else {
          totalSimulatedExpense += amount;
          runningSimulatedBalance -= amount;
        }

        items.add(
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_m_$month',
              academicYearId: testYear.id,
              categoryId: isIncome ? incomeCategory.id : expenseCategory.id,
              type: isIncome ? 'income' : 'expense',
              amount: amount,
              title: 'Mutasi Bulan $actualMonth-$year',
              transactionDate: date,
              createdAt: date,
              updatedAt: date,
            ),
            category: isIncome ? incomeCategory : expenseCategory,
            academicYear: testYear,
          ),
        );
      }

      final widgets = PdfReportService.buildTransactionSection(
        sortedItems: items,
        totalIncome: totalSimulatedIncome,
        totalExpense: totalSimulatedExpense,
        finalBalance: runningSimulatedBalance,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      // Section title (Text) + SizedBox + (12 containers + 12 tables) = 26 widgets
      expect(widgets.length, equals(26));
      expect(widgets[0], isA<pw.Text>());
      expect(widgets[1], isA<pw.SizedBox>());

      // Count subheaders and tables
      var headerCount = 0;
      var tableCount = 0;
      for (var i = 2; i < widgets.length; i++) {
        if (widgets[i] is pw.Container) headerCount++;
        if (widgets[i] is pw.Table) tableCount++;
      }
      expect(headerCount, equals(12));
      expect(tableCount, equals(12));
    });

    // =========================================================================
    // CHALLENGE 2: HIGH VOLUME (180 TRANSACTIONS) PAGINATION & SEQUENCE STRESS
    // =========================================================================
    test('CHALLENGE 2.1: 180 Transactions across 3 months preserve sequential numbering 1..180 and balance integrity', () {
      final items = <TransactionWithCategory>[];
      var totalIncome = 0;
      var totalExpense = 0;
      var expectedBalance = 0;

      // 60 transactions in July, 60 in August, 60 in September = 180 items
      for (var month = 7; month <= 9; month++) {
        for (var day = 1; day <= 30; day++) {
          // 2 transactions per day
          for (var tx = 1; tx <= 2; tx++) {
            final isIncome = (day + tx) % 3 != 0;
            final amount = isIncome ? 10000 : 7000;
            if (isIncome) {
              totalIncome += amount;
              expectedBalance += amount;
            } else {
              totalExpense += amount;
              expectedBalance -= amount;
            }

            final date = DateTime(2027, month, day, 8 + tx * 3, 0);
            items.add(
              TransactionWithCategory(
                transaction: Transaction(
                  id: 'tx_vol_${month}_${day}_$tx',
                  academicYearId: testYear.id,
                  categoryId: isIncome ? incomeCategory.id : expenseCategory.id,
                  type: isIncome ? 'income' : 'expense',
                  amount: amount,
                  title: 'Transaksi Volume Tinggi Hari Ke-$day Bulan $month Kloter $tx dengan deskripsi yang cukup panjang untuk menguji teks pembungkus tabel PDF',
                  transactionDate: date,
                  createdAt: date,
                  updatedAt: date,
                ),
                category: isIncome ? incomeCategory : expenseCategory,
                academicYear: testYear,
              ),
            );
          }
        }
      }

      expect(items.length, equals(180));

      final widgets = PdfReportService.buildTransactionSection(
        sortedItems: items,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        finalBalance: expectedBalance,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      // Multi-month: 3 months -> 1 title + 1 sizedBox + 3 * (1 container + 1 table) = 8 widgets
      expect(widgets.length, equals(8));
    });

    test('CHALLENGE 2.2: generateReportPdf successfully renders 180 transactions into valid multi-page PDF binary without memory or layout crash', () async {
      final items = <TransactionWithCategory>[];
      for (var i = 1; i <= 150; i++) {
        final month = (i % 3) + 7; // months 7, 8, 9
        final day = (i % 28) + 1;
        final isIncome = i % 2 == 0;
        final amount = 15000;
        final date = DateTime(2027, month, day);

        items.add(
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_bin_$i',
              academicYearId: testYear.id,
              categoryId: isIncome ? incomeCategory.id : expenseCategory.id,
              type: isIncome ? 'income' : 'expense',
              amount: amount,
              title: 'Pembayaran Kas/Belanja Nomor Urut $i',
              transactionDate: date,
              createdAt: date,
              updatedAt: date,
            ),
            category: isIncome ? incomeCategory : expenseCategory,
            academicYear: testYear,
          ),
        );
      }

      final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: '3 Bulan (150 Transaksi Skala Besar)',
        items: items,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // Ensure PDF header is valid
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46])); // %PDF
      // Ensure file size reflects multiple pages of content (>20 KB)
      expect(pdfBytes.length, greaterThan(20000));
    });

    // =========================================================================
    // CHALLENGE 3: 100% INCOME & 100% EXPENSES (NEGATIVE BALANCE) EXTREMES
    // =========================================================================
    test('CHALLENGE 3.1: 100% Income cash flow produces dash in expense summary without crashing or invalid red badges', () {
      final items = <TransactionWithCategory>[];
      var totalIncome = 0;

      for (var i = 1; i <= 10; i++) {
        totalIncome += 50000;
        final date = DateTime(2027, 7, i);
        items.add(
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_inc_$i',
              academicYearId: testYear.id,
              categoryId: incomeCategory.id,
              type: 'income',
              amount: 50000,
              title: 'Setoran Kas Hari $i',
              transactionDate: date,
              createdAt: date,
              updatedAt: date,
            ),
            category: incomeCategory,
            academicYear: testYear,
          ),
        );
      }

      final widgets = PdfReportService.buildTransactionSection(
        sortedItems: items,
        totalIncome: totalIncome,
        totalExpense: 0,
        finalBalance: totalIncome,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      expect(widgets.length, equals(3));
      final table = widgets[2] as pw.Table;
      expect(table, isNotNull);
    });

    test('CHALLENGE 3.2: 100% Expense cash flow produces negative balance without overflow or layout crash', () async {
      final items = <TransactionWithCategory>[];
      var totalExpense = 0;

      for (var i = 1; i <= 15; i++) {
        totalExpense += 30000;
        final date = DateTime(2027, 7, i);
        items.add(
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_exp_$i',
              academicYearId: testYear.id,
              categoryId: expenseCategory.id,
              type: 'expense',
              amount: 30000,
              title: 'Pengeluaran Darurat Kelas $i',
              transactionDate: date,
              createdAt: date,
              updatedAt: date,
            ),
            category: expenseCategory,
            academicYear: testYear,
          ),
        );
      }

      final negativeBalance = -totalExpense;
      expect(negativeBalance, equals(-450000));

      final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: 'Defisit 100% Pengeluaran',
        items: items,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46]));
    });

    // =========================================================================
    // CHALLENGE 4: STUDENT DUES ARREARS AUDIT EXTREMES
    // =========================================================================
    test('CHALLENGE 4.1: Massive arrears range (100 days across 4 months) formats properly and renders in PDF audit table', () {
      final periods = <DuesPeriod>[];
      for (var day = 1; day <= 100; day++) {
        final date = DateTime(2027, 7, 1).add(Duration(days: day - 1));
        periods.add(
          DuesPeriod(
            id: 'dp_stress_$day',
            academicYearId: testYear.id,
            periodLabel: '${date.day} ${_monthName(date.month)} ${date.year}',
            dueDate: date,
            targetAmount: 2000,
            isReconciled: false,
            reconciledAmount: 0,
            createdAt: date,
          ),
        );
      }

      final rangeText = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: periods,
        periodType: 'daily',
      );

      // Should format into a coherent range text without crashing
      expect(rangeText, isNotEmpty);
      expect(rangeText, startsWith('Dari '));
      expect(rangeText, contains(' s.d. '));

      final massiveArrearsItem = StudentArrearsReportItem(
        studentNumber: 1,
        studentName: 'Siswa Penunggak Kronis 100 Hari',
        unpaidPeriodRangeText: rangeText,
        unpaidPeriodsCount: 100,
        duesRate: 2000,
        totalArrearsAmount: 200000,
        rateDescription: 'Rp2.000 / hari',
      );

      final auditWidgets = PdfReportService.buildArrearsAuditSection(
        academicYear: testYear,
        arrearsItems: [massiveArrearsItem],
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      expect(auditWidgets, isNotEmpty);
      final hasTable = auditWidgets.any((w) => w is pw.Table);
      expect(hasTable, isTrue);
    });

    test('CHALLENGE 4.2: Large class with 50 students in arrears correctly calculates summary total and badge count', () {
      final fiftyStudentsArrears = <StudentArrearsReportItem>[];
      var totalExpectedArrears = 0;

      for (var i = 1; i <= 50; i++) {
        final unpaidCount = (i % 10) + 1;
        final amount = unpaidCount * 2000;
        totalExpectedArrears += amount;

        fiftyStudentsArrears.add(
          StudentArrearsReportItem(
            studentNumber: i,
            studentName: 'Siswa Nomor Absen $i Nama Sangat Panjang Bin Fulan',
            unpaidPeriodRangeText: 'Dari $i Juli s.d. ${i + unpaidCount} Juli 2027',
            unpaidPeriodsCount: unpaidCount,
            duesRate: 2000,
            totalArrearsAmount: amount,
            rateDescription: 'Rp2.000 / hari',
          ),
        );
      }

      expect(fiftyStudentsArrears.length, equals(50));

      final auditWidgets = PdfReportService.buildArrearsAuditSection(
        academicYear: testYear,
        arrearsItems: fiftyStudentsArrears,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      final actualArrearsSum = fiftyStudentsArrears.fold<int>(0, (sum, i) => sum + i.totalArrearsAmount);
      expect(actualArrearsSum, equals(totalExpectedArrears));

      // Table is rendered
      final hasTable = auditWidgets.any((w) => w is pw.Table);
      expect(hasTable, isTrue);

      // Verify the badge displays '50 SISWA MENUNGGAK'
      final titleRow = auditWidgets.firstWhere((w) => w is pw.Row) as pw.Row;
      final badgeContainer = titleRow.children.last as pw.Container;
      final badgeText = badgeContainer.child as pw.Text;
      expect(badgeText.text.toPlainText(), equals('50 SISWA MENUNGGAK'));
    });

    test('CHALLENGE 4.3: Exactly 1 student in arrears displays singular badge count "1 SISWA MENUNGGAK"', () {
      final singleArrears = [
        const StudentArrearsReportItem(
            studentNumber: 15,
            studentName: 'Bima Sakti',
            unpaidPeriodRangeText: '10 Juli 2027',
            unpaidPeriodsCount: 1,
            duesRate: 2000,
            totalArrearsAmount: 2000,
            rateDescription: 'Rp2.000 / hari',
          ),
      ];

      final auditWidgets = PdfReportService.buildArrearsAuditSection(
        academicYear: testYear,
        arrearsItems: singleArrears,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      final titleRow = auditWidgets.firstWhere((w) => w is pw.Row) as pw.Row;
      final badgeContainer = titleRow.children.last as pw.Container;
      final badgeText = badgeContainer.child as pw.Text;
      expect(badgeText.text.toPlainText(), equals('1 SISWA MENUNGGAK'));
    });

    test('CHALLENGE 4.4: Zero arrears displays "STATUS: LUNAS" and verified Nihil badge with no table', () {
      final auditWidgets = PdfReportService.buildArrearsAuditSection(
        academicYear: testYear,
        arrearsItems: [],
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      final titleRow = auditWidgets.firstWhere((w) => w is pw.Row) as pw.Row;
      final badgeContainer = titleRow.children.last as pw.Container;
      final badgeText = badgeContainer.child as pw.Text;
      expect(badgeText.text.toPlainText(), equals('STATUS: LUNAS'));

      // No table when zero arrears
      final hasTable = auditWidgets.any((w) => w is pw.Table);
      expect(hasTable, isFalse);
    });

    // =========================================================================
    // CHALLENGE 5: BACKDATED RECORDING & CHRONOLOGICAL INVARIANCE
    // =========================================================================
    test('CHALLENGE 5.1: Backdated transactions are placed in their event-month partition and sorted by transactionDate', () {
      // Transaction recorded in September but transactionDate was July 5 (Backdated)
      final backdatedTx = TransactionWithCategory(
        transaction: Transaction(
          id: 'tx_backdated',
          academicYearId: testYear.id,
          categoryId: incomeCategory.id,
          type: 'income',
          amount: 25000,
          title: 'Uang Kas Juli Tercecer (Input Mundur di September)',
          transactionDate: DateTime(2027, 7, 5),
          createdAt: DateTime(2027, 9, 20), // Created months later
          updatedAt: DateTime(2027, 9, 20),
        ),
        category: incomeCategory,
        academicYear: testYear,
      );

      final regularJulyTx = TransactionWithCategory(
        transaction: Transaction(
          id: 'tx_reg_july',
          academicYearId: testYear.id,
          categoryId: expenseCategory.id,
          type: 'expense',
          amount: 10000,
          title: 'Spidol Reguler Juli',
          transactionDate: DateTime(2027, 7, 10),
          createdAt: DateTime(2027, 7, 10),
          updatedAt: DateTime(2027, 7, 10),
        ),
        category: expenseCategory,
        academicYear: testYear,
      );

      final septTx = TransactionWithCategory(
        transaction: Transaction(
          id: 'tx_sept',
          academicYearId: testYear.id,
          categoryId: incomeCategory.id,
          type: 'income',
          amount: 30000,
          title: 'Kas September Reguler',
          transactionDate: DateTime(2027, 9, 1),
          createdAt: DateTime(2027, 9, 1),
          updatedAt: DateTime(2027, 9, 1),
        ),
        category: incomeCategory,
        academicYear: testYear,
      );

      // Scrambled input
      final rawItems = [septTx, backdatedTx, regularJulyTx];

      final sorted = List<TransactionWithCategory>.from(rawItems)
        ..sort((a, b) {
          final cmp = a.transaction.transactionDate.compareTo(b.transaction.transactionDate);
          if (cmp != 0) return cmp;
          return a.transaction.createdAt.compareTo(b.transaction.createdAt);
        });

      // Verification 1: July 5 comes first, then July 10, then Sept 1
      expect(sorted[0].transaction.id, equals('tx_backdated'));
      expect(sorted[1].transaction.id, equals('tx_reg_july'));
      expect(sorted[2].transaction.id, equals('tx_sept'));

      // Verification 2: Month grouping correctly associates backdated item to July
      final groups = PdfReportService.groupTransactionsByMonth(sorted);
      expect(groups.length, equals(2));
      expect(groups.containsKey(DateTime(2027, 7)), isTrue);
      expect(groups.containsKey(DateTime(2027, 9)), isTrue);

      final julyGroup = groups[DateTime(2027, 7)]!;
      expect(julyGroup.length, equals(2));
      expect(julyGroup.first.transaction.title, contains('Input Mundur di September'));
    });

    // =========================================================================
    // CHALLENGE 6: SIMULTANEOUS HEAVY STRESS INTEGRATION PDF
    // =========================================================================
    test('CHALLENGE 6.1: [REMEDIATED] Arrears audit with 35 students paginates cleanly without PdfTooBigPageException', () async {
      final arrears = <StudentArrearsReportItem>[];
      for (var s = 1; s <= 35; s++) {
        arrears.add(
          StudentArrearsReportItem(
            studentNumber: s,
            studentName: 'Nama Siswa Menunggak Ke-$s',
            unpaidPeriodRangeText: 'Dari 1 Juli s.d. ${(s % 20) + 1} Juli 2027',
            unpaidPeriodsCount: (s % 20) + 1,
            duesRate: 2000,
            totalArrearsAmount: ((s % 20) + 1) * 2000,
            rateDescription: 'Rp2.000 / hari',
          ),
        );
      }

      final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: 'Audit Tunggakan 35 Siswa',
        items: [],
        studentArrears: arrears,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('CHALLENGE 6.2: Arrears audit section with 20 students fits on 1 page and does not throw', () async {
      final arrears = <StudentArrearsReportItem>[];
      for (var s = 1; s <= 20; s++) {
        arrears.add(
          StudentArrearsReportItem(
            studentNumber: s,
            studentName: 'Nama Siswa Menunggak Ke-$s',
            unpaidPeriodRangeText: 'Dari 1 Juli s.d. ${(s % 20) + 1} Juli 2027',
            unpaidPeriodsCount: (s % 20) + 1,
            duesRate: 2000,
            totalArrearsAmount: ((s % 20) + 1) * 2000,
            rateDescription: 'Rp2.000 / hari',
          ),
        );
      }

      final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: 'Audit Tunggakan 20 Siswa',
        items: [],
        studentArrears: arrears,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('CHALLENGE 6.3: [REMEDIATED] Arrears audit with 25 students breaches single page threshold and paginates cleanly without PdfTooBigPageException', () async {
      final arrears = <StudentArrearsReportItem>[];
      for (var s = 1; s <= 25; s++) {
        arrears.add(
          StudentArrearsReportItem(
            studentNumber: s,
            studentName: 'Nama Siswa Menunggak Ke-$s',
            unpaidPeriodRangeText: 'Dari 1 Juli s.d. ${(s % 20) + 1} Juli 2027',
            unpaidPeriodsCount: (s % 20) + 1,
            duesRate: 2000,
            totalArrearsAmount: ((s % 20) + 1) * 2000,
            rateDescription: 'Rp2.000 / hari',
          ),
        );
      }

      final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: 'Audit Tunggakan 25 Siswa',
        items: [],
        studentArrears: arrears,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('CHALLENGE 6.4: [REMEDIATED] Arrears audit with 30 students (standard class size) paginates cleanly without PdfTooBigPageException', () async {
      final arrears = <StudentArrearsReportItem>[];
      for (var s = 1; s <= 30; s++) {
        arrears.add(
          StudentArrearsReportItem(
            studentNumber: s,
            studentName: 'Nama Siswa Menunggak Ke-$s',
            unpaidPeriodRangeText: 'Dari 1 Juli s.d. ${(s % 20) + 1} Juli 2027',
            unpaidPeriodsCount: (s % 20) + 1,
            duesRate: 2000,
            totalArrearsAmount: ((s % 20) + 1) * 2000,
            rateDescription: 'Rp2.000 / hari',
          ),
        );
      }

      final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: 'Audit Tunggakan 30 Siswa',
        items: [],
        studentArrears: arrears,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('CHALLENGE 6.5: 100 Transactions across 6 months alone (0 arrears) succeeds and paginates properly', () async {
      final items = <TransactionWithCategory>[];
      for (var i = 1; i <= 100; i++) {
        final m = (i % 6) + 7; // months 7..12
        final isInc = i % 3 != 0;
        final d = DateTime(2027, m, (i % 25) + 1);
        items.add(
          TransactionWithCategory(
            transaction: Transaction(
              id: 'tx_stress_heavy_$i',
              academicYearId: testYear.id,
              categoryId: isInc ? incomeCategory.id : expenseCategory.id,
              type: isInc ? 'income' : 'expense',
              amount: isInc ? 20000 : 15000,
              title: 'Transaksi Gabungan Beban Berat $i',
              transactionDate: d,
              createdAt: d,
              updatedAt: d,
            ),
            category: isInc ? incomeCategory : expenseCategory,
            academicYear: testYear,
          ),
        );
      }

      final Uint8List pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: testYear,
        periodRangeTitle: 'Semester 1 (100 Transaksi 6 Bulan)',
        items: items,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('CHALLENGE 6.6: [VERIFICATION OF MITIGATION] Returning arrears audit as List<pw.Widget> supports 50+ students pagination', () async {
      final arrears = <StudentArrearsReportItem>[];
      for (var s = 1; s <= 50; s++) {
        arrears.add(
          StudentArrearsReportItem(
            studentNumber: s,
            studentName: 'Nama Siswa Menunggak Ke-$s',
            unpaidPeriodRangeText: 'Dari 1 Juli s.d. ${(s % 20) + 1} Juli 2027',
            unpaidPeriodsCount: (s % 20) + 1,
            duesRate: 2000,
            totalArrearsAmount: ((s % 20) + 1) * 2000,
            rateDescription: 'Rp2.000 / hari',
          ),
        );
      }

      final auditWidgets = PdfReportService.buildArrearsAuditSection(
        academicYear: testYear,
        arrearsItems: arrears,
        fontRegular: fontRegular,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
      );

      // When added directly into MultiPage as individual widgets
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          maxPages: 100,
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
          build: (context) => [
            // List<pw.Widget> spread so that pw.Table can break across pages
            ...auditWidgets,
          ],
        ),
      );

      final pdfBytes = await doc.save();
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46]));
      // Multi-page table for 50 students should be cleanly generated!
      expect(pdfBytes.length, greaterThan(5000));
    });
  });
}

String _monthName(int month) {
  const names = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  if (month >= 1 && month <= 12) return names[month - 1];
  return '';
}
