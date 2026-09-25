import 'package:bendahara_app/core/license/license_engine.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/license_repository.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/providers/subscription_notifier.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Titik waktu tetap untuk seluruh pengujian transisi status.
final DateTime _now = DateTime.utc(2026, 9, 24, 10, 30);
final DateTime _issuedAt = DateTime.utc(2026, 9, 20);

/// Holder jam acuan yang bisa dimutasi oleh pengujian untuk mensimulasikan
/// perjalanan waktu tanpa menyentuh jam sistem.
class _Clock {
  DateTime now;
  _Clock(this.now);
  DateTime call() => now;
}

/// Buat container Riverpod dengan database dan jam yang dikontrol.
ProviderContainer _container({
  required AppDatabase db,
  required _Clock clock,
}) {
  return ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      subscriptionClockProvider.overrideWithValue(clock.call),
    ],
  );
}

/// Baca nilai dari [subscriptionNotifierProvider] dengan menunggu future build
/// selesai. Mempermudah assertion di pengujian.
Future<SubscriptionInfo> _read(ProviderContainer container) {
  return container.read(subscriptionNotifierProvider.future);
}

void main() {
  late AppDatabase db;
  late LicenseRepository repo;
  late _Clock clock;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    repo = LicenseRepository(db);
    await db.customSelect('SELECT 1').get();
    clock = _Clock(_now);
  });

  tearDown(() async {
    await db.close();
  });

  group('classifySubscription murni (tanpa Riverpod)', () {
    test('valid dengan sisa > 24 jam -> active', () {
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: _issuedAt.add(const Duration(days: 1)),
      );
      expect(result.status, LicenseStatus.valid);
      expect(
        classifySubscription(
          result,
          expiringSoonWindow: SubscriptionNotifier.expiringSoonWindow,
        ),
        SubscriptionStatus.active,
      );
    });

    test('valid dengan sisa <= 24 jam -> expiringSoon', () {
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: _issuedAt.add(const Duration(days: 27, hours: 23, minutes: 30)),
      );
      expect(result.status, LicenseStatus.valid);
      expect(
        classifySubscription(
          result,
          expiringSoonWindow: SubscriptionNotifier.expiringSoonWindow,
        ),
        SubscriptionStatus.expiringSoon,
      );
    });

    test('expired -> expired', () {
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: _issuedAt.add(const Duration(days: 30)),
      );
      expect(result.status, LicenseStatus.expired);
      expect(
        classifySubscription(
          result,
          expiringSoonWindow: SubscriptionNotifier.expiringSoonWindow,
        ),
        SubscriptionStatus.expired,
      );
    });

    test('clockRollback terdeteksi -> expired walau token valid', () {
      final result = LicenseEngine.validate(
        token: LicenseEngine.generate(issuedAt: _issuedAt),
        now: _now.subtract(const Duration(days: 1)),
        lastKnownTimestamp: _now,
      );
      expect(result.clockRollbackDetected, isTrue);
      expect(
        classifySubscription(
          result,
          expiringSoonWindow: SubscriptionNotifier.expiringSoonWindow,
        ),
        SubscriptionStatus.expired,
      );
    });

    test('badSignature -> expired', () {
      final forged = LicenseEngine.generate(
        issuedAt: _issuedAt,
        secret: 'kunci-palsu-yang-tidak-dipakai-aplikasi',
      );
      final result = LicenseEngine.validate(token: forged, now: _now);
      expect(result.status, LicenseStatus.badSignature);
      expect(
        classifySubscription(
          result,
          expiringSoonWindow: SubscriptionNotifier.expiringSoonWindow,
        ),
        SubscriptionStatus.expired,
      );
    });
  });

  group('buildSubscriptionInfo murni', () {
    test('state null -> unactivated', () {
      final info = buildSubscriptionInfo(
        now: _now,
        state: null,
        expiringSoonWindow: SubscriptionNotifier.expiringSoonWindow,
      );
      expect(info.status, SubscriptionStatus.unactivated);
      expect(info.remaining, isNull);
      expect(info.daysRemaining, isNull);
      expect(info.hoursRemaining, isNull);
      expect(info.message, contains('belum diaktivasi'));
    });

    test('token valid 23 hari 13 jam -> remaining, days, hours konsisten', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final state = LicenseState(
        id: 'license',
        activationCode: token,
        activatedAt: _issuedAt,
        expiresAt: _issuedAt.add(LicenseEngine.validityDuration),
        lastKnownTimestamp: _now,
        updatedAt: _now,
      );
      final info = buildSubscriptionInfo(
        now: _now,
        state: state,
        expiringSoonWindow: SubscriptionNotifier.expiringSoonWindow,
      );
      expect(info.status, SubscriptionStatus.active);
      expect(info.remaining, const Duration(days: 23, hours: 13, minutes: 30));
      expect(info.daysRemaining, 23);
      expect(info.hoursRemaining, 13);
      expect(info.expiresAt, _issuedAt.add(LicenseEngine.validityDuration));
    });

    test('sisa 30 hari penuh -> days=28, hours=0', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final state = LicenseState(
        id: 'license',
        activationCode: token,
        activatedAt: _issuedAt,
        expiresAt: _issuedAt.add(LicenseEngine.validityDuration),
        lastKnownTimestamp: _issuedAt,
        updatedAt: _issuedAt,
      );
      final info = buildSubscriptionInfo(
        now: _issuedAt,
        state: state,
        expiringSoonWindow: SubscriptionNotifier.expiringSoonWindow,
      );
      expect(info.remaining, const Duration(days: 28));
      expect(info.daysRemaining, 28);
      expect(info.hoursRemaining, 0);
    });

    test('sisa 23 jam -> expiringSoon dengan days=0 hours=23', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final state = LicenseState(
        id: 'license',
        activationCode: token,
        activatedAt: _issuedAt,
        expiresAt: _issuedAt.add(LicenseEngine.validityDuration),
        lastKnownTimestamp: _now,
        updatedAt: _now,
      );
      final info = buildSubscriptionInfo(
        now: _issuedAt.add(const Duration(days: 27, hours: 1)),
        state: state,
        expiringSoonWindow: SubscriptionNotifier.expiringSoonWindow,
      );
      expect(info.status, SubscriptionStatus.expiringSoon);
      expect(info.remaining, const Duration(hours: 23));
      expect(info.daysRemaining, 0);
      expect(info.hoursRemaining, 23);
    });

    test('sisa negatif -> daysRemaining mengambil nilai absolut', () {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      final state = LicenseState(
        id: 'license',
        activationCode: token,
        activatedAt: _issuedAt,
        expiresAt: _issuedAt.add(LicenseEngine.validityDuration),
        lastKnownTimestamp: _now,
        updatedAt: _now,
      );
      final info = buildSubscriptionInfo(
        now: _issuedAt.add(const Duration(days: 30, hours: 5)),
        state: state,
        expiringSoonWindow: SubscriptionNotifier.expiringSoonWindow,
      );
      expect(info.status, SubscriptionStatus.expired);
      expect(info.remaining!.isNegative, isTrue);
      expect(info.daysRemaining, greaterThan(0));
      // Sisa -2 hari -5 jam -> daysRemaining=2, hoursRemaining=-5.
      expect(info.daysRemaining, 2);
      expect(info.hoursRemaining, -5);
    });
  });

  group('subscriptionNotifierProvider - lifecycle', () {
    test('tanpa rekaman -> unactivated', () async {
      final container = _container(db: db, clock: clock);
      addTearDown(container.dispose);

      final info = await _read(container);
      expect(info.status, SubscriptionStatus.unactivated);
      expect(info.state, isNull);
      expect(info.remaining, isNull);
      expect(info.isActive, isFalse);
      expect(info.isFullyActive, isFalse);
      expect(info.isExpiringSoon, isFalse);
    });

    test('aktivasi baru -> active dengan sisa hari', () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      final container = _container(db: db, clock: clock);
      addTearDown(container.dispose);

      final info = await _read(container);
      expect(info.status, SubscriptionStatus.active);
      expect(info.state, isNotNull);
      expect(info.remaining, const Duration(days: 28));
      expect(info.daysRemaining, 28);
      expect(info.hoursRemaining, 0);
      expect(info.expiresAt, _now.add(LicenseEngine.validityDuration));
      expect(info.checkedAt, _now);
      expect(info.clockRollbackDetected, isFalse);
    });

    test('jam bergerak melewati 24 jam -> transisi ke expiringSoon',
        () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      final container = _container(db: db, clock: clock);
      addTearDown(container.dispose);

      expect((await _read(container)).status, SubscriptionStatus.active);

      // Maju ke tepat 24 jam tersisa.
      clock.now = _now.add(LicenseEngine.validityDuration -
          const Duration(hours: 24));
      await container.read(subscriptionNotifierProvider.notifier).refreshNow();
      final info = await _read(container);
      expect(info.status, SubscriptionStatus.expiringSoon);
      expect(info.remaining, const Duration(hours: 24));
      expect(info.isExpiringSoon, isTrue);
      expect(info.isFullyActive, isFalse);
      expect(info.isActive, isTrue);
    });

    test('jam melewati masa berlaku -> transisi ke expired', () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      final container = _container(db: db, clock: clock);
      addTearDown(container.dispose);

      clock.now = _now.add(LicenseEngine.validityDuration);
      await container.read(subscriptionNotifierProvider.notifier).refreshNow();
      final info = await _read(container);
      expect(info.status, SubscriptionStatus.expired);
      expect(info.remaining, Duration.zero);
    });

    test('rollback jam terdeteksi -> expired walau struktur token valid',
        () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);
      // Majukan timestamp tersimpan lewat check normal.
      await repo.check(now: _now.add(const Duration(days: 1)));

      final container = _container(db: db, clock: clock);
      addTearDown(container.dispose);

      // Mundur 2 jam dari timestamp terakhir -> terdeteksi sebagai rollback.
      clock.now =
          _now.add(const Duration(days: 1)).subtract(const Duration(hours: 2));
      await container.read(subscriptionNotifierProvider.notifier).refreshNow();
      final info = await _read(container);
      expect(info.clockRollbackDetected, isTrue);
      expect(info.status, SubscriptionStatus.expired);
    });

    test('aktivasi ulang mereplace expired dengan active', () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      final container = _container(db: db, clock: clock);
      addTearDown(container.dispose);

      // Paksa expired.
      clock.now = _now.add(const Duration(days: 30));
      await container.read(subscriptionNotifierProvider.notifier).refreshNow();
      expect((await _read(container)).status, SubscriptionStatus.expired);

      // Aktivasi baru dengan tanggal terbit terkini. issuedAt masa depan
      // jauh agar sisa waktu jelas > 24 jam walaupun jam acuan belum maju
      // dari lastKnownTimestamp yang tersimpan.
      final newIssued = _now.add(const Duration(days: 5));
      final newToken = LicenseEngine.generate(issuedAt: newIssued);
      // Pakai jam yang lebih besar dari lastKnownTimestamp yang tersimpan
      // (yaitu _now + 30 hari) agar validate tidak membatasi effectiveNow.
      final newActivationNow = _now.add(const Duration(days: 31));
      await repo.activate(newToken, now: newActivationNow);

      clock.now = newActivationNow.add(const Duration(hours: 1));
      await container.read(subscriptionNotifierProvider.notifier).refreshNow();
      final info = await _read(container);
      expect(info.status, SubscriptionStatus.active);
      expect(info.daysRemaining, greaterThan(0));
    });

    test('clear() melalui stream memicu transisi kembali ke unactivated',
        () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      final container = _container(db: db, clock: clock);
      addTearDown(container.dispose);

      expect((await _read(container)).status, SubscriptionStatus.active);

      await repo.clear();
      // Listener stream menjadwalkan refreshNow lewat microtask.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final info = await _read(container);
      expect(info.status, SubscriptionStatus.unactivated);
      expect(info.state, isNull);
    });

    test('refreshNow re-schedule timer untuk transisi berikutnya', () async {
      final token = LicenseEngine.generate(issuedAt: _issuedAt);
      await repo.activate(token, now: _now);

      final container = _container(db: db, clock: clock);
      addTearDown(container.dispose);

      // Set jam mendekati 24 jam tersisa dan refresh; status -> expiringSoon.
      clock.now = _now.add(LicenseEngine.validityDuration -
          const Duration(hours: 25));
      await container.read(subscriptionNotifierProvider.notifier).refreshNow();
      expect((await _read(container)).status, SubscriptionStatus.active);

      // Lanjutkan ke 23 jam tersisa -> expiringSoon, jadwal berikutnya = expiresAt.
      clock.now = _now.add(LicenseEngine.validityDuration -
          const Duration(hours: 23));
      await container.read(subscriptionNotifierProvider.notifier).refreshNow();
      expect((await _read(container)).status, SubscriptionStatus.expiringSoon);

      // Lanjutkan tepat ke expiresAt -> expired.
      clock.now = _now.add(LicenseEngine.validityDuration);
      await container.read(subscriptionNotifierProvider.notifier).refreshNow();
      final info = await _read(container);
      expect(info.status, SubscriptionStatus.expired);
    });
  });
}