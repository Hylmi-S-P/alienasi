import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/date_formatter.dart';
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
  final Map<String, Future<DuesPeriod>> _activePeriodCreationLocks = {};

  DuesRepository(this._db);

  Future<DuesPeriod> getOrCreateActivePeriod({
    required String academicYearId,
    required String periodLabel,
    required int targetAmount,
    DateTime? dueDate,
  }) async {
    final lockKey = '$academicYearId::$periodLabel';
    if (_activePeriodCreationLocks.containsKey(lockKey)) {
      return _activePeriodCreationLocks[lockKey]!;
    }

    final future = _getOrCreateActivePeriodInternal(
      academicYearId: academicYearId,
      periodLabel: periodLabel,
      targetAmount: targetAmount,
      dueDate: dueDate,
    );

    _activePeriodCreationLocks[lockKey] = future;
    try {
      return await future;
    } finally {
      _activePeriodCreationLocks.remove(lockKey);
    }
  }

  Future<DuesPeriod> _getOrCreateActivePeriodInternal({
    required String academicYearId,
    required String periodLabel,
    required int targetAmount,
    DateTime? dueDate,
  }) async {
    var period = await (_db.select(_db.duesPeriods)
          ..where((t) => t.academicYearId.equals(academicYearId) & t.periodLabel.equals(periodLabel))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)])
          ..limit(1))
        .getSingleOrNull();

    final effectiveDueDate = dueDate ??
        DateFormatter.tryParsePeriodDate(periodLabel) ??
        DateTime.now();

    if (period == null) {
      const uuid = Uuid();
      final newPeriodId = uuid.v4();
      final newPeriod = DuesPeriodsCompanion.insert(
        id: newPeriodId,
        academicYearId: academicYearId,
        periodLabel: periodLabel,
        dueDate: effectiveDueDate,
        targetAmount: targetAmount,
        isReconciled: const Value(false),
        createdAt: DateTime.now(),
      );

      await _db.into(_db.duesPeriods).insert(newPeriod, mode: InsertMode.insertOrIgnore);
      period = await (_db.select(_db.duesPeriods)
            ..where((t) => t.academicYearId.equals(academicYearId) & t.periodLabel.equals(periodLabel))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)])
            ..limit(1))
          .getSingle();
    } else {
      final parsedDate = DateFormatter.tryParsePeriodDate(period.periodLabel);
      if (parsedDate != null &&
          (period.dueDate.year != parsedDate.year ||
              period.dueDate.month != parsedDate.month ||
              period.dueDate.day != parsedDate.day)) {
        await (_db.update(_db.duesPeriods)..where((t) => t.id.equals(period!.id))).write(
          DuesPeriodsCompanion(
            dueDate: Value(parsedDate),
          ),
        );
        period = await (_db.select(_db.duesPeriods)
              ..where((t) => t.id.equals(period!.id)))
            .getSingle();
      }
    }

    // Pastikan seluruh siswa aktif memiliki entri awal di dues_payments untuk periode ini (self-healing batch)
    final students = await (_db.select(_db.students)
          ..where((t) => t.academicYearId.equals(academicYearId)))
        .get();

    final periodId = period.id;
    if (students.isNotEmpty) {
      await _db.batch((batch) {
        for (final s in students) {
          batch.insert(
            _db.duesPayments,
            DuesPaymentsCompanion.insert(
              id: const Uuid().v4(),
              duesPeriodId: periodId,
              studentId: s.id,
              amountPaid: const Value(0),
              isPaid: const Value(false),
              paidAt: const Value(null),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
    }

    return period;
  }

  Stream<DuesPeriod?> watchActivePeriod({
    required String academicYearId,
    required String periodLabel,
    required int targetAmount,
    DateTime? dueDate,
  }) async* {
    final period = await getOrCreateActivePeriod(
      academicYearId: academicYearId,
      periodLabel: periodLabel,
      targetAmount: targetAmount,
      dueDate: dueDate,
    );
    yield* (_db.select(_db.duesPeriods)
          ..where((t) => t.id.equals(period.id))
          ..limit(1))
        .watchSingleOrNull();
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
      final items = <StudentDuesItem>[];
      for (final row in rows) {
        final student = row.readTable(_db.students);
        final payment = row.readTableOrNull(_db.duesPayments);
        // Siswa non-aktif hanya diikutsertakan jika memiliki riwayat bayar lunas pada periode ini
        if (student.status != 'active' && (payment == null || !payment.isPaid)) {
          continue;
        }
        items.add(StudentDuesItem(
          student: student,
          payment: payment,
        ));
      }
      return items;
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

  Future<void> markAsPaid({
    required String duesPeriodId,
    required String studentId,
    required int targetAmount,
  }) async {
    final existingPayment = await (_db.select(_db.duesPayments)
          ..where((t) => t.duesPeriodId.equals(duesPeriodId) & t.studentId.equals(studentId)))
        .getSingleOrNull();

    if (existingPayment != null && existingPayment.isPaid) {
      return;
    }

    final now = DateTime.now();
    if (existingPayment == null) {
      await _db.into(_db.duesPayments).insert(
        DuesPaymentsCompanion.insert(
          id: const Uuid().v4(),
          duesPeriodId: duesPeriodId,
          studentId: studentId,
          amountPaid: Value(targetAmount),
          isPaid: const Value(true),
          paidAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );
    } else {
      await (_db.update(_db.duesPayments)..where((t) => t.id.equals(existingPayment.id))).write(
        DuesPaymentsCompanion(
          amountPaid: Value(targetAmount),
          isPaid: const Value(true),
          paidAt: Value(now),
        ),
      );
    }
  }

  Future<void> markBatchAsPaid({
    required String duesPeriodId,
    required Iterable<String> studentIds,
    required int targetAmount,
  }) async {
    if (studentIds.isEmpty) return;
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.duesPayments)
            ..where((t) => t.duesPeriodId.equals(duesPeriodId) & t.studentId.isIn(studentIds)))
          .write(
        DuesPaymentsCompanion(
          amountPaid: Value(targetAmount),
          isPaid: const Value(true),
          paidAt: Value(now),
        ),
      );
    });
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
    if (delta <= 0) {
      if (currentPeriod.reconciledAmount != previouslyReconciled) {
        await (_db.update(_db.duesPeriods)..where((t) => t.id.equals(period.id)))
            .write(
          DuesPeriodsCompanion(
            reconciledAmount: Value(previouslyReconciled),
          ),
        );
      }
      return 0;
    }

    // 3. Cari kategori "Uang Kas Rutin"
    final incomeCategory = await (_db.select(_db.categories)
          ..where((t) => t.type.equals('income') & t.name.equals('Uang Kas Rutin')))
        .getSingleOrNull();

    final categoryId = incomeCategory?.id ?? (await _db.select(_db.categories).get()).first.id;

    const uuid = Uuid();
    final txId = uuid.v4();
    final now = DateTime.now();
    final effectivePeriodDate = DateFormatter.tryParsePeriodDate(
          currentPeriod.periodLabel,
          fallbackDueDate: currentPeriod.dueDate,
        ) ??
        currentPeriod.dueDate;

    final txDate = DateTime(
      effectivePeriodDate.year,
      effectivePeriodDate.month,
      effectivePeriodDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    final isFirstReconcile = previouslyReconciled == 0 && !currentPeriod.isReconciled;
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
        transactionDate: txDate,
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

  Future<void> syncReconciledAmount({
    required String duesPeriodId,
    required int actualCollected,
  }) async {
    await (_db.update(_db.duesPeriods)..where((t) => t.id.equals(duesPeriodId)))
        .write(
      DuesPeriodsCompanion(
        reconciledAmount: Value(actualCollected),
      ),
    );
  }
}
