import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/update/update_manifest.dart';
import '../providers/update_notifier.dart';
import '../screens/dialogs/update_check_sheet.dart';

/// Banner pembaruan aplikasi di Dashboard.
///
/// Tampil hanya bila manifest server menyatakan versi lebih baru, dan
/// menampilkan versi terbaru + tombol untuk membuka sheet pembaruan.
/// Banner dapat ditutup per sesi dan muncul kembali saat aplikasi
/// dimulai ulang.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key, required this.manifest});

  final UpdateManifest manifest;

  /// Status dismiss banner per sesi aplikasi.
  static final updateBannerDismissedProvider = NotifierProvider<
      _UpdateBannerDismissedNotifier, bool>(
    _UpdateBannerDismissedNotifier.new,
  );

  static Widget? maybeBuild(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(updateBannerDismissedProvider);
    if (dismissed) return null;

    final updateState = ref.watch(updateNotifierProvider);
    if (updateState.status != UpdateStatus.available) return null;

    final manifest = updateState.manifest;
    if (manifest == null) return null;

    return UpdateBanner(manifest: manifest);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.system_update_alt_rounded,
            color: AppColors.brandPrimary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Versi baru tersedia',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Perbarui ke ${manifest.latestVersion} untuk mendapat '
                  'perbaikan terbaru.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              UpdateCheckSheet.show(context);
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(48, 40),
            ),
            child: const Text(
              'Perbarui',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
            tooltip: 'Tutup notifikasi pembaruan',
            onPressed: () {
              ref
                  .read(updateBannerDismissedProvider.notifier)
                  .dismiss();
            },
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _UpdateBannerDismissedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}
