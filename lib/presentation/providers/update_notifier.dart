import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/update/apk_installer_service.dart';
import '../../core/update/update_error_info.dart';
import '../../core/update/update_manifest.dart';
import '../../core/update/update_service.dart';

/// Konfigurasi pembaruan aplikasi.
///
/// [manifestUrl] diarahkan pembuat ke berkas JSON manifest (lihat
/// [UpdateManifest]). Nilai default memakai GitHub Pages proyek; cukup
/// ganti satu titik ini saat alamat berubah.
class UpdateConfig {
  final String manifestUrl;
  final String currentAppVersion;

  const UpdateConfig({
    required this.manifestUrl,
    required this.currentAppVersion,
  });
}

/// URL endpoint manifest default resmi di repositori GitHub publik pengguna.
const String defaultProductionManifestUrl =
    'https://raw.githubusercontent.com/Hylmi-S-P/alienasi/master/app/manifest.json';

/// Notifier URL manifest kustom untuk memfasilitasi pengujian server lokal / emulator.
class CustomManifestUrlNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setUrl(String? url) => state = url;
}

final customManifestUrlProvider =
    NotifierProvider<CustomManifestUrlNotifier, String?>(
  CustomManifestUrlNotifier.new,
);

/// Provider konfigurasi; dioverride di pengujian untuk mengarahkan ke
/// fetcher stub tanpa jaringan.
final updateConfigProvider = Provider<UpdateConfig>((ref) {
  final customUrl = ref.watch(customManifestUrlProvider);
  return UpdateConfig(
    manifestUrl: customUrl ?? defaultProductionManifestUrl,
    currentAppVersion: '1.0.1',
  );
});

/// Fetcher manifest; pengujian mengganti ini dengan stub.
final updateManifestFetcherProvider = Provider<UpdateManifestFetcher>((ref) {
  final config = ref.watch(updateConfigProvider);
  return HttpUpdateManifestFetcher(url: config.manifestUrl);
});

/// Titik injeksi layanan installer supaya pengujian dapat mencatat panggilan.
typedef ApkInstallTrigger = Future<bool> Function(String filePath);

final apkInstallTriggerProvider = Provider<ApkInstallTrigger>((ref) {
  return ApkInstallerService.installApk;
});

/// Titik injeksi penentu lokasi unduhan; pengujian memakai direktori
/// sementara yang bisa diperiksa.
typedef ApkDownloadDirectoryResolver = Future<Directory> Function();

final apkDownloadDirectoryProvider = Provider<ApkDownloadDirectoryResolver>(
  (ref) => getTemporaryDirectory,
);

/// Titik injeksi klien HTTP; pengujian memakai stub tanpa jaringan.
typedef HttpClientFactory = http.Client? Function();

final httpClientFactoryProvider = Provider<HttpClientFactory>((ref) {
  return () => null;
});

/// Status siklus pembaruan aplikasi.
enum UpdateStatus {
  /// Pengecekan belum pernah dijalankan pada sesi ini.
  idle,

  /// Sedang mengambil manifest dari server.
  checking,

  /// Versi terpasang sudah yang terbaru.
  upToDate,

  /// Ada versi lebih baru, menunggu pengguna mengunduh.
  available,

  /// APK sedang diunduh.
  downloading,

  /// Unduhan gagal karena jaringan atau server.
  downloadFailed,

  /// APK selesai diunduh dan siap dipasang.
  readyToInstall,

  /// Intent installer sudah dikirim; keputusan akhir ada di tangan
  /// pengguna lewat dialog sistem Android.
  installing,
}

/// Snapshot status pembaruan yang siap dipakai UI.
class UpdateState {
  final UpdateStatus status;

  final UpdateManifest? manifest;

  /// Versi terpasang, untuk perbandingan tampilan di UI.
  final String currentVersion;

  /// Fraksi progres unduhan 0.0 s.d. 1.0; null bila ukuran total tidak
  /// diketahui server.
  final double? downloadProgress;

  /// Jumlah byte yang sudah diterima saat mengunduh APK.
  final int? receivedBytes;

  /// Ukuran total byte APK dari server (null bila server tidak mengirim Content-Length).
  final int? totalBytes;

  /// Lokasi APK yang selesai diunduh.
  final String? apkPath;

  /// Pesan galat untuk status [UpdateStatus.downloadFailed].
  final String? errorMessage;

  /// Detail teknis dan log galat terstruktur.
  final UpdateErrorInfo? errorInfo;

  /// Waktu terakhir pemeriksaan pembaruan dijalankan.
  final DateTime? lastCheckedAt;

