import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/date_formatter.dart';

import 'tables/academic_years.dart';
import 'tables/students.dart';
import 'tables/categories.dart';
import 'tables/transactions.dart';
import 'tables/dues_periods.dart';
import 'tables/dues_payments.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  AcademicYears,
  Students,
  Categories,
  Transactions,
  DuesPeriods,
  DuesPayments,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 2;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bendahara_v2_db',
      native: const DriftNativeOptions(
        shareAcrossIsolates: true,
      ),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(academicYears, academicYears.duesPeriodType);
        await m.addColumn(duesPeriods, duesPeriods.reconciledAmount);

        // Sinkronisasi data rekonsiliasi v1 agar tidak double-counting saat upgrade
        await customStatement('''
          UPDATE dues_periods
          SET reconciled_amount = (
            SELECT COALESCE(SUM(amount_paid), 0)
            FROM dues_payments
            WHERE dues_payments.dues_period_id = dues_periods.id AND dues_payments.is_paid = 1
          )
          WHERE is_reconciled = 1;
        ''');

        // Perbarui nama kategori bawaan lama dari 'Iuran' menjadi 'Kas'
        await customStatement("UPDATE categories SET name = 'Kas Khusus Kegiatan' WHERE name = 'Iuran Khusus Kegiatan';");
        await customStatement("UPDATE categories SET name = 'Uang Kas Rutin' WHERE name = 'Uang Iuran Rutin';");
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA journal_mode = WAL;');
      await customStatement('PRAGMA synchronous = NORMAL;');
      await customStatement('PRAGMA temp_store = MEMORY;');
      await customStatement('PRAGMA cache_size = -8000;');

      await sanitizeDuplicatePeriods();
      await sanitizeReconciledTransactionDates();

      // Indeks komposit performa query dan sorting
      await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_year_date ON transactions(academic_year_id, transaction_date);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_year_created_at ON transactions(academic_year_id, created_at);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(academic_year_id, type);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);');
      await customStatement('DROP INDEX IF EXISTS idx_dues_periods_year_label;');
      await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_dues_periods_year_label ON dues_periods(academic_year_id, period_label);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_dues_payments_period_paid ON dues_payments(dues_period_id, is_paid);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_students_year_no ON students(academic_year_id, attendance_number);');

      // Seed categories jika masih kosong
      final categoryCount = await categories.count().getSingle();
      if (categoryCount == 0) {
        await _seedDefaultCategories();
      }
    },
  );

  Future<void> sanitizeDuplicatePeriods() async {
    final duplicateGroups = await customSelect(
      'SELECT academic_year_id, period_label, COUNT(*) as cnt '
      'FROM dues_periods '
      'GROUP BY academic_year_id, period_label '
      'HAVING COUNT(*) > 1;',
    ).get();

    if (duplicateGroups.isEmpty) return;

    for (final group in duplicateGroups) {
      final yearId = group.read<String>('academic_year_id');
      final label = group.read<String>('period_label');

      final periods = await (select(duesPeriods)
            ..where((t) => t.academicYearId.equals(yearId) & t.periodLabel.equals(label))
            ..orderBy([
              (t) => OrderingTerm(expression: t.isReconciled, mode: OrderingMode.desc),
              (t) => OrderingTerm(expression: t.reconciledAmount, mode: OrderingMode.desc),
              (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
            ]))
          .get();

      if (periods.length <= 1) continue;

      final primary = periods.first;
      var isReconciled = primary.isReconciled;
      var reconciledAmount = primary.reconciledAmount;
      var transactionId = primary.transactionId;

      for (int i = 1; i < periods.length; i++) {
        final dup = periods[i];
        if (dup.isReconciled) isReconciled = true;
        if (dup.reconciledAmount > reconciledAmount) {
          reconciledAmount = dup.reconciledAmount;
        }
        if (transactionId == null && dup.transactionId != null) {
          transactionId = dup.transactionId;
        }

        final dupPayments = await (select(duesPayments)..where((t) => t.duesPeriodId.equals(dup.id))).get();
        for (final p in dupPayments) {
          final existingPayment = await (select(duesPayments)
                ..where((t) => t.duesPeriodId.equals(primary.id) & t.studentId.equals(p.studentId)))
              .getSingleOrNull();

          if (existingPayment == null) {
            await (update(duesPayments)..where((t) => t.id.equals(p.id))).write(
              DuesPaymentsCompanion(
                duesPeriodId: Value(primary.id),
              ),
            );
          } else {
            if (!existingPayment.isPaid && p.isPaid) {
              await (update(duesPayments)..where((t) => t.id.equals(existingPayment.id))).write(
                DuesPaymentsCompanion(
                  isPaid: const Value(true),
                  amountPaid: Value(p.amountPaid),
                  paidAt: Value(p.paidAt),
                  notes: Value(p.notes),
                ),
              );
            } else if (p.amountPaid > existingPayment.amountPaid) {
              await (update(duesPayments)..where((t) => t.id.equals(existingPayment.id))).write(
                DuesPaymentsCompanion(
                  amountPaid: Value(p.amountPaid),
                ),
              );
            }
            await (delete(duesPayments)..where((t) => t.id.equals(p.id))).go();
          }
        }

        await (delete(duesPeriods)..where((t) => t.id.equals(dup.id))).go();
      }

      await (update(duesPeriods)..where((t) => t.id.equals(primary.id))).write(
        DuesPeriodsCompanion(
          isReconciled: Value(isReconciled),
          reconciledAmount: Value(reconciledAmount),
          transactionId: Value(transactionId),
        ),
      );
    }
  }

  Future<void> sanitizeReconciledTransactionDates() async {
    try {
      final tableCheck = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('transactions', 'dues_periods');",
      ).get();
      final existingTables = tableCheck.map((r) => r.read<String>('name')).toSet();
      if (!existingTables.contains('transactions') || !existingTables.contains('dues_periods')) {
        return;
      }

      // 1. Sanitasi tanggal pada transaksi rekonsiliasi kas yang tersimpan dengan tanggal hari ini
      final duesTxs = await (select(transactions)
            ..where((t) => t.title.like('Kas Kelas (%')))
          .get();

      for (final tx in duesTxs) {
        final parsedDate = DateFormatter.tryParseDateFromTitle(tx.title);
        if (parsedDate != null) {
          final txDate = tx.transactionDate;
          if (txDate.year != parsedDate.year ||
              txDate.month != parsedDate.month ||
              txDate.day != parsedDate.day) {
            final correctedDate = DateTime(
              parsedDate.year,
              parsedDate.month,
              parsedDate.day,
              txDate.hour,
              txDate.minute,
              txDate.second,
            );
            await (update(transactions)..where((t) => t.id.equals(tx.id))).write(
              TransactionsCompanion(
                transactionDate: Value(correctedDate),
              ),
            );
          }
        }
      }

      // 2. Sanitasi dueDate pada dues_periods jika ada periode yang dueDate-nya tidak sinkron dengan label
      final allPeriods = await select(duesPeriods).get();
      for (final p in allPeriods) {
        final parsed = DateFormatter.tryParsePeriodDate(p.periodLabel);
        if (parsed != null) {
          if (p.dueDate.year != parsed.year ||
              p.dueDate.month != parsed.month ||
              p.dueDate.day != parsed.day) {
            await (update(duesPeriods)..where((t) => t.id.equals(p.id))).write(
              DuesPeriodsCompanion(
                dueDate: Value(parsed),
              ),
            );
          }
        }
      }
    } catch (_) {
      // Defensive fallback: jangan gagalkan startup basis data jika terjadi kendala parsial
    }
  }

  Future<void> _seedDefaultCategories() async {
    const uuid = Uuid();
    final now = DateTime.now();

    final defaultCats = [
      // Pemasukan
      CategoriesCompanion.insert(
        id: uuid.v4(),
        type: 'income',
        name: 'Uang Kas Rutin',
        iconName: 'payments_rounded',
        colorHex: '#16A34A',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: uuid.v4(),
        type: 'income',
        name: 'Kas Khusus Kegiatan',
        iconName: 'event_rounded',
        colorHex: '#2563EB',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: uuid.v4(),
        type: 'income',
        name: 'Sisa Kembalian Belanja',
        iconName: 'currency_exchange_rounded',
        colorHex: '#059669',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: uuid.v4(),
        type: 'income',
        name: 'Kas Awal / Donasi',
        iconName: 'volunteer_activism_rounded',
        colorHex: '#7C3AED',
        isDefault: const Value(true),
        createdAt: now,
      ),

      // Pengeluaran
      CategoriesCompanion.insert(
        id: uuid.v4(),
        type: 'expense',
        name: 'Alat Tulis & Spidol',
        iconName: 'edit_note_rounded',
        colorHex: '#DC2626',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: uuid.v4(),
        type: 'expense',
        name: 'Kebersihan Kelas',
        iconName: 'cleaning_services_rounded',
        colorHex: '#D97706',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: uuid.v4(),
        type: 'expense',
        name: 'Fotokopi & Lembar Tugas',
        iconName: 'print_rounded',
        colorHex: '#475569',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: uuid.v4(),
        type: 'expense',
        name: 'Jenguk Teman Sakit',
        iconName: 'favorite_rounded',
        colorHex: '#E11D48',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: uuid.v4(),
        type: 'expense',
        name: 'Dekorasi Kelas',
        iconName: 'palette_rounded',
        colorHex: '#9333EA',
        isDefault: const Value(true),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: uuid.v4(),
        type: 'expense',
        name: 'Konsumsi & Lainnya',
        iconName: 'more_horiz_rounded',
        colorHex: '#64748B',
        isDefault: const Value(true),
        createdAt: now,
      ),
    ];

    await batch((batch) {
      batch.insertAll(categories, defaultCats);
    });
  }

  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(duesPayments).go();
      await delete(duesPeriods).go();
      await delete(transactions).go();
      await delete(students).go();
      await delete(categories).go();
      await delete(academicYears).go();
      await _seedDefaultCategories();
    });
  }
}
