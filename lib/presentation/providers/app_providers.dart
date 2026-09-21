import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/academic_year_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/dues_repository.dart';

// Database & Repositories
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final academicYearRepoProvider = Provider<AcademicYearRepository>((ref) {
  return AcademicYearRepository(ref.watch(databaseProvider));
});

final studentRepoProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(ref.watch(databaseProvider));
});

final transactionRepoProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
});

final duesRepoProvider = Provider<DuesRepository>((ref) {
  return DuesRepository(ref.watch(databaseProvider));
});

// Active Academic Year
final activeAcademicYearProvider = StreamProvider<AcademicYear?>((ref) {
  return ref.watch(academicYearRepoProvider).watchActiveYear();
});

final allAcademicYearsProvider = StreamProvider<List<AcademicYear>>((ref) {
  return ref.watch(academicYearRepoProvider).watchAllYears();
});

// Categories Stream Provider by Type ('income' or 'expense')
final categoriesStreamProvider = StreamProvider.family<List<Category>, String>((ref, type) {
  return ref.watch(transactionRepoProvider).watchCategoriesByType(type);
});

// Balance Statistics (Dashboard)
final balanceStatsProvider = StreamProvider<BalanceStats>((ref) {
  final activeYear = ref.watch(activeAcademicYearProvider).value;
  if (activeYear == null) {
    return Stream.value(const BalanceStats(
      totalBalance: 0,
      monthlyIncome: 0,
      monthlyExpense: 0,
    ));
  }
  return ref.watch(transactionRepoProvider).watchBalanceStats(activeYear.id);
});

// 5 Recent Transactions (Dashboard)
final recentTransactionsProvider = StreamProvider<List<TransactionWithCategory>>((ref) {
  final activeYear = ref.watch(activeAcademicYearProvider).value;
  if (activeYear == null) {
    return Stream.value([]);
  }
  return ref.watch(transactionRepoProvider).watchRecentTransactions(academicYearId: activeYear.id, limit: 5);
});

// All Transactions (AllTransactionsScreen)
final allTransactionsProvider = StreamProvider<List<TransactionWithCategory>>((ref) {
  final activeYear = ref.watch(activeAcademicYearProvider).value;
  if (activeYear == null) return Stream.value([]);
  return ref.watch(transactionRepoProvider).watchAllTransactions(academicYearId: activeYear.id);
});

final allTransactionsByYearProvider = StreamProvider.family<List<TransactionWithCategory>, String>((ref, yearId) {
  return ref.watch(transactionRepoProvider).watchAllTransactions(academicYearId: yearId);
});

// All Categories (Income + Expense)
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final incomeAsync = ref.watch(categoriesStreamProvider('income'));
  final expenseAsync = ref.watch(categoriesStreamProvider('expense'));
  final income = incomeAsync.value ?? [];
  final expense = expenseAsync.value ?? [];
  return Stream.value([...income, ...expense]);
});


String formatPeriodLabel(DateTime date, String periodType) {
  const monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  final currentMonth = monthNames[date.month - 1];
  switch (periodType) {
    case 'daily':
      return 'Harian ${DateFormatter.toHumanDate(date)}';
    case 'monthly':
      return 'Bulan $currentMonth ${date.year}';
    case 'weekly':
    default:
      final weekNumber = ((date.day - 1) ~/ 7) + 1;
      return 'Minggu $weekNumber $currentMonth ${date.year}';
  }
}

class PeriodOffsetNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void next() => state = state + 1;
  void previous() => state = state - 1;
  void reset() => state = 0;
}

final periodOffsetProvider =
    NotifierProvider<PeriodOffsetNotifier, int>(PeriodOffsetNotifier.new);

class SelectedPeriodDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null; // null = dynamic auto-update based on DateTime.now()

  void selectDate(DateTime date) => state = date;
  void resetToToday() => state = null;
}

final selectedPeriodDateProvider =
    NotifierProvider<SelectedPeriodDateNotifier, DateTime?>(SelectedPeriodDateNotifier.new);

// Dues: Active Period Provider
final activeDuesPeriodProvider = StreamProvider<DuesPeriod?>((ref) {
  final activeYear = ref.watch(activeAcademicYearProvider).value;
  if (activeYear == null) return Stream.value(null);

  final customSelectedDate = ref.watch(selectedPeriodDateProvider);
  final offset = ref.watch(periodOffsetProvider);

  if (customSelectedDate == null && offset == 0) {
    final currentAsync = ref.watch(currentDuesPeriodProvider);
    return currentAsync.when(
      data: (data) => Stream.value(data),
      error: (err, st) => Stream.error(err, st),
      loading: () => const Stream.empty(),
    );
  }

  final duesRepo = ref.watch(duesRepoProvider);
  final now = DateTime.now();

  late DateTime targetDate;
  if (customSelectedDate != null) {
    targetDate = customSelectedDate;
  } else {
    switch (activeYear.duesPeriodType) {
      case 'daily':
        targetDate = DateTime(now.year, now.month, now.day + offset);
        break;
      case 'monthly':
        targetDate = DateTime(now.year, now.month + offset, 1);
        break;
      case 'weekly':
      default:
        targetDate = DateTime(now.year, now.month, now.day + (offset * 7));
        break;
    }
  }

  final label = formatPeriodLabel(targetDate, activeYear.duesPeriodType);

  return duesRepo.watchActivePeriod(
    academicYearId: activeYear.id,
    periodLabel: label,
    targetAmount: activeYear.defaultDuesAmount,
    dueDate: targetDate,
  );
});

