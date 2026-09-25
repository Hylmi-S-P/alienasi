import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Status hasil verifikasi token lisensi.
enum LicenseStatus {
  /// Token asli, belum kedaluwarsa, dan jam perangkat wajar.
  valid,

  /// Struktur token tidak sesuai format BNDH-XXXX-XXXX-XXXX.
  malformed,

  /// Struktur benar tetapi tanda tangan HMAC tidak cocok.
  badSignature,

  /// Tanda tangan benar tetapi masa berlaku 28 hari sudah habis.
  expired,

  /// Jam sistem dimundurkan melewati batas toleransi.
  clockRollback,

  /// Kode lisensi dikunci untuk perangkat lain (ID Perangkat tidak cocok).
  deviceMismatch,
}

/// Hasil verifikasi token: status, rentang berlaku, dan sisa waktu.
class LicenseValidationResult {
  final LicenseStatus status;

  /// Waktu terbit hasil dekode token (UTC, tepat di awal hari).
  final DateTime? issuedAt;

  /// Waktu aktivasi pertama kali di perangkat (bila sudah teraktivasi).
  final DateTime? activatedAt;

  /// Waktu kedaluwarsa, selalu [LicenseEngine.validityDuration] setelah terbit
  /// (atau setelah aktivasi pertama bila sudah diaktivasi).
  final DateTime? expiresAt;

  /// Sisa waktu menuju kedaluwarsa; negatif bila sudah lewat.
  final Duration? remaining;

  /// Waktu acuan yang dipakai verifikasi (nilai terbesar antara jam sistem
  /// dan timestamp monotonik terakhir).
  final DateTime? effectiveNow;

  /// True bila jam sistem terdeteksi mundur melewati batas toleransi.
  final bool clockRollbackDetected;

  final String message;

  const LicenseValidationResult({
    required this.status,
    required this.message,
    this.issuedAt,
    this.activatedAt,
    this.expiresAt,
    this.remaining,
    this.effectiveNow,
    this.clockRollbackDetected = false,
  });

  bool get isValid => status == LicenseStatus.valid;

  /// Panjang masa berlaku token; selalu 28 hari untuk token yang terbaca.
  Duration? get validity {
    final start = activatedAt ?? issuedAt;
    final end = expiresAt;
    if (start == null || end == null) return null;
    return end.difference(start);
  }

  @override
  String toString() => 'LicenseValidationResult($status, $message)';
}

/// Generator dan verifier lisensi offline berbasis HMAC-SHA256.
///
/// Token berformat `BNDH-XXXX-XXXX-XXXX` (12 karakter Crockford Base32,
/// 60 bit): 4 bit versi format, 16 bit nomor hari terbit, dan 40 bit
/// potongan HMAC-SHA256 atas payload tersebut. Masa berlaku dihitung dari
/// tanggal terbit, jadi verifikasi tidak butuh jaringan sama sekali.
///
/// Kunci [defaultSecret] tertanam di binary yang sama dengan verifier.
/// Ini menangkal kode palsu yang diketik sembarangan, bukan menahan
/// reverse engineering APK: siapa pun yang mengekstrak kunci bisa membuat
/// token sendiri.
class LicenseEngine {
  LicenseEngine._();

  static const String tokenPrefix = 'BNDH';
  static const int validityDays = 28;
  static const Duration validityDuration = Duration(days: validityDays);

  /// Batas wajar selisih jam sebelum dianggap mundur. Menampung koreksi NTP
  /// dan jam perangkat yang baru disinkronkan.
  static const Duration rollbackTolerance = Duration(minutes: 10);

  /// Hari nol penomoran tanggal terbit. Rentang 16 bit menampung 65.536 hari
  /// sejak 1 Januari 2024 UTC.
  static final DateTime epoch = DateTime.utc(2024, 1, 1);

  /// Dipakai bersama oleh CLI generator (admin) dan verifier aplikasi.
  static const String defaultSecret =
      'bndh-offline-license-v1::9f3c1a7e5b2d4806a1c9e7f3b5d2084c';

  static const int _formatVersion = 1;
  static const int _groupLength = 4;
  static const int _groupCount = 3;
  static const int _bodyLength = _groupLength * _groupCount;
  static const int _tokenLength = tokenPrefix.length + _bodyLength;
  static const int _tagBits = 60 - 20;
  static const int _tagBytes = _tagBits ~/ 8;
  static const int _issueDayMax = 0xFFFF;
  static const int _issueDayMask = 0xFFFF;
  static const int _tagMask = (1 << _tagBits) - 1;

