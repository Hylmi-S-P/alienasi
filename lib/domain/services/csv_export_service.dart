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

    // Table Column Headers
    rows.add(['No', 'Tanggal', 'Tipe', 'Kategori', 'Keterangan', 'Nominal (Rp)', 'Saldo Berjalan (Rp)']);

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
        i + 1,
        DateFormatter.toShortDate(item.transaction.transactionDate),
        isIncome ? 'Pemasukan' : 'Pengeluaran',
        item.category.name,
        item.transaction.title,
        item.transaction.amount,
        runningBalance,
      ]);
    }

    return csv.encode(rows);
  }
}
