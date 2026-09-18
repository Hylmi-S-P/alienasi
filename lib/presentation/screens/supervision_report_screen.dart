import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';
import '../../domain/services/csv_export_service.dart';
import '../../domain/services/pdf_report_service.dart';
import '../providers/app_providers.dart';
import '../widgets/transaction_list_item.dart';
import '../widgets/financial_chart_card.dart';

class SupervisionReportScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToDashboard;

  const SupervisionReportScreen({super.key, this.onBackToDashboard});

  @override
  ConsumerState<SupervisionReportScreen> createState() => _SupervisionReportScreenState();
}

class _SupervisionReportScreenState extends ConsumerState<SupervisionReportScreen> {
  bool _isGenerating = false;

  String _getRangeTitle(ReportDateRange range, AcademicYear? year) {
    final now = DateTime.now();
    const monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final currentMonth = monthNames[now.month - 1];
    final currentWeek = ((now.day - 1) ~/ 7) + 1;

    switch (range) {
      case ReportDateRange.oneMonth:
        return 'Bulan $currentMonth ${now.year} (Minggu ke-$currentWeek)';
      case ReportDateRange.threeMonths:
        return '3 Bulan (Triwulan)';
      case ReportDateRange.oneYear:
        return '1 Tahun Penuh';
      case ReportDateRange.allTime:
        return 'Semua Rentang (Seluruh Arsip)';
    }
  }

