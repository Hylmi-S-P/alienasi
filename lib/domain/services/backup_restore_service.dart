import 'dart:convert';
import 'package:drift/drift.dart';
import '../../data/database/app_database.dart';

class BackupPreviewData {
  final String academicYearName;
  final String schoolYear;
  final String treasurerName;
  final int studentsCount;
  final int transactionsCount;
  final int periodsCount;
  final int totalBalance;
  final DateTime exportedAt;

  const BackupPreviewData({
    required this.academicYearName,
    required this.schoolYear,
    required this.treasurerName,
    required this.studentsCount,
    required this.transactionsCount,
    required this.periodsCount,
    required this.totalBalance,
    required this.exportedAt,
  });
}

class BackupRestoreService {
  BackupRestoreService._();

  /// Menghasilkan berkas JSON snapshot lengkap dari kelas aktif
  static Future<String> createBackupJson({
    required AppDatabase db,
    required String academicYearId,
  }) async {
    final year = await (db.select(db.academicYears)
          ..where((t) => t.id.equals(academicYearId)))
        .getSingle();

    final students = await (db.select(db.students)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([(t) => OrderingTerm.asc(t.attendanceNumber)]))
        .get();

    final categories = await db.select(db.categories).get();

    final transactions = await (db.select(db.transactions)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([(t) => OrderingTerm.asc(t.transactionDate)]))
        .get();

    final duesPeriods = await (db.select(db.duesPeriods)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    final periodIds = duesPeriods.map((p) => p.id).toList();
    final duesPayments = periodIds.isEmpty
        ? <DuesPayment>[]
        : await (db.select(db.duesPayments)
              ..where((t) => t.duesPeriodId.isIn(periodIds)))
            .get();

    final backupMap = <String, dynamic>{
      'app': 'Bendahara Kelas',
      'version': '1.0.1',
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'academicYear': {
        'id': year.id,
        'name': year.name,
        'grade': year.grade,
        'treasurerName': year.treasurerName,
        'supervisorName': year.supervisorName,
        'defaultDuesAmount': year.defaultDuesAmount,
        'duesPeriodType': year.duesPeriodType,
        'startDate': year.startDate.toIso8601String(),
        'endDate': year.endDate.toIso8601String(),
        'isActive': year.isActive,
        'createdAt': year.createdAt.toIso8601String(),
      },
      'categories': categories
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'type': c.type,
                'iconName': c.iconName,
                'colorHex': c.colorHex,
                'isDefault': c.isDefault,
                'createdAt': c.createdAt.toIso8601String(),
              })
          .toList(),
      'students': students
          .map((s) => {
                'id': s.id,
                'academicYearId': s.academicYearId,
                'attendanceNumber': s.attendanceNumber,
                'name': s.name,
                'status': s.status,
                'createdAt': s.createdAt.toIso8601String(),
              })
          .toList(),
      'transactions': transactions
          .map((t) => {
                'id': t.id,
                'academicYearId': t.academicYearId,
                'categoryId': t.categoryId,
                'type': t.type,
                'amount': t.amount,
                'title': t.title,
                'description': t.description,
                'receiptImagePath': t.receiptImagePath,
                'transactionDate': t.transactionDate.toIso8601String(),
                'createdAt': t.createdAt.toIso8601String(),
                'updatedAt': t.updatedAt.toIso8601String(),
              })
          .toList(),
      'duesPeriods': duesPeriods
          .map((p) => {
                'id': p.id,
                'academicYearId': p.academicYearId,
                'periodLabel': p.periodLabel,
                'targetAmount': p.targetAmount,
                'dueDate': p.dueDate.toIso8601String(),
                'isReconciled': p.isReconciled,
                'reconciledAmount': p.reconciledAmount,
                'transactionId': p.transactionId,
                'createdAt': p.createdAt.toIso8601String(),
              })
          .toList(),
      'duesPayments': duesPayments
          .map((dp) => {
                'id': dp.id,
                'duesPeriodId': dp.duesPeriodId,
                'studentId': dp.studentId,
                'amountPaid': dp.amountPaid,
                'isPaid': dp.isPaid,
                'paidAt': dp.paidAt?.toIso8601String(),
                'notes': dp.notes,
              })
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(backupMap);
  }

  /// Memvalidasi berkas cadangan dan mengembalikan pratinjau ringkasan data
  static BackupPreviewData parseAndPreview(String jsonString) {
    final dynamic decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format berkas cadangan tidak valid (bukan objek JSON).');
    }

