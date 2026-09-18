import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/database/app_database.dart';
import '../../providers/app_providers.dart';

class ClassSetupDialog extends ConsumerStatefulWidget {
  final bool isDismissible;
  final AcademicYear? existingYear;

  const ClassSetupDialog({
    super.key,
    this.isDismissible = false,
    this.existingYear,
  });

  static Future<void> show(
    BuildContext context, {
    bool isDismissible = false,
    AcademicYear? existingYear,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) => ClassSetupDialog(
        isDismissible: isDismissible,
        existingYear: existingYear,
      ),
    );
  }

  @override
  ConsumerState<ClassSetupDialog> createState() => _ClassSetupDialogState();
}

class _ClassSetupDialogState extends ConsumerState<ClassSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _classNameController;
  late final TextEditingController _treasurerController;
  late final TextEditingController _supervisorController;
  late final TextEditingController _duesAmountController;
  int _selectedGrade = 7;
  String _selectedPeriodType = 'weekly';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final year = widget.existingYear;
    _classNameController = TextEditingController(
      text: year?.name ?? 'Kelas 7A - SMP Negeri 1',
    );
    _treasurerController = TextEditingController(
      text: year?.treasurerName ?? 'Fajar (Adik)',
    );
    _supervisorController = TextEditingController(
      text: year?.supervisorName ?? 'Ibu Rina (Pengawas)',
    );
    _duesAmountController = TextEditingController(
      text: year != null ? '${year.defaultDuesAmount}' : '5000',
    );
    _selectedGrade = year?.grade ?? 7;
    _selectedPeriodType = year?.duesPeriodType ?? 'weekly';
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _treasurerController.dispose();
    _supervisorController.dispose();
    _duesAmountController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, 7, 1);
      final endDate = DateTime(now.year + 1, 6, 30);
      final duesAmount = int.tryParse(_duesAmountController.text) ?? 5000;

      final repo = ref.read(academicYearRepoProvider);
      if (widget.existingYear != null) {
        await repo.updateAcademicYear(
          id: widget.existingYear!.id,
          name: _classNameController.text.trim(),
          grade: _selectedGrade,
          treasurerName: _treasurerController.text.trim(),
          supervisorName: _supervisorController.text.trim(),
          defaultDuesAmount: duesAmount,
          duesPeriodType: _selectedPeriodType,
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.brandPrimary,
              content: Text('Info kelas ${_classNameController.text.trim()} berhasil diperbarui!'),
            ),
          );
        }
      } else {
        await repo.createAcademicYear(
          name: _classNameController.text.trim(),
          grade: _selectedGrade,
          treasurerName: _treasurerController.text.trim(),
          supervisorName: _supervisorController.text.trim(),
          defaultDuesAmount: duesAmount,
          duesPeriodType: _selectedPeriodType,
          startDate: startDate,
          endDate: endDate,
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.brandPrimary,
              content: Text('Buku kas untuk ${_classNameController.text.trim()} berhasil dibuat!'),
            ),
          );
        }
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
    return PopScope(
      canPop: widget.isDismissible,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.school_rounded, color: AppColors.brandPrimary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingYear != null ? 'Ubah Info Kelas' : 'Pengaturan Buku Kas Kelas',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.existingYear != null
                                ? 'Perbarui identitas kelas, bendahara, dan pengawas'
                                : 'Masukkan identitas kelas awal Anda',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isDismissible)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Nama Kelas
                const Text(
                  'Nama Kelas',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _classNameController,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Kelas 7A - SMP Negeri 1',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama kelas wajib diisi' : null,
                ),
                const SizedBox(height: 14),

                // Tingkat Kelas
                const Text(
                  'Tingkat Kelas',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [7, 8, 9, 10, 11, 12].map((grade) {
                    final isSelected = _selectedGrade == grade;
                    return ChoiceChip(
                      label: Text('Kelas $grade'),
                      selected: isSelected,
                      selectedColor: AppColors.brandPrimary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedGrade = grade);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Nama Bendahara & Nama Ibu Pengawas
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nama Bendahara',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _treasurerController,
                            decoration: const InputDecoration(hintText: 'Nama Adik'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nama Pengawas',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _supervisorController,
                            decoration: const InputDecoration(hintText: 'Contoh: Pengawas / Orang Tua'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Frekuensi Pembayaran Kas (Harian, Mingguan, Bulanan)
                const Text(
                  'Frekuensi Pembayaran Kas',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    (label: 'Harian', value: 'daily'),
                    (label: 'Mingguan', value: 'weekly'),
                    (label: 'Bulanan', value: 'monthly'),
                  ].map((item) {
                    final isSelected = _selectedPeriodType == item.value;
                    return ChoiceChip(
                      label: Text(item.label),
                      selected: isSelected,
                      selectedColor: AppColors.brandPrimary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedPeriodType = item.value);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Nominal Kas Rutin
                Text(
                  _selectedPeriodType == 'daily'
                      ? 'Nominal Kas Harian (per siswa)'
                      : _selectedPeriodType == 'monthly'
                          ? 'Nominal Kas Bulanan (per siswa)'
                          : 'Nominal Kas Mingguan (per siswa)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _duesAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '5000',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Nominal wajib diisi';
                    final parsed = int.tryParse(v);
                    if (parsed == null || parsed <= 0) return 'Nominal tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Tombol Simpan
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          widget.existingYear != null ? 'Simpan Perubahan' : 'Simpan & Mulai Buku Kas',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
