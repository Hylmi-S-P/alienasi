import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Dialog untuk meminta catatan bendahara sebelum laporan diekspor.
///
/// Mengembalikan:
/// - `null` jika pengguna membatalkan ekspor.
/// - `''` (string kosong) jika pengguna melewati tanpa mengisi catatan.
/// - teks catatan jika pengguna mengisi dan menekan "Sertakan Catatan".
class ReportNoteDialog extends StatefulWidget {
  final String rangeTitle;

  const ReportNoteDialog({super.key, required this.rangeTitle});

  static Future<String?> show(
    BuildContext context, {
    required String rangeTitle,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ReportNoteDialog(rangeTitle: rangeTitle),
    );
  }

  @override
  State<ReportNoteDialog> createState() => _ReportNoteDialogState();
}

class _ReportNoteDialogState extends State<ReportNoteDialog> {
  final _controller = TextEditingController();
  static const int _maxLength = 1200;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteText = _controller.text.trim();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    Icons.edit_note_rounded,
                    color: AppColors.warningText,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Catatan Bendahara',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  tooltip: 'Batal',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Catatan ini akan dicetak di bagian bawah laporan: ${widget.rangeTitle}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLines: 6,
              minLines: 4,
              maxLength: _maxLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Contoh: Sisa kas dititipkan ke bendahara baru. '
                    'Terdapat 2 siswa yang masih menunggak dan akan dilunasi bulan depan.',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35),
                counterStyle: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: AppColors.brandPrimary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Catatan bersifat opsional. Kosongkan jika tidak ada hal khusus yang perlu disampaikan.',
                      style: TextStyle(fontSize: 11, color: AppColors.brandPrimary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(''),
                    child: const Text('Lewati', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    // Tombol utama SELALU aktif. Sebelumnya tombol ini mati
                    // saat catatan kosong sehingga pengguna yang tidak ingin
                    // menulis catatan merasa ekspor tidak bisa dilanjutkan.
                    onPressed: () => Navigator.of(context).pop(noteText),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        noteText.isEmpty ? 'Lanjutkan Ekspor' : 'Sertakan Catatan',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