// Dues: Current Period Provider (Fixed offset 0 for Dashboard - always shows running period)
final currentDuesPeriodProvider = StreamProvider<DuesPeriod?>((ref) {
  final activeYear = ref.watch(activeAcademicYearProvider).value;
  if (activeYear == null) return Stream.value(null);

  final duesRepo = ref.watch(duesRepoProvider);
  final now = DateTime.now();
  final targetDate = DateTime(now.year, now.month, now.day);
  final label = formatPeriodLabel(targetDate, activeYear.duesPeriodType);

  return duesRepo.watchActivePeriod(
    academicYearId: activeYear.id,
    periodLabel: label,
    targetAmount: activeYear.defaultDuesAmount,
    dueDate: targetDate,
  );
});

// Dues: Current Period Summary (Always shows current period for Dashboard)
final currentPeriodSummaryProvider = StreamProvider.autoDispose<DuesPeriodSummary?>((ref) {
  final activeYear = ref.watch(activeAcademicYearProvider).value;
  final currentPeriod = ref.watch(currentDuesPeriodProvider).value;

  if (activeYear == null || currentPeriod == null) {
    return Stream.value(null);
  }

  return ref.watch(duesRepoProvider).watchPeriodSummary(
        period: currentPeriod,
        academicYearId: activeYear.id,
      );
});

// Dues: Student List Stream for Active Period
final activePeriodStudentsProvider = StreamProvider.autoDispose<List<StudentDuesItem>>((ref) {
  final activeYear = ref.watch(activeAcademicYearProvider).value;
  final activePeriod = ref.watch(activeDuesPeriodProvider).value;

  if (activeYear == null || activePeriod == null) {
    return Stream.value([]);
  }

  return ref.watch(duesRepoProvider).watchStudentDuesList(
        academicYearId: activeYear.id,
        duesPeriodId: activePeriod.id,
      );
});

// Dues: Period Summary for currently viewed period in Kas Siswa
final activePeriodSummaryProvider = StreamProvider.autoDispose<DuesPeriodSummary?>((ref) {
  final activeYear = ref.watch(activeAcademicYearProvider).value;
  final activePeriod = ref.watch(activeDuesPeriodProvider).value;

  if (activeYear == null || activePeriod == null) {
    return Stream.value(null);
  }

  return ref.watch(duesRepoProvider).watchPeriodSummary(
        period: activePeriod,
        academicYearId: activeYear.id,
      );
});

// Report Range State
enum ReportDateRange { oneMonth, threeMonths, oneYear, allTime }

class ReportRangeNotifier extends Notifier<ReportDateRange> {
  @override
  ReportDateRange build() => ReportDateRange.oneMonth;

  void setRange(ReportDateRange range) => state = range;
}

final selectedReportRangeProvider =
    NotifierProvider<ReportRangeNotifier, ReportDateRange>(ReportRangeNotifier.new);

class SelectedYearIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setYearId(String? id) => state = id;
}

final selectedReportYearIdProvider =
    NotifierProvider<SelectedYearIdNotifier, String?>(SelectedYearIdNotifier.new);

// Report Transactions Stream
final reportTransactionsProvider = StreamProvider<List<TransactionWithCategory>>((ref) {
  final range = ref.watch(selectedReportRangeProvider);
  final activeYear = ref.watch(activeAcademicYearProvider).value;
  final allYears = ref.watch(allAcademicYearsProvider).value ?? [];
  final selectedYearId = ref.watch(selectedReportYearIdProvider) ?? activeYear?.id;

  if (selectedYearId == null) {
    return Stream.value([]);
  }

  final selectedYear = allYears.firstWhere(
    (y) => y.id == selectedYearId,
    orElse: () => activeYear ?? AcademicYear(
      id: selectedYearId,
      name: 'Kelas',
      grade: 7,
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime(2030, 12, 31),
      treasurerName: 'Bendahara',
      supervisorName: 'Pengawas',
      defaultDuesAmount: 5000,
      duesPeriodType: 'weekly',
      isActive: true,
      createdAt: DateTime.now(),
    ),
  );

  final now = DateTime.now();
  late DateTime startDate;
  late DateTime endDate;

  final isCurrentActive = activeYear != null && selectedYear.id == activeYear.id;

  if (isCurrentActive) {
    endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (range) {
      case ReportDateRange.oneMonth:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case ReportDateRange.threeMonths:
        startDate = now.subtract(const Duration(days: 90));
        break;
      case ReportDateRange.oneYear:
        startDate = now.subtract(const Duration(days: 365));
        break;
      case ReportDateRange.allTime:
        startDate = selectedYear.startDate.isBefore(DateTime(2020, 1, 1))
            ? selectedYear.startDate
            : DateTime(2020, 1, 1);
        endDate = DateTime(now.year + 1, 12, 31);
        break;
    }
  } else {
    final yearEnd = selectedYear.endDate;
    endDate = DateTime(yearEnd.year, yearEnd.month, yearEnd.day, 23, 59, 59);
    switch (range) {
      case ReportDateRange.oneMonth:
        startDate = DateTime(yearEnd.year, yearEnd.month, 1);
        endDate = DateTime(yearEnd.year, yearEnd.month + 1, 0, 23, 59, 59);
        break;
      case ReportDateRange.threeMonths:
        startDate = yearEnd.subtract(const Duration(days: 90));
        break;
      case ReportDateRange.oneYear:
      case ReportDateRange.allTime:
        startDate = selectedYear.startDate;
        break;
    }
  }

  return ref.watch(transactionRepoProvider).watchTransactionsByRange(
        academicYearId: selectedYearId,
        startDate: startDate,
        endDate: endDate,
      );
});
