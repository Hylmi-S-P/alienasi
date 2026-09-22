import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/services/receipt_storage_service.dart';
import '../providers/app_providers.dart';
import 'dialogs/category_management_dialog.dart';

/// Layar koreksi / ubah transaksi kas yang sudah tercatat.
///
/// Prinsip audit: `createdAt` (waktu pencatatan pertama) tidak pernah
/// diubah. Pengguna dapat mengoreksi nominal, kategori, judul, keterangan,
/// tanggal transaksi, dan foto nota.
class EditTransactionScreen extends ConsumerStatefulWidget {
  final TransactionWithCategory item;
  final VoidCallback? onBack;

  const EditTransactionScreen({
    super.key,
    required this.item,
    this.onBack,
  });

  @override
  ConsumerState<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _transactionDate;
  String? _selectedCategoryId;
  String? _receiptImagePath;
  bool _removeReceipt = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.item.transaction;
    _type = tx.type;
    _amountController.text = CurrencyFormatter.format(tx.amount, includeSymbol: false);
    _titleController.text = tx.title;
    _descriptionController.text = tx.description ?? '';
    _transactionDate = tx.transactionDate;
    _selectedCategoryId = tx.categoryId;
    _receiptImagePath = tx.receiptImagePath;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _changeType(String newType) {
    if (_type != newType) {
      setState(() {
        _type = newType;
        _selectedCategoryId = null;
      });
    }
  }

