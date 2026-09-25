import 'package:drift/drift.dart';

import '../../core/license/device_identity_service.dart';
import '../../core/license/license_engine.dart';
import '../database/app_database.dart';

/// Rekam aktivasi lisensi saat ini, lengkap dengan timestamp anti-rollback.
///
/// Hanya satu lisensi aktif dalam satu instalasi, jadi tabel menyimpan
/// satu baris dengan id tetap [singleRowId].
class LicenseRepository {
  static const String singleRowId = 'license';

  final AppDatabase _db;
  LicenseRepository(this._db);

  /// Menormalkan DateTime dari drift (yang muncul sebagai waktu lokal karena
  /// penyimpanan epoch integer) menjadi UTC agar konsisten dengan engine.
  static LicenseState? _toUtc(LicenseState? s) {
    if (s == null) return null;
    return s.copyWith(
      activatedAt: s.activatedAt.toUtc(),
      expiresAt: s.expiresAt.toUtc(),
      lastKnownTimestamp: s.lastKnownTimestamp.toUtc(),
      updatedAt: s.updatedAt.toUtc(),
    );
  }

  /// Mengambil rekaman lisensi; null bila aplikasi belum pernah diaktivasi.
  Future<LicenseState?> getCurrent() {
    return (_db.select(_db.licenseStates)
          ..where((t) => t.id.equals(singleRowId)))
        .getSingleOrNull()
        .then(_toUtc);
  }

  /// Stream rekaman lisensi, null bila belum ada.
  Stream<LicenseState?> watchCurrent() {
    return (_db.select(_db.licenseStates)
          ..where((t) => t.id.equals(singleRowId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _toUtc(row));
  }

  /// Menghapus rekaman lisensi. Dipakai saat aktivasi baru menggantikan
  /// yang lama atau saat pengujian.
  Future<void> clear() async {
    await (_db.delete(_db.licenseStates)
          ..where((t) => t.id.equals(singleRowId)))
        .go();
  }

  /// Memvalidasi token dan menyimpan rekamannya bila lulus.
  ///
  /// [now] digunakan sebagai acuan waktu validasi (default: sistem). [clock]
  /// dipakai untuk menentukan timestamp tersimpan berikutnya: nilainya
  /// dimajukan ke posisi terbesar antara [now] dan
  /// [LicenseState.lastKnownTimestamp] agar mundur tidak pernah memberi
  /// masa aktif lebih panjang.
  Future<LicenseSaveResult> activate(
    String token, {
    String? deviceId,
    DateTime? now,
    DateTime? activatedAt,
    String? secret,
    DateTime Function()? clock,
  }) async {
    final currentNow = (now ?? clock?.call() ?? DateTime.now()).toUtc();
    final previous = await getCurrent();
    final lastKnown = previous?.lastKnownTimestamp;

    final resolvedDeviceId =
        deviceId ?? await DeviceIdentityService.getDeviceId();

    final effectiveNow = LicenseEngine.nextMonotonicTimestamp(
      now: currentNow,
      lastKnownTimestamp: lastKnown,
    );

    final validation = LicenseEngine.validate(
      token: token,
      deviceId: resolvedDeviceId,
      now: effectiveNow,
      lastKnownTimestamp: lastKnown,
      secret: secret,
    );

    if (!validation.isValid) {
      return LicenseSaveResult._(
        validation: validation,
        state: previous,
        saved: false,
      );
    }

    // Waktu aktivasi pertama kali di perangkat ini
    final effectiveActivatedAt = activatedAt ?? effectiveNow;
    final expiresAt = effectiveActivatedAt.add(LicenseEngine.validityDuration);

    final state = LicenseState(
      id: singleRowId,
      activationCode: token,
      activatedAt: effectiveActivatedAt,
      expiresAt: expiresAt,
      lastKnownTimestamp: effectiveNow,
      updatedAt: effectiveNow,
    );

    await _db.transaction(() async {
      await (_db.delete(_db.licenseStates)
            ..where((t) => t.id.equals(singleRowId)))
          .go();
      await _db.into(_db.licenseStates).insert(state);
    });

    return LicenseSaveResult._(
      validation: LicenseValidationResult(
        status: LicenseStatus.valid,
        message: 'Lisensi aktif.',
        issuedAt: validation.issuedAt,
        activatedAt: effectiveActivatedAt,
        expiresAt: expiresAt,
        remaining: expiresAt.difference(effectiveNow),
        effectiveNow: effectiveNow,
      ),
      state: state,
      saved: true,
    );
  }

  /// Mengecek rekaman lisensi terhadap jam sistem saat ini.
  ///
  /// Mengembalikan hasil [LicenseEngine.validate] dengan
  /// [LicenseValidationResult.effectiveNow] yang telah dimajukan ke nilai
  /// terbesar antara jam sistem dan timestamp tersimpan. Memperbarui
  /// `last_known_timestamp` bila tidak ada rollback yang terdeteksi, agar
  /// pertahanan monotonik tetap mengikuti waktu riil.
  Future<LicenseCheckResult> check({
    String? deviceId,
    DateTime? now,
    String? secret,
    DateTime Function()? clock,
  }) async {
    final currentNow = (now ?? clock?.call() ?? DateTime.now()).toUtc();
    final previous = await getCurrent();

    if (previous == null) {
      return LicenseCheckResult._(
        state: null,
        validation: LicenseValidationResult(
          status: LicenseStatus.malformed,
          message: 'Lisensi belum diaktivasi.',
          effectiveNow: currentNow,
        ),
      );
    }

    final resolvedDeviceId =
        deviceId ?? await DeviceIdentityService.getDeviceId();

    final validation = LicenseEngine.validate(
      token: previous.activationCode,
      deviceId: resolvedDeviceId,
      now: currentNow,
      lastKnownTimestamp: previous.lastKnownTimestamp,
      activatedAt: previous.activatedAt,
      secret: secret,
    );

    final effectiveNow = validation.effectiveNow ?? currentNow;
    final advanced = effectiveNow.isAfter(previous.lastKnownTimestamp);

    LicenseState updated = previous;
    if (!validation.clockRollbackDetected && advanced) {
      updated = previous.copyWith(
        lastKnownTimestamp: effectiveNow,
        updatedAt: effectiveNow,
      );
      await (_db.update(_db.licenseStates)
            ..where((t) => t.id.equals(singleRowId)))
          .write(LicenseStatesCompanion(
        lastKnownTimestamp: Value(effectiveNow),
        updatedAt: Value(effectiveNow),
      ));
    }

    return LicenseCheckResult._(
      state: updated,
      validation: validation,
    );
  }
}

/// Hasil [LicenseRepository.activate] setelah mencoba menyimpan token.
class LicenseSaveResult {
  final LicenseValidationResult validation;

  /// Rekanan lisensi tersimpan: nilai baru bila berhasil, nilai lama bila
  /// token ditolak.
  final LicenseState? state;
  final bool saved;

  const LicenseSaveResult._({
    required this.validation,
    required this.state,
    required this.saved,
  });

  bool get isValid => validation.isValid;
}

/// Hasil [LicenseRepository.check] saat memverifikasi lisensi tersimpan.
class LicenseCheckResult {
  final LicenseState? state;
  final LicenseValidationResult validation;

  const LicenseCheckResult._({
    required this.state,
    required this.validation,
  });

  bool get isValid => validation.isValid;
}