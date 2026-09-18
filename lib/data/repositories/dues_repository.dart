import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class StudentDuesItem {
  final Student student;
  final DuesPayment? payment;

  bool get isPaid => payment?.isPaid ?? false;
  int get amountPaid => payment?.amountPaid ?? 0;

  StudentDuesItem({
    required this.student,
    this.payment,
  });
}

class DuesPeriodSummary {
  final DuesPeriod period;
  final int totalTarget;
  final int totalCollected;
  final int paidCount;
  final int totalStudents;

  double get percentage => totalTarget > 0 ? (totalCollected / totalTarget) : 0.0;

  const DuesPeriodSummary({
    required this.period,
    required this.totalTarget,
    required this.totalCollected,
    required this.paidCount,
    required this.totalStudents,
  });
}

class DuesRepository {
  final AppDatabase _db;
  const DuesRepository(this._db);

  Future<DuesPeriod> getOrCreateActivePeriod({
    required String academicYearId,
    required String periodLabel,
    required int targetAmount,
  }) async {
    final existing = await (_db.select(_db.duesPeriods)
          ..where((t) => t.academicYearId.equals(academicYearId) & t.periodLabel.equals(periodLabel)))
        .getSingleOrNull();

    if (existing != null) {
      return existing;
    }

    const uuid = Uuid();
    final newPeriod = DuesPeriodsCompanion.insert(
      id: uuid.v4(),
      academicYearId: academicYearId,
      periodLabel: periodLabel,
      dueDate: DateTime.now(),
      targetAmount: targetAmount,
      isReconciled: const Value(false),
      createdAt: DateTime.now(),
    );

    await _db.into(_db.duesPeriods).insert(newPeriod);
    return (_db.select(_db.duesPeriods)..where((t) => t.id.equals(newPeriod.id.value))).getSingle();
  }

  Stream<DuesPeriod?> watchActivePeriod({
    required String academicYearId,
    required String periodLabel,
    required int targetAmount,
  }) async* {
    final period = await getOrCreateActivePeriod(
      academicYearId: academicYearId,
      periodLabel: periodLabel,
      targetAmount: targetAmount,
    );
    yield* (_db.select(_db.duesPeriods)..where((t) => t.id.equals(period.id))).watchSingleOrNull();
  }

