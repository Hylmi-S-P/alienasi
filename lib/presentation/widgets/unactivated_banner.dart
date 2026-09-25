import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/license/device_identity_service.dart';
import '../providers/subscription_notifier.dart';
import '../screens/dialogs/paywall_sheet.dart';

/// Banner notifikasi di Dashboard ketika aplikasi belum diaktivasi atau lisensi
/// telah berakhir.
///
/// Menyediakan dua tombol aksi langsung:
///   1. "Aktivasi" -> membuka dialog PaywallSheet untuk input token.
///   2. "Beli via WhatsApp" -> membuka chat WhatsApp ke admin
///      dengan template pesan otomatis yang sudah memuat ID Perangkat pengguna.
class UnactivatedBanner extends ConsumerStatefulWidget {
  const UnactivatedBanner({
    super.key,
    required this.info,
  });

  final SubscriptionInfo info;

  static const String _adminPhoneRaw = '081234567890';
  static const String _adminPhoneIntl = '6281234567890';

  /// Pintasan publik untuk membuka WhatsApp pemesanan lisensi dengan menyertakan ID Perangkat.
  static Future<void> launchWhatsApp(
    BuildContext context, [
    String? deviceId,
  ]) async {
    final effectiveDeviceId = (deviceId != null &&
            deviceId != '...' &&
            deviceId.isNotEmpty)
        ? deviceId
        : await DeviceIdentityService.getDeviceId();

    final message =
        'Halo Admin Bendahara Alien, saya ingin membeli kode aktivasi lisensi 28 hari (Rp 25.000) untuk ID Perangkat: $effectiveDeviceId';
    final urlString =
        'https://wa.me/$_adminPhoneIntl?text=${Uri.encodeComponent(message)}';
    final uri = Uri.parse(urlString);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showFallbackDialog(context, message, effectiveDeviceId);
      }
    } catch (_) {
      if (context.mounted) {
        _showFallbackDialog(context, message, effectiveDeviceId);
      }
    }
  }

  /// Mengembalikan widget banner bila status lisensi belum aktif atau expired;
  /// null bila lisensi sedang aktif penuh sehingga slot tidak memakan ruang.
  static Widget? maybeBuild(BuildContext context, WidgetRef ref) {
    final info = ref.watch(subscriptionNotifierProvider).value;
    if (info == null) return null;
    if (info.status == SubscriptionStatus.unactivated ||
        info.status == SubscriptionStatus.expired) {
      return UnactivatedBanner(
        key: const ValueKey('unactivated_banner'),
        info: info,
      );
    }
    return null;
  }

  static void _showFallbackDialog(
    BuildContext context,
    String message,
    String deviceId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buka WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aplikasi WhatsApp tidak dapat dibuka otomatis. Silakan hubungi nomor admin langsung:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const SelectableText(
              '$_adminPhoneRaw (Admin)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sertakan ID Perangkat Anda saat memesan kode aktivasi:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            SelectableText(
              deviceId,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pesan pemesanan disalin ke clipboard.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Salin Pesan'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  ConsumerState<UnactivatedBanner> createState() => _UnactivatedBannerState();
}

class _UnactivatedBannerState extends ConsumerState<UnactivatedBanner> {
  late String _deviceId;

  @override
  void initState() {
    super.initState();
    _deviceId = DeviceIdentityService.cachedDeviceId ?? '...';
    _resolveDeviceId();
  }

  Future<void> _resolveDeviceId() async {
    final id = await DeviceIdentityService.getDeviceId();
    if (mounted && id != _deviceId) {
      setState(() {
        _deviceId = id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = widget.info.status == SubscriptionStatus.expired;
    final title = isExpired
        ? 'Masa Aktif Lisensi Berakhir'
        : 'Aplikasi Belum Diaktivasi';
    final desc = isExpired
        ? 'Fitur pencatatan kas, kas siswa, dan laporan terkunci. Perpanjang lisensi untuk melanjutkan.'
        : 'Aktifkan lisensi 28 hari (Rp 25.000) untuk mencatat kas, kelola kas siswa, dan ekspor laporan.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Amber 50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)), // Amber 200
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
                  color: const Color(0xFFFEF3C7), // Amber 100
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFFD97706), // Amber 600
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E), // Amber 800
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFFCD34D),
                            ),
                          ),
                          child: Text(
                            'ID: $_deviceId',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB45309), // Amber 700
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Tombol Beli via WhatsApp
              Expanded(
                child: ElevatedButton.icon(
                  key: const ValueKey('banner_whatsapp_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: const Text(
                    'Beli via WhatsApp',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => UnactivatedBanner.launchWhatsApp(context, _deviceId),
                ),
              ),
              const SizedBox(width: 8),
              // Tombol Masukkan Kode
              OutlinedButton.icon(
                key: const ValueKey('banner_activate_btn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF92400E),
                  side: const BorderSide(color: Color(0xFFFCD34D), width: 1.2),
                  backgroundColor: Colors.white,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.vpn_key_outlined, size: 15),
                label: const Text(
                  'Aktivasi',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () {
                  PaywallSheet.show(
                    context,
                    mutationLabel: 'mengaktifkan lisensi penuh',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