  const UpdateState({
    required this.status,
    required this.currentVersion,
    this.manifest,
    this.downloadProgress,
    this.receivedBytes,
    this.totalBytes,
    this.apkPath,
    this.errorMessage,
    this.errorInfo,
    this.lastCheckedAt,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateManifest? manifest,
    double? downloadProgress,
    int? receivedBytes,
    int? totalBytes,
    String? apkPath,
    String? errorMessage,
    UpdateErrorInfo? errorInfo,
    DateTime? lastCheckedAt,
  }) {
    return UpdateState(
      status: status ?? this.status,
      manifest: manifest ?? this.manifest,
      currentVersion: currentVersion,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      apkPath: apkPath ?? this.apkPath,
      errorMessage: errorMessage ?? this.errorMessage,
      errorInfo: errorInfo ?? this.errorInfo,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }

  /// Teks persentase progres unduhan, misal "65%".
  String get progressPercentText {
    if (downloadProgress == null) return '0%';
    return '${(downloadProgress! * 100).toStringAsFixed(0)}%';
  }

  /// Format data unduhan dalam MB, misal "46.2 MB / 71.2 MB".
  String get downloadBytesFormatted {
    if (receivedBytes == null) return '';
    final receivedMb = (receivedBytes! / (1024 * 1024)).toStringAsFixed(1);
    if (totalBytes != null && totalBytes! > 0) {
      final totalMb = (totalBytes! / (1024 * 1024)).toStringAsFixed(1);
      return '$receivedMb MB / $totalMb MB';
    }
    return '$receivedMb MB';
  }

  bool get isUpdateAvailable =>
      status == UpdateStatus.available ||
      status == UpdateStatus.downloading ||
      status == UpdateStatus.readyToInstall;
}

/// Notifier siklus pembaruan: cek, unduh, pasang.
///
/// Satu-satunya sumber kebenaran status pembaruan untuk UI. Semua aksi
/// (checkForUpdate, download, install) berjalan lewat sini supaya
/// transisinya terpusat dan dapat diuji.
class UpdateNotifier extends Notifier<UpdateState> {
  Future<void>? _inFlightDownload;

  @override
  UpdateState build() {
    final config = ref.watch(updateConfigProvider);
    return UpdateState(
      status: UpdateStatus.idle,
      currentVersion: config.currentAppVersion,
    );
  }

  UpdateService get _service => UpdateService(
        fetcher: ref.read(updateManifestFetcherProvider),
        currentAppVersion: state.currentVersion,
      );

  /// Memeriksa manifest server dan memperbarui status.
  Future<void> checkForUpdate() async {
    state = state.copyWith(
      status: UpdateStatus.checking,
      errorMessage: null,
      errorInfo: null,
    );
    final config = ref.read(updateConfigProvider);
    try {
      final result = await _service.checkForUpdate();
      if (!ref.mounted) return;
      state = state.copyWith(
        status: result.isUpdateAvailable
            ? UpdateStatus.available
            : UpdateStatus.upToDate,
        manifest: result.manifest,
        apkPath: null,
        downloadProgress: null,
        errorMessage: null,
        errorInfo: null,
        lastCheckedAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      if (!ref.mounted) return;
      final info = UpdateErrorInfo.fromError(
        e,
        targetUrl: config.manifestUrl,
        stackTrace: stackTrace,
        isDownload: false,
      );
      state = state.copyWith(
        status: UpdateStatus.downloadFailed,
        errorMessage: info.userMessage,
        errorInfo: info,
        lastCheckedAt: DateTime.now(),
      );
    }
  }

  /// Mengunduh APK dari manifest aktif.
  ///
  /// Bila unduhan sedang berjalan, panggilan berikutnya mengikuti unduhan
  /// yang sama alih-alih memulai ulang.
  Future<void> downloadApk() async {
    final manifest = state.manifest;
    if (manifest == null) return;
    if (state.status == UpdateStatus.downloading) {
      return _inFlightDownload;
    }

    final directory = await ref.read(apkDownloadDirectoryProvider)();
    final destination =
        '${directory.path}/BendaharaAlien-${manifest.latestVersion}.apk';

    final download = _service
        .downloadApk(
      apkUrl: manifest.apkUrl,
      destinationPath: destination,
      client: ref.read(httpClientFactoryProvider)(),
      onProgress: (progress) {
        if (!ref.mounted) return;
        state = state.copyWith(
          status: UpdateStatus.downloading,
          downloadProgress: progress.fraction,
          receivedBytes: progress.received,
          totalBytes: progress.total,
        );
      },
    )
        .then((file) {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: UpdateStatus.readyToInstall,
        apkPath: file.path,
        downloadProgress: 1.0,
      );
    }).catchError((Object e, StackTrace stackTrace) {
      if (!ref.mounted) return;
      final info = UpdateErrorInfo.fromError(
        e,
        targetUrl: manifest.apkUrl,
        stackTrace: stackTrace,
        isDownload: true,
      );
      state = state.copyWith(
        status: UpdateStatus.downloadFailed,
        errorMessage: info.userMessage,
        errorInfo: info,
      );
    });

    _inFlightDownload = download;
    state = state.copyWith(status: UpdateStatus.downloading);
    await download;
    _inFlightDownload = null;
  }

