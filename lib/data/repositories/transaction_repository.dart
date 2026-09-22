import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../domain/services/receipt_storage_service.dart';

class TransactionWithCategory {
  final Transaction transaction;
  final Category category;
  final AcademicYear academicYear;

  TransactionWithCategory({
    required this.transaction,
    required this.category,
    required this.academicYear,
  });
}

class BalanceStats {
  final int totalBalance;
  final int monthlyIncome;
  final int monthlyExpense;

  const BalanceStats({
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpense,
  });
}

class TransactionRepository {
  final AppDatabase _db;
  const TransactionRepository(this._db);

  Stream<List<TransactionWithCategory>> watchRecentTransactions({
    required String academicYearId,
    int limit = 5,
  }) {
    final query = (_db.select(_db.transactions)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
          ..limit(limit))
        .join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(_db.academicYears, _db.academicYears.id.equalsExp(_db.transactions.academicYearId)),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategory(
          transaction: row.readTable(_db.transactions),
          category: row.readTable(_db.categories),
          academicYear: row.readTable(_db.academicYears),
        );
      }).toList();
    });
  }

  Stream<List<TransactionWithCategory>> watchAllTransactions({
    required String academicYearId,
  }) {
    final query = (_db.select(_db.transactions)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(_db.academicYears, _db.academicYears.id.equalsExp(_db.transactions.academicYearId)),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategory(
          transaction: row.readTable(_db.transactions),
          category: row.readTable(_db.categories),
          academicYear: row.readTable(_db.academicYears),
        );
      }).toList();
    });
  }

  Future<List<TransactionWithCategory>> getAllTransactions({
    required String academicYearId,
  }) async {
    final query = (_db.select(_db.transactions)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(_db.academicYears, _db.academicYears.id.equalsExp(_db.transactions.academicYearId)),
    ]);

    final rows = await query.get();
    return rows.map((row) {
      return TransactionWithCategory(
        transaction: row.readTable(_db.transactions),
        category: row.readTable(_db.categories),
        academicYear: row.readTable(_db.academicYears),
      );
    }).toList();
  }

  Stream<List<TransactionWithCategory>> watchTransactionsByRange({
    String? academicYearId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final query = (_db.select(_db.transactions)
          ..where((t) {
            final dateFilter = t.transactionDate.isBiggerOrEqualValue(startDate) &
                t.transactionDate.isSmallerOrEqualValue(endDate);
            if (academicYearId != null) {
              return t.academicYearId.equals(academicYearId) & dateFilter;
            }
            return dateFilter;
          })
          ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)]))
        .join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(_db.academicYears, _db.academicYears.id.equalsExp(_db.transactions.academicYearId)),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategory(
          transaction: row.readTable(_db.transactions),
          category: row.readTable(_db.categories),
          academicYear: row.readTable(_db.academicYears),
        );
      }).toList();
    });
  }

  Future<List<TransactionWithCategory>> getTransactionsByRange({
    String? academicYearId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = (_db.select(_db.transactions)
          ..where((t) {
            final dateFilter = t.transactionDate.isBiggerOrEqualValue(startDate) &
                t.transactionDate.isSmallerOrEqualValue(endDate);
            if (academicYearId != null) {
              return t.academicYearId.equals(academicYearId) & dateFilter;
            }
            return dateFilter;
          })
          ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.asc)]))
        .join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(_db.academicYears, _db.academicYears.id.equalsExp(_db.transactions.academicYearId)),
    ]);

    final rows = await query.get();
    return rows.map((row) {
      return TransactionWithCategory(
        transaction: row.readTable(_db.transactions),
        category: row.readTable(_db.categories),
        academicYear: row.readTable(_db.academicYears),
      );
    }).toList();
  }

  Stream<BalanceStats> watchBalanceStats(String academicYearId) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Agregasi dihitung langsung oleh SQLite (bukan di Dart) agar tetap
    // ringan walau sudah menampung ribuan transaksi selama 6 tahun.
    final totalExpr = _db.transactions.amount.sum(
      filter: _db.transactions.type.equals('income'),
    );
    final totalExpenseExpr = _db.transactions.amount.sum(
      filter: _db.transactions.type.equals('expense'),
    );
    final monthlyIncomeExpr = _db.transactions.amount.sum(
      filter: _db.transactions.type.equals('income') &
          _db.transactions.transactionDate.isBiggerOrEqualValue(firstDayOfMonth) &
          _db.transactions.transactionDate.isSmallerOrEqualValue(lastDayOfMonth),
    );
    final monthlyExpenseExpr = _db.transactions.amount.sum(
      filter: _db.transactions.type.equals('expense') &
          _db.transactions.transactionDate.isBiggerOrEqualValue(firstDayOfMonth) &
          _db.transactions.transactionDate.isSmallerOrEqualValue(lastDayOfMonth),
    );

    final query = _db.selectOnly(_db.transactions)
      ..addColumns([totalExpr, totalExpenseExpr, monthlyIncomeExpr, monthlyExpenseExpr])
      ..where(_db.transactions.academicYearId.equals(academicYearId));

    return query.watchSingle().map((row) {
      final totalIncome = row.read(totalExpr) ?? 0;
      final totalExpense = row.read(totalExpenseExpr) ?? 0;
      return BalanceStats(
        totalBalance: totalIncome - totalExpense,
        monthlyIncome: row.read(monthlyIncomeExpr) ?? 0,
        monthlyExpense: row.read(monthlyExpenseExpr) ?? 0,
      );
    });
  }

  Future<void> insertTransaction({
    required String academicYearId,
    required String categoryId,
    required String type,
    required int amount,
    required String title,
    String? description,
    String? receiptImagePath,
    required DateTime transactionDate,
  }) async {
    const uuid = Uuid();
    final now = DateTime.now();

    await _db.into(_db.transactions).insert(
      TransactionsCompanion.insert(
        id: uuid.v4(),
        academicYearId: academicYearId,
        categoryId: categoryId,
        type: type,
        amount: amount,
        title: title,
        description: Value(description),
        receiptImagePath: Value(receiptImagePath),
        transactionDate: transactionDate,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Memperbarui transaksi yang sudah ada (koreksi salah input).
  ///
  /// Kolom `createdAt` tidak pernah diubah agar riwayat pencatatan tetap
  /// jujur; hanya `updatedAt` yang diperbarui sebagai jejak audit.
  Future<void> updateTransaction({
    required String transactionId,
    required String categoryId,
    required String type,
    required int amount,
    required String title,
    String? description,
    String? receiptImagePath,
    bool removeReceipt = false,
    required DateTime transactionDate,
  }) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(
        categoryId: Value(categoryId),
        type: Value(type),
        amount: Value(amount),
        title: Value(title),
        description: Value(description),
        receiptImagePath: removeReceipt ? const Value(null) : Value(receiptImagePath),
        transactionDate: Value(transactionDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Menghapus transaksi secara permanen beserta berkas foto nota fisiknya.
  ///
  /// Mengembalikan objek transaksi yang dihapus (untuk keperluan undo /
  /// notifikasi), atau null jika transaksi tidak ditemukan.
  Future<Transaction?> deleteTransaction(String transactionId) async {
    final tx = await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(transactionId)))
        .getSingleOrNull();
    if (tx == null) return null;

    await (_db.delete(_db.transactions)..where((t) => t.id.equals(transactionId))).go();

    // Bersihkan berkas foto nota yang tidak lagi dirujuk.
    if (tx.receiptImagePath != null && tx.receiptImagePath!.isNotEmpty) {
      await ReceiptStorageService.delete(tx.receiptImagePath!);
    }

    return tx;
  }

  /// Mengambil satu transaksi lengkap dengan relasi kategori dan tahun ajaran.
  Future<TransactionWithCategory?> getTransactionById(String transactionId) async {
    final query = (_db.select(_db.transactions)
          ..where((t) => t.id.equals(transactionId)))
        .join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(_db.academicYears, _db.academicYears.id.equalsExp(_db.transactions.academicYearId)),
    ]);

    final rows = await query.get();
    if (rows.isEmpty) return null;
    return TransactionWithCategory(
      transaction: rows.first.readTable(_db.transactions),
      category: rows.first.readTable(_db.categories),
      academicYear: rows.first.readTable(_db.academicYears),
    );
  }

  Future<List<Category>> getCategoriesByType(String type) {
    return (_db.select(_db.categories)
          ..where((t) => t.type.equals(type))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();
  }

  Stream<List<Category>> watchCategoriesByType(String type) {
    return (_db.select(_db.categories)
          ..where((t) => t.type.equals(type))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<Category> createCategory({
    required String name,
    required String type,
    String iconName = 'category_rounded',
    String colorHex = '#16A34A',
  }) async {
    const uuid = Uuid();
    final now = DateTime.now();
    final companion = CategoriesCompanion.insert(
      id: uuid.v4(),
      type: type,
      name: name.trim(),
      iconName: iconName,
      colorHex: colorHex,
      isDefault: const Value(false),
      createdAt: now,
    );
    return await _db.into(_db.categories).insertReturning(companion);
  }

  Future<void> updateCategoryName({
    required String id,
    required String newName,
  }) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(newName.trim()),
      ),
    );
  }

  Future<void> deleteCategory({required String id, String? type}) async {
    final cat = await (_db.select(_db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();
    if (cat == null) return;
    final catType = cat.type;

    final allOfType = await (_db.select(_db.categories)..where((c) => c.type.equals(catType))).get();
    if (allOfType.length <= 1) {
      throw StateError('Minimal harus ada 1 kategori yang dipertahankan.');
    }

    final fallback = allOfType.firstWhere((c) => c.id != id);

    await _db.transaction(() async {
      await (_db.update(_db.transactions)..where((t) => t.categoryId.equals(id))).write(
        TransactionsCompanion(
          categoryId: Value(fallback.id),
        ),
      );

      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    });
  }
}