  /// Alfabet Crockford Base32: tanpa I, L, O, dan U supaya kode yang
  /// diketik ulang dari pesan WhatsApp tidak salah baca.
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Membuat token untuk [issuedAt] (default sekarang).
  /// Bila [deviceId] diisi, kode aktivasi akan dikunci khusus untuk perangkat tersebut.
  static String generate({
    String? deviceId,
    DateTime? issuedAt,
    String? secret,
  }) {
    final day = _dayNumber(issuedAt ?? DateTime.now());
    final payload = (_formatVersion << 16) | day;
    final tag = _sign(payload, secret ?? defaultSecret, deviceId: deviceId);
    return _format((payload << _tagBits) | tag);
  }

  /// Memverifikasi [token] pada waktu [now] (default sekarang).
  ///
  /// Bila [deviceId] diisi, verifikasi memeriksa apakah kode dikunci untuk
  /// perangkat ini atau kode universal. Bila token dibuat untuk perangkat lain,
  /// mengembalikan status [LicenseStatus.deviceMismatch].
  ///
  /// Bila [activatedAt] diberikan (dari database lokal), masa aktif 28 hari
  /// dihitung sejak waktu aktivasi pertama kali pada perangkat tersebut.
  static LicenseValidationResult validate({
    required String token,
    String? deviceId,
    String? expectedDeviceId,
    DateTime? now,
    DateTime? lastKnownTimestamp,
    DateTime? activatedAt,
    String? secret,
  }) {
    final current = (now ?? DateTime.now()).toUtc();
    final reference = lastKnownTimestamp?.toUtc();
    final effectiveNow = nextMonotonicTimestamp(
      now: current,
      lastKnownTimestamp: reference,
    );
    final rollback = isClockRollback(
      now: current,
      lastKnownTimestamp: reference,
    );

    final body = _extractBody(token);
    if (body == null) {
      return LicenseValidationResult(
        status: LicenseStatus.malformed,
        message: 'Format kode tidak dikenali. Contoh: BNDH-XXXX-XXXX-XXXX.',
        effectiveNow: effectiveNow,
        clockRollbackDetected: rollback,
      );
    }

    final value = _decode(body);
    if (value == null) {
      return LicenseValidationResult(
        status: LicenseStatus.malformed,
        message: 'Kode memuat karakter di luar alfabet lisensi.',
        effectiveNow: effectiveNow,
        clockRollbackDetected: rollback,
      );
    }

    final payload = value >> _tagBits;
    final tag = value & _tagMask;
    if (payload >> 16 != _formatVersion) {
      return LicenseValidationResult(
        status: LicenseStatus.malformed,
        message: 'Versi kode lisensi tidak didukung.',
        effectiveNow: effectiveNow,
        clockRollbackDetected: rollback,
      );
    }

    final sec = secret ?? defaultSecret;
    final expectedTagWithDevice =
        (deviceId != null && deviceId.trim().isNotEmpty)
            ? _sign(payload, sec, deviceId: deviceId)
            : null;
    final expectedTagUniversal = _sign(payload, sec, deviceId: null);

    bool matches = false;
    bool isDeviceMismatch = false;

    if (expectedTagWithDevice != null && tag == expectedTagWithDevice) {
      matches = true;
    } else if (tag == expectedTagUniversal) {
      matches = true;
    } else if (expectedDeviceId != null &&
        tag == _sign(payload, sec, deviceId: expectedDeviceId)) {
      isDeviceMismatch = true;
    }

    if (!matches) {
      return LicenseValidationResult(
        status: isDeviceMismatch
            ? LicenseStatus.deviceMismatch
            : LicenseStatus.badSignature,
        message: isDeviceMismatch
            ? 'Kode lisensi ini tidak cocok dengan ID Perangkat Anda.'
            : 'Kode lisensi tidak sah atau sudah diubah.',
        effectiveNow: effectiveNow,
        clockRollbackDetected: rollback,
      );
    }

    final issuedAt = epoch.add(Duration(days: payload & _issueDayMask));
    final baseDate = activatedAt ?? issuedAt;
    final expiresAt = baseDate.add(validityDuration);
    final remaining = expiresAt.difference(effectiveNow);

    if (rollback) {
      return LicenseValidationResult(
        status: LicenseStatus.clockRollback,
        message: 'Jam perangkat dimundurkan. Perbaiki tanggal dan jam, '
            'lalu coba lagi.',
        issuedAt: issuedAt,
        activatedAt: activatedAt,
        expiresAt: expiresAt,
        remaining: remaining,
        effectiveNow: effectiveNow,
        clockRollbackDetected: true,
      );
    }

    if (!effectiveNow.isBefore(expiresAt)) {
      return LicenseValidationResult(
        status: LicenseStatus.expired,
        message: 'Masa aktif 28 hari sudah berakhir.',
        issuedAt: issuedAt,
        activatedAt: activatedAt,
        expiresAt: expiresAt,
        remaining: remaining,
        effectiveNow: effectiveNow,
      );
    }

    return LicenseValidationResult(
      status: LicenseStatus.valid,
      message: 'Lisensi aktif.',
      issuedAt: issuedAt,
      activatedAt: activatedAt,
      expiresAt: expiresAt,
      remaining: remaining,
      effectiveNow: effectiveNow,
    );
  }

