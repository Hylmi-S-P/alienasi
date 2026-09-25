// ignore_for_file: avoid_print

import 'package:bendahara_app/core/license/license_engine.dart';

void main(List<String> args) {
  final deviceId = args.isNotEmpty ? args[0].trim().toUpperCase() : null;
  final now = DateTime.now();
  final token = LicenseEngine.generate(deviceId: deviceId, issuedAt: now);
  final validation = LicenseEngine.validate(
    token: token,
    deviceId: deviceId,
    now: now,
  );

  print('====================================================');
  print('     BENDAHARA APP — 28-DAY LICENSE GENERATOR       ');
  print('====================================================');
  if (deviceId != null) {
    print('Terkunci untuk: $deviceId (1 Perangkat)');
  } else {
    print('Terkunci untuk: Universal (Tanpa ID Perangkat)');
    print('Tip Penggunaan: dart run tool/generate_license.dart <DEVICE_ID>');
  }
  print('Kode Aktivasi : $token');
  print('Tanggal Terbit: ${validation.issuedAt?.toLocal()}');
  print('Masa Aktif    : 28 hari sejak aktivasi pertama kali di HP');
  print('Status Awal   : ${validation.status.name} (${validation.message})');
  print('====================================================');
  print('\nFormat Pesan WhatsApp Siap Kirim ke Pembeli:');
  print('----------------------------------------------------');
  print(
    'Halo! Terima kasih atas pembayarannya (Rp 25.000).\n'
    'Berikut kode aktivasi Bendahara Alien khusus untuk perangkat Anda'
    '${deviceId != null ? " ($deviceId)" : ""}:\n\n'
    '🔑 KODE: $token\n\n'
    'Masa aktif: 28 hari sejak pertama kali diaktivasi di aplikasi.\n'
    'Silakan buka aplikasi Bendahara dan masukkan kode ini pada menu aktivasi.\n'
    'Catatan: Kode ini dikunci khusus untuk 1 HP Anda dan tidak dapat digunakan di perangkat lain.',
  );
  print('----------------------------------------------------');
}
