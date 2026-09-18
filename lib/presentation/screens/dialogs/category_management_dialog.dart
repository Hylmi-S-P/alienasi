import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/app_providers.dart';

class CategoryManagementDialog extends ConsumerStatefulWidget {
  final String initialType;

  const CategoryManagementDialog({super.key, this.initialType = 'expense'});

  static Future<void> show(BuildContext context, {String initialType = 'expense'}) {
    return showDialog(
      context: context,
      builder: (context) => CategoryManagementDialog(initialType: initialType),
    );
  }

  @override
  ConsumerState<CategoryManagementDialog> createState() => _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends ConsumerState<CategoryManagementDialog> {
  late String _currentType;
  final _newCategoryController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.expenseText,
          content: Text('Nama kategori baru tidak boleh kosong.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(transactionRepoProvider);
      final existing = await repo.getCategoriesByType(_currentType);
      if (existing.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.expenseText,
              content: Text('Kategori "$name" sudah ada.'),
            ),
          );
        }
        return;
      }

      await repo.createCategory(
        name: name,
        type: _currentType,
        colorHex: _currentType == 'income' ? '#16A34A' : '#DC2626',
        iconName: _currentType == 'income' ? 'payments_rounded' : 'shopping_bag_rounded',
      );
      _newCategoryController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.brandPrimary,
            content: Text('Kategori "$name" berhasil ditambahkan'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expenseText,
            content: Text('Gagal menambah kategori: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _editCategory(String categoryId, String oldName) async {
    final editController = TextEditingController(text: oldName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Nama Kategori', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama Kategori',
            hintText: 'Masukkan nama kategori baru',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 36)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newName = editController.text.trim();
      if (newName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.expenseText,
              content: Text('Nama kategori tidak boleh kosong.'),
            ),
          );
        }
        return;
      }

      if (newName == oldName) return;

      try {
        final repo = ref.read(transactionRepoProvider);
        final existing = await repo.getCategoriesByType(_currentType);
        if (existing.any((c) => c.id != categoryId && c.name.toLowerCase() == newName.toLowerCase())) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.expenseText,
                content: Text('Kategori dengan nama "$newName" sudah ada.'),
              ),
            );
          }
          return;
        }

        await repo.updateCategoryName(
          id: categoryId,
          newName: newName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.brandPrimary,
              content: Text('Kategori diubah menjadi "$newName"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.expenseText,
              content: Text('Gagal mengubah nama: $e'),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(String categoryId, String name, int currentCount) async {
    if (currentCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.expenseText,
          content: Text('Tidak dapat dihapus. Minimal harus ada 1 kategori yang dipertahankan.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          'Apakah Anda yakin ingin menghapus kategori "$name"? Transaksi lama dengan kategori ini akan dialihkan ke kategori lain.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expenseText),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(transactionRepoProvider).deleteCategory(
              id: categoryId,
              type: _currentType,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.brandPrimary,
              content: Text('Kategori "$name" berhasil dihapus'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.expenseText,
              content: Text('Gagal menghapus: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider(_currentType));
    final isIncome = _currentType == 'income';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isIncome ? AppColors.incomeBg : AppColors.expenseBgSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.category_rounded,
                    color: isIncome ? AppColors.brandPrimary : AppColors.expenseText,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kelola Kategori',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tambah, edit nama, atau hapus kategori kas',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Type Toggle (Pengeluaran / Pemasukan)
            Container(
              decoration: BoxDecoration(
                color: AppColors.slateTag,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _currentType = 'expense'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _currentType == 'expense' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: _currentType == 'expense'
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                              : null,
                        ),
                        child: Text(
                          'Pengeluaran',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _currentType == 'expense' ? FontWeight.w700 : FontWeight.w500,
                            color: _currentType == 'expense' ? AppColors.expenseText : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _currentType = 'income'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _currentType == 'income' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: _currentType == 'income'
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                              : null,
                        ),
                        child: Text(
                          'Pemasukan',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _currentType == 'income' ? FontWeight.w700 : FontWeight.w500,
                            color: _currentType == 'income' ? AppColors.incomeText : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Form Tambah Kategori
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    decoration: InputDecoration(
                      hintText: 'Tambah nama kategori baru...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCategory(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _addCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isIncome ? AppColors.brandPrimary : AppColors.expenseText,
                    minimumSize: const Size(60, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('+ Tambah', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Info Catatan Minimal 1 Kategori
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.brandPrimaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.brandPrimaryDark),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Minimal harus ada 1 kategori dipertahankan. Nama dapat diedit kapan saja.',
                      style: TextStyle(fontSize: 11, color: AppColors.brandPrimaryDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // List Categories
            Expanded(
              child: categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (err, _) => Center(child: Text('Galat: $err', style: const TextStyle(fontSize: 12))),
                data: (categories) {
                  if (categories.isEmpty) {
                    return const Center(
                      child: Text('Belum ada kategori.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    );
                  }

                  return ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.borderSubtle),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isOnlyOne = categories.length <= 1;

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isIncome ? AppColors.incomeBg : AppColors.expenseBgSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isIncome ? Icons.payments_rounded : Icons.label_rounded,
                            size: 16,
                            color: isIncome ? AppColors.incomeText : AppColors.expenseText,
                          ),
                        ),
                        title: Text(
                          cat.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                              tooltip: 'Edit nama kategori',
                              onPressed: () => _editCategory(cat.id, cat.name),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: isOnlyOne ? AppColors.textMuted : AppColors.expenseText,
                              ),
                              tooltip: isOnlyOne
                                  ? 'Minimal 1 kategori dipertahankan'
                                  : 'Hapus kategori',
                              onPressed: isOnlyOne
                                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: AppColors.expenseText,
                                          content: Text('Minimal harus ada 1 kategori yang dipertahankan.'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      )
                                  : () => _deleteCategory(cat.id, cat.name, categories.length),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Selesai Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Selesai'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
