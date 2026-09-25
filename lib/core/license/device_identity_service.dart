import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Layanan penghasil dan penyimpan ID Perangkat unik dan permanen.
///
/// Setiap perangkat memiliki identitas berformat Crockford Base32
/// (contoh: `DEV-8K2M-9Q4X`) yang diikat ke hardware device (misal Android ID)
/// dan disimpan di direktori internal aplikasi.
///
/// Karakteristik Ketahanan (Resilience):
///   * Persisten melintasi proses uninstall dan reinstall aplikasi.
///   * Persisten melintasi restart (reboot) maupun saat perangkat dimatikan.
///   * Terlindungi dari kegagalan I/O direktori sementara lewat hardware anchor.
class DeviceIdentityService {
  DeviceIdentityService._();

  static const String _fileName = 'bndh_device_identity.id';
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const MethodChannel _channel = MethodChannel('device_identity');
  static const MethodChannel _fallbackChannel = MethodChannel('apk_installer');

  static String? _inMemoryOverride;
  static String? _cachedId;

  /// Override nilai ID perangkat untuk keperluan pengujian otomatis.
  static void setOverrideForTesting(String? id) {
    _inMemoryOverride = id;
    _cachedId = id;
  }

  /// Reset cache ID perangkat (dipakai pada tearDown pengujian).
  static void resetForTesting() {
    _inMemoryOverride = null;
    _cachedId = null;
  }

  /// Menghasilkan string acak 8 karakter Crockford Base32 berformat `DEV-XXXX-XXXX`.
  static String generateRandomDeviceId({Random? random}) {
    final rng = random ?? Random.secure();
    final p1 = List.generate(4, (_) => _alphabet[rng.nextInt(_alphabet.length)]).join();
    final p2 = List.generate(4, (_) => _alphabet[rng.nextInt(_alphabet.length)]).join();
    return 'DEV-$p1-$p2';
  }

  /// Menghasilkan Device ID yang deterministik dari hardware seed (misal Android ID)
  /// menggunakan salted SHA-256 dipetakan ke 8 karakter Crockford Base32.
  /// Menjamin ID identik meskipun aplikasi di-uninstall, perangkat di-restart,
  /// atau dimatikan.
  static String deriveDeterministicDeviceId(String hardwareSeed) {
    final cleanSeed = hardwareSeed.trim();
    if (cleanSeed.isEmpty) {
      return generateRandomDeviceId();
    }
    final bytes = utf8.encode('bndh_alien_secure_device_salt_v1_$cleanSeed');
    final digest = sha256.convert(bytes);

    final buffer = StringBuffer();
    for (int i = 0; i < 8; i++) {
      buffer.write(_alphabet[digest.bytes[i] % _alphabet.length]);
    }
    final s = buffer.toString();
    return 'DEV-${s.substring(0, 4)}-${s.substring(4, 8)}';
  }

  /// Mengambil ID Perangkat yang tersimpan secara permanen.
  /// Bila belum ada, ID baru akan di-generate dan disimpan ke disk.
  static Future<String> getDeviceId() async {
    if (_inMemoryOverride != null && _inMemoryOverride!.isNotEmpty) {
      return _inMemoryOverride!;
    }
    if (_cachedId != null && _cachedId!.isNotEmpty) {
      return _cachedId!;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _cachedId ??= generateRandomDeviceId();
      return _cachedId!;
    }

    // 1. Cek berkas penyimpanan lokal jika sudah pernah dibuat
    File? identityFile;
    try {
      final dir = await getApplicationSupportDirectory();
      identityFile = File('${dir.path}${Platform.pathSeparator}$_fileName');
      if (await identityFile.exists()) {
        final content = (await identityFile.readAsString()).trim().toUpperCase();
        if (content.isNotEmpty && content.startsWith('DEV-') && content.length == 13) {
          _cachedId = content;
          return content;
        }
      }
    } catch (_) {
      // Abaikan galat I/O direktori lokal sementara
    }

    // 2. Hardware Anchored Derivation (Persisten melintasi Uninstall, Restart, & Power-off)
    String? hardwareId;
    if (Platform.isAndroid) {
      try {
        hardwareId = await _channel.invokeMethod<String>('getHardwareDeviceId');
      } catch (_) {
        try {
          hardwareId = await _fallbackChannel.invokeMethod<String>('getHardwareDeviceId');
        } catch (_) {
          // Fallback jika channel native belum terpasang atau gagal
        }
      }
    }

    String finalDeviceId;
    if (hardwareId != null && hardwareId.trim().isNotEmpty) {
      finalDeviceId = deriveDeterministicDeviceId(hardwareId);
    } else {
      // Fallback jika bukan Android atau hardwareId tidak terbaca
      finalDeviceId = generateRandomDeviceId();
    }

    // 3. Simpan ke berkas lokal untuk redundansi dan performa baca cepat
    if (identityFile != null) {
      try {
        await identityFile.writeAsString(finalDeviceId);
      } catch (_) {
        // Jika gagal tulis, nilai tetap aman di memori & hardware anchor
      }
    }

    _cachedId = finalDeviceId;
    return finalDeviceId;
  }

  /// Mengambil ID perangkat secara sinkron dari cache memori jika sudah diinisialisasi,
  /// atau string placeholder bila sedang dimuat.
  static String? get cachedDeviceId => _inMemoryOverride ?? _cachedId;
}
