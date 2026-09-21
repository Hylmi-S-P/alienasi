import 'package:csv/csv.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repository.dart';

class CsvExportService {
  CsvExportService._();

  static String generateCsv({
    required AcademicYear academicYear,
    required List<TransactionWithCategory> items,
  }) {
    final rows = <List<dynamic>>[];

    // Header Metadata
    rows.add(['LAPORAN PERTANGGUNGJAWABAN KAS KELAS']);
    rows.add(['Kelas', academicYear.name]);
    rows.add(['Tahun Ajaran', '${academicYear.startDate.year}/${academicYear.endDate.year}']);
    rows.add(['Bendahara', academicYear.treasurerName]);
    rows.add(['Pengawas / Orang Tua', academicYear.supervisorName]);
    rows.add(['Tanggal Cetak', DateFormatter.toHumanDateTime(DateTime.now())]);
    rows.add([]);

    // Table Column Headers (Struktur sejajar dengan Laporan PDF)
    rows.add(['No', 'Tanggal', 'Kategori', 'Keterangan Transaksi', 'Kas Masuk (Rp)', 'Kas Keluar (Rp)', 'Saldo (Rp)', 'Bukti Foto Nota']);

    final sorted = List<TransactionWithCategory>.from(items)
      ..sort((a, b) {
        final cmp = a.transaction.transactionDate.compareTo(b.transaction.transactionDate);
        if (cmp != 0) return cmp;
        return a.transaction.createdAt.compareTo(b.transaction.createdAt);
      });

    var runningBalance = 0;
    var totalIncome = 0;
    var totalExpense = 0;

    for (var i = 0; i < sorted.length; i++) {
      final item = sorted[i];
      final isIncome = item.transaction.type == 'income';
      if (isIncome) {
        runningBalance += item.transaction.amount;
        totalIncome += item.transaction.amount;
      } else {
        runningBalance -= item.transaction.amount;
        totalExpense += item.transaction.amount;
      }

      final hasReceipt = item.transaction.receiptImagePath != null && item.transaction.receiptImagePath!.isNotEmpty;

      rows.add([
        i + 1,
        DateFormatter.toShortDate(item.transaction.transactionDate),
        item.category.name,
        item.transaction.title,
        isIncome ? item.transaction.amount : 0,
        !isIncome ? item.transaction.amount : 0,
        runningBalance,
        hasReceipt ? 'Ada Nota' : '-',
      ]);
    }

    // Baris Total Ringkasan
    rows.add([]);
    rows.add(['TOTAL', '', '', '', totalIncome, totalExpense, runningBalance, '']);

    return csv.encode(rows);
  }
}
