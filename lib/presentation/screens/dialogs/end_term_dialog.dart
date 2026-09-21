import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/services/backup_restore_service.dart';
import '../../../domain/services/dues_arrears_service.dart';
import '../../../domain/services/pdf_report_service.dart';
import '../../providers/app_providers.dart';
import 'report_note_dialog.dart';

/// Dialog "Akhiri Jabatan": memandu bendahara mengamankan seluruh data kelas
/// (PDF laporan lengkap + berkas cadangan JSON) sebelum aplikasi direset
/// ke kondisi baru (fresh onboarding).
class EndTermDialog extends ConsumerStatefulWidget {
  final AcademicYear academicYear;

  const EndTermDialog({super.key, required this.academicYear});

  static Future<void> show(
    BuildContext context, {
    required AcademicYear academicYear,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EndTermDialog(academicYear: academicYear),
    );
  }

  @override
  ConsumerState<EndTermDialog> createState() => _EndTermDialogState();
}

enum _TermStep { intro, working, pdfShare, jsonShare, confirmWipe, done }

class _EndTermDialogState extends ConsumerState<EndTermDialog> {
  _TermStep _step = _TermStep.intro;
  String? _error;

  // Jalur file sementara yang telah dibuat
  File? _pdfFile;
  File? _jsonFile;
  String _jsonFilename = '';

  // Statistik untuk ditampilkan
  int _txCount = 0;
  int _studentCount = 0;
  int _periodCount = 0;
  int _balance = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final txRepo = ref.read(transactionRepoProvider);
      final studentRepo = ref.read(studentRepoProvider);
      final db = ref.read(databaseProvider);

      final txs = await txRepo.getAllTransactions(academicYearId: widget.academicYear.id);
      final students = await studentRepo.getStudents(
        widget.academicYear.id,
        onlyActive: false,
      );
      final periods = await (db.select(db.duesPeriods)
            ..where((t) => t.academicYearId.equals(widget.academicYear.id)))
          .get();

      var balance = 0;
      for (final t in txs) {
        balance += t.transaction.type == 'income' ? t.transaction.amount : -t.transaction.amount;
      }

