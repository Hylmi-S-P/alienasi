import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bendahara_app/core/license/license_engine.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/license_repository.dart';

/// Titik waktu tetap supaya hasil tes tidak bergantung jam mesin runner.
final DateTime _now = DateTime.utc(2026, 9, 24, 10, 30);
final DateTime _issuedAt = DateTime.utc(2026, 9, 20);

void main() {
  late AppDatabase db;
  late LicenseRepository repo;

  // Tes restart memakai dua instance berurutan atas file yang sama; drift
  // memperingatkan hal ini karena berpotensi race bila paralel. Di sini
  // sesisinya tertutup sebelum sesi berikutnya dibuka.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    repo = LicenseRepository(db);
    // Memicu beforeOpen agar seluruh tabel (termasuk license_states) dibuat.
    return db.customSelect('SELECT 1').get().then((_) {});
  });

  group('LicenseRepository - simpan & muat rekaman', () {
    test('getCurrent mengembalikan null saat belum pernah diaktivasi', () async {
      expect(await repo.getCurrent(), isNull);
    });

    test('aktivasi menyimpan semua kolom dengan nilai yang benar', () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final result = await repo.activate(token, now: _now);

      expect(result.saved, isTrue);
      expect(result.isValid, isTrue);

      final saved = await repo.getCurrent();
      expect(saved, isNotNull);
      expect(saved!.id, LicenseRepository.singleRowId);
      expect(saved.activationCode, token);
      expect(saved.activatedAt, _now);
      expect(saved.expiresAt, _now.add(LicenseEngine.validityDuration));
      // lastKnownTimestamp maju ke waktu acuan, bukan jam mundur.
      expect(saved.lastKnownTimestamp, _now);
      expect(saved.updatedAt, _now);
    });

    test('rekaman bertahan melewati siklus buka-tutup database (restart app/reboot)',
        () async {
      final dir = await Directory.systemTemp.createTemp('bndh_license_test');
      final file = File('${dir.path}${Platform.pathSeparator}license.db');
      addTearDown(() async {
        try {
          if (await file.exists()) await file.delete();
          if (await dir.exists()) await dir.delete();
        } on FileSystemException {
          // Windows kadang menahan handle sebentar setelah close; sisa berkas
          // di folder temp tidak memengaruhi hasil tes.
        }
      });

      // Sesi 1: aktivasi lalu tutup database (aplikasi dimatikan).
      final firstDb = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase(file)),
      );
      final firstRepo = LicenseRepository(firstDb);
      await firstDb.customSelect('SELECT 1').get();

      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final result = await firstRepo.activate(token, now: _now);
      expect(result.saved, isTrue);
      final persisted = result.state!;
      await firstDb.close();

      // Sesi 2: buka file yang sama persis (device reboot).
      final secondDb = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase(file)),
      );
      final secondRepo = LicenseRepository(secondDb);
      await secondDb.customSelect('SELECT 1').get();

      final reloaded = await secondRepo.getCurrent();
      expect(reloaded, isNotNull);
      expect(reloaded!.activationCode, persisted.activationCode);
      expect(reloaded.activatedAt, persisted.activatedAt);
      expect(reloaded.expiresAt, persisted.expiresAt);
      expect(reloaded.lastKnownTimestamp, persisted.lastKnownTimestamp);
      expect(reloaded, persisted);

      // Timestamp yang tersimpan tetap efektif di sesi baru: memundurkan jam
      // di bawahnya langsung terdeteksi.
      final rolledBack = reloaded.lastKnownTimestamp
          .subtract(const Duration(days: 30));
      final check = await secondRepo.check(now: rolledBack);
      expect(check.validation.clockRollbackDetected, isTrue);

      await secondDb.close();
    });

    test('token tidak sah tidak menimpa rekaman yang sudah ada', () async {
      final good = LicenseEngine.generate(issuedAt: _issuedAt);
      final activated = await repo.activate(good, now: _now);
      expect(activated.saved, isTrue);

      final forged = LicenseEngine.generate(
        issuedAt: _issuedAt,
        secret: 'kunci-palsu-yang-tidak-dipakai-aplikasi',
      );
      final rejected = await repo.activate(forged, now: _now);

      expect(rejected.saved, isFalse);
      expect(rejected.state, activated.state);

      final still = await repo.getCurrent();
      expect(still!.activationCode, good);
    });

    test('aktivasi baru menggantikan rekaman lama, tetap satu baris', () async {
      final oldToken = LicenseEngine.generate(issuedAt: _issuedAt);
      final newIssued = _issuedAt.add(const Duration(days: 10));
      final newToken = LicenseEngine.generate(issuedAt: newIssued);

      await repo.activate(oldToken, now: _now);
      final second = await repo.activate(newToken, now: _now);

      expect(second.saved, isTrue);
      final rows = await db.select(db.licenseStates).get();
      expect(rows, hasLength(1));
      expect(rows.first.activationCode, newToken);
      expect(
        rows.first.expiresAt.toUtc(),
        _now.add(LicenseEngine.validityDuration),
      );
    });

    test('clear menghapus rekaman lisensi', () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      await repo.clear();
      expect(await repo.getCurrent(), isNull);
    });

    test('watchCurrent memancarkan null lalu rekaman setelah aktivasi',
        () async {
      final emitted = <LicenseState?>[];
      final sub = repo.watchCurrent().listen(emitted.add);

      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.first, isNull);
      expect(emitted.last, isNotNull);
      expect(emitted.last!.activationCode, token);
      await sub.cancel();
    });
  });

  group('LicenseRepository - deteksi jam mundur (anti-rollback)', () {
    test('check memperbarui lastKnownTimestamp saat waktu berjalan normal',
        () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      final later = _now.add(const Duration(days: 2, hours: 5));
      final result = await repo.check(now: later);

      expect(result.isValid, isTrue);
      expect(result.state!.lastKnownTimestamp, later);
      expect(result.state!.updatedAt, later);
    });

    test('jam dimundurkan melewati toleransi terdeteksi sebagai rollback',
        () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      // Pemakaian normal memajukan timestamp tersimpan.
      final later = _now.add(const Duration(days: 3));
      await repo.check(now: later);

      // Jam sistem lalu disetel mundur 2 hari dari timestamp terakhir.
      final rolledBack = later.subtract(const Duration(days: 2));
      final result = await repo.check(now: rolledBack);

      expect(result.validation.clockRollbackDetected, isTrue);
      expect(result.validation.status, LicenseStatus.clockRollback);
      expect(result.validation.message, contains('dimundurkan'));
    });

    test('selisih kecil dalam toleransi tidak dianggap rollback', () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      final result = await repo.check(
        now: _now.subtract(const Duration(minutes: 5)),
      );

      expect(result.validation.clockRollbackDetected, isFalse);
      expect(result.validation.status, LicenseStatus.valid);
    });

    test('timestamp tersimpan tidak mundur saat rollback terdeteksi',
        () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      final later = _now.add(const Duration(days: 5));
      await repo.check(now: later);

      final rolledBack = later.subtract(const Duration(hours: 48));
      await repo.check(now: rolledBack);

      final saved = await repo.getCurrent();
      expect(saved!.lastKnownTimestamp, later);
    });

    test('jam mundur tidak memperpanjang masa aktif lisensi', () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      // lastKnownTimestamp bergerak maju sampai lewat masa berlaku.
      await repo.activate(token, now: _now);
      final realNow = _now.add(const Duration(days: 29));
      await repo.check(now: realNow);

      // Jam sistem lalu disetel mundur; waktu acuan tetap realNow sehingga
      // lisensi tetap kedaluwarsa.
      final rolledBack = realNow.subtract(const Duration(minutes: 5));
      final result = await repo.check(now: rolledBack);

      expect(result.validation.status, LicenseStatus.expired);
      expect(result.validation.effectiveNow, realNow);
    });

    test('check tanpa rekaman melapor belum diaktivasi', () async {
      final result = await repo.check(now: _now);

      expect(result.state, isNull);
      expect(result.isValid, isFalse);
      expect(result.validation.message, contains('belum diaktivasi'));
    });
  });

  group('LicenseRepository - integritas penyimpanan lintas sesi', () {
    test('rekaman yang disimpan database tetap lolos verifikasi saat dimuat ulang',
        () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      final reread = await repo.getCurrent();
      final revalidated = LicenseEngine.validate(
        token: reread!.activationCode,
        now: _now.add(const Duration(days: 1)),
        lastKnownTimestamp: reread.lastKnownTimestamp,
        activatedAt: reread.activatedAt,
      );

      expect(revalidated.status, LicenseStatus.valid);
      expect(revalidated.activatedAt, reread.activatedAt);
      expect(revalidated.expiresAt, reread.expiresAt);
    });

    test('kolom license_states ada di database hasil migrasi versi 3',
        () async {
      final columns = await db.customSelect(
        "PRAGMA table_info('license_states');",
      ).get();

      final names = columns.map((r) => r.read<String>('name')).toSet();
      expect(names, containsAll(<String>{
        'id',
        'activation_code',
        'activated_at',
        'expires_at',
        'last_known_timestamp',
        'updated_at',
      }));
    });
  });
}
