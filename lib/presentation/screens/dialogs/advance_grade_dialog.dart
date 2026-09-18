import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/database/app_database.dart';
import '../../providers/app_providers.dart';

class AdvanceGradeDialog extends ConsumerStatefulWidget {
  final AcademicYear currentYear;

  const AdvanceGradeDialog({super.key, required this.currentYear});

  static Future<void> show(BuildContext context, AcademicYear currentYear) {
    return showDialog(
      context: context,
      builder: (context) => AdvanceGradeDialog(currentYear: currentYear),
    );
  }

  @override
  ConsumerState<AdvanceGradeDialog> createState() => _AdvanceGradeDialogState();
}

class _AdvanceGradeDialogState extends ConsumerState<AdvanceGradeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _classNameController;
  late int _nextGrade;
  bool _copyStudents = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nextGrade = widget.currentYear.grade + 1;
    final nextYearStart = widget.currentYear.endDate.year;
    final nextYearEnd = nextYearStart + 1;
    _classNameController = TextEditingController(
      text: 'Kelas $_nextGrade - SMP Negeri 1 ($nextYearStart/$nextYearEnd)',
    );
  }

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }

  Future<void> _handleAdvance() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final nextYearStart = widget.currentYear.endDate.year;
      final startDate = DateTime(nextYearStart, 7, 1);
      final endDate = DateTime(nextYearStart + 1, 6, 30);

      final newYear = await ref.read(academicYearRepoProvider).advanceToNewGrade(
            newClassName: _classNameController.text.trim(),
            newGrade: _nextGrade,
            startDate: startDate,
            endDate: endDate,
          );

      if (_copyStudents) {
        await ref.read(studentRepoProvider).copyStudentsToAcademicYear(
              sourceAcademicYearId: widget.currentYear.id,
              targetAcademicYearId: newYear.id,
            );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.brandPrimary,
            content: Text('Selamat naik ke ${_classNameController.text.trim()}! Riwayat kelas lama tersimpan aman.'),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
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
                      color: AppColors.incomeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.upgrade_rounded, color: AppColors.incomeText, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Buka Periode Kenaikan Kelas',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Alert Box Keamanan Data Historis
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slateTag,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.brandPrimary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Seluruh catatan transaksi dan laporan pada ${widget.currentYear.name} akan tetap tersimpan abadi dan tidak akan hilang atau tertimpa.',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Nama Kelas Baru',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _classNameController,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Kelas 8A - SMP Negeri 1',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama kelas baru wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                value: _copyStudents,
                onChanged: (val) => setState(() => _copyStudents = val ?? true),
                title: const Text(
                  'Salin daftar siswa dari kelas saat ini',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Nama dan nomor absen siswa akan disalin ke kelas baru agar tidak perlu mengetik ulang.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleAdvance,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Buka Periode Kelas Baru'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
