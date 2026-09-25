import 'dart:io';

import 'package:bendahara_app/core/license/license_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Titik acuan tetap supaya tes tidak bergantung jam mesin yang menjalankan.
final DateTime _now = DateTime.utc(2026, 9, 24, 10, 30);
final DateTime _issuedAt = DateTime.utc(2026, 9, 20);

void main() {
  group('LicenseEngine - format token', () {
    test('token mengikuti pola BNDH-XXXX-XXXX-XXXX', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      expect(token, matches(RegExp(r'^BNDH-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$')));
      expect(token.length, 19);
    });

    test('hanya memakai alfabet Crockford (tanpa I, L, O, U)', () {
      for (var day = 0; day < 40; day++) {
        final token = LicenseEngine.generate(issuedAt: _issuedAt.add(Duration(days: day)));
        final body = token.replaceAll('-', '').substring(4);
        expect(body.contains(RegExp('[ILOU]')), isFalse, reason: 'token=$token');
      }
    });

    test('terbitan pada hari yang sama identik', () {
      final a = LicenseEngine.generate(issuedAt: DateTime.utc(2026, 9, 20, 0, 0, 1));
      final b = LicenseEngine.generate(issuedAt: DateTime.utc(2026, 9, 20, 23, 59, 59));
      expect(a, b);
    });

    test('terbitan pada hari berbeda menghasilkan token berbeda', () {
      final a = LicenseEngine.generate(issuedAt: DateTime.utc(2026, 9, 20));
      final b = LicenseEngine.generate(issuedAt: DateTime.utc(2026, 9, 21));
      expect(a, isNot(b));
    });

    test('hari terbit ikut terdekode pada issuedAt token', () {
      final issued = DateTime.utc(2026, 12, 31);
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: issued),
        now: issued.add(const Duration(days: 1)),
      );
      expect(result.status, LicenseStatus.valid);
      expect(result.issuedAt, DateTime.utc(2026, 12, 31));
    });

    test('tanggal sebelum epoch lisensi ditolak saat generate', () {
      expect(
        () => LicenseEngine.generate(issuedAt: DateTime.utc(2023, 12, 31)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('LicenseEngine - masa berlaku 28 hari', () {
    test('token valid menghasilkan masa berlaku tepat 28 hari', () {
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: _now,
      );
      expect(result.status, LicenseStatus.valid);
      expect(result.isValid, isTrue);
      expect(result.validity, const Duration(days: 28));
      expect(result.validity, LicenseEngine.validityDuration);
      expect(result.expiresAt!.difference(result.issuedAt!), const Duration(days: 28));
      expect(result.issuedAt, _issuedAt);
      expect(result.expiresAt, _issuedAt.add(const Duration(days: 28)));
    });

    test('konstanta mesin menetapkan 28 hari', () {
      expect(LicenseEngine.validityDays, 28);
      expect(LicenseEngine.validityDuration, const Duration(days: 28));
    });

    test('sisa waktu dihitung dari waktu acuan', () {
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: _issuedAt.add(const Duration(days: 27, hours: 23)),
      );
      expect(result.status, LicenseStatus.valid);
      expect(result.remaining, const Duration(hours: 1));
    });

    test('batas akhir: sesaat sebelum 28 hari masih valid', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final result = LicenseEngine.validate(
        token: token,
        now: _issuedAt.add(const Duration(days: 28)).subtract(const Duration(seconds: 1)),
      );
      expect(result.status, LicenseStatus.valid);
      expect(result.remaining, const Duration(seconds: 1));
    });

    test('tepat 28 hari sudah kedaluwarsa', () {
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: _issuedAt.add(const Duration(days: 28)),
      );
      expect(result.status, LicenseStatus.expired);
      expect(result.isValid, isFalse);
      expect(result.remaining, Duration.zero);
    });

    test('token lama 29 hari kedaluwarsa', () {
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: _issuedAt.add(const Duration(days: 29)),
      );
      expect(result.status, LicenseStatus.expired);
      expect(result.remaining!.isNegative, isTrue);
    });

    test('tanggal terbit tetap terbaca pada token kedaluwarsa', () {
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: DateTime.utc(2027, 1, 1),
      );
      expect(result.status, LicenseStatus.expired);
      expect(result.issuedAt, _issuedAt);
      expect(result.expiresAt, _issuedAt.add(const Duration(days: 28)));
    });
  });

  group('LicenseEngine - penolakan token diubah', () {
    test('setiap perubahan satu karakter ditolak', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final body = token.replaceAll('-', '').substring(4);
      var checked = 0;

      for (var i = 0; i < body.length; i++) {
        for (final replacement in ['0', '7', 'Z', 'B', 'Q']) {
          if (replacement == body[i]) continue;
          final tamperedBody =
              body.substring(0, i) + replacement + body.substring(i + 1);
          final tampered = 'BNDH-${tamperedBody.substring(0, 4)}-'
              '${tamperedBody.substring(4, 8)}-${tamperedBody.substring(8)}';
          final result = LicenseEngine.validate(token: tampered, now: _now);
          expect(result.isValid, isFalse, reason: 'lolos: $tampered');
          expect(result.status, isNot(LicenseStatus.valid));
          checked++;
        }
      }
      expect(checked, greaterThan(40));
    });

    test('urutan grup ditukar ditolak', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final body = token.replaceAll('-', '').substring(4);
      final swapped = 'BNDH-${body.substring(4, 8)}-${body.substring(0, 4)}-'
          '${body.substring(8)}';
      final result = LicenseEngine.validate(token: swapped, now: _now);
      // Penukaran grup merusak nibel versi sehingga bisa terbaca malformed
      // atau badSignature; yang penting token tidak pernah lolos.
      expect(result.status, anyOf(LicenseStatus.badSignature, LicenseStatus.malformed));
      expect(result.isValid, isFalse);
    });

    test('token dengan tanda tangan dari kunci lain ditolak', () {
      final forged = LicenseEngine.generate(
        issuedAt: _issuedAt,
        secret: 'kunci-palsu-yang-tidak-dipakai-aplikasi',
      );
      final result = LicenseEngine.validate(token: forged, now: _now);
      expect(result.status, LicenseStatus.badSignature);
      expect(result.message, contains('tidak sah'));
    });

    test('kunci kustom diterima bila dipakai konsisten', () {
      const secret = 'kunci-uji-coba';
      final token = LicenseEngine.generate(issuedAt: _issuedAt, secret: secret);
      final accepted = LicenseEngine.validate(token: token, now: _now, secret: secret);
      final rejected = LicenseEngine.validate(token: token, now: _now);
      expect(accepted.status, LicenseStatus.valid);
      expect(rejected.status, LicenseStatus.badSignature);
    });

    test('token acak ditolak', () {
      const candidates = [
        'BNDH-0000-0000-0000',
        'BNDH-1111-1111-1111',
        'BNDH-ZZZZ-ZZZZ-ZZZZ',
        'BNDH-ABCD-EFGH-JKMN',
      ];
      for (final candidate in candidates) {
        expect(
          LicenseEngine.validate(token: candidate, now: _now).isValid,
          isFalse,
          reason: candidate,
        );
      }
    });
  });

  group('LicenseEngine - token tidak berbentuk', () {
    test('masukan kosong atau sampah ditolak sebagai malformed', () {
      const inputs = ['', '   ', 'BNDH', 'BNDH-', 'halo dunia', '12345', 'BNDH-1234-5678'];
      for (final input in inputs) {
        final result = LicenseEngine.validate(token: input, now: _now);
        expect(result.status, LicenseStatus.malformed, reason: 'input="$input"');
      }
    });

    test('awalan selain BNDH ditolak', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final wrongPrefix = 'XXXX${token.substring(4)}';
      expect(
        LicenseEngine.validate(token: wrongPrefix, now: _now).status,
        LicenseStatus.malformed,
      );
    });

    test('token lebih panjang dari format ditolak', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      expect(
        LicenseEngine.validate(token: '${token}AB', now: _now).status,
        LicenseStatus.malformed,
      );
    });

    test('hasil malformed tidak membawa rentang berlaku', () {
      final result = LicenseEngine.validate(token: 'bukan-kode', now: _now);
      expect(result.issuedAt, isNull);
      expect(result.expiresAt, isNull);
      expect(result.validity, isNull);
    });
  });

  group('LicenseEngine - normalisasi masukan', () {
    test('huruf kecil dan spasi diterima', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final messy = '  ${token.toLowerCase().replaceAll('-', ' ')}  ';
      expect(LicenseEngine.validate(token: messy, now: _now).status, LicenseStatus.valid);
    });

    test('token tanpa pemisah diterima', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      expect(
        LicenseEngine.validate(token: token.replaceAll('-', ''), now: _now).status,
        LicenseStatus.valid,
      );
    });

    test('badan token saja tanpa awalan diterima', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final bodyOnly = token.split('-').skip(1).join();
      expect(
        LicenseEngine.validate(token: bodyOnly, now: _now).status,
        LicenseStatus.valid,
      );
    });

    test('karakter rancu O, I, dan L dipetakan ke digit', () {
      expect(LicenseEngine.normalize('bndh-o1il-zzzz-zzzz'), 'BNDH0111ZZZZZZZZ');
      expect(LicenseEngine.normalize('oOoO'), '0000');
      expect(LicenseEngine.normalize('iIlL'), '1111');
    });

    test('normalisasi tidak mengubah arti token asli', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final mangled = token.replaceAll('0', 'O').replaceAll('1', 'I').toLowerCase();
      expect(LicenseEngine.validate(token: mangled, now: _now).status, LicenseStatus.valid);
    });
  });

  group('LicenseEngine - pertahanan jam mundur', () {
    test('tanpa timestamp tersimpan tidak ada indikasi mundur', () {
      expect(
        LicenseEngine.isClockRollback(now: _now, lastKnownTimestamp: null),
        isFalse,
      );
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: _now,
      );
      expect(result.clockRollbackDetected, isFalse);
      expect(result.status, LicenseStatus.valid);
    });

    test('selisih kecil masih dalam toleransi', () {
      final reference = _now;
      final skewed = reference.subtract(const Duration(minutes: 5));
      expect(
        LicenseEngine.isClockRollback(now: skewed, lastKnownTimestamp: reference),
        isFalse,
      );
      expect(
        LicenseEngine.validate(
          token: LicenseEngine.generate(issuedAt: _issuedAt),
          now: skewed,
          lastKnownTimestamp: reference,
        ).status,
        LicenseStatus.valid,
      );
    });

    test('mundur melewati toleransi ditolak', () {
      final reference = _now;
      final rolledBack = reference.subtract(const Duration(minutes: 30));
      expect(
        LicenseEngine.isClockRollback(now: rolledBack, lastKnownTimestamp: reference),
        isTrue,
      );
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: rolledBack,
        lastKnownTimestamp: reference,
      );
      expect(result.status, LicenseStatus.clockRollback);
      expect(result.clockRollbackDetected, isTrue);
      expect(result.message, contains('dimundurkan'));
    });

    test('jam dimundurkan setahun tetap ditolak', () {
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: _issuedAt.subtract(const Duration(days: 365)),
        lastKnownTimestamp: _now,
      );
      expect(result.status, LicenseStatus.clockRollback);
    });

    test('jam mundur tidak memperpanjang lisensi yang sudah habis', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final realNow = _issuedAt.add(const Duration(days: 40));
      final rolledBack = realNow.subtract(const Duration(minutes: 5));

      final result = LicenseEngine.validate(
        token: token,
        now: rolledBack,
        lastKnownTimestamp: realNow,
      );
      expect(result.status, LicenseStatus.expired);
      expect(result.effectiveNow, realNow);
    });

    test('waktu acuan memakai nilai terbesar antara jam sistem dan timestamp tersimpan', () {
      final reference = _now;
      expect(
        LicenseEngine.nextMonotonicTimestamp(
          now: _now.subtract(const Duration(hours: 2)),
          lastKnownTimestamp: reference,
        ),
        reference,
      );
      expect(
        LicenseEngine.nextMonotonicTimestamp(
          now: _now.add(const Duration(hours: 2)),
          lastKnownTimestamp: reference,
        ),
        _now.add(const Duration(hours: 2)),
      );
      expect(
        LicenseEngine.nextMonotonicTimestamp(now: _now, lastKnownTimestamp: null),
        _now,
      );
    });

    test('waktu acuan dinormalkan ke UTC', () {
      final local = DateTime(2026, 9, 24, 10, 30);
      final result = LicenseEngine.nextMonotonicTimestamp(now: local);
      expect(result.isUtc, isTrue);
      expect(result, local.toUtc());
    });
  });

  group('LicenseEngine - kemurnian offline', () {
    test('kunci default terpasang dan tidak kosong', () {
      expect(LicenseEngine.defaultSecret.isNotEmpty, isTrue);
      expect(LicenseEngine.defaultSecret.length, greaterThanOrEqualTo(32));
    });

    test('sumber engine tidak memanggil jaringan atau I/O', () {
      final source = File(_engineSourcePath()).readAsStringSync();
      const banned = [
        'dart:io',
        'dart:html',
        'HttpClient',
        'Socket',
        'package:http/',
        'package:dio/',
        'WebSocket',
        'Process.run',
      ];
      for (final needle in banned) {
        expect(source.contains(needle), isFalse, reason: 'ditemukan "$needle"');
      }
    });
  });
}

/// Menaiki direktori sampai menemukan pubspec.yaml supaya tes tetap jalan
/// walau runner memakai cwd berbeda.
String _engineSourcePath() {
  var dir = Directory.current;
  for (var depth = 0; depth < 5; depth++) {
    final candidate = File(
      '${dir.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
      'core${Platform.pathSeparator}license${Platform.pathSeparator}license_engine.dart',
    );
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('license_engine.dart tidak ditemukan dari ${Directory.current.path}');
}
