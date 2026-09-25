import 'dart:io';

import 'package:flutter/services.dart';

/// Memicu installer Android untuk berkas APK yang sudah diunduh.
///
/// Memakai platform channel `apk_installer` dengan implementasi Kotlin di
/// `MainActivity.kt`: Intent `ACTION_VIEW` dengan MIME
/// `application/vnd.android.package-archive` dan `FLAG_GRANT_READ_URI_PERMISSION`
/// lewat FileProvider. Di luar Android, metode mengembalikan false dan UI
/// menampilkan pesan yang sesuai.
class ApkInstallerService {
  ApkInstallerService._();

  static const MethodChannel _channel = MethodChannel('apk_installer');

  static bool get _isAndroidRealDevice =>
      Platform.isAndroid && !Platform.environment.containsKey('FLUTTER_TEST');

  /// Mengembalikan true bila intent installer berhasil dikirim.
  ///
  /// Mengirim intent bukan jaminan pemasangan selesai: pengguna masih harus
  /// menekan tombol pemasang di dialog sistem Android, dan izin memasang
  /// aplikasi tak dikenal (REQUEST_INSTALL_PACKAGES) mungkin harus
  /// diaktifkan dulu di pengaturan.
  static Future<bool> installApk(String filePath) async {
    if (!_isAndroidRealDevice) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Platform belum punya implementasi native (mis. sedang diuji di
      // desktop atau web); biarkan UI menampilkan pesan manual.
      return false;
    }
  }

  /// Memeriksa apakah izin memasang aplikasi tak dikenal sudah aktif.
  static Future<bool> canRequestPackageInstalls() async {
    if (!_isAndroidRealDevice) return true;
    try {
      final result = await _channel.invokeMethod<bool>(
        'canRequestPackageInstalls',
      );
      return result ?? true;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  /// Membuka pengaturan sistem untuk izin memasang aplikasi tak dikenal,
  /// dipakai ketika Android menolak memasang tanpa izin tersebut.
  static Future<bool> openUnknownAppsSettings() async {
    if (!_isAndroidRealDevice) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'openUnknownAppsSettings',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Mengambil nama versi aplikasi terpasang (mis. "1.0.2") dari sistem OS Android.
  static Future<String?> getAppVersion() async {
    if (!_isAndroidRealDevice) return null;
    try {
      final result = await _channel.invokeMethod<String>(
        'getAppVersion',
      );
      return result;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
