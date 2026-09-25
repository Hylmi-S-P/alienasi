import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../guards/mutation_guard.dart';
import '../../providers/app_providers.dart';

class NewStudentDialog extends ConsumerStatefulWidget {
  final String academicYearId;
  final int defaultAttendanceNumber;

  const NewStudentDialog({
    super.key,
    required this.academicYearId,
    required this.defaultAttendanceNumber,
  });

  static Future<void> show(BuildContext context, String academicYearId, int defaultAttendanceNumber) {
    return showDialog(
      context: context,
      builder: (context) => NewStudentDialog(
        academicYearId: academicYearId,
        defaultAttendanceNumber: defaultAttendanceNumber,
      ),
    );
  }

  @override
  ConsumerState<NewStudentDialog> createState() => _NewStudentDialogState();
}

class _NewStudentDialogState extends ConsumerState<NewStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _numberController = TextEditingController(text: '${widget.defaultAttendanceNumber}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final number = int.tryParse(_numberController.text) ?? widget.defaultAttendanceNumber;
    if (number <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.expenseText,
          content: Text('Nomor absen harus lebih dari 0'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Explore-first gating: menambah siswa adalah aksi mutasi.
      bool persisted = false;
      final allowed = await runMutationWithGuard(
        context,
        ref,
        mutationLabel: 'Menambah siswa membutuhkan lisensi aktif.',
        onAllowed: () async {
          persisted = await _persistStudent();
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
            content: Text('${_nameController.text.trim()} berhasil ditambahkan.'),
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

  /// Menambah siswa dan mengembalikan true bila data benar-benar tersimpan.
  Future<bool> _persistStudent() async {
    final repo = ref.read(studentRepoProvider);

    final number = int.tryParse(_numberController.text) ?? widget.defaultAttendanceNumber;
    final isNumberTaken = await repo.isAttendanceNumberTaken(      academicYearId: widget.academicYearId,
      attendanceNumber: number,
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

    final isNameTaken = await repo.isStudentNameTaken(
      academicYearId: widget.academicYearId,
      name: _nameController.text.trim(),
    );
    if (isNameTaken && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nama Siswa Sama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text('Siswa dengan nama "${_nameController.text.trim()}" sudah ada di kelas ini. Tetap tambahkan?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tetap Tambahkan'),
            ),
          ],
        ),
      );
      if (confirm != true) {
        return false;
      }
    }

    await repo.addStudent(
      academicYearId: widget.academicYearId,
      attendanceNumber: number,
      name: _nameController.text.trim(),
    );
    return true;
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tambah Siswa Baru',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Nomor Absen', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _numberController,
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              const Text('Nama Lengkap Siswa', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Contoh: Bagas Pratama'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Simpan Siswa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
