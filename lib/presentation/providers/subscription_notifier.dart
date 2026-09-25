import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/license/device_identity_service.dart';
import '../../core/license/license_engine.dart';
import '../../data/database/app_database.dart';
import 'app_providers.dart';

/// Status langganan aplikasi.
enum SubscriptionStatus {
  /// Aplikasi baru dipasang atau rekaman lisensi dihapus; belum ada aktivasi.
  unactivated,

  /// Token valid dan sisa waktu lebih dari 24 jam.
  active,

  /// Token valid tetapi sisa waktu <= 24 jam (pemicu banner perpanjangan).
  expiringSoon,

  /// Masa berlaku habis, token tidak sah, atau rollback jam terdeteksi.
  expired,
}

/// Snapshot status lisensi yang siap dipakai UI.
///
/// [remaining], [daysRemaining] dan [hoursRemaining] dihitung dari acuan waktu
/// yang sama ([checkedAt]) sehingga konsisten satu sama lain.
class SubscriptionInfo {
  final SubscriptionStatus status;

  /// Rekanan lisensi mentah dari database; null saat [SubscriptionStatus.unactivated].
  final LicenseState? state;

  final String message;

  /// Sisa waktu menuju kedaluwarsa. Negatif bila sudah lewat; null saat belum
  /// ada lisensi.
  final Duration? remaining;

  /// Sisa hari bulat ke bawah; null saat [remaining] null.
  final int? daysRemaining;

  /// Sisa jam pada hari parsial ([remaining] modulo 24 jam). Null saat
  /// [remaining] null. Bisa negatif pada lisensi yang sudah lewat beberapa
  /// jam (bagian jam dari sisa negatif).
  final int? hoursRemaining;

  final DateTime? expiresAt;

  /// Acuan waktu yang dipakai saat menghitung snapshot ini.
  final DateTime? checkedAt;

  final bool clockRollbackDetected;

  const SubscriptionInfo({
    required this.status,
    required this.message,
    this.state,
    this.remaining,
    this.daysRemaining,
    this.hoursRemaining,
    this.expiresAt,
    this.checkedAt,
    this.clockRollbackDetected = false,
  });

  /// Aktif termasuk yang segera kedaluwarsa; fitur inti tetap boleh dipakai.
  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.expiringSoon;

  bool get isFullyActive => status == SubscriptionStatus.active;
  bool get isExpiringSoon => status == SubscriptionStatus.expiringSoon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionInfo &&
          other.status == status &&
          other.message == message &&
          other.remaining == remaining &&
          other.expiresAt == expiresAt &&
          other.clockRollbackDetected == clockRollbackDetected;

  @override
  int get hashCode => Object.hash(
        status,
        message,
        remaining,
        expiresAt,
        clockRollbackDetected,
      );
}

/// Titik acuan waktu; disuntik lewat [subscriptionClockProvider] agar uji
/// dapat mengendalikan jam tanpa menyentuh variabel global.
typedef SubscriptionClock = DateTime Function();

DateTime _systemNow() => DateTime.now();

/// Jam acuan yang dipakai [SubscriptionNotifier]. Override di pengujian.
final subscriptionClockProvider = Provider<SubscriptionClock>((ref) {
  return _systemNow;
});

/// Murni: mengklasifikasikan hasil verifikasi menjadi [SubscriptionStatus].
///
/// Dipisah dari notifier supaya mudah diuji tanpa Riverpod sama sekali.
SubscriptionStatus classifySubscription(
  LicenseValidationResult validation, {
  required Duration expiringSoonWindow,
}) {
  if (validation.clockRollbackDetected ||
      validation.status == LicenseStatus.expired ||
      validation.status == LicenseStatus.badSignature ||
      validation.status == LicenseStatus.malformed) {
    return SubscriptionStatus.expired;
  }
  final remaining = validation.remaining;
  if (remaining == null) return SubscriptionStatus.expired;
  if (remaining <= expiringSoonWindow) return SubscriptionStatus.expiringSoon;
  return SubscriptionStatus.active;
}

