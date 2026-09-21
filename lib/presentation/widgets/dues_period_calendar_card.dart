import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';
import '../providers/app_providers.dart';

class DuesPeriodCalendarCard extends ConsumerStatefulWidget {
  final DuesPeriod period;
  final AcademicYear activeYear;
  final VoidCallback? onPeriodChanged;

  const DuesPeriodCalendarCard({
    super.key,
    required this.period,
    required this.activeYear,
    this.onPeriodChanged,
  });

  @override
  ConsumerState<DuesPeriodCalendarCard> createState() => _DuesPeriodCalendarCardState();
}

class _DuesPeriodCalendarCardState extends ConsumerState<DuesPeriodCalendarCard> {
  late DateTime _viewMonth;
  late int _viewYear;
  bool _isExpanded = true;

  static const List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  static const List<String> _shortMonthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month, 1);
    _viewYear = now.year;
  }

  void _previousMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
    });
  }

  void _previousYear() {
    setState(() {
      _viewYear -= 1;
    });
  }

  void _nextYear() {
    setState(() {
      _viewYear += 1;
    });
  }

  void _goToCurrentMonthOrYear() {
    final now = DateTime.now();
    setState(() {
      _viewMonth = DateTime(now.year, now.month, 1);
      _viewYear = now.year;
    });
    ref.read(selectedPeriodDateProvider.notifier).resetToToday();
    ref.read(periodOffsetProvider.notifier).reset();
    widget.onPeriodChanged?.call();
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  void _handlePreviousPeriod() {
    final customDate = ref.read(selectedPeriodDateProvider);
    final periodType = widget.activeYear.duesPeriodType;

    if (customDate != null) {
      DateTime newDate;
      switch (periodType) {
        case 'daily':
          newDate = DateTime(customDate.year, customDate.month, customDate.day - 1);
          break;
        case 'monthly':
          newDate = DateTime(customDate.year, customDate.month - 1, 1);
          break;
        case 'weekly':
        default:
          newDate = DateTime(customDate.year, customDate.month, customDate.day - 7);
          break;
      }
      ref.read(selectedPeriodDateProvider.notifier).selectDate(newDate);
      setState(() {
        _viewMonth = DateTime(newDate.year, newDate.month, 1);
        _viewYear = newDate.year;
      });
    } else {
      ref.read(periodOffsetProvider.notifier).previous();
    }
    widget.onPeriodChanged?.call();
  }

  void _handleNextPeriod() {
    final customDate = ref.read(selectedPeriodDateProvider);
    final periodType = widget.activeYear.duesPeriodType;

    if (customDate != null) {
      DateTime newDate;
      switch (periodType) {
        case 'daily':
          newDate = DateTime(customDate.year, customDate.month, customDate.day + 1);
          break;
        case 'monthly':
          newDate = DateTime(customDate.year, customDate.month + 1, 1);
          break;
        case 'weekly':
        default:
          newDate = DateTime(customDate.year, customDate.month, customDate.day + 7);
          break;
      }
      ref.read(selectedPeriodDateProvider.notifier).selectDate(newDate);
      setState(() {
        _viewMonth = DateTime(newDate.year, newDate.month, 1);
        _viewYear = newDate.year;
      });
    } else {
      ref.read(periodOffsetProvider.notifier).next();
    }
    widget.onPeriodChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final customDate = ref.watch(selectedPeriodDateProvider);
    final offset = ref.watch(periodOffsetProvider);
    final isOverridingDate = customDate != null || offset != 0;

    // Hitung tanggal yang saat ini sedang aktif ditampilkan
    DateTime activeDate;
    if (customDate != null) {
      activeDate = customDate;
    } else {
      switch (widget.activeYear.duesPeriodType) {
        case 'daily':
          activeDate = DateTime(now.year, now.month, now.day + offset);
          break;
        case 'monthly':
          activeDate = DateTime(now.year, now.month + offset, 1);
          break;
        case 'weekly':
        default:
          activeDate = DateTime(now.year, now.month, now.day + (offset * 7));
          break;
      }
    }

    final periodType = widget.activeYear.duesPeriodType;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Utama: Navigasi Panah Cepat + Periode Aktif + Toggle Kalender
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  tooltip: 'Periode Sebelumnya',
                  onPressed: _handlePreviousPeriod,
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  periodType == 'daily'
                                      ? 'KALENDER KAS HARIAN'
                                      : periodType == 'monthly'
                                          ? 'KALENDER KAS BULANAN'
                                          : 'KALENDER KAS MINGGUAN',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isOverridingDate) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.incomeBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    periodType == 'daily'
                                        ? 'Otomatis Hari Ini'
                                        : periodType == 'monthly'
                                            ? 'Otomatis Bulan Ini'
                                            : 'Otomatis Minggu Ini',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.incomeText,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.period.periodLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.brandPrimaryDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.brandPrimary,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 28),
                  tooltip: 'Periode Berikutnya',
                  onPressed: _handleNextPeriod,
                ),
              ],
            ),
          ),

          // 2. Konten Kalender yang Dapat Ditampilkan / Diciutkan
          if (_isExpanded) ...[
            const Divider(height: 1, color: AppColors.borderSubtle),

            // Kalender Khusus sesuai Mode Frekuensi
            if (periodType == 'daily')
              _buildDailyCalendar(activeDate, now)
            else if (periodType == 'monthly')
              _buildMonthlyCalendar(activeDate, now)
            else
              _buildWeeklyCalendar(activeDate, now),
          ],

          // 3. Tombol Pintas Kembali ke Hari/Minggu/Bulan Ini jika sedang melihat periode lain
          if (isOverridingDate) ...[
            const Divider(height: 1, color: AppColors.borderSubtle),
            InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              onTap: _goToCurrentMonthOrYear,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_rounded, size: 14, color: AppColors.brandPrimary),
                    const SizedBox(width: 6),
                    Text(
                      periodType == 'daily'
                          ? 'Ketuk untuk kembali ke Hari Ini (${now.day} ${_monthNames[now.month - 1]})'
                          : periodType == 'monthly'
                              ? 'Ketuk untuk kembali ke Bulan Ini (${_monthNames[now.month - 1]})'
                              : 'Ketuk untuk kembali ke Minggu Berjalan Ini',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                'Target kas: ${CurrencyFormatter.format(widget.period.targetAmount)}/siswa',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // A. KALENDER MODE HARIAN (FULL 1 BULAN)
  // ==========================================
  Widget _buildDailyCalendar(DateTime activeDate, DateTime now) {
    final year = _viewMonth.year;
    final month = _viewMonth.month;
    final totalDays = _daysInMonth(year, month);
    // Hari pertama dalam bulan: 1 = Senin, 7 = Minggu
    final firstWeekday = DateTime(year, month, 1).weekday; // 1 (Mon) to 7 (Sun)
    final leadingEmpty = firstWeekday - 1;

    final isViewingCurrentMonth = (year == now.year && month == now.month);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Sub-header Navigasi Bulan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Bulan Sebelumnya',
                onPressed: _previousMonth,
              ),
              Row(
                children: [
                  Text(
                    '${_monthNames[month - 1]} $year',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (isViewingCurrentMonth) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.incomeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Bulan Ini',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.incomeText),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        setState(() {
                          _viewMonth = DateTime(now.year, now.month, 1);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.today_rounded, size: 11, color: AppColors.brandPrimary),
                            SizedBox(width: 3),
                            Text(
                              'Ke Bulan Sekarang',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.brandPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Bulan Berikutnya',
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Header Hari (Sen - Min)
          Row(
            children: const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (d == 'Min' || d == 'Sab') ? AppColors.expenseText : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),

          // Grid Tanggal
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmpty + totalDays,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmpty) {
                return const SizedBox.shrink();
              }

              final day = index - leadingEmpty + 1;
              final cellDate = DateTime(year, month, day);
              final isToday = (year == now.year && month == now.month && day == now.day);
              final isSelected = (year == activeDate.year && month == activeDate.month && day == activeDate.day);

              Color bgColor = Colors.transparent;
              Color textColor = AppColors.textPrimary;
              FontWeight fontWeight = FontWeight.w500;
              Border? border;

              if (isSelected) {
                bgColor = AppColors.brandPrimary;
                textColor = Colors.white;
                fontWeight = FontWeight.w800;
              } else if (isToday) {
                border = Border.all(color: AppColors.brandPrimary, width: 1.5);
                fontWeight = FontWeight.w700;
              }

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  ref.read(selectedPeriodDateProvider.notifier).selectDate(cellDate);
                  widget.onPeriodChanged?.call();
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: border,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: fontWeight,
                          color: textColor,
                        ),
                      ),
                      if (isToday && !isSelected)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: const BoxDecoration(
                            color: AppColors.brandPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // B. KALENDER MODE MINGGUAN (MINGGU 1 - 4/5)
  // ==========================================
  Widget _buildWeeklyCalendar(DateTime activeDate, DateTime now) {
    final year = _viewMonth.year;
    final month = _viewMonth.month;
    final totalDays = _daysInMonth(year, month);
    final totalWeeks = ((totalDays - 1) ~/ 7) + 1;

    final isViewingCurrentMonth = (year == now.year && month == now.month);
    final currentRunningWeek = ((now.day - 1) ~/ 7) + 1;
    final activeSelectedWeek = ((activeDate.day - 1) ~/ 7) + 1;
    final isSelectedInThisMonth = (year == activeDate.year && month == activeDate.month);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Sub-header Navigasi Bulan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Bulan Sebelumnya',
                onPressed: _previousMonth,
              ),
              Row(
                children: [
                  Text(
                    '${_monthNames[month - 1]} $year',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (isViewingCurrentMonth) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.incomeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Bulan Ini',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.incomeText),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        setState(() {
                          _viewMonth = DateTime(now.year, now.month, 1);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.today_rounded, size: 11, color: AppColors.brandPrimary),
                            SizedBox(width: 3),
                            Text(
                              'Ke Bulan Sekarang',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.brandPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Bulan Berikutnya',
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Daftar Kartu Minggu 1 s/d Minggu 4/5
          Column(
            children: List.generate(totalWeeks, (wIndex) {
              final weekNum = wIndex + 1;
              final startDay = (wIndex * 7) + 1;
              final endDay = (startDay + 6 > totalDays) ? totalDays : startDay + 6;

              final isThisWeek = isViewingCurrentMonth && (weekNum == currentRunningWeek);
              final isSelected = isSelectedInThisMonth && (weekNum == activeSelectedWeek);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    final targetDate = DateTime(year, month, startDay);
                    ref.read(selectedPeriodDateProvider.notifier).selectDate(targetDate);
                    widget.onPeriodChanged?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.brandPrimary : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : isThisWeek
                                ? AppColors.brandPrimary
                                : AppColors.borderSubtle,
                        width: isSelected || isThisWeek ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event_note_rounded,
                              size: 18,
                              color: isSelected ? Colors.white : AppColors.brandPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Minggu $weekNum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '($startDay–$endDay ${_shortMonthNames[month - 1]})',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (isThisWeek)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.incomeBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Minggu Ini',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppColors.incomeText,
                              ),
                            ),
                          )
                        else if (isSelected)
                          const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // C. KALENDER MODE BULANAN (12 BULAN JAN - DES)
  // ==========================================
  Widget _buildMonthlyCalendar(DateTime activeDate, DateTime now) {
    final year = _viewYear;
    final isViewingCurrentYear = (year == now.year);
    final activeSelectedMonth = activeDate.month;
    final isSelectedInThisYear = (year == activeDate.year);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Sub-header Navigasi Tahun
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Tahun Sebelumnya',
                onPressed: _previousYear,
              ),
              Row(
                children: [
                  Text(
                    'Tahun $year',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (isViewingCurrentYear) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.incomeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Tahun Ini',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.incomeText),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        setState(() {
                          _viewYear = now.year;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.today_rounded, size: 11, color: AppColors.brandPrimary),
                            SizedBox(width: 3),
                            Text(
                              'Ke Tahun Sekarang',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.brandPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Tahun Berikutnya',
                onPressed: _nextYear,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Grid 12 Bulan (4 baris x 3 kolom)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.6,
            ),
            itemBuilder: (context, mIndex) {
              final month = mIndex + 1;
              final isCurrentMonth = isViewingCurrentYear && (month == now.month);
              final isSelected = isSelectedInThisYear && (month == activeSelectedMonth);

              Color bgColor = Colors.white;
              Color textColor = AppColors.textPrimary;
              FontWeight fontWeight = FontWeight.w600;
              Border border = Border.all(color: AppColors.borderSubtle);

              if (isSelected) {
                bgColor = AppColors.brandPrimary;
                textColor = Colors.white;
                fontWeight = FontWeight.w800;
                border = Border.all(color: AppColors.brandPrimary);
              } else if (isCurrentMonth) {
                border = Border.all(color: AppColors.brandPrimary, width: 1.5);
                fontWeight = FontWeight.w700;
              }

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  final targetDate = DateTime(year, month, 1);
                  ref.read(selectedPeriodDateProvider.notifier).selectDate(targetDate);
                  widget.onPeriodChanged?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: border,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _monthNames[mIndex],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: fontWeight,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isCurrentMonth) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Bulan Ini',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppColors.incomeText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
