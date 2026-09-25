// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Server lokal untuk menguji pembaruan in-app secara nyata di emulator atau HP.
///
/// Menjalankan HTTP server di port 8080 yang menyajikan:
///   - GET /manifest.json (berkas manifest pembaruan)
///   - GET /app.apk (berkas APK Bendahara Alien dari root proyek atau build)
///
/// Penggunaan:
///   dart run tool/serve_update.dart
void main() async {
  final port = 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  
  // Deteksi berkas APK yang tersedia
  File apkFile = File('Bendahara-Alien-v1.0.1.apk');
  if (!await apkFile.exists()) {
    apkFile = File('Bendahara-Alien-v1.0.0.apk');
  }
  if (!await apkFile.exists()) {
    apkFile = File('build/app/outputs/flutter-apk/app-release.apk');
  }

  if (!await apkFile.exists()) {
    print('Peringatan: Berkas APK belum ditemukan di root proyek atau folder build.');
    print('Jalankan `flutter build apk --release` lalu salin ke root terlebih dahulu.');
  } else {
    print('Berkas APK terdeteksi: ${apkFile.path} (${(await apkFile.length() / 1024 / 1024).toStringAsFixed(1)} MB)');
  }

  print('========================================================');
  print('     BENDAHARA ALIEN — LOCAL UPDATE TEST SERVER         ');
  print('========================================================');
  print('Server berjalan di port $port (0.0.0.0:$port)');
  print('');
  print('URL Endpoint Pengujian:');
  print('  • Emulator / MuMuPlayer : http://10.0.2.2:$port/manifest.json');
  
  try {
    final interfaces = await NetworkInterface.list();
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          print('  • HP Fisik (Wi-Fi yang sama) : http://${addr.address}:$port/manifest.json');
        }
      }
    }
  } catch (_) {}

  print('========================================================');
  print('Menunggu koneksi dari aplikasi Bendahara Alien...');

  await for (final request in server) {
    final path = request.uri.path;
    final clientIp = request.connectionInfo?.remoteAddress.address ?? 'unknown';

    if (path == '/manifest.json' || path == '/') {
      final hostHeader = request.headers.value('host') ?? '10.0.2.2:$port';
      final manifest = {
        'latest_version': '1.0.2',
        'release_notes':
            'Pembaruan v1.0.2 (Uji Coba Nyata):\n'
            '• Peningkatan performa dan optimasi render 60fps.\n'
            '• Notifikasi lisensi & tombol WhatsApp langsung ke Admin di Dashboard.\n'
            '• Uji coba unduh & instalasi in-app berhasil.',
        'apk_url': 'http://$hostHeader/app.apk',
        'min_required_version': '1.0.0',
      };

      final body = utf8.encode(jsonEncode(manifest));
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..headers.contentLength = body.length
        ..add(body);
      await request.response.close();
      print('[$clientIp] 200 GET /manifest.json (v1.0.2 dikirim)');
    } else if (path == '/app.apk') {
      if (await apkFile.exists()) {
        final length = await apkFile.length();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType =
              ContentType('application', 'vnd.android.package-archive')
          ..headers.contentLength = length;
        await request.response.addStream(apkFile.openRead());
        await request.response.close();
        print('[$clientIp] 200 GET /app.apk (Ukuran: ${(length / 1024 / 1024).toStringAsFixed(1)} MB dikirim)');
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('APK not found on server');
        await request.response.close();
        print('[$clientIp] 404 GET /app.apk (Berkas APK tidak ditemukan)');
      }
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found');
      await request.response.close();
      print('[$clientIp] 404 ${request.method} $path');
    }
  }
}