      setState(() {
        _txCount = txs.length;
        _studentCount = students.length;
        _periodCount = periods.length;
        _balance = balance;
      });
    } catch (_) {
      // Statistik bersifat informatif; biarkan 0 jika gagal dimuat.
    }
  }

  Future<void> _startBackup() async {
    setState(() {
      _step = _TermStep.working;
      _error = null;
    });

    try {
      final txRepo = ref.read(transactionRepoProvider);
      final studentRepo = ref.read(studentRepoProvider);
      final db = ref.read(databaseProvider);

      // ===== 1. PDF Laporan Lengkap (seluruh rentang) =====
      final txItems = await txRepo.getAllTransactions(academicYearId: widget.academicYear.id);

      final students = await studentRepo.getStudents(widget.academicYear.id);
      final periods = await (db.select(db.duesPeriods)
            ..where((t) => t.academicYearId.equals(widget.academicYear.id)))
          .get();
      final periodIds = periods.map((p) => p.id).toList();
      final allPayments = periodIds.isEmpty
          ? <DuesPayment>[]
          : await (db.select(db.duesPayments)
                ..where((t) => t.duesPeriodId.isIn(periodIds)))
              .get();

      final arrears = const DuesArrearsService().calculateArrears(
        students: students,
        academicYear: widget.academicYear,
        duesPeriods: periods,
        duesPayments: allPayments,
      );

      if (!mounted) return;
      final note = await ReportNoteDialog.show(
        context,
        rangeTitle: 'Laporan Akhir Jabatan (Seluruh Periode)',
      );
      if (!mounted) return;
      if (note == null) return; // batal seluruh proses

      final pdfBytes = await PdfReportService.generateReportPdf(
        academicYear: widget.academicYear,
        periodRangeTitle: 'Laporan Akhir - Seluruh Periode Jabatan',
        items: txItems,
        studentArrears: arrears,
        customNote: note,
      );

      final tempDir = await getTemporaryDirectory();
      final cleanName = widget.academicYear.name
          .replaceAll(RegExp(r'[^\w\s]+'), '')
          .replaceAll(' ', '_');
      final pdfFile = File('${tempDir.path}/Laporan_Akhir_$cleanName.pdf');
      await pdfFile.writeAsBytes(pdfBytes, flush: true);

      if (!mounted) return;
      setState(() {
        _pdfFile = pdfFile;
        _step = _TermStep.pdfShare;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _TermStep.intro;
          _error = 'Gagal membuat PDF laporan: $e';
        });
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfFile == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_pdfFile!.path, mimeType: 'application/pdf')],
          subject: 'Laporan Akhir Kas - ${widget.academicYear.name}',
        ),
      );
    } catch (_) {
      // User boleh membatalkan share sheet; tetap lanjut ke tahap berikutnya.
    }
    if (mounted) {
      setState(() => _step = _TermStep.working);
      await _prepareJsonBackup();
    }
  }

  Future<void> _prepareJsonBackup() async {
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
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      _jsonFilename = 'Cadangan_Kas_${cleanName}_$dateStr.json';

      final tempDir = await getTemporaryDirectory();
      final jsonFile = File('${tempDir.path}/$_jsonFilename');
      await jsonFile.writeAsString(jsonString, encoding: utf8, flush: true);

      if (!mounted) return;
      setState(() {
        _jsonFile = jsonFile;
        _step = _TermStep.jsonShare;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _TermStep.intro;
          _error = 'Gagal membuat berkas cadangan: $e';
        });
      }
    }
  }

  Future<void> _shareJson() async {
    if (_jsonFile == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(_jsonFile!.path, mimeType: 'application/json', name: _jsonFilename),
          ],
          subject: 'Cadangan Kas Kelas - ${widget.academicYear.name}',
        ),
      );
    } catch (_) {
      // User boleh membatalkan share sheet; tetap lanjut ke tahap konfirmasi.
    }
    if (mounted) {
      setState(() => _step = _TermStep.confirmWipe);
    }
  }

  Future<void> _executeWipe() async {
    setState(() => _step = _TermStep.working);
    try {
      final db = ref.read(databaseProvider);
      await db.clearAllData();

      // Invalidate seluruh provider reaktif agar UI kembali ke onboarding.
      ref.invalidate(activeAcademicYearProvider);
      ref.invalidate(allAcademicYearsProvider);
      ref.invalidate(balanceStatsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(reportTransactionsProvider);
      ref.invalidate(currentDuesPeriodProvider);
      ref.invalidate(currentPeriodSummaryProvider);
      ref.invalidate(selectedReportRangeProvider);
      ref.invalidate(selectedReportYearIdProvider);

      if (!mounted) return;
      setState(() => _step = _TermStep.done);
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _TermStep.confirmWipe;
          _error = 'Gagal mereset data: $e';
        });
      }
    }
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.expenseBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.expenseText, height: 1.35),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              switch (_step) {
                _TermStep.intro => _buildIntro(),
                _TermStep.working => _buildWorking(),
                _TermStep.pdfShare => _buildPdfShare(),
                _TermStep.jsonShare => _buildJsonShare(),
                _TermStep.confirmWipe => _buildConfirmWipe(),
                _TermStep.done => _buildDone(),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _step == _TermStep.done ? AppColors.incomeBg : AppColors.expenseBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _step == _TermStep.done ? Icons.check_circle_rounded : Icons.flag_rounded,
            color: _step == _TermStep.done ? AppColors.incomeText : AppColors.expenseText,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Akhiri Jabatan Bendahara',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ),
        if (_step != _TermStep.done)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
            tooltip: 'Tutup',
            onPressed: _step == _TermStep.working ? null : _close,
          ),
      ],
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fitur ini untuk penyerahan tugas: lulus, digantikan, atau pergantian periode. '
          'Seluruh data kelas akan diamankan menjadi 2 berkas, lalu aplikasi direset ke kondisi baru.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.canvasLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              _buildStatRow('Kelas', widget.academicYear.name),
              _buildStatRow('Siswa Terdaftar', '$_studentCount Siswa'),
              _buildStatRow('Total Transaksi', '$_txCount Transaksi'),
              _buildStatRow('Periode Kas', '$_periodCount Periode'),
              _buildStatRow(
                'Saldo Kas Saat Ini',
                CurrencyFormatter.format(_balance),
                isBold: true,
                color: _balance >= 0 ? AppColors.incomeText : AppColors.expenseText,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warningBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warningText),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Setelah reset, data di aplikasi ini terhapus permanen dan tidak bisa dikembalikan '
                  'kecuali lewat berkas cadangan yang Anda simpan. Pastikan kedua berkas tersimpan '
                  'aman di Google Drive, WhatsApp, atau memori HP.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.warningText,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.backup_rounded, size: 18),
            label: const Text(
              'Mulai Pengamanan Data',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: _startBackup,
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, {bool isBold = false, Color? color}) {
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
              overflow: TextOverflow.ellipsis,
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

  Widget _buildWorking() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.brandPrimary),
            SizedBox(height: 14),
            Text(
              'Menyiapkan berkas pengamanan data...',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int current, int total, String label, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.brandPrimary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$current/$total',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileActionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onPressed,
            child: Text(buttonLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfShare() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicator(
          1,
          2,
          'Simpan PDF Laporan Lengkap',
          'Berkas PDF berisi seluruh transaksi dari awal hingga akhir, audit tunggakan, dan catatan penyerahan Anda. '
          'Ketuk "Simpan" lalu pilih Google Drive, WhatsApp, atau Simpan ke Perangkat.',
        ),
        const SizedBox(height: 14),
        _buildFileActionRow(
          icon: Icons.picture_as_pdf_rounded,
          iconColor: AppColors.expenseText,
          title: 'Laporan_Akhir_${widget.academicYear.name}',
          subtitle: 'PDF laporan pertanggungjawaban lengkap',
          buttonLabel: 'Simpan',
          onPressed: _sharePdf,
        ),
        const SizedBox(height: 12),
        const Text(
          'Sudah tersimpan? Lanjut ke berkas cadangan berikutnya.',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildJsonShare() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicator(
          2,
          2,
          'Simpan Berkas Cadangan Data (JSON)',
          'Berkas ini berisi seluruh data mentah (siswa, transaksi, periode kas, pembayaran). '
          'Bisa dipulihkan kembali lewat menu Cadangkan & Pulihkan jika suatu saat diperlukan.',
        ),
        const SizedBox(height: 14),
        _buildFileActionRow(
          icon: Icons.data_object_rounded,
          iconColor: const Color(0xFF2563EB),
          title: _jsonFilename,
          subtitle: 'Cadangan data lengkap format JSON',
          buttonLabel: 'Simpan',
          onPressed: _shareJson,
        ),
        const SizedBox(height: 12),
        const Text(
          'Sudah tersimpan? Lanjut ke konfirmasi reset data.',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildConfirmWipe() {
    return const _ConfirmWipeStep();
  }

  Widget _buildDone() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.incomeBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_rounded,
            color: AppColors.incomeText,
            size: 36,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Jabatan Berakhir',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Seluruh data telah dihapus dan aplikasi kembali ke kondisi baru. '
          'Bendahara berikutnya dapat mulai mengatur kelas dari awal. '
          'Terima kasih atas tanggung jawab Anda!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _close,
            child: const Text(
              'Selesai',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tahap konfirmasi akhir: pengguna harus mengetik "HAPUS" untuk mengeksekusi reset.
class _ConfirmWipeStep extends StatefulWidget {
  const _ConfirmWipeStep();

  @override
  State<_ConfirmWipeStep> createState() => _ConfirmWipeStepState();
}

class _ConfirmWipeStepState extends State<_ConfirmWipeStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isConfirmed => _controller.text.trim().toUpperCase() == 'HAPUS';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kedua berkas pengaman sudah dibuat. Sebelum melanjutkan, pastikan Anda sudah menyalinnya '
          'ke tempat aman (Google Drive / WhatsApp / galeri HP).',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.expenseBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.delete_forever_rounded, size: 18, color: AppColors.expenseText),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tindakan ini menghapus PERMANEN seluruh siswa, transaksi, periode kas, dan pengaturan '
                  'kelas dari aplikasi ini. Ketik HAPUS (huruf besar) untuk melanjutkan.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.expenseText, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Ketik HAPUS di sini',
            hintStyle: TextStyle(fontSize: 12.5),
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text(
              'Hapus Semua Data & Akhiri Jabatan',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            onPressed: _isConfirmed
                ? () => (context.findAncestorStateOfType<_EndTermDialogState>())?._executeWipe()
                : null,
          ),
        ),
      ],
    );
  }
}