  Stream<List<DuesPeriod>> watchPeriods(String academicYearId) {
    return (_db.select(_db.duesPeriods)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<StudentDuesItem>> watchStudentDuesList({
    required String academicYearId,
    required String duesPeriodId,
  }) {
    final studentsQuery = (_db.select(_db.students)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([(t) => OrderingTerm(expression: t.attendanceNumber, mode: OrderingMode.asc)]))
        .join([
      leftOuterJoin(
        _db.duesPayments,
        _db.duesPayments.studentId.equalsExp(_db.students.id) &
            _db.duesPayments.duesPeriodId.equals(duesPeriodId),
      ),
    ]);

    return studentsQuery.watch().map((rows) {
      return rows.map((row) {
        return StudentDuesItem(
          student: row.readTable(_db.students),
          payment: row.readTableOrNull(_db.duesPayments),
        );
      }).toList();
    });
  }

  Stream<DuesPeriodSummary> watchPeriodSummary({
    required DuesPeriod period,
    required String academicYearId,
  }) {
    return watchStudentDuesList(academicYearId: academicYearId, duesPeriodId: period.id).map((items) {
      final totalStudents = items.length;
      final totalTarget = totalStudents * period.targetAmount;
      var totalCollected = 0;
      var paidCount = 0;

      for (final item in items) {
        if (item.isPaid) {
          paidCount++;
          totalCollected += item.amountPaid;
        }
      }

      return DuesPeriodSummary(
        period: period,
        totalTarget: totalTarget,
        totalCollected: totalCollected,
        paidCount: paidCount,
        totalStudents: totalStudents,
      );
    });
  }

  Future<void> togglePaymentStatus({
    required String duesPeriodId,
    required String studentId,
    required int targetAmount,
    required bool currentStatus,
  }) async {
    const uuid = Uuid();
    final newStatus = !currentStatus;
    final now = DateTime.now();

    final existingPayment = await (_db.select(_db.duesPayments)
          ..where((t) => t.duesPeriodId.equals(duesPeriodId) & t.studentId.equals(studentId)))
        .getSingleOrNull();

    if (existingPayment == null) {
      await _db.into(_db.duesPayments).insert(
        DuesPaymentsCompanion.insert(
          id: uuid.v4(),
          duesPeriodId: duesPeriodId,
          studentId: studentId,
          amountPaid: Value(newStatus ? targetAmount : 0),
          isPaid: Value(newStatus),
          paidAt: Value(newStatus ? now : null),
        ),
      );
    } else {
      await (_db.update(_db.duesPayments)
            ..where((t) => t.id.equals(existingPayment.id)))
          .write(
        DuesPaymentsCompanion(
          amountPaid: Value(newStatus ? targetAmount : 0),
          isPaid: Value(newStatus),
          paidAt: Value(newStatus ? now : null),
        ),
      );
    }
  }

  Future<int> reconcileIntoGeneralCash({
    required DuesPeriod period,
    required String academicYearId,
  }) async {
    // 1. Ambil data periode terkini dari database
    final currentPeriod = await (_db.select(_db.duesPeriods)
          ..where((t) => t.id.equals(period.id)))
        .getSingle();

    // 2. Hitung total kas yang sudah terkumpul dari siswa yang ditandai lunas
    final payments = await (_db.select(_db.duesPayments)
          ..where((t) => t.duesPeriodId.equals(period.id) & t.isPaid.equals(true)))
        .get();

    final totalCollected = payments.fold<int>(0, (sum, p) => sum + p.amountPaid);
    
    // Ambil nominal yang sudah pernah direkonsiliasi sebelumnya
    var previouslyReconciled = currentPeriod.reconciledAmount;
    if (previouslyReconciled == 0 && currentPeriod.isReconciled) {
      // Fallback untuk periode yang sudah direkonsiliasi sebelum kolom reconciledAmount ditambahkan
      final linkedTx = await (_db.select(_db.transactions)
            ..where((t) => t.academicYearId.equals(academicYearId) & t.title.like('%${period.periodLabel}%')))
          .get();
      if (linkedTx.isNotEmpty) {
        previouslyReconciled = linkedTx.fold<int>(0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
      }
    }

    final delta = totalCollected - previouslyReconciled;
    if (delta <= 0) return 0;

    // 3. Cari kategori "Uang Kas Rutin"
    final incomeCategory = await (_db.select(_db.categories)
          ..where((t) => t.type.equals('income') & t.name.equals('Uang Kas Rutin')))
        .getSingleOrNull();

    final categoryId = incomeCategory?.id ?? (await _db.select(_db.categories).get()).first.id;

    const uuid = Uuid();
    final txId = uuid.v4();
    final now = DateTime.now();

    final isFirstReconcile = previouslyReconciled == 0;
    final deltaStudentCount = currentPeriod.targetAmount > 0
        ? (delta ~/ currentPeriod.targetAmount)
        : payments.length;

    // 4. Simpan transaksi kas masuk di buku kas umum HANYA sebesar delta (selisih baru)
    await _db.into(_db.transactions).insert(
      TransactionsCompanion.insert(
        id: txId,
        academicYearId: academicYearId,
        categoryId: categoryId,
        type: 'income',
        amount: delta,
        title: isFirstReconcile
            ? 'Kas Kelas (${period.periodLabel})'
            : 'Kas Kelas (${period.periodLabel}) - Tambahan',
        description: Value(isFirstReconcile
            ? 'Penerimaan kas dari ${payments.length} siswa lunas'
            : 'Penerimaan kas tambahan ($deltaStudentCount siswa baru lunas)'),
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 5. Perbarui status periode dan simpan total nominal yang sudah direkonsiliasi
    await (_db.update(_db.duesPeriods)..where((t) => t.id.equals(period.id)))
        .write(
      DuesPeriodsCompanion(
        isReconciled: const Value(true),
        reconciledAmount: Value(totalCollected),
        transactionId: Value(txId),
      ),
    );

    return delta;
  }
}
