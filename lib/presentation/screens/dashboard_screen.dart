import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/transaction_repository.dart';
import '../providers/app_providers.dart';
import '../providers/update_notifier.dart';
import '../guards/mutation_guard.dart';
import '../widgets/h1_warning_banner.dart';
import '../widgets/transaction_list_item.dart';
import '../widgets/unactivated_banner.dart';
import '../widgets/update_banner.dart';
import 'dialogs/backup_restore_dialog.dart';
import 'dialogs/class_setup_dialog.dart';
import 'dialogs/end_term_dialog.dart';
import 'dialogs/update_check_sheet.dart';
import 'all_transactions_screen.dart';
import 'transaction_form_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _setupDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(updateNotifierProvider.notifier).checkForUpdateSilently();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeYearAsync = ref.watch(activeAcademicYearProvider);
    final statsAsync = ref.watch(balanceStatsProvider);
    final recentTxAsync = ref.watch(recentTransactionsProvider);
    final duesSummaryAsync = ref.watch(currentPeriodSummaryProvider);

    return activeYearAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.brandPrimary)),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Galat memuat data: $err')),
      ),
      data: (activeYear) {
        if (activeYear == null) {
          if (!_setupDialogShown) {
            _setupDialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ClassSetupDialog.show(context, isDismissible: false);
              }
            });
          }
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school_rounded, size: 56, color: AppColors.brandPrimary),
                  const SizedBox(height: 16),
                  const Text(
                    'Selamat Datang di Bendahara Kelas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Silakan atur kelas pertama Anda untuk memulai.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      minimumSize: const Size(200, 48),
                    ),
                    onPressed: () => ClassSetupDialog.show(context, isDismissible: false),
                    child: const Text('Atur Kelas Pertama'),
                  ),
                ],
              ),
            ),
          );
        }

        _setupDialogShown = false;

        final stats = statsAsync.value ??
            const BalanceStats(totalBalance: 0, monthlyIncome: 0, monthlyExpense: 0);
        final recentItems = recentTxAsync.value ?? [];
        final duesSummary = duesSummaryAsync.value;

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.brandPrimary,
              onRefresh: () async {
                ref.invalidate(balanceStatsProvider);
                ref.invalidate(recentTransactionsProvider);
                ref.invalidate(currentPeriodSummaryProvider);
                ref.read(updateNotifierProvider.notifier).checkForUpdateSilently();
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header Kelas (Card Header)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.blueLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.school_rounded, color: AppColors.brandPrimary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeYear.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tahun Ajaran ${activeYear.startDate.year}/${activeYear.endDate.year} • ${activeYear.treasurerName}',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cloud_sync_outlined, color: AppColors.brandPrimary, size: 20),
                            tooltip: 'Cadangkan & Pulihkan Data',
                            onPressed: () {
                              BackupRestoreDialog.show(context, academicYear: activeYear);
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                            tooltip: 'Menu Lainnya',
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) async {
                              if (value == 'check_update') {
                                await UpdateCheckSheet.show(context);
                                return;
                              }
                              if (value == 'end_term') {
                                final didReset = await EndTermDialog.show(context, academicYear: activeYear);
                                if (didReset == true && context.mounted) {
                                  _setupDialogShown = true;
                                  ClassSetupDialog.show(context, isDismissible: false);
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'check_update',
                                child: Row(
                                  children: [
                                    Icon(Icons.system_update_outlined, size: 18, color: AppColors.brandPrimary),
                                    SizedBox(width: 10),
                                    Text(
                                      'Cek Pembaruan Aplikasi',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'end_term',
                                child: Row(
                                  children: [
                                    Icon(Icons.flag_rounded, size: 18, color: AppColors.expenseText),
                                    SizedBox(width: 10),
                                    Text(
                                      'Akhiri Jabatan Bendahara',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                            tooltip: 'Edit Info Kelas',
                            onPressed: () {
                              ClassSetupDialog.show(context, isDismissible: true, existingYear: activeYear);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 1a. Banner notifikasi lisensi belum aktif / kedaluwarsa
                    // dengan tombol WhatsApp langsung ke Admin.
                    if (UnactivatedBanner.maybeBuild(context, ref)
                        case final unactivatedBanner?)
                      ...[
                        unactivatedBanner,
                        const SizedBox(height: 14),
                      ],

                    // 1b. Banner peringatan H-1 (hanya tampil saat sisa
                    // lisensi <= 24 jam dan belum di-dismiss sesi ini).
                    if (H1WarningBanner.maybeBuild(context, ref) case final banner?)
                      ...[
                        banner,
                        const SizedBox(height: 14),
                      ],

                    // 1c. Banner pembaruan aplikasi (tampil hanya saat
                    // server menyatakan versi lebih baru).
                    if (UpdateBanner.maybeBuild(context, ref)
                        case final updateBanner?)
                      ...[
                        updateBanner,
                        const SizedBox(height: 14),
                      ],

                    // 2. Kartu Total Saldo Kas Kelas
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
                          const Text(
                            'Total Saldo Kas Kelas',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            CurrencyFormatter.format(stats.totalBalance),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Kas Masuk Bulan Ini
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.incomeBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.arrow_downward_rounded, size: 12, color: AppColors.incomeText),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Kas Masuk Bulan Ini',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.incomeText,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        CurrencyFormatter.format(stats.monthlyIncome),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.incomeText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Kas Keluar Bulan Ini
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.expenseBgSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.arrow_upward_rounded, size: 12, color: AppColors.expenseText),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Kas Keluar Bulan Ini',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.expenseText,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        CurrencyFormatter.format(stats.monthlyExpense),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.expenseText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. Tombol Aksi Cepat
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            context: context,
                            label: '+ Uang Masuk',
                            bgColor: AppColors.incomeBg,
                            textColor: AppColors.brandPrimary,
                            icon: Icons.add_circle_outline_rounded,
                            onTap: () async {
                              final allowed = await runMutationWithGuard(
                                context,
                                ref,
                                mutationLabel:
                                    'Mencatat transaksi butuh lisensi aktif.',
                                onAllowed: () async {
                                  if (!context.mounted) return;
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const TransactionFormScreen(initialType: 'income'),
                                    ),
                                  );
                                },
                              );
                              // Ketika paywall ditutup tanpa aktivasi,
                              // navigasi tidak dilakukan sama sekali.
                              if (!allowed) return;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionButton(
                            context: context,
                            label: '- Uang Keluar',
                            bgColor: AppColors.expenseBgSoft,
                            textColor: AppColors.expenseText,
                            icon: Icons.remove_circle_outline_rounded,
                            onTap: () async {
                              await runMutationWithGuard(
                                context,
                                ref,
                                mutationLabel:
                                    'Mencatat transaksi butuh lisensi aktif.',
                                onAllowed: () async {
                                  if (!context.mounted) return;
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const TransactionFormScreen(initialType: 'expense'),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionButton(
                            context: context,
                            label: 'Centang Kas',
                            bgColor: AppColors.blueLight,
                            textColor: AppColors.textPrimary,
                            icon: Icons.fact_check_outlined,
                            onTap: () {
                              if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 4. Progres Kas Periode Berjalan
                    if (duesSummary != null)
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
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.event_note_rounded, color: AppColors.brandPrimary, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Kas ${duesSummary.period.periodLabel}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.incomeBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${(duesSummary.percentage * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 11,
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
                                value: duesSummary.percentage.clamp(0.0, 1.0),
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
                                  'Terkumpul: ${CurrencyFormatter.format(duesSummary.totalCollected)}',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                                Text(
                                  '${duesSummary.paidCount} dari ${duesSummary.totalStudents} Siswa Lunas',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),

                    // 5. Riwayat Pencatatan Terkini
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Riwayat Pencatatan Terkini',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AllTransactionsScreen(academicYear: activeYear),
                              ),
                            );
                          },
                          child: const Text(
                            'Lihat Semua',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (recentItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textMuted),
                            SizedBox(height: 8),
                            Text(
                              'Belum ada transaksi di kelas ini',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Gunakan tombol + Uang Masuk atau - Uang Keluar di atas untuk mencatat.',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ...recentItems.take(5).map((item) => TransactionListItem(key: ValueKey(item.transaction.id), item: item)),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required String label,
    required Color bgColor,
    required Color textColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
