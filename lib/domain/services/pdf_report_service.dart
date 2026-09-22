import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repository.dart';
import 'dues_arrears_service.dart';
import 'receipt_storage_service.dart';

class PdfReportService {
  PdfReportService._();

  static const List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  static const Map<int, pw.TableColumnWidth> tableColumnWidths = {
    0: pw.FixedColumnWidth(26), // No
    1: pw.FixedColumnWidth(64), // Tanggal
    2: pw.FixedColumnWidth(85), // Kategori
    3: pw.FlexColumnWidth(2.6), // Keterangan Transaksi
    4: pw.FixedColumnWidth(74), // Kas Masuk
    5: pw.FixedColumnWidth(74), // Kas Keluar
    6: pw.FixedColumnWidth(78), // Saldo
  };

  static const Map<int, pw.Alignment> tableHeaderAlignments = {
    0: pw.Alignment.center,
    1: pw.Alignment.center,
    2: pw.Alignment.centerLeft,
    3: pw.Alignment.centerLeft,
    4: pw.Alignment.centerRight,
    5: pw.Alignment.centerRight,
    6: pw.Alignment.centerRight,
  };

  static const Map<int, pw.Alignment> tableCellAlignments = {
    0: pw.Alignment.center,
    1: pw.Alignment.center,
    2: pw.Alignment.centerLeft,
    3: pw.Alignment.centerLeft,
    4: pw.Alignment.centerRight,
    5: pw.Alignment.centerRight,
    6: pw.Alignment.centerRight,
  };

  @visibleForTesting
  static String getMonthHeaderTitle(DateTime monthKey) {
    final monthName = (monthKey.month >= 1 && monthKey.month <= 12)
        ? _monthNames[monthKey.month - 1].toUpperCase()
        : '';
    return 'BULAN $monthName ${monthKey.year}';
  }

