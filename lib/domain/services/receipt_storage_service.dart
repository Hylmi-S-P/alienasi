import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
/// Service penyimpanan foto nota fisik yang permanen.
///
/// Sesuai spesifikasi ARCHITECTURE.md seksi 3.3:
/// - Foto nota TIDAK disimpan sebagai BLOB di database SQLite.
/// - Foto disimpan di subdirektori terisolasi `receipts/YYYY-MM/`
///   di dalam application documents directory dengan nama berkas UUID.
/// - Di database hanya path relatif (contoh: `receipts/2026-09/abc....jpg`)
///   yang disimpan agar pemulihan / pemindahan perangkat tetap fleksibel.
/// - Menyediakan garbage collection untuk berkas foto yang tidak lagi
///   dirujuk transaksi mana pun.
class ReceiptStorageService {
  ReceiptStorageService._();

  static const String _receiptsRootDir = 'receipts';

  /// Cache hasil getApplicationDocumentsDirectory agar versi sinkron bisa
  /// dipakai di UI/test tanpa menunggu platform channel.
  static Directory? _cachedAppDocsDir;

  /// Inisialisasi cepat yang aman dipanggil di bootstrap aplikasi.
  static Future<void> warmUpCache() async {
    try {
      _cachedAppDocsDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      // Biarkan null; sync fallback akan menangani.
    }
  }

  static Directory get _appDocsDir {
    return _cachedAppDocsDir ?? Directory.systemTemp;
  }

  /// Menyalin berkas foto sementara (cache image_picker / kamera) ke
  /// penyimpanan aplikasi yang permanen.
  ///
  /// Mengembalikan path relatif (contoh: `receipts/2026-09/uuid.jpg`)
  /// atau null jika gagal.
  ///
  /// Jika [relativePath] sudah berupa path relatif milik penyimpanan
  /// aplikasi ini (bukan path cache eksternal), berkas tidak disalin ulang.
  static Future<String?> persistPickedReceipt(String pickedPath) async {
    try {
      // Jika sudah path relatif internal, kembalikan apa adanya.
      if (!p.isAbsolute(pickedPath) && pickedPath.startsWith('$_receiptsRootDir/')) {
        return pickedPath;
      }

      final source = File(pickedPath);
      if (!await source.exists()) return null;

      final bytes = await source.readAsBytes();
      if (bytes.isEmpty) return null;

      return await writeReceiptBytes(bytes, extension: p.extension(pickedPath).toLowerCase());
    } catch (e) {
      debugPrint('ReceiptStorageService.persistPickedReceipt gagal: $e');
      return null;
    }
  }

  /// Menulis byte foto nota ke penyimpanan aplikasi permanen.
  ///
  /// Mengembalikan path relatif berkas yang baru dibuat.
  static Future<String?> writeReceiptBytes(
    Uint8List bytes, {
    String extension = '.jpg',
  }) async {
    try {
      final appDir = _appDocsDir;
      final now = DateTime.now();
      final monthDir = p.join(
        appDir.path,
        _receiptsRootDir,
        '${now.year}-${now.month.toString().padLeft(2, '0')}',
      );

      await Directory(monthDir).create(recursive: true);

      final safeExt = (extension.isEmpty || !extension.startsWith('.')) ? '.jpg' : extension;
      final filename = '${const Uuid().v4()}$safeExt';
      final target = p.join(monthDir, filename);

      final file = File(target);
      await file.writeAsBytes(bytes, flush: true);

      // Kembalikan path relatif terhadap application documents directory.
      return p.relative(target, from: appDir.path).replaceAll('\\', '/');
    } catch (e) {
      debugPrint('ReceiptStorageService.writeReceiptBytes gagal: $e');
      return null;
    }
  }

  static Future<String> resolveAbsolutePath(String storedPath) async {
    if (p.isAbsolute(storedPath)) {
      return storedPath;
    }
    if (_cachedAppDocsDir == null) {
      await warmUpCache();
    }
    return p.join(_appDocsDir.path, storedPath.replaceAll('/', p.separator));
  }

  /// Versi sinkron dari [resolveAbsolutePath]. Aman dipakai di widget build
  /// dan test karena tidak memuat platform channel; jika cache belum siap
  /// (mis. di unit test tanpa mock), jatuh ke direktori temporer sistem dan
  /// `existsSync` akan mengembalikan false seperti perilaku implementasi lama.
  static String resolveAbsolutePathSync(String storedPath) {
    if (p.isAbsolute(storedPath)) {
      return storedPath;
    }
    return p.join(_appDocsDir.path, storedPath.replaceAll('/', p.separator));
  }

  /// Memeriksa apakah berkas foto nota masih ada di penyimpanan. Sinkron,
  /// tidak bergantung pada plugin channel async.
  static bool existsSync(String storedPath) {
    try {
      return File(resolveAbsolutePathSync(storedPath)).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Memeriksa apakah berkas foto nota masih ada di penyimpanan.
  static Future<bool> exists(String storedPath) async {
    try {
      final abs = await resolveAbsolutePath(storedPath);
      return File(abs).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Membaca byte foto nota. Mengembalikan null jika berkas tidak ada.
  static Future<Uint8List?> readBytes(String storedPath) async {
    try {
      final abs = await resolveAbsolutePath(storedPath);
      final f = File(abs);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  /// Menghapus berkas foto nota dari penyimpanan aplikasi.
  static Future<void> delete(String storedPath) async {
    try {
      if (storedPath.isEmpty) return;
      final abs = await resolveAbsolutePath(storedPath);
      final f = File(abs);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {
      // Penghapusan bersifat best-effort.
    }
  }

  /// Membaca seluruh path relatif foto nota yang masih dirujuk database.
  ///
  /// [referencedPaths] adalah daftar path foto (dari kolom
  /// transactions.receipt_image_path) yang masih dipakai.
  static Future<void> garbageCollectUnreferenced(Set<String> referencedPaths) async {
    try {
      if (_cachedAppDocsDir == null) {
        await warmUpCache();
      }
      final appDir = _appDocsDir;
      final receiptsRoot = Directory(p.join(appDir.path, _receiptsRootDir));
      if (!await receiptsRoot.exists()) return;

      // Normalisasi referensi: hanya path relatif internal.
      final referenced = referencedPaths
          .where((path) => path.isNotEmpty && !p.isAbsolute(path) && path.startsWith('$_receiptsRootDir/'))
          .map((path) => path.replaceAll('\\', '/'))
          .toSet();

      await for (final entity in receiptsRoot.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final rel = p
            .relative(entity.path, from: appDir.path)
            .replaceAll('\\', '/');
        if (!referenced.contains(rel)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {
      // GC bersifat best-effort; jangan ganggu alur utama.
    }
  }
}
