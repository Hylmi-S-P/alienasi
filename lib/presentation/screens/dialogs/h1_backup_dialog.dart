import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../domain/services/csv_export_service.dart';
import '../../../domain/services/dues_arrears_service.dart';
import '../../../domain/services/excel_report_service.dart';
import '../../../domain/services/pdf_report_service.dart';
import '../../providers/app_providers.dart';

/// Dialog cadangan data yang dipicu tombol CTA pada banner H-1.
///
/// Menawarkan tiga jalur cadangan yang memakai utilitas ekspor yang sudah
/// ada (CSV, Excel, PDF) berikut cadangan JSON penuh lewat
/// [BackupRestoreDialog]. Tidak ada logika ekspor baru: dialog hanya
/// menyambungkan banner ke mesin yang sama dengan tab Laporan.
class H1BackupDialog extends ConsumerStatefulWidget {
  const H1BackupDialog({super.key, required this.academicYear});

  static Future<void> show(
    BuildContext context, {
    required AcademicYear academicYear,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => H1BackupDialog(academicYear: academicYear),
    );
  }

  final AcademicYear academicYear;

  @override
  ConsumerState<H1BackupDialog> createState() => _H1BackupDialogState();
}

class _H1BackupDialogState extends ConsumerState<H1BackupDialog> {
  bool _isGenerating = false;

  String get _cleanName => widget.academicYear.name
      .replaceAll(RegExp(r'[^\w\s]+'), '')
      .replaceAll(' ', '_');

  String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<List<TransactionWithCategory>> _loadAllTransactions() async {
    final txRepo = ref.read(transactionRepoProvider);
    return txRepo.getAllTransactions(academicYearId: widget.academicYear.id);
  }

  Future<void> _shareFile({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType, name: filename)],
        subject: filename,
      ),
    );
  }

  Future<void> _runExport(Future<void> Function() action) async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expenseText,
            content: Text('Gagal membuat berkas cadangan: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportPdf() async {
    final items = await _loadAllTransactions();
    final arrears = await _loadStudentArrears();

    final pdfBytes = await PdfReportService.generateReportPdf(
      academicYear: widget.academicYear,
      periodRangeTitle: 'Cadangan Penuh (Semua Transaksi)',
      items: items,
      studentArrears: arrears,
    );

    await _shareFile(
      bytes: pdfBytes,
      filename: 'Cadangan_Kas_${_cleanName}_${_dateStamp()}.pdf',
      mimeType: 'application/pdf',
    );
  }

  Future<List<StudentArrearsReportItem>> _loadStudentArrears() async {
    try {
      final db = ref.read(databaseProvider);
      final studentRepo = ref.read(studentRepoProvider);

      final students = await studentRepo.getStudents(widget.academicYear.id);
      final periods = await (db.select(
        db.duesPeriods,
      )..where((t) => t.academicYearId.equals(widget.academicYear.id))).get();
      final periodIds = periods.map((p) => p.id).toList();
      final payments = periodIds.isEmpty
          ? <DuesPayment>[]
          : await (db.select(
              db.duesPayments,
            )..where((t) => t.duesPeriodId.isIn(periodIds))).get();

      return DuesArrearsService().calculateArrears(
        students: students,
        academicYear: widget.academicYear,
        duesPeriods: periods,
        duesPayments: payments,
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> _exportCsv() async {
    final items = await _loadAllTransactions();
    final csvContent = CsvExportService.generateCsv(
      academicYear: widget.academicYear,
      items: items,
    );

    final tempDir = await getTemporaryDirectory();
    final filename = 'Cadangan_Kas_${_cleanName}_${_dateStamp()}.csv';
    final file = File('${tempDir.path}/$filename');
    // BOM UTF-8 agar Excel Windows membaca karakter Indonesia dengan benar.
    await file.writeAsString(
      '\u{FEFF}$csvContent',
      encoding: const Utf8Codec(),
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv', name: filename)],
        subject: filename,
      ),
    );
  }

  Future<void> _exportExcel() async {
    final items = await _loadAllTransactions();
    final studentSummaries = await _loadStudentSummaries();

    final excelBytes = ExcelReportService.generateExcel(
      academicYear: widget.academicYear,
      items: items,
      studentSummaries: studentSummaries,
    );

    await _shareFile(
      bytes: excelBytes,
      filename: 'Cadangan_Kas_${_cleanName}_${_dateStamp()}.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<List<StudentDuesReportSummary>> _loadStudentSummaries() async {
    final studentRepo = ref.read(studentRepoProvider);
    final db = ref.read(databaseProvider);

    final students = await studentRepo.getStudents(widget.academicYear.id);
    final periods = await (db.select(
      db.duesPeriods,
    )..where((t) => t.academicYearId.equals(widget.academicYear.id))).get();

    final periodIds = periods.map((p) => p.id).toList();
    final allPayments = periodIds.isEmpty
        ? <DuesPayment>[]
        : await (db.select(
            db.duesPayments,
          )..where((t) => t.duesPeriodId.isIn(periodIds))).get();

    final summaries = <StudentDuesReportSummary>[];
    for (final s in students) {
      final studentPayments = allPayments
          .where((p) => p.studentId == s.id)
          .toList();
      var totalPaid = 0;
      var paidPeriodsCount = 0;
      for (final p in studentPayments) {
        if (p.isPaid) {
          paidPeriodsCount++;
          totalPaid += p.amountPaid;
        }
      }
      final isAllPaid =
          periods.isNotEmpty && paidPeriodsCount >= periods.length;
      summaries.add(
        StudentDuesReportSummary(
          attendanceNumber: s.attendanceNumber,
          name: s.name,
          totalPaid: totalPaid,
          isAllPaid: isAllPaid,
        ),
      );
    }
    return summaries;
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
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.warningText,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cadangkan Data Segera',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Lisensi berakhir dalam waktu kurang dari 24 jam.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildExportTile(
              icon: Icons.picture_as_pdf_outlined,
              color: AppColors.expenseText,
              title: 'Laporan PDF (Semua Transaksi)',
              description: 'Dokumen pertanggungjawaban lengkap dengan rekap tunggakan, siap dikirim ke Ibu.',
              label: 'Simpan PDF',
              onTap: _exportPdf,
            ),
            const SizedBox(height: 10),
            _buildExportTile(
              icon: Icons.grid_on_outlined,
              color: AppColors.brandPrimary,
              title: 'Berkas Excel (Buku Kas)',
              description: 'Spreadsheet buku kas umum dan rekap pembayaran siswa per periode.',
              label: 'Simpan Excel',
              onTap: _exportExcel,
            ),
            const SizedBox(height: 10),
            _buildExportTile(
              icon: Icons.table_view_outlined,
              color: const Color(0xFF2563EB),
              title: 'Berkas CSV (Buku Kas)',
              description: 'Tabel kas ringkas yang bisa dibuka di Excel atau Google Sheets.',
              label: 'Simpan CSV',
              onTap: _exportCsv,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportTile({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required String label,
    required Future<void> Function() onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download_outlined, size: 18),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _isGenerating ? null : () => _runExport(onTap),
            ),
          ),
        ],
      ),
    );
  }
}
