import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/database/app_database.dart';

/// Item baris audit tunggakan kas siswa untuk laporan PDF dan UI audit.
class StudentArrearsReportItem {
  final int studentNumber;
  final String studentName;
  final String unpaidPeriodRangeText;
  final int unpaidPeriodsCount;
  final int duesRate;
  final int totalArrearsAmount;
  final String? studentId;
  final String rateDescription;
  final List<DuesPeriod> unpaidPeriods;

  const StudentArrearsReportItem({
    required this.studentNumber,
    required this.studentName,
    required this.unpaidPeriodRangeText,
    required this.unpaidPeriodsCount,
    required this.duesRate,
    required this.totalArrearsAmount,
    this.studentId,
    this.rateDescription = '',
    this.unpaidPeriods = const [],
  });

  String get formattedRate => CurrencyFormatter.format(duesRate);
  String get formattedTotalArrears => CurrencyFormatter.format(totalArrearsAmount);

  @override
  String toString() {
    return 'StudentArrearsReportItem(no: $studentNumber, name: $studentName, '
        'range: $unpaidPeriodRangeText, unpaid: $unpaidPeriodsCount, '
        'rate: $duesRate, total: $totalArrearsAmount)';
  }
}

/// Ringkasan agregat audit tunggakan kas kelas.
class DuesArrearsSummary {
  final List<StudentArrearsReportItem> arrearsItems;
  final int totalArrearsAmount;
  final int totalStudentsWithArrears;
  final int totalEffectivePeriods;

  const DuesArrearsSummary({
    required this.arrearsItems,
    required this.totalArrearsAmount,
    required this.totalStudentsWithArrears,
    required this.totalEffectivePeriods,
  });

  String get formattedTotalArrears => CurrencyFormatter.format(totalArrearsAmount);
}

/// Domain engine untuk perhitungan tunggakan kas siswa (Dues Arrears).
///
/// Mengimplementasikan aturan bisnis:
/// - F11: Pengecualian akhir pekan (Sabtu & Minggu bebas kas harian).
/// - F12: Pengenalan hari libur berbasis aktivitas (0 pembayaran di hari kerja = libur bebas kas).
/// - F13: Hanya berlaku untuk kas harian siswa; kas umum kelas tetap 100% bebas kapan saja.
/// - Pengelompokan rentang tanggal menunggak berturut-turut ("Dari 14 Juli s.d. 18 Juli 2026").
class DuesArrearsService {
  const DuesArrearsService();

  static const List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  static String _monthName(int month) {
    if (month >= 1 && month <= 12) return _monthNames[month - 1];
    return '';
  }

  /// Mengekstrak tanggal kalender dari DuesPeriod (mengutamakan label, fallback ke dueDate).
  static DateTime extractPeriodDate(DuesPeriod period) {
    final parsed = DateFormatter.tryParsePeriodDate(period.periodLabel, fallbackDueDate: period.dueDate);
    final raw = parsed ?? period.dueDate;
    return DateTime(raw.year, raw.month, raw.day);
  }

