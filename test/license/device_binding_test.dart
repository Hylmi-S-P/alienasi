import 'package:bendahara_app/core/license/device_identity_service.dart';
import 'package:bendahara_app/core/license/license_engine.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/license_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 9, 25, 10, 0, 0);

  group('DeviceIdentityService & Normalization', () {
    tearDown(() {
      DeviceIdentityService.resetForTesting();
    });

    test('generateRandomDeviceId menghasilkan format DEV-XXXX-XXXX yang valid', () {
      final id = DeviceIdentityService.generateRandomDeviceId();
      expect(id, matches(r'^DEV-[0-9A-Z]{4}-[0-9A-Z]{4}$'));
    });

    test('normalizeDeviceId menangani huruf kecil, spasi, dan alias I/L/O', () {
      expect(
        LicenseEngine.normalizeDeviceId('dev-8k2m-9q4x'),
        'DEV-8K2M-9Q4X',
      );
      expect(
        LicenseEngine.normalizeDeviceId('8k2m9q4x'),
        'DEV-8K2M-9Q4X',
      );
      // Karakter I/L -> 1, O -> 0
      expect(
        LicenseEngine.normalizeDeviceId('DEV-IL12-O987'),
        'DEV-1112-0987',
      );
    });

    test('setOverrideForTesting dan cachedDeviceId bekerja konsisten', () async {
      DeviceIdentityService.setOverrideForTesting('DEV-TEST-1234');
      expect(DeviceIdentityService.cachedDeviceId, 'DEV-TEST-1234');
      expect(await DeviceIdentityService.getDeviceId(), 'DEV-TEST-1234');
    });
  });

  group('LicenseEngine - 1-Device Offline Binding', () {
    const deviceA = 'DEV-AAAA-1111';
    const deviceB = 'DEV-BBBB-2222';

    test('Token yang dikunci ke Device A valid saat diperiksa di Device A', () {
      final token = LicenseEngine.generate(deviceId: deviceA, issuedAt: now);
      final result = LicenseEngine.validate(
        token: token,
        deviceId: deviceA,
        now: now,
      );

      expect(result.isValid, isTrue);
      expect(result.status, LicenseStatus.valid);
    });

    test('Token yang dikunci ke Device A ditolak di Device B (tidak dapat dibagikan)', () {
      final token = LicenseEngine.generate(deviceId: deviceA, issuedAt: now);

      // Verifikasi di Device B tanpa target explicit -> badSignature (ditolak)
      final resultOnDeviceB = LicenseEngine.validate(
        token: token,
        deviceId: deviceB,
        now: now,
      );
      expect(resultOnDeviceB.isValid, isFalse);

      // Verifikasi dengan expectedDeviceId = deviceA -> status deviceMismatch
      final resultMismatch = LicenseEngine.validate(
        token: token,
        deviceId: deviceB,
        expectedDeviceId: deviceA,
        now: now,
      );
      expect(resultMismatch.isValid, isFalse);
      expect(resultMismatch.status, LicenseStatus.deviceMismatch);
      expect(resultMismatch.message, contains('tidak cocok dengan ID Perangkat Anda'));
    });

    test('Token universal tanpa deviceId valid di semua perangkat', () {
      final universalToken = LicenseEngine.generate(deviceId: null, issuedAt: now);

      final resultA = LicenseEngine.validate(
        token: universalToken,
        deviceId: deviceA,
        now: now,
      );
      final resultB = LicenseEngine.validate(
        token: universalToken,
        deviceId: deviceB,
        now: now,
      );

      expect(resultA.isValid, isTrue);
      expect(resultB.isValid, isTrue);
    });

    test('Masa berlaku dihitung 28 hari sejak aktivasi pertama (activatedAt)', () {
      final issuedOld = now.subtract(const Duration(days: 10));
      final token = LicenseEngine.generate(deviceId: deviceA, issuedAt: issuedOld);

      // Diaktivasi pada waktu "now"
      final validation = LicenseEngine.validate(
        token: token,
        deviceId: deviceA,
        now: now,
        activatedAt: now,
      );

      expect(validation.isValid, isTrue);
      expect(validation.activatedAt, now);
      expect(validation.expiresAt, now.add(LicenseEngine.validityDuration));
      expect(validation.remaining, LicenseEngine.validityDuration);
    });
  });

  group('LicenseRepository - End-to-End Device Locking', () {
    late AppDatabase db;
    late LicenseRepository repo;
    const testDevice = 'DEV-H7K2-9M4P';
    const otherDevice = 'DEV-X1Y2-Z3W4';

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      repo = LicenseRepository(db);
      await db.customSelect('SELECT 1').get();
      DeviceIdentityService.setOverrideForTesting(testDevice);
    });

    tearDown(() async {
      DeviceIdentityService.resetForTesting();
      await db.close();
    });

    test('Aktivasi otomatis mengunci ke device ID aktif dan valid selama 28 hari', () async {
      final token = LicenseEngine.generate(deviceId: testDevice, issuedAt: now);
      final saveResult = await repo.activate(token, now: now);

      expect(saveResult.saved, isTrue);
      expect(saveResult.isValid, isTrue);

      final state = await repo.getCurrent();
      expect(state, isNotNull);
      expect(state!.activatedAt, now);
      expect(state.expiresAt, now.add(const Duration(days: 28)));

      // Check berkala di perangkat ini tetap valid
      final checkResult = await repo.check(now: now.add(const Duration(days: 1)));
      expect(checkResult.isValid, isTrue);
    });

    test('Kode dari perangkat lain ditolak saat dicoba aktivasi', () async {
      final foreignToken = LicenseEngine.generate(deviceId: otherDevice, issuedAt: now);

      final saveResult = await repo.activate(foreignToken, now: now);
      expect(saveResult.saved, isFalse);
      expect(saveResult.isValid, isFalse);
      expect(await repo.getCurrent(), isNull);
    });
  });
}