    if (decoded['app'] != 'Bendahara Kelas') {
      throw const FormatException('Berkas ini bukan berkas cadangan resmi aplikasi Bendahara Kelas.');
    }

    final yearMap = decoded['academicYear'] as Map<String, dynamic>?;
    if (yearMap == null || yearMap['name'] == null) {
      throw const FormatException('Data identitas kelas tidak ditemukan di dalam berkas cadangan.');
    }

    final startDate = DateTime.parse(yearMap['startDate'] as String);
    final endDate = DateTime.parse(yearMap['endDate'] as String);
    final schoolYear = '${startDate.year}/${endDate.year}';

    final studentsList = (decoded['students'] as List<dynamic>?) ?? [];
    final txList = (decoded['transactions'] as List<dynamic>?) ?? [];
    final periodsList = (decoded['duesPeriods'] as List<dynamic>?) ?? [];

    var balance = 0;
    for (final item in txList) {
      if (item is Map<String, dynamic>) {
        final amount = (item['amount'] as num?)?.toInt() ?? 0;
        final type = item['type'] as String? ?? 'income';
        if (type == 'income') {
          balance += amount;
        } else {
          balance -= amount;
        }
      }
    }

    final exportedAt = decoded['exportedAt'] != null
        ? DateTime.parse(decoded['exportedAt'] as String)
        : DateTime.now();

