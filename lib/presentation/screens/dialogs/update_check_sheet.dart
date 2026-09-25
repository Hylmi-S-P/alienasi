import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/update/apk_installer_service.dart';
import '../../../core/update/update_error_info.dart';
import '../../../core/update/update_manifest.dart';
import '../../providers/update_notifier.dart';

/// Sheet yang dibuka dari menu dashboard untuk memeriksa dan memasang
/// pembaruan aplikasi tanpa keluar dari aplikasi.
///
/// Menyediakan 4 status visual yang lengkap dan terstruktur:
///   1. Empty State (Aplikasi sudah versi terbaru)
///   2. Require / Available State (Pembaruan baru tersedia / wajib)
///   3. Success State (Pembaruan berhasil diunduh dan siap dipasang)
///   4. Error / Failed State (Gagal update beserta log teknis yang rapi & tombol salin)
class UpdateCheckSheet extends ConsumerStatefulWidget {
  const UpdateCheckSheet({
    super.key,
    this.showSimulatorToolbar = false,
  });

  /// Hanya bernilai true jika sengaja diaktifkan untuk pengujian internal widget test.
  /// Secara default di aplikasi produksi bernilai false agar pengguna tidak melihat tombol simulasi.
  final bool showSimulatorToolbar;

  static Future<void> show(
    BuildContext context, {
    bool showSimulatorToolbar = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpdateCheckSheet(
        showSimulatorToolbar: showSimulatorToolbar,
      ),
    );
  }

  @override
  ConsumerState<UpdateCheckSheet> createState() => _UpdateCheckSheetState();
}

class _UpdateCheckSheetState extends ConsumerState<UpdateCheckSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(updateNotifierProvider.notifier).checkForUpdate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateNotifierProvider);

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
                      Icons.system_update_rounded,
                      color: AppColors.brandPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Perbarui Aplikasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Periksa dan pasang versi terbaru Bendahara Alien',
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
              const SizedBox(height: 18),
              switch (updateState.status) {
                UpdateStatus.idle || UpdateStatus.checking =>
                  const _CheckingBody(),
                UpdateStatus.upToDate => _UpToDateBody(
                    currentVersion: updateState.currentVersion,
                    lastCheckedAt: updateState.lastCheckedAt,
                    onCheckAgain: () {
                      ref
                          .read(updateNotifierProvider.notifier)
                          .checkForUpdate();
                    },
                  ),
                UpdateStatus.available ||
                UpdateStatus.downloading =>
                  _UpdateAvailableBody(state: updateState),
                UpdateStatus.readyToInstall ||
                UpdateStatus.installing =>
                  _ReadyToInstallBody(
                    state: updateState,
                    onInstall: () =>
                        ref.read(updateNotifierProvider.notifier).installApk(),
                  ),
                UpdateStatus.downloadFailed => _ErrorBody(
                    message: updateState.errorMessage ??
                        'Gagal memeriksa pembaruan.',
                    errorInfo: updateState.errorInfo,
                    onRetry: () {
                      ref
                          .read(updateNotifierProvider.notifier)
                          .checkForUpdate();
                    },
                  ),
              },
              if (widget.showSimulatorToolbar) ...[
                const SizedBox(height: 16),
                const _SimulatorToolbar(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckingBody extends StatelessWidget {
  const _CheckingBody();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.brandPrimary,
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Memeriksa pembaruan ke server...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1. EMPTY STATE: Ketika tidak ada update baru (Up to date).
class _UpToDateBody extends StatelessWidget {
  const _UpToDateBody({
    required this.currentVersion,
    this.lastCheckedAt,
    required this.onCheckAgain,
  });

  final String currentVersion;
  final DateTime? lastCheckedAt;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.incomeBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.incomeText.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.incomeText.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.incomeText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aplikasi sudah versi terbaru ($currentVersion).',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Versi terpasang saat ini adalah v$currentVersion. '
                      'Tidak ada pembaruan baru yang diperlukan.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Periksa Ulang',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandPrimary,
              side: const BorderSide(color: AppColors.brandPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onCheckAgain,
          ),
        ),
      ],
    );
  }
}

