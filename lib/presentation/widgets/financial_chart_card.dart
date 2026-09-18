import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/transaction_repository.dart';
import '../providers/app_providers.dart';

class FinancialChartCard extends StatefulWidget {
  final List<TransactionWithCategory> items;
  final ReportDateRange selectedRange;

  const FinancialChartCard({
    super.key,
    required this.items,
    required this.selectedRange,
  });

  @override
  State<FinancialChartCard> createState() => _FinancialChartCardState();
}

class _FinancialChartCardState extends State<FinancialChartCard> {
  int _chartMode = 0; // 0: Tren Arus Kas, 1: Komposisi Kategori
  int _categoryTabMode = 0; // 0: Pengeluaran, 1: Pemasukan
  int? _selectedBucketIndex;

  @override
  void didUpdateWidget(covariant FinancialChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRange != widget.selectedRange ||
        oldWidget.items.length != widget.items.length) {
      _selectedBucketIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalIncome = 0;
    int totalExpense = 0;
    for (final it in widget.items) {
      if (it.transaction.type == 'income') {
        totalIncome += it.transaction.amount;
      } else {
        totalExpense += it.transaction.amount;
      }
    }
    final netCashFlow = totalIncome - totalExpense;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Mode Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: AppColors.brandPrimary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Grafik Analisis Keuangan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.slateTag,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildToggleChip('Tren', 0),
                    _buildToggleChip('Kategori', 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (widget.items.isEmpty)
            _buildEmptyState()
          else if (_chartMode == 0)
            _buildTrendBarChart(netCashFlow)
          else
            _buildCategoryComposition(totalIncome, totalExpense),
        ],
      ),
    );
  }

  Widget _buildToggleChip(String label, int mode) {
    final isSelected = _chartMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _chartMode = mode;
        _selectedBucketIndex = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.brandPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.insights_rounded, size: 36, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text(
            'Belum ada data riwayat transaksi untuk divisualisasikan.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBarChart(int netCashFlow) {
    final buckets = _groupTransactionsIntoBuckets();
    int maxAmount = 1;
    for (final b in buckets) {
      maxAmount = max(maxAmount, max(b.income, b.expense));
    }

    final selectedBucket = (_selectedBucketIndex != null &&
            _selectedBucketIndex! >= 0 &&
            _selectedBucketIndex! < buckets.length)
        ? buckets[_selectedBucketIndex!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend & Selection Tooltip
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildLegendItem('Pemasukan', AppColors.brandPrimary),
                const SizedBox(width: 12),
                _buildLegendItem('Pengeluaran', AppColors.expenseText),
              ],
            ),
            if (selectedBucket != null)
              Text(
                selectedBucket.label,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Selected Bucket Popup Detail if any
        if (selectedBucket != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.brandPrimaryLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${selectedBucket.label}:',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    Text(
                      '+${CurrencyFormatter.format(selectedBucket.income)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.incomeText,
                      ),
                    ),
                    const Text('  vs  ', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    Text(
                      '-${CurrencyFormatter.format(selectedBucket.expense)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.expenseText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Bars Container
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(buckets.length, (idx) {
              final b = buckets[idx];
              final isSelected = _selectedBucketIndex == idx;
              final incomeRatio = (b.income / maxAmount).clamp(0.0, 1.0);
              final expenseRatio = (b.expense / maxAmount).clamp(0.0, 1.0);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBucketIndex = (_selectedBucketIndex == idx) ? null : idx;
                    });
                  },
                  child: Container(
                    color: isSelected
                        ? AppColors.brandPrimaryLight.withValues(alpha: 0.3)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Bar Pemasukan
                              Flexible(
                                child: Container(
                                  height: max(4.0, 100 * incomeRatio),
                                  decoration: BoxDecoration(
                                    color: b.income > 0 ? AppColors.brandPrimary : AppColors.borderSubtle,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              // Bar Pengeluaran
                              Flexible(
                                child: Container(
                                  height: max(4.0, 100 * expenseRatio),
                                  decoration: BoxDecoration(
                                    color: b.expense > 0 ? AppColors.expenseText : AppColors.borderSubtle,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          b.label,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.brandPrimaryDark : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const Divider(height: 20, color: AppColors.borderSubtle),

        // Net Cashflow Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Arus Kas Bersih Periode Ini',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: netCashFlow >= 0 ? AppColors.incomeBg : AppColors.expenseBgSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${netCashFlow >= 0 ? '+' : ''}${CurrencyFormatter.format(netCashFlow)} (${netCashFlow >= 0 ? 'Surplus' : 'Defisit'})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: netCashFlow >= 0 ? AppColors.incomeText : AppColors.expenseText,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryComposition(int totalIncome, int totalExpense) {
    final expenseByCat = <String, int>{};
    final incomeByCat = <String, int>{};

    for (final it in widget.items) {
      if (it.transaction.type == 'expense') {
        expenseByCat[it.category.name] = (expenseByCat[it.category.name] ?? 0) + it.transaction.amount;
      } else {
        incomeByCat[it.category.name] = (incomeByCat[it.category.name] ?? 0) + it.transaction.amount;
      }
    }

    final isExpenseMode = _categoryTabMode == 0;
    final currentMap = isExpenseMode ? expenseByCat : incomeByCat;
    final currentTotal = isExpenseMode ? totalExpense : totalIncome;
    final currentThemeColor = isExpenseMode ? AppColors.expenseText : AppColors.brandPrimary;

    final sortedEntries = currentMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-toggle Pengeluaran / Pemasukan
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isExpenseMode ? 'Alokasi Pengeluaran' : 'Sumber Pemasukan',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.slateTag,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _categoryTabMode = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _categoryTabMode == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Keluar',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: _categoryTabMode == 0 ? FontWeight.w700 : FontWeight.w500,
                          color: _categoryTabMode == 0 ? AppColors.expenseText : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _categoryTabMode = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _categoryTabMode == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Masuk',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: _categoryTabMode == 1 ? FontWeight.w700 : FontWeight.w500,
                          color: _categoryTabMode == 1 ? AppColors.brandPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (currentMap.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text(
              'Tidak ada transaksi ${isExpenseMode ? 'pengeluaran' : 'pemasukan'} pada periode ini.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          )
        else
          ...sortedEntries.map((e) {
            final percentage = currentTotal > 0 ? (e.value / currentTotal * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${CurrencyFormatter.format(e.value)} (${percentage.toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: currentThemeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (percentage / 100).clamp(0.0, 1.0),
                      backgroundColor: AppColors.slateTag,
                      color: currentThemeColor,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  List<_ChartBucket> _groupTransactionsIntoBuckets() {
    if (widget.items.isEmpty) return [];

    final now = DateTime.now();
    DateTime maxTxDate = widget.items.first.transaction.transactionDate;
    DateTime minTxDate = widget.items.first.transaction.transactionDate;
    for (final it in widget.items) {
      final dt = it.transaction.transactionDate;
      if (dt.isAfter(maxTxDate)) maxTxDate = dt;
      if (dt.isBefore(minTxDate)) minTxDate = dt;
    }

    // Jika seluruh transaksi adalah data historis (misal tahun lalu), gunakan tanggal transaksi terbaru sebagai acuan
    final refDate = (maxTxDate.isBefore(now.subtract(const Duration(days: 60))))
        ? DateTime(maxTxDate.year, maxTxDate.month, maxTxDate.day, 23, 59, 59)
        : now;

    final buckets = <_ChartBucket>[];
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

    switch (widget.selectedRange) {
      case ReportDateRange.oneMonth:
        // Bagi bulan berjalan menjadi 4 interval mingguan berbasis kalender yang sinkron dengan penomoran minggu aplikasi:
        // Mgg 1: tgl 1 - 7
        // Mgg 2: tgl 8 - 14
        // Mgg 3: tgl 15 - 21
        // Mgg 4: tgl 22 - akhir bulan
        final daysInMonth = DateTime(refDate.year, refDate.month + 1, 0).day;
        final weekIntervals = [
          (1, 7, 'Mgg 1'),
          (8, 14, 'Mgg 2'),
          (15, 21, 'Mgg 3'),
          (22, daysInMonth, 'Mgg 4'),
        ];

        final monthStart = DateTime(refDate.year, refDate.month, 1, 0, 0, 0);
        final monthEnd = DateTime(refDate.year, refDate.month, daysInMonth, 23, 59, 59);

        for (var i = 0; i < weekIntervals.length; i++) {
          final interval = weekIntervals[i];
          final label = interval.$3;

          var inc = 0;
          var exp = 0;
          for (final it in widget.items) {
            final dt = it.transaction.transactionDate;
            final isSameMonth = dt.year == refDate.year && dt.month == refDate.month;
            
            bool inRange = false;
            if (isSameMonth) {
              final weekIndex = ((dt.day - 1) ~/ 7);
              final safeWeekIndex = weekIndex >= 3 ? 3 : weekIndex;
              inRange = (safeWeekIndex == i);
            } else if (i == 0 && dt.isBefore(monthStart)) {
              // Transaksi sebelum bulan ini jika ada dalam rentang 30 hari dimasukkan ke bucket pertama
              inRange = true;
            } else if (i == 3 && dt.isAfter(monthEnd)) {
              inRange = true;
            }

            if (inRange) {
              if (it.transaction.type == 'income') {
                inc += it.transaction.amount;
              } else {
                exp += it.transaction.amount;
              }
            }
          }
          buckets.add(_ChartBucket(label: label, income: inc, expense: exp));
        }
        break;

      case ReportDateRange.threeMonths:
        for (var i = 2; i >= 0; i--) {
          final mDate = DateTime(refDate.year, refDate.month - i, 1);
          final nextMDate = DateTime(refDate.year, refDate.month - i + 1, 1);
          final label = monthNames[(mDate.month - 1) % 12];
          var inc = 0;
          var exp = 0;
          for (final it in widget.items) {
            final dt = it.transaction.transactionDate;
            // Jika bucket tertua (i == 2), sertakan semua transaksi sebelum nextMDate
            final matches = (i == 2)
                ? dt.isBefore(nextMDate)
                : (!dt.isBefore(mDate) && dt.isBefore(nextMDate));
            if (matches) {
              if (it.transaction.type == 'income') {
                inc += it.transaction.amount;
              } else {
                exp += it.transaction.amount;
              }
            }
          }
          buckets.add(_ChartBucket(label: label, income: inc, expense: exp));
        }
        break;

      case ReportDateRange.oneYear:
        const count = 6;
        for (var i = count - 1; i >= 0; i--) {
          final mDate = DateTime(refDate.year, refDate.month - (i * 2), 1);
          final nextMDate = DateTime(refDate.year, refDate.month - (i * 2) + 2, 1);
          final startName = monthNames[(mDate.month - 1) % 12];
          final endName = monthNames[(nextMDate.month - 2 + 12) % 12];
          final label = '$startName-$endName';
          var inc = 0;
          var exp = 0;
          for (final it in widget.items) {
            final dt = it.transaction.transactionDate;
            final matches = (i == count - 1)
                ? dt.isBefore(nextMDate)
                : (!dt.isBefore(mDate) && dt.isBefore(nextMDate));
            if (matches) {
              if (it.transaction.type == 'income') {
                inc += it.transaction.amount;
              } else {
                exp += it.transaction.amount;
              }
            }
          }
          buckets.add(_ChartBucket(label: label, income: inc, expense: exp));
        }
        break;

      case ReportDateRange.allTime:
        // Bagi seluruh rentang waktu transaksi yang ada menjadi 4-6 bucket interval
        final spanStart = DateTime(minTxDate.year, minTxDate.month, minTxDate.day);
        final spanEnd = DateTime(maxTxDate.year, maxTxDate.month, maxTxDate.day, 23, 59, 59);
        final totalSpanMs = max(spanEnd.difference(spanStart).inMilliseconds, 1);
        final bucketCount = min(6, max(3, widget.items.length > 5 ? 5 : 3));
        final bucketMs = (totalSpanMs / bucketCount).round();

        for (var i = 0; i < bucketCount; i++) {
          final bStart = spanStart.add(Duration(milliseconds: i * bucketMs));
          final bEnd = (i == bucketCount - 1)
              ? spanEnd.add(const Duration(seconds: 1))
              : spanStart.add(Duration(milliseconds: (i + 1) * bucketMs));

          final label = (bStart.year != bEnd.year)
              ? '${bStart.year}'
              : '${monthNames[(bStart.month - 1) % 12]} \'${bStart.year.toString().substring(2)}';

          var inc = 0;
          var exp = 0;
          for (final it in widget.items) {
            final dt = it.transaction.transactionDate;
            final inRange = (dt.isAfter(bStart.subtract(const Duration(seconds: 1))) || dt.isAtSameMomentAs(bStart)) &&
                dt.isBefore(bEnd);
            if (inRange) {
              if (it.transaction.type == 'income') {
                inc += it.transaction.amount;
              } else {
                exp += it.transaction.amount;
              }
            }
          }
          buckets.add(_ChartBucket(label: label, income: inc, expense: exp));
        }
        break;
    }

    return buckets;
  }
}

class _ChartBucket {
  final String label;
  final int income;
  final int expense;

  _ChartBucket({
    required this.label,
    required this.income,
    required this.expense,
  });
}
