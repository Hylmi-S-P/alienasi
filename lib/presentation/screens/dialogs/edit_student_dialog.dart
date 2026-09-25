import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../guards/mutation_guard.dart';
import '../../providers/app_providers.dart';

class EditStudentDialog extends ConsumerStatefulWidget {
  final Student student;
  final String academicYearId;
  final VoidCallback? onDeleted;

  const EditStudentDialog({
    super.key,
    required this.student,
    required this.academicYearId,
    this.onDeleted,
  });

  static Future<void> show(
    BuildContext context, {
    required Student student,
    required String academicYearId,
    VoidCallback? onDeleted,
  }) {
    return showDialog(
      context: context,
      builder: (context) => EditStudentDialog(
        student: student,
        academicYearId: academicYearId,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  ConsumerState<EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends ConsumerState<EditStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.name);
    _numberController = TextEditingController(text: '${widget.student.attendanceNumber}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final number = int.tryParse(_numberController.text) ?? widget.student.attendanceNumber;
    if (number <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.expenseText,
          content: Text('Nomor absen harus lebih dari 0'),
        ),
      );
      return;
    }

    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Explore-first gating: mengubah data siswa adalah aksi mutasi.
      bool persisted = false;
      final allowed = await runMutationWithGuard(
        context,
        ref,
        mutationLabel: 'Mengubah data siswa membutuhkan lisensi aktif.',
        onAllowed: () async {
          persisted = await _persistUpdate(trimmedName);
        },
      );
      if (!allowed || !persisted) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.brandPrimary,
            content: Text('Data $trimmedName berhasil diperbarui.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.expenseText, content: Text('Galat: $e')),
        );
      }
    }
  }

  Future<bool> _persistUpdate(String trimmedName) async {
    final repo = ref.read(studentRepoProvider);
    final number = int.tryParse(_numberController.text) ?? widget.student.attendanceNumber;

    // 1. Cek bentrok nomor absen dengan siswa lain
    final isNumberTaken = await repo.isAttendanceNumberTakenExcluding(
      academicYearId: widget.academicYearId,
      attendanceNumber: number,
      excludeStudentId: widget.student.id,
    );

    if (isNumberTaken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expenseText,
            content: Text('Nomor absen $number sudah digunakan oleh siswa lain.'),
          ),
        );
      }
      return false;
    }

    // 2. Cek nama siswa kembar
    final isNameTaken = await repo.isStudentNameTakenExcluding(
      academicYearId: widget.academicYearId,
      name: trimmedName,
      excludeStudentId: widget.student.id,
    );

    if (isNameTaken && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nama Siswa Sama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text('Siswa lain dengan nama "$trimmedName" sudah ada di kelas ini. Tetap simpan perubahan?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tetap Simpan'),
            ),
          ],
        ),
      );
      if (confirm != true) {
        return false;
      }
    }

    // 3. Simpan pembaruan
    await repo.updateStudent(
      studentId: widget.student.id,
      attendanceNumber: number,
      name: trimmedName,
    );
    return true;
  }

  Future<void> _handleDelete() async {
    final repo = ref.read(studentRepoProvider);
    final paidTotal = await repo.getStudentPaidTotal(widget.student.id);

    if (!mounted) return;

    final isHardDelete = paidTotal == 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isHardDelete ? Icons.delete_forever_rounded : Icons.person_remove_rounded,
              color: AppColors.expenseText,
            ),
            const SizedBox(width: 8),
            Text(
              isHardDelete ? 'Hapus Siswa?' : 'Keluarkan Siswa?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          isHardDelete
              ? 'Siswa "${widget.student.name}" (Absen ${widget.student.attendanceNumber}) belum memiliki catatan pembayaran kas.\n\nData siswa ini akan dihapus secara permanen dari kelas.'
              : 'Siswa "${widget.student.name}" (Absen ${widget.student.attendanceNumber}) telah memiliki riwayat setoran kas sebesar ${CurrencyFormatter.format(paidTotal)}.\n\nUang kas yang sudah disetor tetap aman di saldo kas kelas. Siswa ini akan dinonaktifkan dari daftar absen aktif dan tidak akan ditagih di periode kas mendatang.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isHardDelete ? 'Hapus Permanen' : 'Nonaktifkan Siswa'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Explore-first gating: menghapus/menonaktifkan siswa adalah mutasi.
    final allowed = await runMutationWithGuard(
      context,
      ref,
      mutationLabel: 'Menghapus siswa membutuhkan lisensi aktif.',
      onAllowed: () async {
        await _performDelete();
      },
    );
    if (!allowed) return;
  }

  Future<void> _performDelete() async {
    setState(() => _isLoading = true);
    try {
      final wasHardDeleted =
          await ref.read(studentRepoProvider).deleteStudent(studentId: widget.student.id);
      widget.onDeleted?.call();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: wasHardDeleted ? AppColors.brandPrimary : const Color(0xFFD97706),
            content: Text(
              wasHardDeleted
                  ? 'Siswa ${widget.student.name} berhasil dihapus.'
                  : 'Siswa ${widget.student.name} dinonaktifkan. Riwayat kas tetap terjaga.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.expenseText, content: Text('Galat menghapus siswa: $e')),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: AppColors.brandPrimary, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Edit Data Siswa',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nomor Absen
              TextFormField(
                controller: _numberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nomor Absen',
                  hintText: 'Contoh: 1',
                  prefixIcon: Icon(Icons.format_list_numbered_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Nomor absen wajib diisi';
                  final n = int.tryParse(val.trim());
                  if (n == null || n <= 0) return 'Nomor absen harus angka > 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Nama Siswa
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap Siswa',
                  hintText: 'Contoh: Ahmad Dahlan',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Nama siswa wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Tombol Simpan
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Simpan Perubahan'),
              ),
              const SizedBox(height: 10),

              // Tombol Hapus Siswa
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.expenseText,
                  minimumSize: const Size.fromHeight(42),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text(
                  'Hapus / Keluarkan Siswa',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: _isLoading ? null : _handleDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