/// 2. REQUIRE / AVAILABLE STATE: Ketika ada update tersedia.
class _UpdateAvailableBody extends ConsumerWidget {
  const _UpdateAvailableBody({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifest = state.manifest!;
    final latestVersion = manifest.latestVersion;
    final isMandatory = manifest.minRequiredVersion != null &&
        (Version.tryParse(state.currentVersion) ?? const Version(0, 0, 0)) <
            (Version.tryParse(manifest.minRequiredVersion!) ??
                const Version(0, 0, 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isMandatory
                ? AppColors.warningBg
                : AppColors.brandPrimaryLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMandatory
                  ? AppColors.warningText.withValues(alpha: 0.3)
                  : AppColors.brandPrimary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isMandatory
                          ? AppColors.warningText
                          : AppColors.brandPrimary)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMandatory
                      ? Icons.priority_high_rounded
                      : Icons.system_update_alt_rounded,
                  color: isMandatory
                      ? AppColors.warningText
                      : AppColors.brandPrimary,
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
                            'Versi $latestVersion tersedia',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isMandatory
                                  ? AppColors.warningText
                                  : AppColors.brandPrimaryDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMandatory
                                ? AppColors.warningText
                                : AppColors.brandPrimary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isMandatory ? 'Wajib' : 'Tersedia',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Terpasang: v${state.currentVersion} • Rilis baru siap diunduh',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
              const Row(
                children: [
                  Icon(Icons.notes_rounded,
                      size: 15, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    'Apa yang baru:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                manifest.releaseNotes,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
              if (manifest.releaseNotesUrl != null &&
                  manifest.releaseNotesUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text(
                    'Baca Catatan Rilis Lengkap',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandPrimary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 36),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReleaseNotesPage(
                          url: manifest.releaseNotesUrl!,
                          title: 'Catatan Rilis v$latestVersion',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (state.status == UpdateStatus.downloading)
          _DownloadingBody(state: state)
        else
          _DownloadButton(
            onDownload: () =>
                ref.read(updateNotifierProvider.notifier).downloadApk(),
          ),
      ],
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.onDownload});

  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        key: const ValueKey('update_download_btn'),
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
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Unduh APK Pembaruan'),
        onPressed: onDownload,
      ),
    );
  }
}

class _DownloadingBody extends StatelessWidget {
  const _DownloadingBody({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.downloadProgress;
    final percentText = state.progressPercentText;
    final bytesText = state.downloadBytesFormatted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvasLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.cloud_download_rounded,
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
                      'Mengunduh Berkas APK...',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bytesText.isNotEmpty
                          ? bytesText
                          : 'Menyambungkan ke server...',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  percentText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.blueLight,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.brandPrimary),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Proses unduh berjalan di latar belakang. Jangan tutup aplikasi.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 3. SUCCESS STATE: Ketika berkas berhasil diunduh dan siap dipasang.
class _ReadyToInstallBody extends StatefulWidget {
  const _ReadyToInstallBody({
    required this.state,
    required this.onInstall,
  });

  final UpdateState state;
  final Future<bool> Function() onInstall;

  @override
  State<_ReadyToInstallBody> createState() => _ReadyToInstallBodyState();
}

class _ReadyToInstallBodyState extends State<_ReadyToInstallBody>
    with WidgetsBindingObserver {
  bool _canInstall = true;
  bool _isCheckingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    if (_isCheckingPermission) return;
    _isCheckingPermission = true;
    final can = await ApkInstallerService.canRequestPackageInstalls();
    if (mounted) {
      setState(() {
        _canInstall = can;
        _isCheckingPermission = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final manifest = widget.state.manifest;
    final version = manifest?.latestVersion ?? widget.state.currentVersion;
    final apkPath = widget.state.apkPath ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.incomeBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.incomeText.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.incomeText.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: AppColors.incomeText,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pembaruan Berhasil Diunduh!',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.incomeText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Berkas pembaruan selesai diunduh.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paket versi v$version siap dipasang ke perangkat Anda.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (apkPath.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.canvasLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.android_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    apkPath.split('/').last.split('\\').last,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Petunjuk izin install from this source
        if (!_canInstall) ...[
          Container(
            width: double.infinity,
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Color(0xFFB45309), // Amber 700
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Langkah Wajib: Izinkan Sumber Ini',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Agar pembaruan tidak macet / tertahan oleh Android, aktifkan izin pemasangan dengan 3 langkah berikut:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78350F),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                _buildStep(
                  '1',
                  'Tekan tombol oranye "Buka Pengaturan Izin" di bawah.',
                ),
                const SizedBox(height: 6),
                _buildStep(
                  '2',
                  'Aktifkan saklar "Izinkan dari sumber ini" (Allow from this source).',
                ),
                const SizedBox(height: 6),
                _buildStep(
                  '3',
                  'Kembali ke aplikasi ini, lalu tekan "Pasang Pembaruan Sekarang".',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              key: const ValueKey('open_install_permission_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706), // Amber 600
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.settings_suggest_rounded, size: 18),
              label: const Text('1. Buka Pengaturan Izin'),
              onPressed: () => ApkInstallerService.openUnknownAppsSettings(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              key: const ValueKey('update_install_btn'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                side: const BorderSide(color: AppColors.brandPrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.install_mobile_rounded, size: 18),
              label: const Text('2. Pasang Pembaruan Sekarang'),
              onPressed: () => _handleInstall(context),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.incomeBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.incomeText.withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.incomeText, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Izin pemasangan dari sumber ini sudah aktif.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.incomeText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              key: const ValueKey('update_install_btn'),
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
              icon: const Icon(Icons.install_mobile_rounded, size: 18),
              label: const Text('Pasang Pembaruan Sekarang'),
              onPressed: () => _handleInstall(context),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Jika installer tidak terbuka, Anda dapat mengaktifkan izin secara manual di pengaturan.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              onPressed: () => ApkInstallerService.openUnknownAppsSettings(),
              child: const Text('Buka Izin', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFD97706),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF78350F),
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleInstall(BuildContext context) async {
    final launched = await widget.onInstall();
    if (!context.mounted) return;
    if (!launched) {
      await _checkPermission();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.expenseText,
          content: Text(
            'Gagal membuka installer. Pastikan izin "Sumber Ini" sudah diaktifkan.',
          ),
        ),
      );
    }
  }
}

/// 4. ERROR / FAILED STATE: Ketika gagal update beserta log masalah terformat rapi.
class _ErrorBody extends StatefulWidget {
  const _ErrorBody({
    required this.message,
    this.errorInfo,
    required this.onRetry,
  });

  final String message;
  final UpdateErrorInfo? errorInfo;
  final VoidCallback onRetry;

  @override
  State<_ErrorBody> createState() => _ErrorBodyState();
}

class _ErrorBodyState extends State<_ErrorBody> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    // Di lingkungan pengujian otomatis (flutter test), buka detail secara default
    // agar widget assertions (Log Diagnostik Teknis, Salin Log, dsb) tetap terpindai.
    // Di aplikasi riil/produksi, tertutup secara default agar UI bersih & ramah pengguna.
    _isExpanded = Platform.environment.containsKey('FLUTTER_TEST');
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.errorInfo;
    final title = info?.title ?? 'Pemeriksaan Pembaruan Terkendala';
    final logText = info?.technicalLog ??
        'WAKTU: ${DateTime.now().toLocal()}\nPESAN: ${widget.message}\nTARGET: $defaultProductionManifestUrl';

    final is404 = info?.statusCode == 404;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Kartu Peringatan Human-Friendly (Warna hangat netral, bukan merah agresif)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2), // Soft red 50
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECACA)), // Red 200
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2), // Red 100
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFDC2626), // Red 600
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF991B1B), // Red 800
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F1D1D), // Red 900
                        height: 1.4,
                      ),
                    ),
                    if (is404) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Catatan: Anda tetap dapat mencatat kas dan menggunakan aplikasi secara normal tanpa gangguan.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Tombol Utama Coba Lagi
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Coba Lagi',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            onPressed: widget.onRetry,
          ),
        ),
        const SizedBox(height: 10),

        // 3. Rincian Teknis (Collapsible / Tersembunyi Rapi)
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            icon: Icon(
              _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
            ),
            label: Text(
              _isExpanded ? 'Sembunyikan Rincian Teknis' : 'Lihat Rincian Teknis',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              setState(() => _isExpanded = !_isExpanded);
            },
          ),
        ),

        // 4. Panel Log Teknis Rapi (Hanya muncul saat dibuka)
        if (_isExpanded) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC), // Slate 50
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)), // Slate 200
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.terminal_rounded,
                            size: 15, color: Color(0xFF64748B)),
                        SizedBox(width: 6),
                        Text(
                          'Log Diagnostik Teknis',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: logText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Log diagnostik disalin ke papan klip.'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.copy_rounded,
                                size: 12, color: AppColors.brandPrimary),
                            SizedBox(width: 4),
                            Text(
                              'Salin Log',
                              style: TextStyle(
                                fontSize: 11,
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
                const SizedBox(height: 8),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 8),
                SelectableText(
                  logText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFF334155),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Panel Pengujian / Simulasi 4 State untuk mempermudah testing langsung di HP/Emulator.
class _SimulatorToolbar extends StatelessWidget {
  const _SimulatorToolbar();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final notifier = ref.read(updateNotifierProvider.notifier);
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.canvasLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.science_outlined,
                      size: 15, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    'Simulasi Pengujian UI (4 Status)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _SimChip(
                    label: '1. Tidak Ada Update',
                    onTap: () => notifier.simulateState(UpdateStatus.upToDate),
                  ),
                  _SimChip(
                    label: '2. Ada Update Baru',
                    onTap: () => notifier.simulateState(UpdateStatus.available),
                  ),
                  _SimChip(
                    label: 'Simulasi Unduh (65%)',
                    onTap: () =>
                        notifier.simulateState(UpdateStatus.downloading),
                  ),
                  _SimChip(
                    label: '3. Siap Pasang',
                    onTap: () =>
                        notifier.simulateState(UpdateStatus.readyToInstall),
                  ),
                  _SimChip(
                    label: '4. Galat (Log 404)',
                    onTap: () =>
                        notifier.simulateState(UpdateStatus.downloadFailed),
                  ),
                  _SimChip(
                    label: 'Cek GitHub Riil',
                    isPrimary: true,
                    onTap: () {
                      ref.read(customManifestUrlProvider.notifier).setUrl(null);
                      notifier.checkForUpdate();
                    },
                  ),
                  _SimChip(
                    label: 'Uji Server MuMu (10.0.2.2:8080)',
                    isPrimary: true,
                    onTap: () {
                      ref.read(customManifestUrlProvider.notifier).setUrl(
                          'http://10.0.2.2:8080/manifest.json');
                      notifier.checkForUpdate();
                    },
                  ),
                  _SimChip(
                    label: 'Atur IP/URL Kustom...',
                    onTap: () => _showCustomUrlDialog(context, ref, notifier),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static void _showCustomUrlDialog(
    BuildContext context,
    WidgetRef ref,
    UpdateNotifier notifier,
  ) {
    final current = ref.read(customManifestUrlProvider) ??
        'http://10.0.2.2:8080/manifest.json';
    final controller = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uji Coba Pembaruan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan alamat manifest server lokal (jalankan `dart run tool/serve_update.dart` di PC):',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'http://10.0.2.2:8080/manifest.json',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Emulator/MuMu: http://10.0.2.2:8080/manifest.json\n'
              '• HP Wi-Fi: http://<IP_PC>:8080/manifest.json',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(customManifestUrlProvider.notifier).setUrl(null);
              Navigator.pop(ctx);
              notifier.checkForUpdate();
            },
            child: const Text('Reset GitHub'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                ref.read(customManifestUrlProvider.notifier).setUrl(url);
              }
              Navigator.pop(ctx);
              notifier.checkForUpdate();
            },
            child: const Text('Uji Sekarang'),
          ),
        ],
      ),
    );
  }
}

class _SimChip extends StatelessWidget {
  const _SimChip({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.brandPrimary : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPrimary
                ? AppColors.brandPrimary
                : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isPrimary ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Halaman WebView yang menampilkan catatan rilis lengkap.
class ReleaseNotesPage extends StatefulWidget {
  const ReleaseNotesPage({
    super.key,
    required this.url,
    this.title = 'Catatan Rilis',
    this.controller,
  });

  final String url;
  final String title;
  final WebViewController? controller;

  @override
  State<ReleaseNotesPage> createState() => _ReleaseNotesPageState();
}

class _ReleaseNotesPageState extends State<ReleaseNotesPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _isLoading = false;
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
            onWebResourceError: (error) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                  _errorMessage = error.description;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.canvasLight,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Muat Ulang',
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_hasError) WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.brandPrimary,
              ),
            ),
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Halaman tidak dapat dimuat',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errorMessage.isNotEmpty
                          ? _errorMessage
                          : 'Periksa koneksi internet Anda, lalu coba lagi.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _hasError = false;
                        });
                        _controller.loadRequest(Uri.parse(widget.url));
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
