import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

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
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA journal_mode = WAL;');

      // Seed categories jika masih kosong
      final categoryCount = await categories.count().getSingle();
      if (categoryCount == 0) {
        await _seedDefaultCategories();
      }
    },
  );

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