    return BackupPreviewData(
      academicYearName: yearMap['name'] as String? ?? 'Kelas',
      schoolYear: schoolYear,
      treasurerName: yearMap['treasurerName'] as String? ?? '-',
      studentsCount: studentsList.length,
      transactionsCount: txList.length,
      periodsCount: periodsList.length,
      totalBalance: balance,
      exportedAt: exportedAt,
    );
  }

  /// Menjalankan pemulihan data cadangan secara atomik ke dalam basis data SQLite
  static Future<void> restoreFromBackupJson({
    required AppDatabase db,
    required String jsonString,
  }) async {
    final dynamic decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format berkas cadangan tidak valid.');
    }

    if (decoded['app'] != 'Bendahara Kelas') {
      throw const FormatException('Berkas ini bukan berkas cadangan resmi aplikasi Bendahara Kelas.');
    }

    final yearMap = decoded['academicYear'] as Map<String, dynamic>;
    final categoriesList = (decoded['categories'] as List<dynamic>?) ?? [];
    final studentsList = (decoded['students'] as List<dynamic>?) ?? [];
    final txList = (decoded['transactions'] as List<dynamic>?) ?? [];
    final periodsList = (decoded['duesPeriods'] as List<dynamic>?) ?? [];
    final paymentsList = (decoded['duesPayments'] as List<dynamic>?) ?? [];

    await db.transaction(() async {
      // 1. Bersihkan data relasional lama untuk kelas ini agar tidak terjadi bentrok
      final targetYearId = yearMap['id'] as String;

      // Ambil seluruh periode kas yang ada di kelas ini
      final existingPeriods = await (db.select(db.duesPeriods)
            ..where((t) => t.academicYearId.equals(targetYearId)))
          .get();
      final existingPeriodIds = existingPeriods.map((p) => p.id).toList();

      if (existingPeriodIds.isNotEmpty) {
        await (db.delete(db.duesPayments)
              ..where((t) => t.duesPeriodId.isIn(existingPeriodIds)))
            .go();
      }

      await (db.delete(db.duesPeriods)
            ..where((t) => t.academicYearId.equals(targetYearId)))
          .go();

      await (db.delete(db.transactions)
            ..where((t) => t.academicYearId.equals(targetYearId)))
          .go();

      await (db.delete(db.students)
            ..where((t) => t.academicYearId.equals(targetYearId)))
          .go();

      // 2. Pulihkan Tahun Ajaran (Insert or Replace)
      final yearCompanion = AcademicYearsCompanion(
        id: Value(yearMap['id'] as String),
        name: Value(yearMap['name'] as String),
        grade: Value((yearMap['grade'] as num).toInt()),
        treasurerName: Value(yearMap['treasurerName'] as String),
        supervisorName: Value(yearMap['supervisorName'] as String? ?? 'Ibu Pengawas'),
        defaultDuesAmount: Value((yearMap['defaultDuesAmount'] as num).toInt()),
        duesPeriodType: Value(yearMap['duesPeriodType'] as String? ?? 'weekly'),
        startDate: Value(DateTime.parse(yearMap['startDate'] as String)),
        endDate: Value(DateTime.parse(yearMap['endDate'] as String)),
        isActive: Value(yearMap['isActive'] as bool? ?? true),
        createdAt: Value(DateTime.parse(yearMap['createdAt'] as String)),
      );
      await db.into(db.academicYears).insertOnConflictUpdate(yearCompanion);

      // 3. Pulihkan Kategori
      for (final rawCat in categoriesList) {
        if (rawCat is Map<String, dynamic>) {
          final catCompanion = CategoriesCompanion(
            id: Value(rawCat['id'] as String),
            name: Value(rawCat['name'] as String),
            type: Value(rawCat['type'] as String),
            iconName: Value(rawCat['iconName'] as String? ?? 'category'),
            colorHex: Value(rawCat['colorHex'] as String? ?? '#16A34A'),
            isDefault: Value(rawCat['isDefault'] as bool? ?? false),
            createdAt: Value(DateTime.parse(rawCat['createdAt'] as String)),
          );
          await db.into(db.categories).insertOnConflictUpdate(catCompanion);
        }
      }

      // 4. Pulihkan Siswa
      for (final rawS in studentsList) {
        if (rawS is Map<String, dynamic>) {
          final studentCompanion = StudentsCompanion(
            id: Value(rawS['id'] as String),
            academicYearId: Value(rawS['academicYearId'] as String),
            attendanceNumber: Value((rawS['attendanceNumber'] as num).toInt()),
            name: Value(rawS['name'] as String),
            status: Value(rawS['status'] as String? ?? 'active'),
            createdAt: Value(DateTime.parse(rawS['createdAt'] as String)),
          );
          await db.into(db.students).insertOnConflictUpdate(studentCompanion);
        }
      }

      // 5. Pulihkan Transaksi Kas
      for (final rawTx in txList) {
        if (rawTx is Map<String, dynamic>) {
          final txCompanion = TransactionsCompanion(
            id: Value(rawTx['id'] as String),
            academicYearId: Value(rawTx['academicYearId'] as String),
            categoryId: Value(rawTx['categoryId'] as String),
            type: Value(rawTx['type'] as String),
            amount: Value((rawTx['amount'] as num).toInt()),
            title: Value(rawTx['title'] as String),
            description: Value(rawTx['description'] as String?),
            receiptImagePath: Value(rawTx['receiptImagePath'] as String?),
            transactionDate: Value(DateTime.parse(rawTx['transactionDate'] as String)),
            createdAt: Value(DateTime.parse(rawTx['createdAt'] as String)),
            updatedAt: Value(DateTime.parse(rawTx['updatedAt'] as String)),
          );
          await db.into(db.transactions).insertOnConflictUpdate(txCompanion);
        }
      }

      // 6. Pulihkan Periode Kas
      for (final rawPeriod in periodsList) {
        if (rawPeriod is Map<String, dynamic>) {
          final dueDateStr = rawPeriod['dueDate'] as String?;
          final createdAtStr = rawPeriod['createdAt'] as String;
          final periodCompanion = DuesPeriodsCompanion(
            id: Value(rawPeriod['id'] as String),
            academicYearId: Value(rawPeriod['academicYearId'] as String),
            periodLabel: Value(rawPeriod['periodLabel'] as String),
            targetAmount: Value((rawPeriod['targetAmount'] as num).toInt()),
            dueDate: Value(dueDateStr != null ? DateTime.parse(dueDateStr) : DateTime.parse(createdAtStr)),
            isReconciled: Value(rawPeriod['isReconciled'] as bool? ?? false),
            reconciledAmount: Value((rawPeriod['reconciledAmount'] as num?)?.toInt() ?? 0),
            transactionId: Value(rawPeriod['transactionId'] as String?),
            createdAt: Value(DateTime.parse(createdAtStr)),
          );
          await db.into(db.duesPeriods).insertOnConflictUpdate(periodCompanion);
        }
      }

      // 7. Pulihkan Catatan Pembayaran Kas Siswa
      for (final rawPay in paymentsList) {
        if (rawPay is Map<String, dynamic>) {
          final payCompanion = DuesPaymentsCompanion(
            id: Value(rawPay['id'] as String),
            duesPeriodId: Value(rawPay['duesPeriodId'] as String),
            studentId: Value(rawPay['studentId'] as String),
            amountPaid: Value((rawPay['amountPaid'] as num).toInt()),
            isPaid: Value(rawPay['isPaid'] as bool? ?? false),
            paidAt: Value(rawPay['paidAt'] != null ? DateTime.parse(rawPay['paidAt'] as String) : null),
            notes: Value(rawPay['notes'] as String?),
          );
          await db.into(db.duesPayments).insertOnConflictUpdate(payCompanion);
        }
      }
    });
  }
}
