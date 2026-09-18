import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repository.dart';

class PdfReportService {
  PdfReportService._();

  static Future<Uint8List> generateReportPdf({
    required AcademicYear academicYear,
    required String periodRangeTitle, // misal: "1 Bulan (1 Sep 2026 s/d 30 Sep 2026)"
    required List<TransactionWithCategory> items,
  }) async {
    final pdf = pw.Document();

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

          // 2. Tabel Rincian Arus Kas
          pw.Text(
            'Rincian Transaksi Kas Kelas',
            style: pw.TextStyle(font: fontSemiBold, fontSize: 11, color: PdfColor.fromHex('#0F172A')),
          ),
          pw.SizedBox(height: 6),
          items.isEmpty
              ? pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Tidak ada catatan transaksi pada rentang waktu ini.',
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B')),
                  ),
                )
              : pw.TableHelper.fromTextArray(
                  headers: [
                    'No',
                    'Tanggal',
                    'Kategori',
                    'Keterangan Transaksi',
                    'Kas Masuk',
                    'Kas Keluar',
                    'Saldo',
                  ],
                  data: _buildTableRows(items),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                  headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1B4332')),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.center,
                    4: pw.Alignment.centerRight,
                    5: pw.Alignment.centerRight,
                    6: pw.Alignment.centerRight,
                  },
                  rowDecoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                  ),
                  oddRowDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8F9FA'),
                  ),
                ),
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

  static List<List<dynamic>> _buildTableRows(List<TransactionWithCategory> items) {
    final rows = <List<dynamic>>[];
    var runningBalance = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isIncome = item.transaction.type == 'income';
      if (isIncome) {
        runningBalance += item.transaction.amount;
      } else {
        runningBalance -= item.transaction.amount;
      }

      rows.add([
        '${i + 1}',
        DateFormatter.toShortDate(item.transaction.transactionDate),
        item.category.name,
        item.transaction.title,
        isIncome ? CurrencyFormatter.format(item.transaction.amount) : '-',
        !isIncome ? CurrencyFormatter.format(item.transaction.amount) : '-',
        CurrencyFormatter.format(runningBalance),
      ]);
    }

    return rows;
  }
}