  /// Memicu installer Android untuk APK yang sudah diunduh.
  Future<bool> installApk() async {
    final apkPath = state.apkPath;
    if (apkPath == null) return false;
    if (state.status != UpdateStatus.readyToInstall) return false;

    state = state.copyWith(status: UpdateStatus.installing);
    final trigger = ref.read(apkInstallTriggerProvider);
    final launched = await trigger(apkPath);
    if (!ref.mounted) return launched;

    // Kembali ke readyToInstall supaya tombol pasang tetap hidup bila
    // pengguna membatalkan dialog sistem dan ingin mencoba lagi.
    state = state.copyWith(status: UpdateStatus.readyToInstall);
    return launched;
  }

  /// Memungkinkan simulasi 4 status pembaruan untuk pengujian UI langsung di HP/emulator.
  void simulateState(UpdateStatus targetStatus) {
    final config = ref.read(updateConfigProvider);
    switch (targetStatus) {
      case UpdateStatus.upToDate:
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          manifest: UpdateManifest(
            latestVersion: state.currentVersion,
            releaseNotes: 'Tidak ada pembaruan baru. Versi saat ini adalah yang paling mutakhir.',
            apkUrl: '',
          ),
          apkPath: null,
          downloadProgress: null,
          errorMessage: null,
          errorInfo: null,
          lastCheckedAt: DateTime.now(),
        );
        break;
      case UpdateStatus.available:
        state = state.copyWith(
          status: UpdateStatus.available,
          manifest: const UpdateManifest(
            latestVersion: '1.1.0',
            releaseNotes:
                '• Peningkatan sistem pelaporan rekapitulasi kas siswa.\n• Desain baru kartu status pembaruan dan log diagnostik.\n• Optimasi performa database SQLite dan kelancaran UI.',
            apkUrl: 'https://example.com/BendaharaAlien-v1.1.0.apk',
            minRequiredVersion: '1.0.0',
          ),
          apkPath: null,
          downloadProgress: null,
          receivedBytes: null,
          totalBytes: null,
          errorMessage: null,
          errorInfo: null,
          lastCheckedAt: DateTime.now(),
        );
        break;
      case UpdateStatus.downloading:
        state = state.copyWith(
          status: UpdateStatus.downloading,
          manifest: const UpdateManifest(
            latestVersion: '1.1.0',
            releaseNotes:
                '• Peningkatan sistem pelaporan rekapitulasi kas siswa.\n• Desain baru kartu status pembaruan dan log diagnostik.\n• Optimasi performa database SQLite dan kelancaran UI.',
            apkUrl: 'https://example.com/BendaharaAlien-v1.1.0.apk',
            minRequiredVersion: '1.0.0',
          ),
          apkPath: null,
          downloadProgress: 0.65,
          receivedBytes: 46347059,
          totalBytes: 71303168,
          errorMessage: null,
          errorInfo: null,
          lastCheckedAt: DateTime.now(),
        );
        break;
      case UpdateStatus.readyToInstall:
        state = state.copyWith(
          status: UpdateStatus.readyToInstall,
          manifest: const UpdateManifest(
            latestVersion: '1.1.0',
            releaseNotes: 'Pembaruan siap dipasang.',
            apkUrl: 'https://example.com/BendaharaAlien-v1.1.0.apk',
          ),
          apkPath: '/data/user/0/com.bendahara.app.alien/cache/BendaharaAlien-1.1.0.apk',
          downloadProgress: 1.0,
          errorMessage: null,
          errorInfo: null,
          lastCheckedAt: DateTime.now(),
        );
        break;
      case UpdateStatus.downloadFailed:
        final info = UpdateErrorInfo.fromError(
          const HttpException('Server manifest membalas kode 404.'),
          targetUrl: config.manifestUrl,
        );
        state = state.copyWith(
          status: UpdateStatus.downloadFailed,
          errorMessage: info.userMessage,
          errorInfo: info,
          lastCheckedAt: DateTime.now(),
        );
        break;
      default:
        break;
    }
  }
}

/// Provider reaktif untuk UI: watch [updateNotifierProvider].
final updateNotifierProvider =
    NotifierProvider<UpdateNotifier, UpdateState>(UpdateNotifier.new);
