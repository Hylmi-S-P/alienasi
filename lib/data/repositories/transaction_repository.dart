import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

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
          ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)])
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

    return (_db.select(_db.transactions)..where((t) => t.academicYearId.equals(academicYearId)))
        .watch()
        .map((allTransactions) {
      var totalBalance = 0;
      var monthlyIncome = 0;
      var monthlyExpense = 0;

      for (final tx in allTransactions) {
        if (tx.type == 'income') {
          totalBalance += tx.amount;
        } else {
          totalBalance -= tx.amount;
        }

        final isThisMonth = tx.transactionDate.isAfter(firstDayOfMonth.subtract(const Duration(seconds: 1))) &&
            tx.transactionDate.isBefore(lastDayOfMonth.add(const Duration(seconds: 1)));

        if (isThisMonth) {
          if (tx.type == 'income') {
            monthlyIncome += tx.amount;
          } else {
            monthlyExpense += tx.amount;
          }
        }
      }

      return BalanceStats(
        totalBalance: totalBalance,
        monthlyIncome: monthlyIncome,
        monthlyExpense: monthlyExpense,
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
