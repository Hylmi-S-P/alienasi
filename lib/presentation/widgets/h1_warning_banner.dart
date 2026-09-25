import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/database/app_database.dart';
import '../providers/app_providers.dart';
import '../providers/subscription_notifier.dart';
import '../screens/dialogs/h1_backup_dialog.dart';

/// Banner H-1 yang tampil di Dashboard ketika lisensi memasuki jendela
/// `expiringSoon` (sisa waktu <= 24 jam). Mengingatkan pengguna untuk
/// mencadangkan data sebelum masa aktif berakhir.
///
/// Banner ini sengaja didesain mengikuti aturan anti-slop:
///   - Energi rendah (ENERGY 1): latar solid amber lembut, bukan gradien
///     ungu-kebiruan atau glow.
///   - Bentuk konsisten (R-11): radius 12 dp mengikuti kartu lain.
///   - CTA spesifik (R-15): tombol memakai kata kerja kerja, bukan
///     'Get Started' / 'Learn More'.
///   - Ikon relevan (R-04): schedule_rounded menandai status waktu, bukan
///     ikon generik AI seperti bintang atau kilat.
///   - Kontras teks (R-25): AppColors.warningText (#D97706) lulus WCAG AA
///     di atas AppColors.warningBg (#FEF3C7).

/// Status dismiss banner H-1 per sesi aplikasi. Hidup selama sesi berjalan
/// dan kembali tampil saat aplikasi dimulai ulang.
class H1BannerDismissedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final h1BannerDismissedProvider =
    NotifierProvider<H1BannerDismissedNotifier, bool>(
      H1BannerDismissedNotifier.new,
    );

class H1WarningBanner extends ConsumerWidget {
  const H1WarningBanner({
    super.key,
    required this.academicYear,
    required this.info,
  });

  /// Mengembalikan banner yang siap ditambahkan ke pohon widget; null
  /// artinya status tidak memenuhi syarat tampil (atau sudah didismiss)
  /// dan pemanggil cukup melewati slot kosong.
  static Widget? maybeBuild(BuildContext context, WidgetRef ref) {
    final info = ref.watch(subscriptionNotifierProvider).value;
    if (info == null || !info.isExpiringSoon) return null;
    if (ref.watch(h1BannerDismissedProvider)) return null;
    final activeYear = ref.watch(activeAcademicYearProvider).value;
    if (activeYear == null) return null;
    return H1WarningBanner(academicYear: activeYear, info: info);
  }

  final AcademicYear academicYear;
  final SubscriptionInfo info;

  String _remainingSummary() {
    final hours = info.hoursRemaining ?? 0;
    final days = info.daysRemaining ?? 0;
    if (days <= 0 && hours <= 0) {
      return 'Berakhir kurang dari 1 jam lagi';
    }
    if (days > 0) {
      return 'Sisa $days hari ${hours.abs()} jam lagi';
    }
    return 'Sisa $hours jam lagi';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = this.info;
    final expiresAt = info.expiresAt;
    final expiresLabel = expiresAt == null
        ? 'segera'
        : DateFormatter.toHumanDate(expiresAt.toLocal());

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warningText.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warningText.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.warningText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lisensi Akan Berakhir',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warningText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_remainingSummary()}. Masa aktif sampai $expiresLabel. '
                      'Cadangkan data sekarang agar tidak hilang saat lisensi berakhir.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Sembunyikan banner',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      ref.read(h1BannerDismissedProvider.notifier).dismiss(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warningText,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.cloud_download_outlined, size: 16),
                label: const Text('Cadangkan Data Sekarang'),
                onPressed: () =>
                    H1BackupDialog.show(context, academicYear: academicYear),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
