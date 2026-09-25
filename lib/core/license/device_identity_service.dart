import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

/// Layanan penghasil dan penyimpan ID Perangkat unik dan permanen.
///
/// Setiap perangkat memiliki identitas berformat Crockford Base32
/// (contoh: `DEV-8K2M-9Q4X`) yang disimpan di direktori internal aplikasi.
/// ID ini digunakan untuk mengunci satu kode aktivasi agar hanya bisa
/// digunakan pada perangkat ini.
class DeviceIdentityService {
  DeviceIdentityService._();

  static const String _fileName = 'bndh_device_identity.id';
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

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

    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$_fileName');
      if (await file.exists()) {
        final content = (await file.readAsString()).trim().toUpperCase();
        if (content.isNotEmpty) {
          _cachedId = content;
          return content;
        }
      }

      final newId = generateRandomDeviceId();
      await file.writeAsString(newId);
      _cachedId = newId;
      return newId;
    } catch (_) {
      // Fallback jika path_provider tidak tersedia (misal lingkungan murni test tanpa mocking)
      _cachedId ??= generateRandomDeviceId();
      return _cachedId!;
    }
  }

  /// Mengambil ID perangkat secara sinkron dari cache memori jika sudah diinisialisasi,
  /// atau string placeholder bila sedang dimuat.
  static String? get cachedDeviceId => _inMemoryOverride ?? _cachedId;
}