  /// Memeriksa apakah suatu periode kas harian jatuh pada akhir pekan (Sabtu/Minggu).
  static bool isWeekendPeriod(DuesPeriod period) {
    final date = extractPeriodDate(period);
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// Memeriksa apakah suatu periode hari kerja (Senin s.d. Jumat) otomatis diakui
  /// sebagai hari libur sekolah / tanggal merah karena tidak ada siswa yang membayar kas.
  static bool isActivityHoliday({
    required DuesPeriod period,
    required List<DuesPayment> duesPayments,
  }) {
    final periodPayments = duesPayments.where((p) => p.duesPeriodId == period.id);
    final paidCount = periodPayments.where((p) => p.isPaid || p.amountPaid > 0).length;
    return paidCount == 0;
  }

  /// Memfilter daftar periode menjadi hanya periode efektif tagihan kas.
  ///
  /// Aturan filter:
  /// - Hanya periode milik academicYear yang bersangkutan.
  /// - Jika periodType == 'daily':
  ///   - Sabtu & Minggu dieksklusi secara mutlak (F11).
  ///   - Hari kerja (Senin - Jumat) dengan 0 pembayaran dieksklusi sebagai hari libur (F12).
  ///   - Hari kerja dengan >= 1 pembayaran diakui sebagai hari kas efektif.
  /// - Jika periodType != 'daily' (weekly/monthly): semua periode aktif ditagihkan.
  List<DuesPeriod> filterEffectivePeriods({
    required AcademicYear academicYear,
    required List<DuesPeriod> duesPeriods,
    required List<DuesPayment> duesPayments,
  }) {
    final yearPeriods = duesPeriods
        .where((p) => p.academicYearId == academicYear.id)
        .toList()
      ..sort((a, b) => extractPeriodDate(a).compareTo(extractPeriodDate(b)));

    if (academicYear.duesPeriodType != 'daily') {
      return yearPeriods;
    }

    final effectivePeriods = <DuesPeriod>[];
    for (final period in yearPeriods) {
      if (isWeekendPeriod(period)) {
        // F11: Sabtu & Minggu bebas kas
        continue;
      }

      if (isActivityHoliday(period: period, duesPayments: duesPayments)) {
        // F12: Hari kerja tanpa aktivitas pembayaran = hari libur bebas kas
        continue;
      }

      effectivePeriods.add(period);
    }

    return effectivePeriods;
  }

  /// Memformat daftar periode yang belum dibayar menjadi teks rentang yang nyaman dibaca.
  ///
  /// Contoh keluaran:
  /// - Harian berturut-turut: "Dari 14 Juli s.d. 18 Juli 2026"
  /// - Harian tunggal: "14 Juli 2026"
  /// - Harian terpisah: "Dari 14 Juli s.d. 16 Juli 2026, 20 Juli 2026"
  /// - Mingguan berturut-turut: "Minggu 2 Juli s.d. Minggu 4 Juli 2026"
  /// - Mingguan tunggal: "Minggu 2 Juli 2026"
  static String formatUnpaidRange({
    required List<DuesPeriod> unpaidPeriods,
    required String periodType,
    List<DuesPeriod>? allEffectivePeriods,
  }) {
    if (unpaidPeriods.isEmpty) return '-';

    final sorted = List<DuesPeriod>.from(unpaidPeriods)
      ..sort((a, b) => extractPeriodDate(a).compareTo(extractPeriodDate(b)));

    // Kelompokkan periode yang berdampingan / berturut-turut
    final clusters = <List<DuesPeriod>>[];
    List<DuesPeriod> currentCluster = [];

    for (final period in sorted) {
      if (currentCluster.isEmpty) {
        currentCluster.add(period);
      } else {
        final prevPeriod = currentCluster.last;
        final prevDate = extractPeriodDate(prevPeriod);
        final currDate = extractPeriodDate(period);

        var isConsecutive = false;

        if (periodType == 'daily') {
          // 1. Tanggal kalender berurutan langsung (diff 1 hari)
          if (currDate.difference(prevDate).inDays == 1) {
            isConsecutive = true;
          }
          // 2. Berurutan antar-minggu (Jumat ke Senin, diff <= 3 hari melewati akhir pekan)
          else if (prevDate.weekday == DateTime.friday &&
              currDate.weekday == DateTime.monday &&
              currDate.difference(prevDate).inDays <= 3) {
            isConsecutive = true;
          }
          // 3. Berdampingan dalam urutan periode efektif sekolah
          else if (allEffectivePeriods != null) {
            final prevIdx = allEffectivePeriods.indexOf(prevPeriod);
            final currIdx = allEffectivePeriods.indexOf(period);
            if (prevIdx != -1 && currIdx == prevIdx + 1) {
              isConsecutive = true;
            }
          }
        } else if (periodType == 'weekly') {
          if (currDate.difference(prevDate).inDays >= 5 &&
              currDate.difference(prevDate).inDays <= 9) {
            isConsecutive = true;
          } else if (allEffectivePeriods != null) {
            final prevIdx = allEffectivePeriods.indexOf(prevPeriod);
            final currIdx = allEffectivePeriods.indexOf(period);
            if (prevIdx != -1 && currIdx == prevIdx + 1) {
              isConsecutive = true;
            }
          }
        } else {
          // Monthly
          final monthDiff = (currDate.year - prevDate.year) * 12 + (currDate.month - prevDate.month);
          if (monthDiff == 1) {
            isConsecutive = true;
          } else if (allEffectivePeriods != null) {
            final prevIdx = allEffectivePeriods.indexOf(prevPeriod);
            final currIdx = allEffectivePeriods.indexOf(period);
            if (prevIdx != -1 && currIdx == prevIdx + 1) {
              isConsecutive = true;
            }
          }
        }

        if (isConsecutive) {
          currentCluster.add(period);
        } else {
          clusters.add(currentCluster);
          currentCluster = [period];
        }
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final formattedClusters = clusters.map((cluster) {
      if (cluster.length == 1) {
        final p = cluster.first;
        if (periodType == 'daily') {
          final d = extractPeriodDate(p);
          return '${d.day} ${_monthName(d.month)} ${d.year}';
        }
        return p.periodLabel;
      }

      final startPeriod = cluster.first;
      final endPeriod = cluster.last;
      final startDate = extractPeriodDate(startPeriod);
      final endDate = extractPeriodDate(endPeriod);

      if (periodType == 'daily') {
        if (startDate.year == endDate.year) {
          if (startDate.month == endDate.month) {
            return 'Dari ${startDate.day} ${_monthName(startDate.month)} s.d. ${endDate.day} ${_monthName(endDate.month)} ${endDate.year}';
          }
          return 'Dari ${startDate.day} ${_monthName(startDate.month)} s.d. ${endDate.day} ${_monthName(endDate.month)} ${endDate.year}';
        }
        return 'Dari ${startDate.day} ${_monthName(startDate.month)} ${startDate.year} s.d. ${endDate.day} ${_monthName(endDate.month)} ${endDate.year}';
      }

      // Weekly atau Monthly: contoh "Minggu 2 Juli s.d. Minggu 4 Juli 2026"
      final startLabelClean = _stripYear(startPeriod.periodLabel);
      if (startDate.year == endDate.year) {
        return '$startLabelClean s.d. ${endPeriod.periodLabel}';
      }
      return '${startPeriod.periodLabel} s.d. ${endPeriod.periodLabel}';
    }).toList();

    return formattedClusters.join(', ');
  }

  static String _stripYear(String label) {
    return label.replaceFirst(RegExp(r'\s+\d{4}$'), '').trim();
  }

  /// Menghitung rincian tunggakan untuk setiap siswa aktif.
  ///
  /// Hanya mengembalikan siswa yang memiliki total tunggakan > 0.
  /// Diurutkan berdasarkan nomor absen siswa.
  List<StudentArrearsReportItem> calculateArrears({
    required List<Student> students,
    required AcademicYear academicYear,
    required List<DuesPeriod> duesPeriods,
    required List<DuesPayment> duesPayments,
  }) {
    final effectivePeriods = filterEffectivePeriods(
      academicYear: academicYear,
      duesPeriods: duesPeriods,
      duesPayments: duesPayments,
    );

    if (effectivePeriods.isEmpty) {
      return [];
    }

    final activeStudents = students
        .where((s) => s.status == 'active')
        .toList()
      ..sort((a, b) => a.attendanceNumber.compareTo(b.attendanceNumber));

    final rate = academicYear.defaultDuesAmount > 0
        ? academicYear.defaultDuesAmount
        : (effectivePeriods.isNotEmpty ? effectivePeriods.first.targetAmount : 0);

    String rateDesc;
    switch (academicYear.duesPeriodType.toLowerCase()) {
      case 'daily':
        rateDesc = '${CurrencyFormatter.format(rate)} / hari';
        break;
      case 'weekly':
        rateDesc = '${CurrencyFormatter.format(rate)} / minggu';
        break;
      case 'monthly':
        rateDesc = '${CurrencyFormatter.format(rate)} / bulan';
        break;
      default:
        rateDesc = CurrencyFormatter.format(rate);
    }

    final result = <StudentArrearsReportItem>[];

    for (final student in activeStudents) {
      final unpaidPeriods = <DuesPeriod>[];

      for (final period in effectivePeriods) {
        final payment = duesPayments.where((p) {
          return p.duesPeriodId == period.id && p.studentId == student.id;
        }).firstOrNull;

        final isPaid = payment != null &&
            (payment.isPaid || (period.targetAmount > 0 && payment.amountPaid >= period.targetAmount));

        if (!isPaid) {
          unpaidPeriods.add(period);
        }
      }

      if (unpaidPeriods.isEmpty) {
        continue;
      }

      final unpaidCount = unpaidPeriods.length;
      final totalArrears = unpaidCount * rate;

      final rangeText = formatUnpaidRange(
        unpaidPeriods: unpaidPeriods,
        periodType: academicYear.duesPeriodType,
        allEffectivePeriods: effectivePeriods,
      );

      result.add(
        StudentArrearsReportItem(
          studentId: student.id,
          studentNumber: student.attendanceNumber,
          studentName: student.name,
          unpaidPeriodRangeText: rangeText,
          unpaidPeriodsCount: unpaidCount,
          duesRate: rate,
          totalArrearsAmount: totalArrears,
          rateDescription: rateDesc,
          unpaidPeriods: unpaidPeriods,
        ),
      );
    }

    return result;
  }

  /// Menghitung ringkasan tunggakan lengkap (daftar item + total agregat kelas).
  DuesArrearsSummary calculateArrearsSummary({
    required List<Student> students,
    required AcademicYear academicYear,
    required List<DuesPeriod> duesPeriods,
    required List<DuesPayment> duesPayments,
  }) {
    final items = calculateArrears(
      students: students,
      academicYear: academicYear,
      duesPeriods: duesPeriods,
      duesPayments: duesPayments,
    );

    final totalAmount = items.fold<int>(0, (sum, item) => sum + item.totalArrearsAmount);
    final effectivePeriods = filterEffectivePeriods(
      academicYear: academicYear,
      duesPeriods: duesPeriods,
      duesPayments: duesPayments,
    );

    return DuesArrearsSummary(
      arrearsItems: items,
      totalArrearsAmount: totalAmount,
      totalStudentsWithArrears: items.length,
      totalEffectivePeriods: effectivePeriods.length,
    );
  }
}