  void _addQuickAmount(int additional) {
    final current = CurrencyFormatter.parseAmount(_amountController.text);
    final updated = current + additional;
    final formatted = CurrencyFormatter.format(updated, includeSymbol: false);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1600,
      );
      if (picked != null) {
        final permanentPath = await ReceiptStorageService.persistPickedReceipt(picked.path);
        if (permanentPath == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal menyimpan foto nota ke penyimpanan aplikasi')),
            );
          }
          return;
        }
        setState(() {
          _receiptImagePath = permanentPath;
          _removeReceipt = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih foto: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
      helpText: 'Pilih Tanggal Transaksi',
    );
    if (picked != null) {
      setState(() {
        _transactionDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _transactionDate.hour,
          _transactionDate.minute,
          _transactionDate.second,
        );
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final categoriesList = ref.read(categoriesStreamProvider(_type)).value ?? [];
    final effectiveCategoryId = (_selectedCategoryId != null && categoriesList.any((c) => c.id == _selectedCategoryId))
        ? _selectedCategoryId
        : (categoriesList.isNotEmpty ? categoriesList.first.id : null);

    if (effectiveCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori transaksi terlebih dahulu')),
      );
      return;
    }

    final rawAmount = CurrencyFormatter.parseAmount(_amountController.text);
    if (rawAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal transaksi tidak valid')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(transactionRepoProvider).updateTransaction(
            transactionId: widget.item.transaction.id,
            categoryId: effectiveCategoryId,
            type: _type,
            amount: rawAmount,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            receiptImagePath: _receiptImagePath,
            removeReceipt: _removeReceipt,
            transactionDate: _transactionDate,
          );

      ref.invalidate(balanceStatsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(reportTransactionsProvider);
      ref.invalidate(allTransactionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.brandPrimary,
            content: Text('Transaksi berhasil diperbarui'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.expenseText, content: Text('Galat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider(_type));
    final categoriesList = categoriesAsync.value ?? [];
    final isIncome = _type == 'income';

    final effectiveCategoryId = (_selectedCategoryId != null && categoriesList.any((c) => c.id == _selectedCategoryId))
        ? _selectedCategoryId
        : (categoriesList.isNotEmpty ? categoriesList.first.id : null);

    final hasExistingReceipt = _receiptImagePath != null && !_removeReceipt;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text('Ubah Transaksi Kas'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 0. Banner Konfirmasi Koreksi
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warningText.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.edit_note_rounded, color: AppColors.warningText, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mode Koreksi Transaksi',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warningText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Waktu pencatatan awal (${DateFormatter.toHumanDateTime(widget.item.transaction.createdAt)}) '
                            'tetap dipertahankan sebagai jejak audit.',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 1. Tab Toggle Uang Keluar vs Uang Masuk
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeTab(
                        label: 'Uang Keluar',
                        isSelected: !isIncome,
                        activeBg: AppColors.expenseBg,
                        activeText: AppColors.expenseText,
                        icon: Icons.arrow_upward_rounded,
                        onTap: () => _changeType('expense'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildTypeTab(
                        label: 'Uang Masuk',
                        isSelected: isIncome,
                        activeBg: AppColors.incomeBg,
                        activeText: AppColors.incomeText,
                        icon: Icons.arrow_downward_rounded,
                        onTap: () => _changeType('income'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Nominal
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
                      isIncome ? 'Nominal Pemasukan' : 'Nominal Pengeluaran',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        ThousandSeparatorInputFormatter(),
                      ],
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isIncome ? AppColors.incomeText : AppColors.expenseText,
                      ),
                      decoration: const InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        hintText: '0',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nominal wajib diisi';
                        final num = CurrencyFormatter.parseAmount(v);
                        if (num <= 0) return 'Nominal tidak valid';
                        if (num < 100) return 'Nominal minimal Rp 100';
                        if (num > 1000000000) return 'Nominal maksimal Rp 1.000.000.000';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [5000, 10000, 20000, 50000].map((amt) {
                        return ActionChip(
                          label: Text('+${CurrencyFormatter.format(amt, includeSymbol: false)}'),
                          labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                          backgroundColor: AppColors.blueLight,
                          side: BorderSide.none,
                          onPressed: () => _addQuickAmount(amt),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Tanggal Transaksi
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
                    const Text('Tanggal Transaksi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.slateTag,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.brandPrimary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                DateFormatter.toHumanDate(_transactionDate),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ),
                            const Icon(Icons.edit_rounded, size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Kategori
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
                        const Text('Pilih Kategori', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        TextButton.icon(
                          onPressed: () => CategoryManagementDialog.show(context, initialType: _type),
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('Kelola Kategori', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (categoriesList.isEmpty)
                      const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...categoriesList.map((cat) {
                            final isSelected = effectiveCategoryId == cat.id;
                            return ChoiceChip(
                              label: Text(cat.name),
                              selected: isSelected,
                              selectedColor: isIncome ? AppColors.incomeBg : AppColors.expenseBg,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? (isIncome ? AppColors.incomeText : AppColors.expenseText)
                                    : AppColors.textPrimary,
                              ),
                              onSelected: (sel) {
                                if (sel) setState(() => _selectedCategoryId = cat.id);
                              },
                            );
                          }),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Judul & Keterangan
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
                    const Text('Judul Transaksi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Beli 2 spidol hitam & 1 penghapus papan',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul transaksi wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    const Text('Keterangan Tambahan (Opsional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Catatan tambahan...',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 6. Foto Nota
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
                        const Text('Foto Nota', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        if (hasExistingReceipt || _removeReceipt)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _receiptImagePath = null;
                                _removeReceipt = true;
                              });
                            },
                            child: const Text('Hapus Foto', style: TextStyle(color: AppColors.expenseText, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (hasExistingReceipt && _receiptImagePath != null)
                      Builder(
                        builder: (context) {
                          final file = File(ReceiptStorageService.resolveAbsolutePathSync(_receiptImagePath!));
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              file,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                height: 140,
                                alignment: Alignment.center,
                                color: AppColors.slateTag,
                                child: const Text(
                                  'Foto lama tidak dapat dimuat',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    else if (_removeReceipt)
                      Container(
                        height: 70,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.slateTag,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: const Text(
                          'Foto nota akan dihapus saat perubahan disimpan',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Kamera'),
                              onPressed: () => _pickImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: const Text('Galeri'),
                              onPressed: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                    if (hasExistingReceipt) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.borderSubtle),
                          ),
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: const Text('Ganti Foto', style: TextStyle(fontSize: 12.5)),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 7. Tombol Simpan
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isIncome ? AppColors.incomeText : AppColors.brandPrimary,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text(
                        'Simpan Perubahan Transaksi',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeTab({
    required String label,
    required bool isSelected,
    required Color activeBg,
    required Color activeText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? activeText : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeText : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
