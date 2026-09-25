import 'package:drift/drift.dart';

/// Lisensi aktif terakhir. Hanya boleh berisi satu baris (id tetap 'license'),
/// karena aplikasi kecil ini hanya punya satu slot aktivasi.
class LicenseStates extends Table {
  TextColumn get id => text()(); // selalu 'license'
  TextColumn get activationCode => text()();
  DateTimeColumn get activatedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();

  /// Timestamp monotonik terakhir yang pernah dilihat aplikasi. Dipakai
  /// untuk mendeteksi rollback jam sistem.
  DateTimeColumn get lastKnownTimestamp => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
