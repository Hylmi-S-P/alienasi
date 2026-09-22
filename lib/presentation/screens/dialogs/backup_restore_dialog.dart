import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/services/backup_restore_service.dart';
import '../../providers/app_providers.dart';

class BackupRestoreDialog extends ConsumerStatefulWidget {
  final AcademicYear academicYear;

  const BackupRestoreDialog({
    super.key,
    required this.academicYear,
  });

  static Future<void> show(
    BuildContext context, {
    required AcademicYear academicYear,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BackupRestoreDialog(academicYear: academicYear),
    );
  }

  @override
  ConsumerState<BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends ConsumerState<BackupRestoreDialog> {
  bool _isBackingUp = false;
  bool _isRestoring = false;

  Future<void> _handleBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final db = ref.read(databaseProvider);
      final jsonString = await BackupRestoreService.createBackupJson(
        db: db,
        academicYearId: widget.academicYear.id,
      );

      final cleanName = widget.academicYear.name
          .replaceAll(RegExp(r'[^\w\s]+'), '')
          .replaceAll(' ', '_');
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'Cadangan_Kas_${cleanName}_$dateStr.json';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(jsonString, encoding: utf8);

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'application/json',
              name: filename,
            ),
          ],
          subject: 'Cadangan Kas Kelas - ${widget.academicYear.name}',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.incomeText,
            content: Text('Berkas cadangan berhasil disiapkan & siap disimpan.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expenseText,
            content: Text('Gagal mencadangkan data: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handlePickAndRestore() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (pickedFiles.isEmpty) {
        return;
      }

      final path = pickedFiles.first.path;
      if (path == null) {
        throw Exception('Path berkas cadangan tidak dapat diakses.');
      }

      final file = File(path);
      final jsonContent = await file.readAsString();

      // Validasi dan ambil ringkasan data sebelum konfirmasi
      final preview = BackupRestoreService.parseAndPreview(jsonContent);

      if (!mounted) return;
      await _showRestoreConfirmationDialog(preview, jsonContent);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expenseText,
            content: Text('Gagal membaca berkas cadangan: $e'),
          ),
        );
      }
    }
  }

  Future<void> _showRestoreConfirmationDialog(
    BackupPreviewData preview,
    String jsonString,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.expenseBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.expenseText,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Konfirmasi Pemulihan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Periksa data cadangan di bawah ini sebelum memulihkan:',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.canvasLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      _buildPreviewRow('Kelas', preview.academicYearName),
                      _buildPreviewRow('Tahun Ajaran', preview.schoolYear),
                      _buildPreviewRow('Bendahara', preview.treasurerName),
                      _buildPreviewRow('Jumlah Siswa', '${preview.studentsCount} Siswa'),
                      _buildPreviewRow('Total Transaksi', '${preview.transactionsCount} Transaksi'),
                      _buildPreviewRow('Periode Kas', '${preview.periodsCount} Periode'),
                      _buildPreviewRow('Foto Nota Tersertakan', '${preview.receiptsCount} Foto'),
                      _buildPreviewRow(
                        'Total Saldo',
                        CurrencyFormatter.format(preview.totalBalance),
                        isBold: true,
                        color: preview.totalBalance >= 0 ? AppColors.incomeText : AppColors.expenseText,
                      ),
                      _buildPreviewRow(
                        'Dicadangkan Pada',
                        DateFormatter.toHumanDate(preview.exportedAt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Peringatan: Pemulihan akan menggantikan data kas, siswa, dan transaksi kelas saat ini dengan isi cadangan.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.amber.shade900,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expenseText,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Pulihkan Sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _executeRestore(jsonString);
    }
  }

  Widget _buildPreviewRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeRestore(String jsonString) async {
    setState(() => _isRestoring = true);
    try {
      final db = ref.read(databaseProvider);
      await BackupRestoreService.restoreFromBackupJson(
        db: db,
        jsonString: jsonString,
      );

      // Invalidate semua provider agar UI segera diperbarui
      ref.invalidate(activeAcademicYearProvider);
      ref.invalidate(allAcademicYearsProvider);
      ref.invalidate(balanceStatsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(currentPeriodSummaryProvider);
      ref.invalidate(reportTransactionsProvider);

      if (mounted) {
        Navigator.of(context).pop(); // Tutup dialog utama
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.incomeText,
            content: Text('Data berhasil dipulihkan secara utuh!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expenseText,
            content: Text('Gagal memulihkan basis data: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Dialog
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.cloud_sync_rounded,
                    color: AppColors.brandPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cadangkan & Pulihkan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelas: ${widget.academicYear.name}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Card 1: Cadangkan Data
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.upload_file_rounded, color: AppColors.brandPrimary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Cadangkan Data (Backup)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Simpan berkas .json berisi seluruh rekaman kas, siswa, dan transaksi kelas untuk diamankan ke Google Drive atau WhatsApp.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: _isBackingUp
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.file_download_outlined, size: 18),
                      label: Text(
                        _isBackingUp ? 'Menyiapkan Cadangan...' : 'Cadangkan Data Sekarang',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      onPressed: (_isBackingUp || _isRestoring) ? null : _handleBackup,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Card 2: Pulihkan Data
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF2563EB), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Pulihkan Data (Restore)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Impor berkas cadangan .json yang pernah Anda simpan untuk memulihkan seluruh data kelas.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: _isRestoring
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                            )
                          : const Icon(Icons.file_upload_outlined, size: 18),
                      label: Text(
                        _isRestoring ? 'Memulihkan Basis Data...' : 'Pilih Berkas Cadangan (.json)',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      onPressed: (_isBackingUp || _isRestoring) ? null : _handlePickAndRestore,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
