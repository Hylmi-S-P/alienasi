import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/license/device_identity_service.dart';
import '../../../core/license/license_engine.dart';
import '../../providers/app_providers.dart';
import '../../providers/subscription_notifier.dart';
import '../../widgets/unactivated_banner.dart';

/// Paywall modal/bottom sheet untuk model freemium "explore-first".
///
/// Ditampilkan tepat saat pengguna mencoba melakukan aksi mutasi
/// (mencatat transaksi, menandai iuran lunas, atau menambah siswa)
/// padahal lisensi tidak aktif. Desain sengaja tenang dan netral:
/// energi rendah (ENERGY 1), radius konsisten (R-11), CTA spesifik
/// (R-15), tanpa gradien atau glow.
class PaywallSheet extends ConsumerStatefulWidget {
  const PaywallSheet({
    super.key,
    required this.context,
    required this.mutationLabel,
  });

  /// Konteks pemanggil yang menyediakan SubscriptionInfo, LicenseRepository,
  /// dan SubscriptionNotifier. Dipakai agar sheet dapat membaca status
  /// terkini tanpa harus membawa state internal ekstra.
  final BuildContext context;

  /// Label mutasi yang memicu paywall (mis. "menyimpan transaksi",
  /// "menandai iuran siswa"). Ditampilkan sebagai alasan agar
  /// pengguna paham kenapa paywall muncul.
  final String mutationLabel;

