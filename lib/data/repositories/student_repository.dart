import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class StudentRepository {
  final AppDatabase _db;
  const StudentRepository(this._db);

  Stream<List<Student>> watchStudents(String academicYearId, {bool onlyActive = true}) {
    return (_db.select(_db.students)
          ..where((t) =>
              t.academicYearId.equals(academicYearId) &
              (onlyActive ? t.status.equals('active') : const Constant(true)))
          ..orderBy([(t) => OrderingTerm(expression: t.attendanceNumber, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<List<Student>> getStudents(String academicYearId, {bool onlyActive = true}) {
    return (_db.select(_db.students)
          ..where((t) =>
              t.academicYearId.equals(academicYearId) &
              (onlyActive ? t.status.equals('active') : const Constant(true)))
          ..orderBy([(t) => OrderingTerm(expression: t.attendanceNumber, mode: OrderingMode.asc)]))
        .get();
  }

  Future<void> addStudent({
    required String academicYearId,
    required int attendanceNumber,
    required String name,
  }) async {
    const uuid = Uuid();
    final studentId = uuid.v4();
    await _db.transaction(() async {
      await _db.into(_db.students).insert(
        StudentsCompanion.insert(
          id: studentId,
          academicYearId: academicYearId,
          attendanceNumber: attendanceNumber,
          name: name.trim(),
          status: const Value('active'),
          createdAt: DateTime.now(),
        ),
      );

      // Otomatis buat entri dues_payments awal untuk seluruh periode kas yang sudah ada di tahun ajaran ini
      final periods = await (_db.select(_db.duesPeriods)
            ..where((t) => t.academicYearId.equals(academicYearId)))
          .get();

      for (final p in periods) {
        await _db.into(_db.duesPayments).insert(
          DuesPaymentsCompanion.insert(
            id: uuid.v4(),
            duesPeriodId: p.id,
            studentId: studentId,
            amountPaid: const Value(0),
            isPaid: const Value(false),
            paidAt: const Value(null),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<void> updateStudent({
    required String studentId,
    required int attendanceNumber,
    required String name,
  }) async {
    await (_db.update(_db.students)..where((t) => t.id.equals(studentId))).write(
      StudentsCompanion(
        attendanceNumber: Value(attendanceNumber),
        name: Value(name.trim()),
      ),
    );
  }

  Future<int> getStudentPaidTotal(String studentId) async {
    final payments = await (_db.select(_db.duesPayments)
          ..where((t) => t.studentId.equals(studentId) & t.isPaid.equals(true)))
        .get();
    return payments.fold<int>(0, (sum, p) => sum + p.amountPaid);
  }

  /// Menghapus siswa dengan proteksi integritas kas:
  /// - Jika siswa sudah pernah membayar kas (> 0), status diubah jadi 'inactive' (soft delete)
  ///   agar riwayat kas dan rekonsiliasi saldo tetap valid, dan menghapus dues_payments yang belum lunas.
  /// - Jika siswa belum pernah bayar kas sama sekali, dilakukan hard delete bersih.
  /// Mengembalikan true jika hard delete, false jika soft delete (diarsipkan).
  Future<bool> deleteStudent({required String studentId}) async {
    return await _db.transaction(() async {
      final paidTotal = await getStudentPaidTotal(studentId);
      if (paidTotal > 0) {
        await (_db.update(_db.students)..where((t) => t.id.equals(studentId))).write(
          const StudentsCompanion(
            status: Value('inactive'),
          ),
        );
        // Hapus dues_payments yang belum bayar agar tidak menggantung di DB
        await (_db.delete(_db.duesPayments)
              ..where((t) => t.studentId.equals(studentId) & t.isPaid.equals(false)))
            .go();
        return false;
      } else {
        await (_db.delete(_db.duesPayments)..where((t) => t.studentId.equals(studentId))).go();
        await (_db.delete(_db.students)..where((t) => t.id.equals(studentId))).go();
        return true;
      }
    });
  }

  Future<bool> isAttendanceNumberTaken({
    required String academicYearId,
    required int attendanceNumber,
  }) async {
    final match = await (_db.select(_db.students)
          ..where((t) =>
              t.academicYearId.equals(academicYearId) &
              t.status.equals('active') &
              t.attendanceNumber.equals(attendanceNumber)))
        .getSingleOrNull();
    return match != null;
  }

  Future<bool> isAttendanceNumberTakenExcluding({
    required String academicYearId,
    required int attendanceNumber,
    required String excludeStudentId,
  }) async {
    final match = await (_db.select(_db.students)
          ..where((t) =>
              t.academicYearId.equals(academicYearId) &
              t.status.equals('active') &
              t.id.equals(excludeStudentId).not() &
              t.attendanceNumber.equals(attendanceNumber)))
        .getSingleOrNull();
    return match != null;
  }

  Future<bool> isStudentNameTaken({
    required String academicYearId,
    required String name,
  }) async {
    final normalized = name.trim().toLowerCase();
    final match = await (_db.select(_db.students)
          ..where((t) =>
              t.academicYearId.equals(academicYearId) &
              t.status.equals('active') &
              t.name.lower().equals(normalized))
          ..limit(1))
        .getSingleOrNull();
    return match != null;
  }

  Future<bool> isStudentNameTakenExcluding({
    required String academicYearId,
    required String name,
    required String excludeStudentId,
  }) async {
    final normalized = name.trim().toLowerCase();
    final match = await (_db.select(_db.students)
          ..where((t) =>
              t.academicYearId.equals(academicYearId) &
              t.status.equals('active') &
              t.id.equals(excludeStudentId).not() &
              t.name.lower().equals(normalized))
          ..limit(1))
        .getSingleOrNull();
    return match != null;
  }

  Future<int> copyStudentsToAcademicYear({
    required String sourceAcademicYearId,
    required String targetAcademicYearId,
  }) async {
    final students = await getStudents(sourceAcademicYearId);
    const uuid = Uuid();
    var copiedCount = 0;
    await _db.transaction(() async {
      final targetPeriods = await (_db.select(_db.duesPeriods)
            ..where((t) => t.academicYearId.equals(targetAcademicYearId)))
          .get();

      for (final s in students) {
        if (s.status == 'active') {
          final studentId = uuid.v4();
          await _db.into(_db.students).insert(
            StudentsCompanion.insert(
              id: studentId,
              academicYearId: targetAcademicYearId,
              attendanceNumber: s.attendanceNumber,
              name: s.name,
              status: const Value('active'),
              createdAt: DateTime.now(),
            ),
          );

          for (final p in targetPeriods) {
            await _db.into(_db.duesPayments).insert(
              DuesPaymentsCompanion.insert(
                id: uuid.v4(),
                duesPeriodId: p.id,
                studentId: studentId,
                amountPaid: const Value(0),
                isPaid: const Value(false),
                paidAt: const Value(null),
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
          copiedCount++;
        }
      }
    });
    return copiedCount;
  }
}
