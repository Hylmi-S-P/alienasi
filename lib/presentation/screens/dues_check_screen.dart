import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/dues_repository.dart';
import '../guards/mutation_guard.dart';
import '../providers/app_providers.dart';
import '../widgets/dues_period_calendar_card.dart';
import 'dialogs/new_student_dialog.dart';
import 'dialogs/edit_student_dialog.dart';

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
  final Set<String> _selectedStudentIds = <String>{};

  @override
  void dispose() {
    try {
      ref.read(periodOffsetProvider.notifier).reset();
      ref.read(selectedPeriodDateProvider.notifier).resetToToday();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _handleSaveAndReconcile(
    DuesPeriod period,
    String academicYearId,
    int unreconciledDelta,
  ) async {
    if (_selectedStudentIds.isEmpty) return;

    // Explore-first gating: menandai iuran siswa adalah aksi mutasi.
    final allowed = await runMutationWithGuard(
      context,
      ref,
      mutationLabel: 'Menandai pembayaran kas siswa membutuhkan lisensi aktif.',
      onAllowed: () async {
        await _performSaveAndReconcile(period, academicYearId, unreconciledDelta);
      },
    );
    if (!allowed) return;
  }

  Future<void> _performSaveAndReconcile(
    DuesPeriod period,
    String academicYearId,
    int unreconciledDelta,
  ) async {
    final selectedCount = _selectedStudentIds.length;
    final selectedAmount = selectedCount * period.targetAmount;
    final totalDeltaToReconcile =
        (unreconciledDelta > 0 ? unreconciledDelta : 0) + selectedAmount;

    // --- Dialog 1: Konfirmasi Pembayaran Siswa ---
    final confirmPaid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.brandPrimary, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Konfirmasi Pembayaran Siswa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Sudah yakin siswa / siswi yang dipilih ($selectedCount siswa) sudah membayar?\n\n(Aksi ini tidak bisa dibatalkan jika memilih Ya)',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              minimumSize: const Size(100, 40),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Sudah'),
          ),
        ],
      ),
    );

    if (confirmPaid != true || !mounted) return;

    // --- Dialog 2: Masukkan ke kas kelas? ---
    final confirmReconcile = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppColors.brandPrimary, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Masukkan ke kas kelas?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Total kas sebesar ${CurrencyFormatter.format(totalDeltaToReconcile)} ($selectedCount siswa yang dipilih) akan dimasukkan dan dicatat sebagai Pemasukan di Buku Kas Utama.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
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

    if (confirmReconcile != true || !mounted) return;

    setState(() => _isReconciling = true);
    try {
      final duesRepo = ref.read(duesRepoProvider);
      await duesRepo.markBatchAsPaid(
        duesPeriodId: period.id,
        studentIds: _selectedStudentIds,
        targetAmount: period.targetAmount,
      );

      final deltaReconciled = await duesRepo.reconcileIntoGeneralCash(
        period: period,
        academicYearId: academicYearId,
      );

      if (mounted) {
        setState(() {
          _selectedStudentIds.clear();
        });
      }

      ref.invalidate(activePeriodStudentsProvider);
      ref.invalidate(activeDuesPeriodProvider);
      ref.invalidate(activePeriodSummaryProvider);
      ref.invalidate(balanceStatsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(reportTransactionsProvider);
      ref.invalidate(currentPeriodSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.brandPrimary,
            content: Text(
              'Kas sebesar ${CurrencyFormatter.format(deltaReconciled)} dari $selectedCount siswa berhasil dicatat ke Kas Kelas!',
            ),
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

  Future<void> _handleOverReconciled(DuesPeriod period, int totalCollected) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sesuaikan Kas Tercatat?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Kas yang tercatat sebelumnya (${CurrencyFormatter.format(period.reconciledAmount)}) melebihi total kas siswa yang lunas saat ini (${CurrencyFormatter.format(totalCollected)}).\n\n'
          'Apakah kamu ingin menyinkronkan kas tercatat menjadi ${CurrencyFormatter.format(totalCollected)} agar dapat mencatat kas berikutnya?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              minimumSize: const Size(120, 40),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Sesuaikan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(duesRepoProvider).syncReconciledAmount(
            duesPeriodId: period.id,
            actualCollected: totalCollected,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.brandPrimary,
            content: Text('Kas tercatat berhasil disesuaikan!'),
          ),
        );
      }
    }
  }

  Future<void> _handleReconcile(
    DuesPeriod period,
    String academicYearId,
    int paidCount,
    int unreconciledDelta,
  ) async {
    if (unreconciledDelta < 0) {
      final totalCollected = period.reconciledAmount + unreconciledDelta;
      await _handleOverReconciled(period, totalCollected);
      return;
    }
    if (unreconciledDelta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.incomeText,
          content: Text('Semua pembayaran kas untuk periode ini sudah dicatat di Buku Kas Umum.'),
        ),
      );
      return;
    }

    // Explore-first gating: mencatat kas ke buku utama adalah aksi mutasi.
    final allowed = await runMutationWithGuard(
      context,
      ref,
      mutationLabel: 'Mencatat kas siswa ke buku utama membutuhkan lisensi aktif.',
      onAllowed: () async {
        await _performReconcile(period, academicYearId, paidCount, unreconciledDelta);
      },
    );
    if (!allowed) return;
  }

  Future<void> _performReconcile(
    DuesPeriod period,
    String academicYearId,
    int paidCount,
    int unreconciledDelta,
  ) async {
    final isAdditional = period.isReconciled || period.reconciledAmount > 0;
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
    ref.listen<AsyncValue<DuesPeriod?>>(activeDuesPeriodProvider, (prev, next) {
      final prevId = prev?.value?.id;
      final nextId = next.value?.id;
      if (prevId != nextId) {
        setState(() {
          _selectedStudentIds.clear();
        });
      }
    });

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

    if (activePeriodAsync.hasError) {
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 52, color: AppColors.expenseText),
                const SizedBox(height: 16),
                const Text(
                  'Gagal Memuat Periode Kas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  '${activePeriodAsync.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    ref.invalidate(activeDuesPeriodProvider);
                    ref.invalidate(currentDuesPeriodProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (period == null) {
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
        body: const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary)),
      );
    }

    final isListLoading = activePeriodAsync.isLoading || studentDuesAsync.isLoading;

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
        child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        // 1. Kalender Pemilih Periode Kas Adaptif & Auto-Update Dinamis
                        DuesPeriodCalendarCard(
                          period: period,
                          activeYear: activeYear,
                          onPeriodChanged: () {
                            setState(() => _selectedStudentIds.clear());
                          },
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
                                    Flexible(
                                      child: Text(
                                        'Tarif: ${CurrencyFormatter.format(period.targetAmount)} per siswa',
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '$paidCount Lunas, $unpaidCount Belum Bayar',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brandPrimaryDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        // 3. Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildFilterChip(
                                label: 'Semua (${isListLoading ? '-' : allItems.length})',
                                isSelected: _selectedFilter == DuesFilterStatus.all,
                                onTap: () => setState(() => _selectedFilter = DuesFilterStatus.all),
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Belum Bayar (${isListLoading ? '-' : unpaidCount})',
                                isSelected: _selectedFilter == DuesFilterStatus.unpaid,
                                onTap: () => setState(() => _selectedFilter = DuesFilterStatus.unpaid),
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Lunas (${isListLoading ? '-' : paidCount})',
                                isSelected: _selectedFilter == DuesFilterStatus.paid,
                                onTap: () => setState(() => _selectedFilter = DuesFilterStatus.paid),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 4. Student List Header & Multi-Pick Quick Action
                        if (!isListLoading && allItems.isNotEmpty)
                          Builder(
                            builder: (context) {
                              final selectableItems = filteredItems.where((it) => !it.isPaid).toList();
                              final isAllSelected = selectableItems.isNotEmpty &&
                                  selectableItems.every((it) => _selectedStudentIds.contains(it.student.id));

                              return Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 8, left: 2, right: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'DAFTAR SISWA (${filteredItems.length})',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (selectableItems.isNotEmpty)
                                      InkWell(
                                        key: const ValueKey('select_all_students_btn'),
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () {
                                          setState(() {
                                            if (isAllSelected) {
                                              for (final it in selectableItems) {
                                                _selectedStudentIds.remove(it.student.id);
                                              }
                                            } else {
                                              for (final it in selectableItems) {
                                                _selectedStudentIds.add(it.student.id);
                                              }
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isAllSelected
                                                    ? Icons.deselect_rounded
                                                    : Icons.select_all_rounded,
                                                size: 16,
                                                color: AppColors.brandPrimaryDark,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isAllSelected
                                                    ? 'Batal Pilih'
                                                    : 'Centang Semua (${selectableItems.length})',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.brandPrimaryDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),

                        // 5. Student List
                        if (isListLoading)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: AppColors.brandPrimary),
                                SizedBox(height: 12),
                                Text(
                                  'Memuat data siswa...',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        else if (allItems.isEmpty)
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
                      final totalCollected = allItems.where((i) => i.isPaid).fold<int>(0, (sum, i) => sum + i.amountPaid);
                      final unreconciledDelta = totalCollected - period.reconciledAmount;
                      final isOverReconciled = unreconciledDelta < 0 && period.reconciledAmount > 0;
                      final isFullyReconciled = _selectedStudentIds.isEmpty && unreconciledDelta == 0 && paidCount > 0 && period.reconciledAmount > 0;
                      final hasSelected = _selectedStudentIds.isNotEmpty;

                      Color buttonBg = AppColors.borderSubtle;
                      Color buttonFg = AppColors.textSecondary;
                      IconData buttonIcon = Icons.account_balance_wallet_rounded;
                      String buttonLabel = 'Simpan & Masukkan ke Kas Kelas';
                      VoidCallback? buttonOnPressed;

                      if (isListLoading) {
                        buttonLabel = 'Memuat data...';
                        buttonOnPressed = null;
                      } else if (_isReconciling) {
                        buttonLabel = 'Memproses...';
                      } else if (allItems.isEmpty) {
                        buttonLabel = 'Belum Ada Siswa Terdaftar';
                      } else if (hasSelected) {
                        buttonBg = AppColors.brandPrimary;
                        buttonFg = Colors.white;
                        buttonIcon = Icons.account_balance_wallet_rounded;
                        buttonLabel = 'Simpan & Masukkan ke Kas Kelas (${_selectedStudentIds.length} Siswa)';
                        buttonOnPressed = () => _handleSaveAndReconcile(period, activeYear.id, unreconciledDelta);
                      } else if (isOverReconciled) {
                        buttonBg = const Color(0xFFD97706);
                        buttonFg = Colors.white;
                        buttonIcon = Icons.warning_amber_rounded;
                        buttonLabel = 'Kas Tercatat (${CurrencyFormatter.format(period.reconciledAmount)}) Melebihi Total Bayar (Ketuk untuk Sesuaikan)';
                        buttonOnPressed = () => _handleOverReconciled(period, totalCollected);
                      } else if (unreconciledDelta > 0) {
                        buttonBg = AppColors.brandPrimary;
                        buttonFg = Colors.white;
                        buttonIcon = Icons.account_balance_wallet_rounded;
                        buttonLabel = (period.isReconciled || period.reconciledAmount > 0)
                            ? 'Simpan Tambahan Kas Baru (+${CurrencyFormatter.format(unreconciledDelta)})'
                            : 'Simpan & Masukkan ke Kas Kelas ($paidCount Siswa)';
                        buttonOnPressed = () => _handleReconcile(period, activeYear.id, paidCount, unreconciledDelta);
                      } else if (isFullyReconciled) {
                        buttonBg = AppColors.incomeText;
                        buttonFg = Colors.white;
                        buttonIcon = Icons.check_circle_rounded;
                        buttonLabel = 'Semua Kas Periode Ini Sudah Dicatat';
                      } else if (paidCount == 0) {
                        buttonLabel = 'Pilih Siswa yang Membayar Kas';
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonBg,
                            foregroundColor: buttonFg,
                            minimumSize: const Size.fromHeight(50),
                          ),
                          icon: Icon(buttonIcon, color: buttonFg),
                          label: Text(
                            buttonLabel,
                            textAlign: TextAlign.center,
                          ),
                          onPressed: buttonOnPressed,
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
    final isSelected = _selectedStudentIds.contains(item.student.id);

    return Container(
      key: ValueKey(item.student.id),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Nomor Absen Box
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.blueLight : AppColors.slateTag,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${item.student.attendanceNumber}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.brandPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Nama Siswa & Trigger Edit
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                EditStudentDialog.show(
                  context,
                  student: item.student,
                  academicYearId: period.academicYearId,
                  onDeleted: () {
                    setState(() {
                      _selectedStudentIds.remove(item.student.id);
                    });
                  },
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
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
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          'Dipilih (Belum Disimpan)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Tombol Edit Siswa Khusus (Action Button)
          Tooltip(
            message: 'Edit data siswa (absen/nama)',
            child: IconButton(
              icon: const Icon(Icons.edit_note_rounded, size: 22, color: AppColors.textSecondary),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                EditStudentDialog.show(
                  context,
                  student: item.student,
                  academicYearId: period.academicYearId,
                  onDeleted: () {
                    setState(() {
                      _selectedStudentIds.remove(item.student.id);
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 6),

          // Tombol Status Bayar (Min 48dp touch target)
          Tooltip(
            message: isPaid
                ? 'Sudah lunas (terkunci)'
                : (isSelected ? 'Batal memilih siswa' : 'Pilih siswa yang sudah membayar'),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: isPaid
                  ? null
                  : () {
                      setState(() {
                        if (isSelected) {
                          _selectedStudentIds.remove(item.student.id);
                        } else {
                          _selectedStudentIds.add(item.student.id);
                        }
                      });
                    },
              child: Container(
                constraints: const BoxConstraints(minWidth: 100, minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppColors.incomeBg
                      : (isSelected ? AppColors.blueLight : AppColors.canvasLight),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPaid
                        ? AppColors.incomeText
                        : (isSelected ? AppColors.brandPrimary : AppColors.borderSubtle),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPaid
                          ? Icons.check_circle_rounded
                          : (isSelected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded),
                      size: 16,
                      color: isPaid
                          ? AppColors.incomeText
                          : (isSelected ? AppColors.brandPrimary : AppColors.textMuted),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPaid
                          ? 'Lunas'
                          : (isSelected ? 'Dipilih' : 'Belum'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPaid
                            ? AppColors.incomeText
                            : (isSelected ? AppColors.brandPrimary : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