  /// True bila [now] tertinggal lebih dari [rollbackTolerance] dari
  /// [lastKnownTimestamp].
  static bool isClockRollback({
    required DateTime now,
    DateTime? lastKnownTimestamp,
  }) {
    final reference = lastKnownTimestamp?.toUtc();
    if (reference == null) return false;
    return now.toUtc().isBefore(reference.subtract(rollbackTolerance));
  }

  /// Timestamp monotonik berikutnya: nilai terbesar antara [now] dan
  /// [lastKnownTimestamp], supaya waktu yang dipakai aplikasi tidak pernah
  /// bergerak mundur.
  static DateTime nextMonotonicTimestamp({
    required DateTime now,
    DateTime? lastKnownTimestamp,
  }) {
    final current = now.toUtc();
    final reference = lastKnownTimestamp?.toUtc();
    if (reference == null || current.isAfter(reference)) return current;
    return reference;
  }

  /// Menyeragamkan input pengguna: huruf besar, tanpa pemisah, dan karakter
  /// rancu dipetakan ke alfabet resmi (O ke 0, I dan L ke 1).
  static String normalize(String raw) {
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < cleaned.length; i++) {
      final char = cleaned[i];
      if (char == 'O') {
        buffer.write('0');
      } else if (char == 'I' || char == 'L') {
        buffer.write('1');
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static int _dayNumber(DateTime issuedAt) {
    final utc = issuedAt.toUtc();
    if (utc.isBefore(epoch)) {
      throw ArgumentError.value(
        issuedAt,
        'issuedAt',
        'Tanggal terbit sebelum epoch lisensi (${epoch.toIso8601String()})',
      );
    }
    final days = utc.difference(epoch).inDays;
    if (days > _issueDayMax) {
      throw ArgumentError.value(
        issuedAt,
        'issuedAt',
        'Tanggal terbit di luar rentang token ($_issueDayMax hari sejak epoch)',
      );
    }
    return days;
  }

  /// Normalisasi ID Perangkat agar seragam untuk HMAC.
  static String normalizeDeviceId(String id) {
    final clean = id
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^0-9A-Z]'), '')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('O', '0');
    final body = clean.startsWith('DEV') ? clean.substring(3) : clean;
    if (body.isEmpty) return '';
    if (body.length >= 8) {
      return 'DEV-${body.substring(0, 4)}-${body.substring(4, 8)}';
    }
    return 'DEV-$body';
  }

  /// Potongan 40 bit pertama HMAC-SHA256 atas payload (dan opsional deviceId).
  static int _sign(int payload, String secret, {String? deviceId}) {
    final normalizedDevice = (deviceId != null && deviceId.trim().isNotEmpty)
        ? normalizeDeviceId(deviceId)
        : '';
    final message = normalizedDevice.isNotEmpty
        ? '$tokenPrefix|$_formatVersion|$payload|$normalizedDevice'
        : '$tokenPrefix|$_formatVersion|$payload';
    final mac = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(message))
        .bytes;
    var tag = 0;
    for (var i = 0; i < _tagBytes; i++) {
      tag = (tag << 8) | mac[i];
    }
    return tag;
  }

  static String _format(int value) {
    final chars = List<String>.filled(_bodyLength, '0');
    var rest = value;
    for (var i = _bodyLength - 1; i >= 0; i--) {
      chars[i] = _alphabet[rest & 31];
      rest >>= 5;
    }
    final groups = <String>[];
    for (var g = 0; g < _groupCount; g++) {
      groups.add(chars.sublist(g * _groupLength, (g + 1) * _groupLength).join());
    }
    return '$tokenPrefix-${groups.join('-')}';
  }

  /// Mengembalikan 12 karakter badan token, atau null bila panjangnya salah.
  ///
  /// Panjang 16 wajib berawalan BNDH. Panjang 12 diterima sebagai badan tanpa
  /// awalan, kecuali bila berawalan BNDH: itu hampir pasti token utuh yang
  /// terpotong satu grup.
  static String? _extractBody(String token) {
    final normalized = normalize(token);
    if (normalized.length == _tokenLength) {
      if (!normalized.startsWith(tokenPrefix)) return null;
      return normalized.substring(tokenPrefix.length);
    }
    if (normalized.length == _bodyLength &&
        !normalized.startsWith(tokenPrefix)) {
      return normalized;
    }
    return null;
  }

  static int? _decode(String body) {
    var value = 0;
    for (var i = 0; i < body.length; i++) {
      final index = _alphabet.indexOf(body[i]);
      if (index < 0) return null;
      value = (value << 5) | index;
    }
    return value;
  }
}
