import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repository.dart';
import '../guards/mutation_guard.dart';
import '../providers/app_providers.dart';
import '../widgets/transaction_list_item.dart';
import 'edit_transaction_screen.dart';

enum TransactionTypeFilter { all, income, expense }

class AllTransactionsScreen extends ConsumerStatefulWidget {
  final AcademicYear? academicYear;

  const AllTransactionsScreen({
    super.key,
    this.academicYear,
  });

  @override
  ConsumerState<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends ConsumerState<AllTransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  TransactionTypeFilter _typeFilter = TransactionTypeFilter.all;
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditTransaction(BuildContext context, TransactionWithCategory item) async {
    Navigator.of(context).pop(); // tutup dialog detail dulu
    final didEdit = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditTransactionScreen(item: item)),
    );
    if (didEdit == true) {
      ref.invalidate(allTransactionsProvider);
      if (widget.academicYear != null) {
        ref.invalidate(allTransactionsByYearProvider(widget.academicYear!.id));
      }
      ref.invalidate(balanceStatsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(reportTransactionsProvider);
    }
  }

  Future<void> _deleteTransaction(TransactionWithCategory item) async {
    final allowed = await runMutationWithGuard(
      context,
      ref,
      mutationLabel: 'Hapus Transaksi',
      onAllowed: () async {
        try {
          await ref.read(transactionRepoProvider).deleteTransaction(item.transaction.id);
          ref.invalidate(allTransactionsProvider);
          if (widget.academicYear != null) {
            ref.invalidate(allTransactionsByYearProvider(widget.academicYear!.id));
          }
          ref.invalidate(balanceStatsProvider);
          ref.invalidate(recentTransactionsProvider);
          ref.invalidate(reportTransactionsProvider);
          ref.invalidate(currentPeriodSummaryProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.brandPrimary,
                content: Text('Transaksi "${item.transaction.title}" berhasil dihapus'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.expenseText, content: Text('Galat menghapus: $e')),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeYear = widget.academicYear ?? ref.watch(activeAcademicYearProvider).value;

    if (activeYear == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text(
            'Semua Riwayat Transaksi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        body: const Center(
          child: Text(
            'Kelas belum aktif atau belum dipilih.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final allTxAsync = widget.academicYear != null
        ? ref.watch(allTransactionsByYearProvider(widget.academicYear!.id))
        : ref.watch(allTransactionsProvider);

    final categoriesAsync = ref.watch(categoriesProvider);
    final categoriesList = categoriesAsync.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.canvasLight,
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Semua Riwayat Transaksi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              activeYear.name,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.borderSubtle, height: 1.0),
        ),
      ),
      body: allTxAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.expenseText),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat riwayat transaksi: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        data: (allItems) {
          // Merge unique categories from transactions so nothing is missed
          final catMap = <String, Category>{};
          for (final cat in categoriesList) {
            catMap[cat.id] = cat;
          }
          for (final item in allItems) {
            catMap.putIfAbsent(item.category.id, () => item.category);
          }
          final availableCategories = catMap.values.toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          // Visible category chips based on active type filter
          final visibleCategories = _typeFilter == TransactionTypeFilter.all
              ? availableCategories
              : availableCategories
                  .where((c) => c.type == (_typeFilter == TransactionTypeFilter.income ? 'income' : 'expense'))
                  .toList();

          // Filtering
          final query = _searchController.text.trim().toLowerCase();
          final filteredItems = allItems.where((item) {
            final tx = item.transaction;

            // Search query filter (matches title or description)
            if (query.isNotEmpty) {
              final matchesTitle = tx.title.toLowerCase().contains(query);
              final matchesDesc = tx.description != null && tx.description!.toLowerCase().contains(query);
              if (!matchesTitle && !matchesDesc) {
                return false;
              }
            }

            // Type filter
            if (_typeFilter == TransactionTypeFilter.income && tx.type != 'income') {
              return false;
            }
            if (_typeFilter == TransactionTypeFilter.expense && tx.type != 'expense') {
              return false;
            }

            // Category filter
            if (_selectedCategoryId != null && tx.categoryId != _selectedCategoryId) {
              return false;
            }

            return true;
          }).toList();

          // Dynamic Mutations Summary Calculation
          int totalFilteredIncome = 0;
          int totalFilteredExpense = 0;
          for (final item in filteredItems) {
            if (item.transaction.type == 'income') {
              totalFilteredIncome += item.transaction.amount;
            } else if (item.transaction.type == 'expense') {
              totalFilteredExpense += item.transaction.amount;
            }
          }
          final netMutation = totalFilteredIncome - totalFilteredExpense;
          final isCompactKeyboard = MediaQuery.sizeOf(context).height < 500 && MediaQuery.viewInsetsOf(context).bottom > 0;

          return Column(
            children: [
              // Top Filter Controls Section
              Container(
                    color: Colors.white,
                    padding: EdgeInsets.fromLTRB(16, isCompactKeyboard ? 4 : 12, 16, isCompactKeyboard ? 4 : 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Search Bar
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Cari judul atau keterangan transaksi...',
                            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondary),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.canvasLight,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isCompactKeyboard ? 4 : 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.borderSubtle),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.borderSubtle),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
                            ),
                          ),
                        ),
                        if (!isCompactKeyboard) ...[
                          const SizedBox(height: 10),

                        // 2. Category Choice Chips (Horizontal Scrollable)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // "Semua" Chip
                              ChoiceChip(
                                label: const Text('Semua'),
                                selected: _typeFilter == TransactionTypeFilter.all && _selectedCategoryId == null,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _typeFilter = TransactionTypeFilter.all;
                                      _selectedCategoryId = null;
                                    });
                                  }
                                },
                                selectedColor: AppColors.brandPrimaryLight,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: (_typeFilter == TransactionTypeFilter.all && _selectedCategoryId == null)
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: (_typeFilter == TransactionTypeFilter.all && _selectedCategoryId == null)
                                      ? AppColors.brandPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),

                              // "Kas Masuk" Chip
                              ChoiceChip(
                                label: const Text('Kas Masuk'),
                                selected: _typeFilter == TransactionTypeFilter.income && _selectedCategoryId == null,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _typeFilter = TransactionTypeFilter.income;
                                      _selectedCategoryId = null;
                                    } else {
                                      _typeFilter = TransactionTypeFilter.all;
                                    }
                                  });
                                },
                                selectedColor: AppColors.incomeBg,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: (_typeFilter == TransactionTypeFilter.income && _selectedCategoryId == null)
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: (_typeFilter == TransactionTypeFilter.income && _selectedCategoryId == null)
                                      ? AppColors.incomeText
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),

                              // "Kas Keluar" Chip
                              ChoiceChip(
                                label: const Text('Kas Keluar'),
                                selected: _typeFilter == TransactionTypeFilter.expense && _selectedCategoryId == null,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _typeFilter = TransactionTypeFilter.expense;
                                      _selectedCategoryId = null;
                                    } else {
                                      _typeFilter = TransactionTypeFilter.all;
                                    }
                                  });
                                },
                                selectedColor: AppColors.expenseBg,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: (_typeFilter == TransactionTypeFilter.expense && _selectedCategoryId == null)
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: (_typeFilter == TransactionTypeFilter.expense && _selectedCategoryId == null)
                                      ? AppColors.expenseText
                                      : AppColors.textSecondary,
                                ),
                              ),

                              // Individual Category Chips
                              if (visibleCategories.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                ...visibleCategories.map((cat) {
                                  final isSelected = _selectedCategoryId == cat.id;
                                  final isCatIncome = cat.type == 'income';
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(cat.name),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedCategoryId = cat.id;
                                            _typeFilter = isCatIncome
                                                ? TransactionTypeFilter.income
                                                : TransactionTypeFilter.expense;
                                          } else {
                                            _selectedCategoryId = null;
                                            _typeFilter = TransactionTypeFilter.all;
                                          }
                                        });
                                      },
                                      selectedColor: isCatIncome ? AppColors.incomeBg : AppColors.expenseBg,
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected
                                            ? (isCatIncome ? AppColors.incomeText : AppColors.expenseText)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // 3. Live Dynamic Mutations Summary Card (hidden in compact landscape keyboard mode)
              if (!isCompactKeyboard)
                Container(
                    margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Ringkasan Mutasi',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${filteredItems.length} dari ${allItems.length} Transaksi',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Total Masuk
                            Expanded(
                              child: _buildSummaryMetric(
                                title: 'Total Masuk',
                                amountText: '+${CurrencyFormatter.format(totalFilteredIncome)}',
                                textColor: AppColors.incomeText,
                                bgColor: AppColors.incomeBg,
                                icon: Icons.arrow_downward_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Total Keluar
                            Expanded(
                              child: _buildSummaryMetric(
                                title: 'Total Keluar',
                                amountText: '-${CurrencyFormatter.format(totalFilteredExpense)}',
                                textColor: AppColors.expenseText,
                                bgColor: AppColors.expenseBg,
                                icon: Icons.arrow_upward_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Selisih Bersih
                            Expanded(
                              child: _buildSummaryMetric(
                                title: 'Selisih',
                                amountText:
                                    '${netMutation >= 0 ? '+' : '-'}${CurrencyFormatter.format(netMutation.abs())}',
                                textColor: netMutation >= 0 ? AppColors.incomeText : AppColors.expenseText,
                                bgColor: netMutation >= 0 ? AppColors.incomeBg : AppColors.expenseBg,
                                icon: Icons.account_balance_wallet_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

              // 4. Full List of Transactions or Empty State
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(isCompactKeyboard ? 6 : 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isCompactKeyboard) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: AppColors.blueLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.search_off_rounded,
                                    size: 40,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              const Text(
                                'Tidak Ada Transaksi Ditemukan',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (!isCompactKeyboard) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'Coba sesuaikan kata kunci pencarian atau reset filter kategori.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                              if (_searchController.text.isNotEmpty ||
                                  _selectedCategoryId != null ||
                                  _typeFilter != TransactionTypeFilter.all) ...[
                                SizedBox(height: isCompactKeyboard ? 6 : 16),
                                OutlinedButton.icon(
                                  style: isCompactKeyboard
                                      ? OutlinedButton.styleFrom(visualDensity: VisualDensity.compact)
                                      : null,
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _typeFilter = TransactionTypeFilter.all;
                                      _selectedCategoryId = null;
                                    });
                                  },
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Reset Filter', style: TextStyle(fontSize: 12.5)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.brandPrimary,
                        onRefresh: () async {
                          ref.invalidate(allTransactionsProvider);
                          if (widget.academicYear != null) {
                            ref.invalidate(allTransactionsByYearProvider(widget.academicYear!.id));
                          }
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return TransactionListItem(
                              key: ValueKey(item.transaction.id),
                              item: item,
                              onEdit: () => _openEditTransaction(context, item),
                              onDelete: () => _deleteTransaction(item),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String title,
    required String amountText,
    required Color textColor,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: textColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amountText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
