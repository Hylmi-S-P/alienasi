import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/license/device_identity_service.dart';
import '../../providers/subscription_notifier.dart';
import '../../widgets/unactivated_banner.dart';
import 'paywall_sheet.dart';

/// Modal bottom sheet yang menampilkan rincian informasi langganan aktif:
/// status lisensi, sisa hari/jam, masa berlaku, serta ID Perangkat pengguna.
class SubscriptionInfoSheet extends ConsumerStatefulWidget {
  const SubscriptionInfoSheet({super.key});

  /// Menampilkan lembar informasi langganan sebagai modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SubscriptionInfoSheet(),
    );
  }

  @override
  ConsumerState<SubscriptionInfoSheet> createState() => _SubscriptionInfoSheetState();
}

class _SubscriptionInfoSheetState extends ConsumerState<SubscriptionInfoSheet> {
  String _deviceId = '...';
  bool _isLoadingDeviceId = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(subscriptionNotifierProvider.notifier).refreshNow();
      }
    });
  }

  Future<void> _loadDeviceId() async {
    final id = await DeviceIdentityService.getDeviceId();
    if (mounted) {
      setState(() {
        _deviceId = id;
        _isLoadingDeviceId = false;
      });
    }
  }

  void _copyDeviceId() {
    if (_isLoadingDeviceId || _deviceId == '...') return;
    Clipboard.setData(ClipboardData(text: _deviceId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ID Perangkat berhasil disalin ke papan klip.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _maskToken(String token) {
    if (token.length <= 8) return token;
    final start = token.substring(0, 4);
    final end = token.substring(token.length - 4);
    return '$start-••••-••••-$end';
  }

  @override
  Widget build(BuildContext context) {
    final subInfo = ref.watch(subscriptionNotifierProvider).value;

    final status = subInfo?.status ?? SubscriptionStatus.unactivated;
    final isActive = subInfo?.isActive ?? false;
    final isExpiringSoon = subInfo?.isExpiringSoon ?? false;
    final isExpired = status == SubscriptionStatus.expired;
    final daysRemaining = subInfo?.daysRemaining;
    final hoursRemaining = subInfo?.hoursRemaining;
    final expiresAt = subInfo?.expiresAt;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.brandPrimaryLight
                          : isExpired
                              ? AppColors.expenseBg
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.card_membership_rounded,
                      color: isActive
                          ? AppColors.brandPrimary
                          : isExpired
                              ? AppColors.expenseText
                              : AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informasi Langganan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Status lisensi dan masa aktif aplikasi',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Kartu Status Utama
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isExpired
                      ? const Color(0xFFFEF2F2)
                      : isExpiringSoon
                          ? const Color(0xFFFFFBEB)
                          : isActive
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExpired
                        ? const Color(0xFFFECACA)
                        : isExpiringSoon
                            ? const Color(0xFFFDE68A)
                            : isActive
                                ? const Color(0xFFBBF7D0)
                                : AppColors.borderSubtle,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status Lisensi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _buildRemainingDurationText(
                        status: status,
                        daysRemaining: daysRemaining,
                        hoursRemaining: hoursRemaining,
                      ),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isExpired
                            ? AppColors.expenseText
                            : isExpiringSoon
                                ? const Color(0xFFD97706)
                                : isActive
                                    ? AppColors.brandPrimaryDark
                                    : AppColors.textPrimary,
                      ),
                    ),
                    if (expiresAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Masa Berlaku Hingga: ${DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(expiresAt)} WIB',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Aplikasi berjalan dalam mode penjelajahan gratis. Fitur mutasi data terkunci hingga lisensi diaktifkan.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Kartu ID Perangkat
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ID Perangkat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _deviceId,
                            style: const TextStyle(
                              fontSize: 15,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Salin ID Perangkat',
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.brandPrimary),
                          onPressed: _copyDeviceId,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID ini terikat permanen pada ponsel Anda dan tidak berubah meski aplikasi di-install ulang.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Kartu Kunci Lisensi (Jika ada yang aktif)
              if (subInfo?.state?.activationCode case final activationCode? when activationCode.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kunci Lisensi Terpasang',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _maskToken(activationCode),
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Tombol-tombol Aksi
              if (!isActive) ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.key_rounded, size: 18),
                    label: const Text(
                      'Aktivasi Lisensi',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      PaywallSheet.show(context, mutationLabel: 'Aktivasi Lisensi');
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF14B8A6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text(
                      'Beli via WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    onPressed: () {
                      UnactivatedBanner.launchWhatsApp(context, _deviceId);
                    },
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brandPrimary,
                            side: const BorderSide(color: AppColors.brandPrimary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_moderator_rounded, size: 18),
                          label: const Text(
                            'Perpanjang Lisensi',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            PaywallSheet.show(context, mutationLabel: 'Perpanjang Lisensi');
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Tutup',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SubscriptionStatus status) {
    late final Color bgColor;
    late final Color textColor;
    late final String label;

    switch (status) {
      case SubscriptionStatus.active:
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF15803D);
        label = 'Aktif';
        break;
      case SubscriptionStatus.expiringSoon:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        label = 'Segera Berakhir';
        break;
      case SubscriptionStatus.expired:
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFB91C1C);
        label = 'Kedaluwarsa';
        break;
      case SubscriptionStatus.unactivated:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
        label = 'Belum Aktif';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  String _buildRemainingDurationText({
    required SubscriptionStatus status,
    required int? daysRemaining,
    required int? hoursRemaining,
  }) {
    switch (status) {
      case SubscriptionStatus.active:
        if (daysRemaining != null && daysRemaining > 0) {
          return '$daysRemaining hari lagi';
        }
        return 'Sisa ${hoursRemaining ?? 0} jam lagi';
      case SubscriptionStatus.expiringSoon:
        final hours = hoursRemaining ?? 0;
        if (daysRemaining != null && daysRemaining > 0) {
          return '$daysRemaining hari $hours jam lagi';
        }
        return 'Sisa $hours jam lagi';
      case SubscriptionStatus.expired:
        return 'Masa Berlaku Berakhir';
      case SubscriptionStatus.unactivated:
        return 'Belum Diaktivasi';
    }
  }
}