  @visibleForTesting
  static Map<DateTime, List<TransactionWithCategory>> groupTransactionsByMonth(
    List<TransactionWithCategory> sortedItems,
  ) {
    final Map<DateTime, List<TransactionWithCategory>> groups = {};
    for (final item in sortedItems) {
      final key = DateTime(
        item.transaction.transactionDate.year,
        item.transaction.transactionDate.month,
      );
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }

  @visibleForTesting
  static pw.Widget buildExpenseCell({
    required int amount,
    required pw.Font fontBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FEF2F2'),
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: PdfColor.fromHex('#FECACA'), width: 0.5),
      ),
      child: pw.Text(
        CurrencyFormatter.format(amount),
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 8,
          color: PdfColor.fromHex('#DC2626'),
        ),
        textAlign: pw.TextAlign.right,
      ),
    );
  }

  @visibleForTesting
  static pw.Widget buildIncomeCell({
    required int amount,
    required pw.Font fontRegular,
  }) {
    return pw.Text(
      CurrencyFormatter.format(amount),
      style: pw.TextStyle(
        font: fontRegular,
        fontSize: 8,
        color: PdfColor.fromHex('#16A34A'),
      ),
      textAlign: pw.TextAlign.right,
    );
  }

  @visibleForTesting
  static List<pw.Widget> buildTransactionSection({
    required List<TransactionWithCategory> sortedItems,
    required int totalIncome,
    required int totalExpense,
    required int finalBalance,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    final widgets = <pw.Widget>[
      pw.Text(
        'Rincian Transaksi Kas Kelas',
        style: pw.TextStyle(font: fontSemiBold, fontSize: 11, color: PdfColor.fromHex('#0F172A')),
      ),
      pw.SizedBox(height: 6),
    ];

    if (sortedItems.isEmpty) {
      widgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Tidak ada catatan transaksi pada rentang waktu ini.',
            style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B')),
          ),
        ),
      );
      return widgets;
    }

    final monthGroups = groupTransactionsByMonth(sortedItems);
    final isMultiMonth = monthGroups.length > 1;

    var runningBalance = 0;
    var runningRowIndex = 1;
    final totalEntries = monthGroups.entries.length;
    var entryIndex = 0;

    for (final entry in monthGroups.entries) {
      entryIndex++;
      final isLastMonth = entryIndex == totalEntries;
      final monthItems = entry.value;

      // 1. Month Partition Sub-header (when multi-month)
      if (isMultiMonth) {
        widgets.add(
          pw.Container(
            margin: pw.EdgeInsets.only(top: entryIndex == 1 ? 2 : 10, bottom: 4),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#2D6A4F'),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  getMonthHeaderTitle(entry.key),
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.Text(
                  '${monthItems.length} Transaksi Tercatat',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
                ),
              ],
            ),
          ),
        );
      }

      // 2. Table rows for this month
      final rows = <List<dynamic>>[];
      for (final item in monthItems) {
        final isIncome = item.transaction.type == 'income';
        if (isIncome) {
          runningBalance += item.transaction.amount;
        } else {
          runningBalance -= item.transaction.amount;
        }

        final hasReceipt = item.transaction.receiptImagePath != null && item.transaction.receiptImagePath!.isNotEmpty;
        final titleText = hasReceipt ? '${item.transaction.title} [Ada Nota]' : item.transaction.title;

        rows.add([
          '$runningRowIndex',
          DateFormatter.toShortDate(item.transaction.transactionDate),
          item.category.name,
          titleText,
          isIncome
              ? buildIncomeCell(amount: item.transaction.amount, fontRegular: fontRegular)
              : pw.Text('-', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8'))),
          !isIncome
              ? buildExpenseCell(amount: item.transaction.amount, fontBold: fontBold)
              : pw.Text('-', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8'))),
          pw.Text(
            CurrencyFormatter.format(runningBalance),
            style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#0F172A')),
            textAlign: pw.TextAlign.right,
          ),
        ]);
        runningRowIndex++;
      }

      // If last month, append the TOTAL cumulative summary row
      if (isLastMonth) {
        rows.add([
          pw.Text('TOTAL', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColor.fromHex('#0F172A')), textAlign: pw.TextAlign.center),
          pw.Text('-', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')), textAlign: pw.TextAlign.center),
          pw.Text('-', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')), textAlign: pw.TextAlign.left),
          pw.Text('${sortedItems.length} Transaksi Tercatat', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#0F172A')), textAlign: pw.TextAlign.left),
          pw.Text(
            CurrencyFormatter.format(totalIncome),
            style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#16A34A')),
            textAlign: pw.TextAlign.right,
          ),
          totalExpense > 0
              ? buildExpenseCell(amount: totalExpense, fontBold: fontBold)
              : pw.Text('-', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8'))),
          pw.Text(
            CurrencyFormatter.format(finalBalance),
            style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#0F172A')),
            textAlign: pw.TextAlign.right,
          ),
        ]);
      }

      widgets.add(
        pw.TableHelper.fromTextArray(
          headers: const [
            'No',
            'Tanggal',
            'Kategori',
            'Keterangan Transaksi',
            'Kas Masuk',
            'Kas Keluar',
            'Saldo',
          ],
          data: rows,
          columnWidths: tableColumnWidths,
          headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1B4332')),
          headerHeight: 26,
          headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          headerAlignments: tableHeaderAlignments,
          cellStyle: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#1E293B')),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          cellAlignment: pw.Alignment.centerLeft,
          cellAlignments: tableCellAlignments,
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
            bottom: pw.BorderSide(color: PdfColor.fromHex('#CBD5E1'), width: 1.0),
          ),
          rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
          oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
        ),
      );
    }

    return widgets;
  }

  @visibleForTesting
  static List<pw.Widget> buildArrearsAuditSection({
    required AcademicYear academicYear,
    required List<StudentArrearsReportItem> arrearsItems,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    final totalUncollected = arrearsItems.fold<int>(0, (sum, i) => sum + i.totalArrearsAmount);

    String duesRateDesc = '';
    if (arrearsItems.isNotEmpty && arrearsItems.first.rateDescription.isNotEmpty) {
      duesRateDesc = arrearsItems.first.rateDescription;
    } else {
      final rate = academicYear.defaultDuesAmount;
      switch (academicYear.duesPeriodType.toLowerCase()) {
        case 'daily':
          duesRateDesc = '${CurrencyFormatter.format(rate)} / hari';
          break;
        case 'weekly':
          duesRateDesc = '${CurrencyFormatter.format(rate)} / minggu';
          break;
        case 'monthly':
          duesRateDesc = '${CurrencyFormatter.format(rate)} / bulan';
          break;
        default:
          duesRateDesc = CurrencyFormatter.format(rate);
      }
    }

    return [
      pw.SizedBox(height: 18),
      pw.Divider(thickness: 1, color: PdfColor.fromHex('#CBD5E1')),
      pw.SizedBox(height: 8),

        // Section Title & Status Badge
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'REKAPITULASI TUNGGAKAN KAS SISWA (AUDIT KAS KELAS)',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 11,
                color: PdfColor.fromHex('#1B4332'),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: arrearsItems.isEmpty
                    ? PdfColor.fromHex('#DCFCE7')
                    : PdfColor.fromHex('#FEE2E2'),
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(
                  color: arrearsItems.isEmpty
                      ? PdfColor.fromHex('#86EFAC')
                      : PdfColor.fromHex('#FECACA'),
                  width: 0.5,
                ),
              ),
              child: pw.Text(
                arrearsItems.isEmpty
                    ? 'STATUS: LUNAS'
                    : '${arrearsItems.length} SISWA MENUNGGAK',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 8,
                  color: arrearsItems.isEmpty
                      ? PdfColor.fromHex('#15803D')
                      : PdfColor.fromHex('#B91C1C'),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Tarif Kas Aktif: $duesRateDesc  |  Audit Kepatuhan Kas Berdasarkan Periode Efektif Sekolah',
          style: pw.TextStyle(
            font: fontRegular,
            fontSize: 8.5,
            color: PdfColor.fromHex('#64748B'),
          ),
        ),
        pw.SizedBox(height: 8),

        if (arrearsItems.isEmpty)
          // Verified Nihil Tunggakan Badge
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F0FDF4'),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColor.fromHex('#86EFAC'), width: 1),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 22,
                  height: 22,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#16A34A'),
                    shape: pw.BoxShape.circle,
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'OK',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      font: fontBold,
                      fontSize: 8,
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Nihil Tunggakan (Semua Siswa Lunas)',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColor.fromHex('#15803D'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Seluruh siswa aktif telah melunasi seluruh kewajiban kas kelas pada periode efektif ini. Tidak ada tagihan kas tertunggak.',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColor.fromHex('#166534'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          // Table Rincian Tunggakan
          pw.TableHelper.fromTextArray(
            headers: const [
              'No',
              'Nama Siswa',
              'Rentang Periode Belum Bayar',
              'Tarif Kas',
              'Total Tunggakan',
            ],
            data: [
              ...arrearsItems.map((item) {
                return [
                  '${item.studentNumber}',
                  item.studentName,
                  item.unpaidPeriodRangeText,
                  item.rateDescription.isNotEmpty ? item.rateDescription : CurrencyFormatter.format(item.duesRate),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#FEF2F2'),
                      borderRadius: pw.BorderRadius.circular(3),
                      border: pw.Border.all(color: PdfColor.fromHex('#FECACA'), width: 0.5),
                    ),
                    child: pw.Text(
                      CurrencyFormatter.format(item.totalArrearsAmount),
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8,
                        color: PdfColor.fromHex('#DC2626'),
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ];
              }),
              // Summary footer row
              [
                pw.Text('TOTAL', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColor.fromHex('#0F172A')), textAlign: pw.TextAlign.center),
                pw.Text('-', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')), textAlign: pw.TextAlign.center),
                pw.Text(
                  'Total Kas Kelas Belum Tertagih (${arrearsItems.length} Siswa)',
                  style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#0F172A')),
                ),
                pw.Text('-', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')), textAlign: pw.TextAlign.center),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FEF2F2'),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    CurrencyFormatter.format(totalUncollected),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8.5,
                      color: PdfColor.fromHex('#DC2626'),
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ],
            columnWidths: const {
              0: pw.FixedColumnWidth(28), // No
              1: pw.FixedColumnWidth(120), // Nama Siswa
              2: pw.FlexColumnWidth(2.5), // Rentang Periode Belum Bayar
              3: pw.FixedColumnWidth(85), // Tarif Kas
              4: pw.FixedColumnWidth(85), // Total Tunggakan
            },
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1B4332')),
            headerHeight: 24,
            headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            headerAlignments: const {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            cellStyle: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#1E293B')),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: const {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
              bottom: pw.BorderSide(color: PdfColor.fromHex('#CBD5E1'), width: 1.0),
            ),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
          ),
    ];
  }

  @visibleForTesting
  static List<pw.Widget> buildSignatureSection({
    required String treasurerName,
    required String supervisorName,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
    required DateTime date,
  }) {
    pw.Widget signatureColumn(String role, String name) {
      return pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              role,
              style: pw.TextStyle(font: fontSemiBold, fontSize: 9, color: PdfColor.fromHex('#0F172A')),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 34),
            pw.Text(
              name,
              style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColor.fromHex('#0F172A')),
              textAlign: pw.TextAlign.center,
            ),
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 2),
              padding: const pw.EdgeInsets.symmetric(horizontal: 2),
              decoration: pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('#94A3B8'), width: 0.7)),
              ),
              child: pw.Text(
                DateFormatter.toShortDate(date),
                style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColor.fromHex('#94A3B8')),
              ),
            ),
          ],
        ),
      );
    }

    return [
      pw.SizedBox(height: 20),
      pw.Divider(thickness: 1, color: PdfColor.fromHex('#CBD5E1')),
      pw.SizedBox(height: 6),
      pw.Text(
        'PENGESAHAN LAPORAN',
        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromHex('#1B4332')),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'Laporan ini sah dan disetujui untuk pertanggungjawaban kas kelas.',
        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColor.fromHex('#64748B')),
      ),
      pw.SizedBox(height: 10),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          signatureColumn('Bendahara Kelas', treasurerName),
          pw.SizedBox(width: 12),
          signatureColumn('Ketua Kelas', '( ................ )'),
          pw.SizedBox(width: 12),
          signatureColumn('Wali Kelas', '( ................ )'),
          pw.SizedBox(width: 12),
          signatureColumn('Orang Tua / Pengawas', supervisorName),
        ],
      ),
    ];
  }

  @visibleForTesting
  static List<pw.Widget> buildNoteSection({
    required String note,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required String signedBy,
    required DateTime date,
  }) {
    return [
      pw.SizedBox(height: 18),
      pw.Divider(thickness: 1, color: PdfColor.fromHex('#CBD5E1')),
      pw.SizedBox(height: 8),
      pw.Row(
        children: [
          pw.Container(
            width: 4,
            height: 16,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#D97706'),
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            'CATATAN BENDAHARA',
            style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColor.fromHex('#B45309')),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Catatan resmi yang ditulis langsung oleh bendahara kelas untuk kelengkapan laporan ini.',
        style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColor.fromHex('#64748B')),
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#FFFBEB'),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColor.fromHex('#FCD34D'), width: 1),
        ),
        child: pw.Text(
          note,
          style: pw.TextStyle(
            font: fontRegular,
            fontSize: 10,
            color: PdfColor.fromHex('#1E293B'),
            lineSpacing: 2,
          ),
        ),
      ),
      pw.SizedBox(height: 14),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Dibuat oleh,',
              style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColor.fromHex('#475569')),
            ),
            pw.SizedBox(height: 28),
            pw.Text(
              signedBy,
              style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromHex('#0F172A')),
            ),
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 3),
              padding: const pw.EdgeInsets.symmetric(horizontal: 2),
              decoration: pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('#94A3B8'), width: 0.7)),
              ),
              child: pw.Text(
                'Bendahara Kelas',
                style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColor.fromHex('#64748B')),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              DateFormatter.toHumanDate(date),
              style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
            ),
          ],
        ),
      ),
    ];
  }

  static Future<Uint8List> generateReportPdf({
    required AcademicYear academicYear,
    required String periodRangeTitle, // misal: "1 Bulan (1 Sep 2026 s/d 30 Sep 2026)"
    required List<TransactionWithCategory> items,
    List<StudentArrearsReportItem>? studentArrears,
    String? customNote,
  }) async {
    final pdf = pw.Document();

    // Urutkan transaksi secara kronologis (terlama ke terbaru: old -> new)
    final sorted = List<TransactionWithCategory>.from(items)
      ..sort((a, b) {
        final cmp = a.transaction.transactionDate.compareTo(b.transaction.transactionDate);
        if (cmp != 0) return cmp;
        return a.transaction.createdAt.compareTo(b.transaction.createdAt);
      });

    // Kumpulkan bukti foto nota yang valid dan ada di penyimpanan lokal
    final receiptItems = <(TransactionWithCategory, Uint8List)>[];
    for (final item in sorted) {
      final p = item.transaction.receiptImagePath;
      if (p != null && p.isNotEmpty) {
        final bytes = await ReceiptStorageService.readBytes(p);
        if (bytes != null && bytes.isNotEmpty) {
          receiptItems.add((item, bytes));
        }
      }
    }

    // Hitung total
    var totalIncome = 0;
    var totalExpense = 0;
    for (final item in items) {
      if (item.transaction.type == 'income') {
        totalIncome += item.transaction.amount;
      } else {
        totalExpense += item.transaction.amount;
      }
    }
    final finalBalance = totalIncome - totalExpense;

    // Load font
    final fontRegular = await PdfGoogleFonts.plusJakartaSansRegular();
    final fontBold = await PdfGoogleFonts.plusJakartaSansBold();
    final fontSemiBold = await PdfGoogleFonts.plusJakartaSansSemiBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 100,
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LAPORAN PERTANGGUNGJAWABAN KAS KELAS',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 14,
                        color: PdfColor.fromHex('#1B4332'),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${academicYear.name} (Tahun Ajaran ${academicYear.startDate.year}/${academicYear.endDate.year})',
                      style: pw.TextStyle(
                        font: fontSemiBold,
                        fontSize: 11,
                        color: PdfColor.fromHex('#0F172A'),
                      ),
                    ),
                    pw.Text(
                      'Periode Laporan: $periodRangeTitle',
                      style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Cetak: ${DateFormatter.toHumanDateTime(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#1B4332')),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#94A3B8')),
          ),
        ),
        build: (context) => [
          // 1. Kotak Ringkasan Eksekutif
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8F9FA'),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryBox(
                  title: 'TOTAL KAS MASUK',
                  amount: CurrencyFormatter.format(totalIncome),
                  amountColor: PdfColor.fromHex('#16A34A'),
                  fontBold: fontBold,
                ),
                pw.Container(height: 32, width: 1, color: PdfColor.fromHex('#CBD5E1')),
                _buildSummaryBox(
                  title: 'TOTAL KAS KELUAR',
                  amount: CurrencyFormatter.format(totalExpense),
                  amountColor: PdfColor.fromHex('#DC2626'),
                  fontBold: fontBold,
                ),
                pw.Container(height: 32, width: 1, color: PdfColor.fromHex('#CBD5E1')),
                _buildSummaryBox(
                  title: 'SISA SALDO KAS',
                  amount: CurrencyFormatter.format(finalBalance),
                  amountColor: PdfColor.fromHex('#0F172A'),
                  fontBold: fontBold,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // 2. Tabel Rincian Arus Kas (Terpartisi Bulanan jika multi-bulan)
          ...buildTransactionSection(
            sortedItems: sorted,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            finalBalance: finalBalance,
            fontRegular: fontRegular,
            fontBold: fontBold,
            fontSemiBold: fontSemiBold,
          ),

          // 3. Seksi Audit Tunggakan Kas Siswa (Jika studentArrears disediakan)
          if (studentArrears != null)
            ...buildArrearsAuditSection(
              academicYear: academicYear,
              arrearsItems: studentArrears,
              fontRegular: fontRegular,
              fontBold: fontBold,
              fontSemiBold: fontSemiBold,
            ),

          // 4. Seksi Catatan Bendahara (Jika customNote diisi)
          if (customNote != null && customNote.trim().isNotEmpty)
            ...buildNoteSection(
              note: customNote.trim(),
              fontRegular: fontRegular,
              fontBold: fontBold,
              signedBy: academicYear.treasurerName,
              date: DateTime.now(),
            ),

          // 5. Kolom Pengesahan & Tanda Tangan (sesuai spesifikasi DESIGN.md)
          ...buildSignatureSection(
            treasurerName: academicYear.treasurerName,
            supervisorName: academicYear.supervisorName,
            fontRegular: fontRegular,
            fontBold: fontBold,
            fontSemiBold: fontSemiBold,
            date: DateTime.now(),
          ),

          // 6. Lampiran Bukti Foto Nota (Jika ada transaksi berbukti fisik)
          if (receiptItems.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Divider(thickness: 1, color: PdfColor.fromHex('#CBD5E1')),
            pw.SizedBox(height: 8),
            pw.Text(
              'Lampiran Bukti Foto Nota (${receiptItems.length} Foto Nota Terlampir)',
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColor.fromHex('#1B4332')),
            ),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: receiptItems.map((entry) {
                final txItem = entry.$1;
                final imgBytes = entry.$2;
                final isInc = txItem.transaction.type == 'income';
                return pw.Container(
                  width: 245,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                    color: PdfColor.fromHex('#F8F9FA'),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.ClipRRect(
                        horizontalRadius: 4,
                        verticalRadius: 4,
                        child: pw.Image(
                          pw.MemoryImage(imgBytes),
                          height: 130,
                          width: 245,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        txItem.transaction.title,
                        style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('#0F172A')),
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            DateFormatter.toShortDate(txItem.transaction.transactionDate),
                            style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#64748B')),
                          ),
                          pw.Text(
                            '${isInc ? '+' : '-'}${CurrencyFormatter.format(txItem.transaction.amount)}',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 8.5,
                              color: isInc ? PdfColor.fromHex('#16A34A') : PdfColor.fromHex('#DC2626'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryBox({
    required String title,
    required String amount,
    required PdfColor amountColor,
    required pw.Font fontBold,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#64748B')),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          amount,
          style: pw.TextStyle(font: fontBold, fontSize: 11, color: amountColor),
        ),
      ],
    );
  }

  @visibleForTesting
  static List<List<dynamic>> buildTableRows(
    List<TransactionWithCategory> items, {
    int totalIncome = 0,
    int totalExpense = 0,
    int finalBalance = 0,
    pw.Font? fontRegular,
    pw.Font? fontBold,
  }) {
    final rows = <List<dynamic>>[];
    final sorted = List<TransactionWithCategory>.from(items)
      ..sort((a, b) {
        final cmp = a.transaction.transactionDate.compareTo(b.transaction.transactionDate);
        if (cmp != 0) return cmp;
        return a.transaction.createdAt.compareTo(b.transaction.createdAt);
      });
    var runningBalance = 0;

    for (var i = 0; i < sorted.length; i++) {
      final item = sorted[i];
      final isIncome = item.transaction.type == 'income';
      if (isIncome) {
        runningBalance += item.transaction.amount;
      } else {
        runningBalance -= item.transaction.amount;
      }

      final hasReceipt = item.transaction.receiptImagePath != null && item.transaction.receiptImagePath!.isNotEmpty;
      final titleText = hasReceipt ? '${item.transaction.title} [Ada Nota]' : item.transaction.title;

      rows.add([
        '${i + 1}',
        DateFormatter.toShortDate(item.transaction.transactionDate),
        item.category.name,
        titleText,
        isIncome ? CurrencyFormatter.format(item.transaction.amount) : '-',
        !isIncome ? CurrencyFormatter.format(item.transaction.amount) : '-',
        CurrencyFormatter.format(runningBalance),
      ]);
    }

    if (sorted.isNotEmpty) {
      rows.add([
        'TOTAL',
        '-',
        '-',
        '${sorted.length} Transaksi Tercatat',
        CurrencyFormatter.format(totalIncome),
        CurrencyFormatter.format(totalExpense),
        CurrencyFormatter.format(finalBalance),
      ]);
    }

    return rows;
  }
}