/// Murni: membangun [SubscriptionInfo] dari satu rekaman lisensi.
SubscriptionInfo buildSubscriptionInfo({
  required DateTime now,
  LicenseState? state,
  required Duration expiringSoonWindow,
  String? deviceId,
}) {
  if (state == null) {
    return SubscriptionInfo(
      status: SubscriptionStatus.unactivated,
      message: 'Lisensi belum diaktivasi.',
      checkedAt: now,
    );
  }
  final validation = LicenseEngine.validate(
    token: state.activationCode,
    deviceId: deviceId ?? DeviceIdentityService.cachedDeviceId,
    now: now,
    lastKnownTimestamp: state.lastKnownTimestamp,
    activatedAt: state.activatedAt,
  );
  final remaining = validation.remaining;
  final negative = remaining != null && remaining.isNegative;
  final days = remaining == null
      ? null
      : negative ? -remaining.inDays : remaining.inDays;
  final hours = remaining == null
      ? null
      : remaining.inHours - (negative ? -days! : days!) * 24;
  return SubscriptionInfo(
    status: classifySubscription(
      validation,
      expiringSoonWindow: expiringSoonWindow,
    ),
    state: state,
    message: validation.message,
    remaining: remaining,
    daysRemaining: days,
    hoursRemaining: hours,
    expiresAt: validation.expiresAt,
    checkedAt: now,
    clockRollbackDetected: validation.clockRollbackDetected,
  );
}

/// State machine subscription reaktif.
///
/// Transisi terjadi otomatis saat rekaman lisensi berubah (aktivasi baru,
/// hapus, pembaruan anti-rollback), saat jam acuan berubah, atau saat
/// [refreshNow] dipanggil; sehingga UI bereaksi langsung terhadap
/// kedaluwarsa atau aktivasi.
class SubscriptionNotifier extends AsyncNotifier<SubscriptionInfo> {
  /// Batas "akan kedaluwarsa": 24 jam atau kurang tersisa.
  static const Duration expiringSoonWindow = Duration(hours: 24);

  StreamSubscription<LicenseState?>? _sub;
  Timer? _timer;

  @override
  Future<SubscriptionInfo> build() async {
    final clock = ref.watch(subscriptionClockProvider);
    final repo = ref.watch(licenseRepoProvider);

    // check() juga memajukan lastKnownTimestamp sehingga deteksi rollback
    // di langkah berikut akurat.
    final first = await repo.check(now: clock());
    final info = _infoFor(now: clock(), state: first.state);

    _sub?.cancel();
    _sub = repo.watchCurrent().listen((_) {
      if (!ref.mounted) return;
      Future.microtask(refreshNow);
    });
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
      _timer?.cancel();
      _timer = null;
    });

    _scheduleNextTransition(info, clock());
    return info;
  }

  SubscriptionInfo _infoFor({
    required DateTime now,
    LicenseState? state,
  }) {
    return buildSubscriptionInfo(
      now: now,
      state: state,
      expiringSoonWindow: expiringSoonWindow,
    );
  }

  /// Menjadwalkan evaluasi ulang tepat saat status berikutnya berubah:
  /// active -> expiringSoon (sisa 24 jam) atau expiringSoon -> expired.
  void _scheduleNextTransition(SubscriptionInfo info, DateTime now) {
    _timer?.cancel();
    _timer = null;
    final expiresAt = info.expiresAt;
    if (expiresAt == null) return;

    DateTime target;
    if (info.status == SubscriptionStatus.active) {
      target = expiresAt.subtract(expiringSoonWindow);
    } else if (info.status == SubscriptionStatus.expiringSoon) {
      target = expiresAt;
    } else {
      return;
    }

    final delay = target.difference(now);
    if (delay > Duration.zero) {
      _timer = Timer(delay, refreshNow);
    }
  }

  /// Membaca ulang status segera, mis. saat aplikasi resume dari background.
  Future<void> refreshNow() async {
    if (!ref.mounted) return;
    final clock = ref.read(subscriptionClockProvider);
    final repo = ref.read(licenseRepoProvider);
    final result = await repo.check(now: clock());
    if (!ref.mounted) return;
    final info = _infoFor(now: clock(), state: result.state);
    state = AsyncData(info);
    _scheduleNextTransition(info, clock());
  }
}

/// Provider reaktif untuk UI: watch [subscriptionNotifierProvider] lalu baca
/// [AsyncValue.value] untuk mendapat [SubscriptionInfo] terkini.
final subscriptionNotifierProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionInfo>(
        SubscriptionNotifier.new);