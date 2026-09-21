import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String toHumanDate(DateTime date) {
    return DateFormat('d MMMM yyyy', 'id_ID').format(date);
  }

  static String toShortDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String toHumanDateTime(DateTime date) {
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(date);
  }

  static String toMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy', 'id_ID').format(date);
  }

  static const Map<String, int> _monthMap = {
    'januari': 1, 'jan': 1,
    'februari': 2, 'feb': 2,
    'maret': 3, 'mar': 3,
    'april': 4, 'apr': 4,
    'mei': 5, 'may': 5,
    'juni': 6, 'jun': 6,
    'juli': 7, 'jul': 7,
    'agustus': 8, 'agu': 8, 'agt': 8,
    'september': 9, 'sep': 9,
    'oktober': 10, 'okt': 10, 'oct': 10,
    'november': 11, 'nov': 11,
    'desember': 12, 'des': 12, 'dec': 12,
  };

  /// Mencoba mengekstrak DateTime dari label periode kas (Harian, Mingguan, Bulanan)
  static DateTime? tryParsePeriodDate(String label, {DateTime? fallbackDueDate}) {
    final clean = label.trim();

    // 1. Format Harian: e.g. "Harian 14 September 2026"
    final dailyMatch = RegExp(r'Harian\s+(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})', caseSensitive: false).firstMatch(clean);
    if (dailyMatch != null) {
      final day = int.tryParse(dailyMatch.group(1)!);
      final month = _monthMap[dailyMatch.group(2)!.toLowerCase()];
      final year = int.tryParse(dailyMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    // 2. Format Mingguan: e.g. "Minggu 2 September 2026"
    final weeklyMatch = RegExp(r'Minggu\s+(\d+)\s+([A-Za-z]+)\s+(\d{4})', caseSensitive: false).firstMatch(clean);
    if (weeklyMatch != null) {
      final week = int.tryParse(weeklyMatch.group(1)!);
      final month = _monthMap[weeklyMatch.group(2)!.toLowerCase()];
      final year = int.tryParse(weeklyMatch.group(3)!);
      if (week != null && month != null && year != null) {
        if (fallbackDueDate != null && fallbackDueDate.year == year && fallbackDueDate.month == month) {
          return fallbackDueDate;
        }
        final day = ((week - 1) * 7 + 1).clamp(1, 28);
        return DateTime(year, month, day);
      }
    }

    // 3. Format Bulanan: e.g. "Bulan September 2026"
    final monthlyMatch = RegExp(r'Bulan\s+([A-Za-z]+)\s+(\d{4})', caseSensitive: false).firstMatch(clean);
    if (monthlyMatch != null) {
      final month = _monthMap[monthlyMatch.group(1)!.toLowerCase()];
      final year = int.tryParse(monthlyMatch.group(2)!);
      if (month != null && year != null) {
        return DateTime(year, month, 1);
      }
    }

    return fallbackDueDate;
  }

  /// Mencoba mengekstrak DateTime dari judul transaksi rekonsiliasi kas
  /// Contoh: "Kas Kelas (Harian 14 September 2026)" atau "... - Tambahan"
  static DateTime? tryParseDateFromTitle(String title, {DateTime? fallback}) {
    final titleMatch = RegExp(r'Kas Kelas \(([^)]+)\)', caseSensitive: false).firstMatch(title);
    if (titleMatch != null) {
      final label = titleMatch.group(1)!;
      final parsed = tryParsePeriodDate(label, fallbackDueDate: fallback);
      if (parsed != null) return parsed;
    }
    return fallback;
  }
}