  /// Pintasan untuk menampilkan paywall dari mana pun dalam aplikasi.
  static Future<PaywallOutcome> show(
    BuildContext context, {
    required String mutationLabel,
  }) {
    return showModalBottomSheet<PaywallOutcome>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaywallSheet(
        context: ctx,
        mutationLabel: mutationLabel,
      ),
    ).then((value) => value ?? PaywallOutcome.cancelled);
  }

  @override
  ConsumerState<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<PaywallSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  bool _isSubmitting = false;
  String? _inlineError;
  String _deviceId = '...';

  static const _priceText = 'Rp 25.000';
  static const _validityText = '28 hari';

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
      });
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      final repo = ref.read(licenseRepoProvider);
      // Pakai jam acuan yang sama dengan SubscriptionNotifier supaya validasi
      // aktivasi dan status langganan tidak saling bertentangan (misalnya
      // diuji dengan jam tersuntik yang berbeda dari jam sistem).
      final clock = ref.read(subscriptionClockProvider);
      final currentDeviceId = _deviceId.startsWith('DEV-')
          ? _deviceId
          : await DeviceIdentityService.getDeviceId();
      final normalized = LicenseEngine.normalize(_tokenController.text);
      final result = await repo.activate(
        normalized,
        deviceId: currentDeviceId,
        clock: clock,
      );

      if (!mounted) return;

      if (!result.isValid) {
        setState(() {
          _inlineError = _friendlyMessage(result.validation.status);
          _isSubmitting = false;
        });
        return;
      }

      await ref.read(subscriptionNotifierProvider.notifier).refreshNow();
      if (!mounted) return;
      Navigator.of(context).pop(PaywallOutcome.activated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inlineError = 'Galat tak terduga: $e';
        _isSubmitting = false;
      });
    }
  }

  String _friendlyMessage(LicenseStatus status) {
    switch (status) {
      case LicenseStatus.malformed:
        return 'Format kode tidak dikenali. Contoh: BNDH-XXXX-XXXX-XXXX.';
      case LicenseStatus.badSignature:
        return 'Kode lisensi tidak sah atau sudah diubah.';
      case LicenseStatus.deviceMismatch:
        return 'Kode lisensi ini tidak cocok dengan ID Perangkat Anda.';
      case LicenseStatus.expired:
        return 'Masa aktif kode ini sudah berakhir.';
      case LicenseStatus.clockRollback:
        return 'Jam perangkat dimundurkan. Perbaiki tanggal dan jam, lalu coba lagi.';
      case LicenseStatus.valid:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = ref.watch(subscriptionNotifierProvider).value;
    final remainingLabel = _buildRemainingLabel(info);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.only(top: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar netral (R-05/R-11) tanpa gradien.
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

                  // Header ringkas (R-20, R-23).
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.lock_open_rounded,
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
                              'Aktivasi Lisensi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.mutationLabel,
                              style: const TextStyle(
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
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context)
                                .pop(PaywallOutcome.cancelled),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Kartu harga (satu focal point, R-29).
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.brandPrimary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_priceText / $_validityText',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandPrimaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Akses penuh selama 28 hari. Tidak ada perpanjangan otomatis.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                              if (remainingLabel != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  remainingLabel,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warningText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.confirmation_number_outlined,
                            color: AppColors.brandPrimary,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Manfaat (R-05: konten mengikuti kebutuhan produk).
                  const Text(
                    'Setelah aktivasi, kamu dapat:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._benefits.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              line,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ID Perangkat Unik untuk penguncian 1-device
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.canvasLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_android_rounded,
                              size: 16,
                              color: AppColors.brandPrimary,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'ID PERANGKAT INI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              key: const ValueKey('copy_device_id_btn'),
                              borderRadius: BorderRadius.circular(4),
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: _deviceId),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'ID Perangkat berhasil disalin. Kirim ke Admin untuk kode aktivasi.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 13,
                                      color: AppColors.brandPrimary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Salin ID',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.brandPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _deviceId,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Satu kode hanya dapat digunakan pada satu perangkat ini.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Input kode (R-26: field nyata, fokus otomatis).
                  const Text(
                    'Kode Aktivasi',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _tokenController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                      _TokenInputFormatter(),
                    ],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'BNDH-XXXX-XXXX-XXXX',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        letterSpacing: 1.0,
                      ),
                      prefixIcon: const Icon(
                        Icons.vpn_key_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      errorText: _inlineError,
                      errorMaxLines: 2,
                      filled: true,
                      fillColor: AppColors.canvasLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.borderSubtle,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.brandPrimary,
                          width: 1.4,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.borderSubtle,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) {
                      if (_inlineError != null) {
                        setState(() => _inlineError = null);
                      }
                    },
                    validator: (v) {
                      final cleaned = (v ?? '').replaceAll(RegExp(r'[^0-9A-Z]'), '');
                      if (cleaned.isEmpty) return 'Masukkan kode aktivasi.';
                      if (cleaned.length < 12) return 'Kode terlalu pendek.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Format: BNDH-XXXX-XXXX-XXXX (alfabet tanpa I, L, O, U).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // CTA spesifik (R-15).
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const ValueKey('paywall_activate_btn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_open_rounded, size: 18),
                      label: Text(
                        _isSubmitting
                            ? 'Memvalidasi kode...'
                            : 'Aktivasi Sekarang',
                      ),
                      onPressed: _isSubmitting ? null : _activate,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      key: const ValueKey('paywall_whatsapp_btn'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF15803D),
                        side: const BorderSide(color: Color(0xFF22C55E)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: const Text(
                        'Belum punya kode? Beli via WhatsApp',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => UnactivatedBanner.launchWhatsApp(context, _deviceId),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Ringkas nominal agar transparan (R-36).
                  Center(
                    child: Text(
                      'Satu kali bayar $_priceText untuk $_validityText akses penuh.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _buildRemainingLabel(SubscriptionInfo? info) {
    if (info == null) return null;
    if (info.status == SubscriptionStatus.unactivated) return null;
    if (info.status == SubscriptionStatus.active) return null;
    if (info.status == SubscriptionStatus.expiringSoon) {
      final h = info.hoursRemaining ?? 0;
      return 'Sisa ${h.clamp(0, 24)} jam lagi. Segera perpanjang agar tidak terkunci.';
    }
    return 'Lisensi sebelumnya sudah berakhir. Masukkan kode baru untuk melanjutkan.';
  }
}

/// Input formatter yang membatasi ke alfabet lisensi dan menambahkan strip
/// setiap 4 karakter seperti format BNDH-XXXX-XXXX-XXXX.
class _TokenInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^0-9A-Z]'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('-');
      buffer.write(cleaned[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Daftar manfaat yang ditampilkan di paywall. Ditulis netral tanpa
/// klaim bombastis (R-16, R-36).
const List<String> _benefits = [
  'Mencatat transaksi kas masuk dan kas keluar tanpa batas.',
  'Menandai pembayaran iuran siswa dan rekap tunggakan.',
  'Menambah, mengubah, dan menghapus data siswa.',
];

/// Hasil akhir paywall setelah ditutup.
enum PaywallOutcome {
  /// Pengguna menutup sheet tanpa aktivasi.
  cancelled,

  /// Kode valid dimasukkan dan lisensi kini aktif.
  activated,
}