  Future<void> _sharePdf(AcademicYear academicYear) async {
    setState(() => _isGenerating = true);
    try {
      final range = ref.read(selectedReportRangeProvider);
      final txItems = ref.read(reportTransactionsProvider).value ?? [];
      final rangeTitle = _getRangeTitle(range, academicYear);

      final pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: academicYear,
        periodRangeTitle: rangeTitle,
        items: txItems,
      );

      final safeRange = rangeTitle.replaceAll(' ', '_').replaceAll('(', '').replaceAll(')', '');
      final filename = 'Laporan_Kas_${academicYear.name.replaceAll(' ', '_')}_$safeRange.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.expenseText, content: Text('Galat membuat PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _previewPdf(AcademicYear academicYear) async {
    setState(() => _isGenerating = true);
    try {
      final range = ref.read(selectedReportRangeProvider);
      final txItems = ref.read(reportTransactionsProvider).value ?? [];
      final rangeTitle = _getRangeTitle(range, academicYear);

      final pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: academicYear,
        periodRangeTitle: rangeTitle,
        items: txItems,
      );

      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'Laporan_Kas_${academicYear.name}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.expenseText, content: Text('Galat pratinjau: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportCsv(AcademicYear academicYear) async {
    try {
      final txItems = ref.read(reportTransactionsProvider).value ?? [];
      final csvString = CsvExportService.generateCsv(academicYear: academicYear, items: txItems);

      final filename = 'Laporan_Kas_${academicYear.name.replaceAll(' ', '_')}.csv';
      await SharePlus.instance.share(ShareParams(text: csvString, subject: filename));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.expenseText, content: Text('Galat ekspor CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeYearAsync = ref.watch(activeAcademicYearProvider);
    final allYearsAsync = ref.watch(allAcademicYearsProvider);
    final activeYear = activeYearAsync.value;
    final allYears = allYearsAsync.value ?? [];
    final selectedRange = ref.watch(selectedReportRangeProvider);
    final txListAsync = ref.watch(reportTransactionsProvider);
    final selectedYearId = ref.watch(selectedReportYearIdProvider);

    if (activeYear == null) {
      return Scaffold(
        appBar: AppBar(
          leading: (Navigator.canPop(context) || widget.onBackToDashboard != null)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Kembali',
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    } else if (widget.onBackToDashboard != null) {
                      widget.onBackToDashboard!();
                    }
                  },
                )
              : null,
          title: const Text('Laporan Kas & Keuangan'),
        ),
        body: const Center(child: Text('Silakan atur kelas terlebih dahulu')),
      );
    }

    // Gabungkan and deduplikasi tahun agar DropdownButton tidak pernah crash
    final yearsMap = <String, AcademicYear>{};
    yearsMap[activeYear.id] = activeYear;
    for (final y in allYears) {
      yearsMap[y.id] = y;
    }
    final validYearsList = yearsMap.values.toList();

    final validSelectedYearId = (selectedYearId != null && validYearsList.any((y) => y.id == selectedYearId))
        ? selectedYearId
        : activeYear.id;

    // Historical Year Snapshot: Cari tahun yang dipilih jika memilih arsip tahun lalu
    final displayYear = validYearsList.firstWhere(
      (y) => y.id == validSelectedYearId,
      orElse: () => activeYear,
    );

    final txItems = txListAsync.value ?? [];
    int totalIncome = 0;
    int totalExpense = 0;
    for (final item in txItems) {
      if (item.transaction.type == 'income') {
        totalIncome += item.transaction.amount.toInt();
      } else {
        totalExpense += item.transaction.amount.toInt();
      }
    }
    final balance = totalIncome - totalExpense;

    return Scaffold(
      appBar: AppBar(
        leading: (Navigator.canPop(context) || widget.onBackToDashboard != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Kembali',
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  } else if (widget.onBackToDashboard != null) {
                    widget.onBackToDashboard!();
                  }
                },
              )
            : null,
        title: const Text('Laporan Kas & Keuangan'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Supervisi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.incomeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user_rounded, color: AppColors.incomeText, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'LAPORAN ARUS KAS',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.incomeText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pusat Laporan Kas & Ekspor',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Laporan pertanggungjawaban kas untuk ${displayYear.name} bagi orang tua murid dan sekolah.',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),

                    // Kartu Profil Tim Pengawas & Siswa
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.slateTag,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AppColors.blueLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.family_restroom_rounded, color: AppColors.brandPrimary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${displayYear.supervisorName} & ${displayYear.treasurerName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.circle, color: AppColors.incomeText, size: 8),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        'Sesi Rekonsiliasi Aktif • ${displayYear.name}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Pemilih Periode Kelas (Jika ada lebih dari 1 kelas / tahun ajaran)
              if (validYearsList.length > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Pilih Periode Kelas:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: validSelectedYearId,
                          underline: const SizedBox(),
                          alignment: AlignmentDirectional.centerEnd,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.brandPrimary),
                          items: validYearsList.map((y) {
                            return DropdownMenuItem(
                              value: y.id,
                              child: Text(
                                y.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (newId) {
                            if (newId != null) {
                              ref.read(selectedReportYearIdProvider.notifier).setYearId(newId);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 2. Bilah Filter Rentang Waktu (Filter Bar)
              const Text(
                'Pilih Rentang Laporan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRangeButton(
                      label: '1 Bulan',
                      range: ReportDateRange.oneMonth,
                      selected: selectedRange,
                    ),
                    const SizedBox(width: 8),
                    _buildRangeButton(
                      label: '3 Bulan',
                      range: ReportDateRange.threeMonths,
                      selected: selectedRange,
                    ),
                    const SizedBox(width: 8),
                    _buildRangeButton(
                      label: '1 Tahun',
                      range: ReportDateRange.oneYear,
                      selected: selectedRange,
                    ),
                    const SizedBox(width: 8),
                    _buildRangeButton(
                      label: 'Semua Rentang',
                      range: ReportDateRange.allTime,
                      selected: selectedRange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Ringkasan Audit Keuangan
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Finansial (${_getRangeTitle(selectedRange, displayYear)})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Total Masuk',
                            amount: CurrencyFormatter.format(totalIncome),
                            color: AppColors.incomeText,
                          ),
                        ),
                        Container(width: 1, height: 36, color: AppColors.borderSubtle),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Total Keluar',
                            amount: CurrencyFormatter.format(totalExpense),
                            color: AppColors.expenseText,
                          ),
                        ),
                        Container(width: 1, height: 36, color: AppColors.borderSubtle),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Sisa Saldo',
                            amount: CurrencyFormatter.format(balance),
                            color: AppColors.brandPrimaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Grafik Analisis Keuangan
              FinancialChartCard(
                items: txItems,
                selectedRange: selectedRange,
              ),
              const SizedBox(height: 16),

              // 4. Tombol Aksi Utama Ekspor
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                label: Text(
                  _isGenerating ? 'Menyusun Dokumen PDF...' : 'Bagikan Laporan PDF ke WhatsApp',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                onPressed: _isGenerating ? null : () => _sharePdf(displayYear),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('Pratinjau PDF', style: TextStyle(fontSize: 13)),
                      onPressed: _isGenerating ? null : () => _previewPdf(displayYear),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.table_chart_outlined, size: 18),
                      label: const Text('Ekspor Excel', style: TextStyle(fontSize: 13)),
                      onPressed: _isGenerating ? null : () => _exportCsv(displayYear),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 5. Daftar Transaksi pada Rentang Ini
              Text(
                'Arus Kas Tercatat (${txItems.length} Transaksi)',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),

              if (txItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Text(
                    'Tidak ada transaksi pada rentang waktu ini.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                )
              else
                ...txItems.map((item) => TransactionListItem(item: item)),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangeButton({
    required String label,
    required ReportDateRange range,
    required ReportDateRange selected,
  }) {
    final isSelected = range == selected;
    return InkWell(
      onTap: () {
        ref.read(selectedReportRangeProvider.notifier).setRange(range);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandPrimary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String amount,
    required Color color,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
