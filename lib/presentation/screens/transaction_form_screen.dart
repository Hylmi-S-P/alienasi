import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../providers/app_providers.dart';
import 'dialogs/category_management_dialog.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final String initialType; // 'income' or 'expense'
  final VoidCallback? onBackToDashboard;

  const TransactionFormScreen({
    super.key,
    this.initialType = 'expense',
    this.onBackToDashboard,
  });

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DateTime _transactionDate = DateTime.now();
  String? _selectedCategoryId;
  String? _receiptImagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  void _changeType(String newType) {
    if (_type != newType) {
      setState(() {
        _type = newType;
        _selectedCategoryId = null;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addQuickAmount(int additional) {
    final current = int.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    final updated = current + additional;
    _amountController.text = '$updated';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 70);
      if (picked != null) {
        setState(() => _receiptImagePath = picked.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih foto: $e')),
        );
      }
    }
  }

  Future<void> _handleSubmit(String academicYearId, String? effectiveCategoryId, int currentBalance) async {
    if (!_formKey.currentState!.validate()) return;
    if (effectiveCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori transaksi terlebih dahulu')),
      );
      return;
    }

    final rawAmount = int.tryParse(_amountController.text.replaceAll('.', ''));
    if (rawAmount == null || rawAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal transaksi tidak valid')),
      );
      return;
    }

    if (_type == 'expense' && rawAmount > currentBalance) {
      final deficit = rawAmount - currentBalance;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.expenseText, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pengeluaran Melebihi Saldo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Text(
            'Saldo kas saat ini adalah ${CurrencyFormatter.format(currentBalance)}. '
            'Pengeluaran sebesar ${CurrencyFormatter.format(rawAmount)} akan membuat kas defisit (-${CurrencyFormatter.format(deficit)}).\n\n'
            'Apakah kamu yakin nominal pengeluaran ini sudah sesuai?',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Periksa Kembali', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.expenseText),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tetap Simpan'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(transactionRepoProvider).insertTransaction(
            academicYearId: academicYearId,
            categoryId: effectiveCategoryId,
            type: _type,
            amount: rawAmount,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            receiptImagePath: _receiptImagePath,
            transactionDate: _transactionDate,
          );

      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        } else {
          _amountController.clear();
          _titleController.clear();
          _descriptionController.clear();
          setState(() {
            _receiptImagePath = null;
            _selectedCategoryId = null;
          });
          if (widget.onBackToDashboard != null) {
            widget.onBackToDashboard!();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.brandPrimary,
            content: Text('${_type == 'income' ? 'Pemasukan' : 'Pengeluaran'} berhasil dicatat!'),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeYearAsync = ref.watch(activeAcademicYearProvider);
    final statsAsync = ref.watch(balanceStatsProvider);
    final activeYear = activeYearAsync.value;
    final currentBalance = statsAsync.value?.totalBalance ?? 0;
    final categoriesAsync = ref.watch(categoriesStreamProvider(_type));
    final categoriesList = categoriesAsync.value ?? [];

    final effectiveCategoryId = (_selectedCategoryId != null && categoriesList.any((c) => c.id == _selectedCategoryId))
        ? _selectedCategoryId
        : (categoriesList.isNotEmpty ? categoriesList.first.id : null);

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
          title: Text(_type == 'income' ? 'Catat Uang Masuk' : 'Catat Uang Keluar'),
        ),
        body: const Center(child: Text('Kelas belum disetel')),
      );
    }

    final isIncome = _type == 'income';

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
        title: Text(isIncome ? 'Catat Uang Masuk' : 'Catat Uang Keluar'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Status Kas Cepat & Panduan Pengisian
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slateTag,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline_rounded, color: AppColors.brandPrimary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIncome
                                ? 'Pencatatan Kas Masuk • ${activeYear.name}'
                                : 'Pencatatan Pengeluaran • ${activeYear.name}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandPrimaryDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isIncome
                                ? 'Untuk uang kas rutin siswa, gunakan tab "Kas Siswa". Gunakan form ini khusus pemasukan umum (donasi, kas awal, sisa kembalian).'
                                : 'Catat belanja kelas (ATK, spidol, konsumsi, kebersihan). Disarankan melampirkan foto nota untuk arsip laporan.',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Tab Toggle Uang Keluar vs Uang Masuk
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

              // 3. Kolom Input Nominal Uang
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
                        Text(
                          isIncome ? 'Nominal Pemasukan' : 'Nominal Pengeluaran',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Saldo Kas: ${CurrencyFormatter.format(currentBalance)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: currentBalance > 0 ? AppColors.brandPrimary : AppColors.expenseText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
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
                        final num = int.tryParse(v.replaceAll('.', ''));
                        if (num == null || num <= 0) return 'Nominal tidak valid';
                        if (num < 100) return 'Nominal minimal Rp 100';
                        if (num > 1000000000) return 'Nominal maksimal Rp 1.000.000.000';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Quick Amount Chips
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

              // 4. Kategori Transaksi
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
                    if (categoriesAsync.isLoading && categoriesList.isEmpty)
                      const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    else if (categoriesList.isEmpty)
                      Center(
                        child: TextButton.icon(
                          onPressed: () => CategoryManagementDialog.show(context, initialType: _type),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Tambah Kategori Pertama'),
                        ),
                      )
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
                          ActionChip(
                            avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.textSecondary),
                            label: const Text('Tambah Baru'),
                            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            backgroundColor: AppColors.slateTag,
                            side: const BorderSide(color: AppColors.borderSubtle),
                            onPressed: () => CategoryManagementDialog.show(context, initialType: _type),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Rincian & Keterangan
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

              // 6. Lampiran Foto Nota Fisik
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
                        const Text(
                          'Bukti Foto Nota Fisik',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        if (_receiptImagePath != null)
                          TextButton(
                            onPressed: () => setState(() => _receiptImagePath = null),
                            child: const Text('Hapus Foto', style: TextStyle(color: AppColors.expenseText, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_receiptImagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_receiptImagePath!),
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
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
                onPressed: _isLoading ? null : () => _handleSubmit(activeYear.id, effectiveCategoryId, currentBalance),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : Text(
                        isIncome ? 'Simpan Pemasukan Kas' : 'Simpan Pengeluaran Kas',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
