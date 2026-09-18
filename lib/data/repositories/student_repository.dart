import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class StudentRepository {
  final AppDatabase _db;
  const StudentRepository(this._db);

  Stream<List<Student>> watchStudents(String academicYearId) {
    return (_db.select(_db.students)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([(t) => OrderingTerm(expression: t.attendanceNumber, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<List<Student>> getStudents(String academicYearId) {
    return (_db.select(_db.students)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([(t) => OrderingTerm(expression: t.attendanceNumber, mode: OrderingMode.asc)]))
        .get();
  }

  Future<void> addStudent({
    required String academicYearId,
    required int attendanceNumber,
    required String name,
  }) async {
    const uuid = Uuid();
    await _db.into(_db.students).insert(
      StudentsCompanion.insert(
        id: uuid.v4(),
        academicYearId: academicYearId,
        attendanceNumber: attendanceNumber,
        name: name,
        status: const Value('active'),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<bool> isAttendanceNumberTaken({
    required String academicYearId,
    required int attendanceNumber,
  }) async {
    final match = await (_db.select(_db.students)
          ..where((t) =>
              t.academicYearId.equals(academicYearId) &
              t.attendanceNumber.equals(attendanceNumber)))
        .getSingleOrNull();
    return match != null;
  }

  Future<bool> isStudentNameTaken({
    required String academicYearId,
    required String name,
  }) async {
    final list = await getStudents(academicYearId);
    final normalized = name.trim().toLowerCase();
    return list.any((s) => s.name.trim().toLowerCase() == normalized);
  }

  Future<int> copyStudentsToAcademicYear({
    required String sourceAcademicYearId,
    required String targetAcademicYearId,
  }) async {
    final students = await getStudents(sourceAcademicYearId);
    const uuid = Uuid();
    var copiedCount = 0;
    for (final s in students) {
      if (s.status == 'active') {
        await _db.into(_db.students).insert(
          StudentsCompanion.insert(
            id: uuid.v4(),
            academicYearId: targetAcademicYearId,
            attendanceNumber: s.attendanceNumber,
            name: s.name,
            status: const Value('active'),
            createdAt: DateTime.now(),
          ),
        );
        copiedCount++;
      }
    }
    return copiedCount;
  }
}
