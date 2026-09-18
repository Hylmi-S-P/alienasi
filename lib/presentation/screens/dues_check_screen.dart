import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/dues_repository.dart';
import '../providers/app_providers.dart';
import 'dialogs/new_student_dialog.dart';

enum DuesFilterStatus { all, unpaid, paid }

class DuesCheckScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToDashboard;

  const DuesCheckScreen({super.key, this.onBackToDashboard});

  @override
  ConsumerState<DuesCheckScreen> createState() => _DuesCheckScreenState();
}

class _DuesCheckScreenState extends ConsumerState<DuesCheckScreen> {
  DuesFilterStatus _selectedFilter = DuesFilterStatus.all;
  bool _isReconciling = false;

  Future<void> _handleReconcile(
    DuesPeriod period,
    String academicYearId,
    int paidCount,
    int unreconciledDelta,
  ) async {
    if (unreconciledDelta <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.incomeText,
          content: Text('Semua pembayaran kas untuk periode ini sudah dicatat di Buku Kas Umum.'),
        ),
      );
      return;
    }

    final isAdditional = period.reconciledAmount > 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isAdditional ? 'Masukkan Tambahan Kas?' : 'Masukkan ke Kas Kelas?',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          isAdditional
              ? 'Tambahan kas sebesar ${CurrencyFormatter.format(unreconciledDelta)} akan dicatat sebagai Pemasukan di Buku Kas Utama.'
              : 'Total kas dari $paidCount siswa (${CurrencyFormatter.format(unreconciledDelta)}) yang sudah lunas akan secara otomatis dicatat sebagai Pemasukan di Buku Kas Utama.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              minimumSize: const Size(110, 40),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Masukkan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isReconciling = true);
    try {
      final deltaReconciled = await ref.read(duesRepoProvider).reconcileIntoGeneralCash(
            period: period,
            academicYearId: academicYearId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.brandPrimary,
            content: Text(isAdditional
                ? 'Tambahan kas ${CurrencyFormatter.format(deltaReconciled)} berhasil dicatat!'
                : 'Kas berhasil dimasukkan ke Buku Kas Umum!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.expenseText, content: Text('Galat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isReconciling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeYearAsync = ref.watch(activeAcademicYearProvider);
    final activePeriodAsync = ref.watch(activeDuesPeriodProvider);
    final studentDuesAsync = ref.watch(activePeriodStudentsProvider);
    final summaryAsync = ref.watch(activePeriodSummaryProvider);

    final activeYear = activeYearAsync.value;
    final period = activePeriodAsync.value;
    final allItems = studentDuesAsync.value ?? [];
    final summary = summaryAsync.value;

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
          title: const Text('Kas Siswa'),
        ),
        body: const Center(child: Text('Silakan pilih atau atur kelas terlebih dahulu.')),
      );
    }

    final filteredItems = allItems.where((item) {
      if (_selectedFilter == DuesFilterStatus.paid) return item.isPaid;
      if (_selectedFilter == DuesFilterStatus.unpaid) return !item.isPaid;
      return true;
    }).toList();

    final paidCount = allItems.where((i) => i.isPaid).length;
    final unpaidCount = allItems.length - paidCount;

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
        title: const Text('Kas Siswa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Tambah Siswa Baru',
            onPressed: () {
              NewStudentDialog.show(context, activeYear.id, allItems.length + 1);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: period == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary))
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        // 1. Selector Minggu
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                                tooltip: 'Periode Sebelumnya',
                                onPressed: () {
                                  ref.read(periodOffsetProvider.notifier).previous();
                                },
                              ),
                              Column(
                                children: [
                                  Text(
                                    period.periodLabel,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brandPrimaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Target kas: ${CurrencyFormatter.format(period.targetAmount)}/siswa',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                                tooltip: 'Periode Berikutnya',
                                onPressed: () {
                                  ref.read(periodOffsetProvider.notifier).next();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2. Collection Summary Card
                        if (summary != null)
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          activeYear.duesPeriodType == 'daily'
                                              ? 'TARGET KAS HARIAN'
                                              : activeYear.duesPeriodType == 'monthly'
                                                  ? 'TARGET KAS BULANAN'
                                                  : 'TARGET KAS MINGGUAN',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textSecondary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              CurrencyFormatter.format(summary.totalCollected),
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.brandPrimaryDark,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '/ ${CurrencyFormatter.format(summary.totalTarget)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.incomeBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${(summary.percentage * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.incomeText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: summary.percentage.clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor: AppColors.blueLight,
                                    valueColor: const AlwaysStoppedAnimation(AppColors.incomeText),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tarif: ${CurrencyFormatter.format(period.targetAmount)} per siswa',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    ),
                                    Text(
                                      '$paidCount Lunas, $unpaidCount Belum Bayar',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brandPrimaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        // 3. Filter Chips
                        Row(
                          children: [
                            _buildFilterChip(
                              label: 'Semua (${allItems.length})',
                              isSelected: _selectedFilter == DuesFilterStatus.all,
                              onTap: () => setState(() => _selectedFilter = DuesFilterStatus.all),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Belum Bayar ($unpaidCount)',
                              isSelected: _selectedFilter == DuesFilterStatus.unpaid,
                              onTap: () => setState(() => _selectedFilter = DuesFilterStatus.unpaid),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Lunas ($paidCount)',
                              isSelected: _selectedFilter == DuesFilterStatus.paid,
                              onTap: () => setState(() => _selectedFilter = DuesFilterStatus.paid),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 4. Student List
                        if (allItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum Ada Siswa Terdaftar',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tambahkan nama teman-teman sekelasmu terlebih dahulu dengan menekan tombol (+) di pojok kanan atas.',
                                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.person_add_outlined, size: 18),
                                  label: const Text('Tambah Siswa Sekarang'),
                                  onPressed: () {
                                    NewStudentDialog.show(context, activeYear.id, 1);
                                  },
                                ),
                              ],
                            ),
                          )
                        else if (filteredItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: const Text(
                              'Tidak ada siswa pada filter ini',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          )
                        else
                          ...filteredItems.map((item) => _buildStudentTile(item, period)),
                      ],
                    ),
                  ),

                  // 5. Bottom Action Button
                  Builder(
                    builder: (context) {
                      final totalCollected = summary?.totalCollected ??
                          allItems.where((i) => i.isPaid).fold<int>(0, (sum, i) => sum + i.amountPaid);
                      final unreconciledDelta = totalCollected - period.reconciledAmount;
                      final isFullyReconciled = unreconciledDelta <= 0 && paidCount > 0 && period.reconciledAmount > 0;
                      final canReconcile = unreconciledDelta > 0 && !_isReconciling && allItems.isNotEmpty && paidCount > 0;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFullyReconciled
                                ? AppColors.incomeText
                                : (canReconcile ? AppColors.brandPrimary : AppColors.borderSubtle),
                            foregroundColor: (isFullyReconciled || canReconcile)
                                ? Colors.white
                                : AppColors.textSecondary,
                            minimumSize: const Size.fromHeight(50),
                          ),
                          icon: Icon(
                            isFullyReconciled
                                ? Icons.check_circle_rounded
                                : Icons.account_balance_wallet_rounded,
                            color: (isFullyReconciled || canReconcile) ? Colors.white : AppColors.textSecondary,
                          ),
                          label: Text(
                            isFullyReconciled
                                ? 'Semua Kas Periode Ini Sudah Dicatat'
                                : _isReconciling
                                    ? 'Memproses...'
                                    : allItems.isEmpty
                                        ? 'Belum Ada Siswa Terdaftar'
                                        : paidCount == 0
                                            ? 'Belum Ada Siswa yang Membayar'
                                            : period.reconciledAmount > 0
                                                ? 'Simpan Tambahan Kas Baru (+${CurrencyFormatter.format(unreconciledDelta)})'
                                                : 'Simpan & Masukkan ke Kas Kelas ($paidCount Siswa)',
                          ),
                          onPressed: canReconcile
                              ? () => _handleReconcile(period, activeYear.id, paidCount, unreconciledDelta)
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandPrimary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentTile(StudentDuesItem item, DuesPeriod period) {
    final isPaid = item.isPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          // Nomor Absen Box
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.slateTag,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${item.student.attendanceNumber}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Nama Siswa
          Expanded(
            child: Text(
              item.student.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),

          // Tombol Status Bayar (Min 48dp touch target)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              ref.read(duesRepoProvider).togglePaymentStatus(
                    duesPeriodId: period.id,
                    studentId: item.student.id,
                    targetAmount: period.targetAmount,
                    currentStatus: isPaid,
                  );
            },
            child: Container(
              constraints: const BoxConstraints(minWidth: 100, minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isPaid ? AppColors.incomeBg : AppColors.canvasLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPaid ? AppColors.incomeText : AppColors.borderSubtle,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: isPaid ? AppColors.incomeText : AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPaid ? 'Lunas' : 'Belum',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPaid ? AppColors.incomeText : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
