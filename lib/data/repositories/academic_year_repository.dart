import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class AcademicYearRepository {
  final AppDatabase _db;
  const AcademicYearRepository(this._db);

  Stream<AcademicYear?> watchActiveYear() {
    return (_db.select(_db.academicYears)..where((t) => t.isActive.equals(true)))
        .watchSingleOrNull();
  }

  Future<AcademicYear?> getActiveYear() {
    return (_db.select(_db.academicYears)..where((t) => t.isActive.equals(true)))
        .getSingleOrNull();
  }

  Future<List<AcademicYear>> getAllYears() {
    return (_db.select(_db.academicYears)
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .get();
  }

  Stream<List<AcademicYear>> watchAllYears() {
    return (_db.select(_db.academicYears)
          ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<AcademicYear> createAcademicYear({
    required String name,
    required int grade,
    required String treasurerName,
    required String supervisorName,
    required int defaultDuesAmount,
    String duesPeriodType = 'weekly',
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    const uuid = Uuid();
    final now = DateTime.now();

    final newYear = AcademicYearsCompanion.insert(
      id: uuid.v4(),
      name: name,
      grade: grade,
      treasurerName: Value(treasurerName),
      supervisorName: Value(supervisorName),
      defaultDuesAmount: Value(defaultDuesAmount),
      duesPeriodType: Value(duesPeriodType),
      startDate: startDate,
      endDate: endDate,
      isActive: const Value(true),
      createdAt: now,
    );

    // Seluruh operasi harus atomik: jika insert gagal (disk penuh, dsb.),
    // tahun ajaran sebelumnya TIDAK boleh ikut non-aktif — jika tidak,
    // aplikasi akan terjebak tanpa tahun ajaran aktif sama sekali.
    final created = await _db.transaction(() async {
      await (_db.update(_db.academicYears)..where((t) => t.isActive.equals(true)))
          .write(const AcademicYearsCompanion(isActive: Value(false)));

      await _db.into(_db.academicYears).insert(newYear);

      return await (_db.select(_db.academicYears)..where((t) => t.id.equals(newYear.id.value)))
          .getSingle();
    });

    return created;
  }

  Future<AcademicYear> advanceToNewGrade({
    required String newClassName,
    required int newGrade,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final currentActive = await getActiveYear();
    final treasurerName = currentActive?.treasurerName ?? 'Bendahara';
    final supervisorName = currentActive?.supervisorName ?? 'Ibu Pengawas';
    final defaultDues = currentActive?.defaultDuesAmount ?? 5000;
    final duesPeriodType = currentActive?.duesPeriodType ?? 'weekly';

    return await createAcademicYear(
      name: newClassName,
      grade: newGrade,
      treasurerName: treasurerName,
      supervisorName: supervisorName,
      defaultDuesAmount: defaultDues,
      duesPeriodType: duesPeriodType,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> updateAcademicYear({
    required String id,
    required String name,
    required int grade,
    required String treasurerName,
    required String supervisorName,
    required int defaultDuesAmount,
    String? duesPeriodType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await (_db.update(_db.academicYears)..where((t) => t.id.equals(id))).write(
      AcademicYearsCompanion(
        name: Value(name),
        grade: Value(grade),
        treasurerName: Value(treasurerName),
        supervisorName: Value(supervisorName),
        defaultDuesAmount: Value(defaultDuesAmount),
        duesPeriodType: duesPeriodType != null ? Value(duesPeriodType) : const Value.absent(),
        startDate: startDate != null ? Value(startDate) : const Value.absent(),
        endDate: endDate != null ? Value(endDate) : const Value.absent(),
      ),
    );
  }
}
