import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('TransactionRepository - createdAt Sort & Unrestricted General Cash (F5, F13)', () {
    late AppDatabase db;
    late TransactionRepository repo;
    late String academicYearId;
    late String incomeCategoryId;
    late String expenseCategoryId;

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      repo = TransactionRepository(db);

      // Trigger beforeOpen to create indexes and tables
      await db.customSelect('SELECT 1').get();

      academicYearId = 'year_2026_test';
      await db.into(db.academicYears).insert(
            AcademicYearsCompanion.insert(
              id: academicYearId,
              name: 'Kelas 7A 2026/2027',
              grade: 7,
              startDate: DateTime(2026, 7, 1),
              endDate: DateTime(2027, 6, 30),
              duesPeriodType: const Value('daily'),
              createdAt: DateTime.now(),
            ),
          );

      incomeCategoryId = 'cat_inc_1';
      expenseCategoryId = 'cat_exp_1';
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: incomeCategoryId,
              type: 'income',
              name: 'Uang Kas Rutin',
              iconName: 'payments',
              colorHex: '#16A34A',
              createdAt: DateTime.now(),
            ),
          );
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: expenseCategoryId,
              type: 'expense',
              name: 'Alat Tulis & Spidol',
              iconName: 'edit_note',
              colorHex: '#DC2626',
              createdAt: DateTime.now(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('Composite index idx_transactions_year_created_at exists in SQLite schema', () async {
      final indexRows = await db.customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'index' AND name = 'idx_transactions_year_created_at';",
      ).get();

      expect(indexRows.isNotEmpty, true, reason: 'Index idx_transactions_year_created_at must be registered');
      final sql = indexRows.first.read<String>('sql').toLowerCase();
      expect(sql.contains('academic_year_id'), true);
      expect(sql.contains('created_at'), true);
    });

    test('watchRecentTransactions sorts strictly by createdAt DESC (backdated transaction appears first)', () async {
      // 1. Transaksi lama: dicatat kemarin (createdAt: 2026-09-19), dengan tanggal transaksi kemarin (2026-09-19)
      final txOlderInput = TransactionsCompanion.insert(
        id: 'tx_old_input',
        academicYearId: academicYearId,
        categoryId: incomeCategoryId,
        type: 'income',
        amount: 50000,
        title: 'Pemasukan September',
        transactionDate: DateTime(2026, 9, 19, 10, 0),
        createdAt: DateTime(2026, 9, 19, 10, 0),
        updatedAt: DateTime(2026, 9, 19, 10, 0),
      );
      await db.into(db.transactions).insert(txOlderInput);

      // 2. Transaksi mundur (backdated): tanggal transaksi di masa lalu (Juli 2026),
      // tapi waktu pencatatan baru saja dilakukan bendahara hari ini (createdAt: 2026-09-20 14:00)
      final txBackdatedRecentInput = TransactionsCompanion.insert(
        id: 'tx_backdated',
        academicYearId: academicYearId,
        categoryId: incomeCategoryId,
        type: 'income',
        amount: 25000,
        title: 'Kas Kelas Mundur (Harian 14 Juli 2026)',
        transactionDate: DateTime(2026, 7, 14, 8, 0),
        createdAt: DateTime(2026, 9, 20, 14, 0),
        updatedAt: DateTime(2026, 9, 20, 14, 0),
      );
      await db.into(db.transactions).insert(txBackdatedRecentInput);

      // Ambil stream recent transactions
      final recent = await repo.watchRecentTransactions(academicYearId: academicYearId, limit: 5).first;

      expect(recent.length, 2);
      // Item pertama harus tx_backdated karena createdAt lebih baru, meskipun transactionDate lebih lampau!
      expect(recent[0].transaction.id, 'tx_backdated');
      expect(recent[0].transaction.title, 'Kas Kelas Mundur (Harian 14 Juli 2026)');
      expect(recent[1].transaction.id, 'tx_old_input');
    });

    test('watchRecentTransactions obeys the limit parameter', () async {
      for (int i = 1; i <= 7; i++) {
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                id: 'tx_$i',
                academicYearId: academicYearId,
                categoryId: incomeCategoryId,
                type: 'income',
                amount: i * 1000,
                title: 'Transaksi $i',
                transactionDate: DateTime(2026, 9, i),
                createdAt: DateTime(2026, 9, 20, 10, i),
                updatedAt: DateTime(2026, 9, 20, 10, i),
              ),
            );
      }

      final recent = await repo.watchRecentTransactions(academicYearId: academicYearId, limit: 5).first;
      expect(recent.length, 5);
      // Yang pertama harus tx_7 (createdAt paling baru)
      expect(recent[0].transaction.id, 'tx_7');
      expect(recent[4].transaction.id, 'tx_3');
    });

    test('watchAllTransactions and getAllTransactions return all items ordered by transactionDate DESC, then createdAt DESC', () async {
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx_july',
              academicYearId: academicYearId,
              categoryId: incomeCategoryId,
              type: 'income',
              amount: 10000,
              title: 'Transaksi Juli',
              transactionDate: DateTime(2026, 7, 15),
              createdAt: DateTime(2026, 9, 20, 12, 0),
              updatedAt: DateTime(2026, 9, 20, 12, 0),
            ),
          );

      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx_august',
              academicYearId: academicYearId,
              categoryId: incomeCategoryId,
              type: 'income',
              amount: 20000,
              title: 'Transaksi Agustus',
              transactionDate: DateTime(2026, 8, 20),
              createdAt: DateTime(2026, 9, 10, 12, 0),
              updatedAt: DateTime(2026, 9, 10, 12, 0),
            ),
          );

      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx_september',
              academicYearId: academicYearId,
              categoryId: expenseCategoryId,
              type: 'expense',
              amount: 5000,
              title: 'Transaksi September',
              transactionDate: DateTime(2026, 9, 18),
              createdAt: DateTime(2026, 9, 18, 12, 0),
              updatedAt: DateTime(2026, 9, 18, 12, 0),
            ),
          );

      final streamItems = await repo.watchAllTransactions(academicYearId: academicYearId).first;
      expect(streamItems.length, 3);
      expect(streamItems[0].transaction.id, 'tx_september');
      expect(streamItems[1].transaction.id, 'tx_august');
      expect(streamItems[2].transaction.id, 'tx_july');

      final futureItems = await repo.getAllTransactions(academicYearId: academicYearId);
      expect(futureItems.length, 3);
      expect(futureItems[0].transaction.id, 'tx_september');
    });

    test('F13: General class cash transactions can be freely logged on weekends without restriction', () async {
      // Sabtu 19 September 2026: Pemasukan dari bazar sekolah
      final saturday = DateTime(2026, 9, 19, 11, 30);
      expect(saturday.weekday, DateTime.saturday);

      await repo.insertTransaction(
        academicYearId: academicYearId,
        categoryId: incomeCategoryId,
        type: 'income',
        amount: 150000,
        title: 'Hasil Penjualan Bazar Sabtu',
        description: 'Bazar kewirausahaan kelas',
        transactionDate: saturday,
      );

      // Minggu 20 September 2026: Pengeluaran konsumsi lomba di akhir pekan
      final sunday = DateTime(2026, 9, 20, 16, 0);
      expect(sunday.weekday, DateTime.sunday);

      await repo.insertTransaction(
        academicYearId: academicYearId,
        categoryId: expenseCategoryId,
        type: 'expense',
        amount: 60000,
        title: 'Konsumsi Lomba Paduan Suara Hari Minggu',
        description: 'Snack dan air mineral',
        transactionDate: sunday,
      );

      final allTxs = await repo.getAllTransactions(academicYearId: academicYearId);
      expect(allTxs.length, 2);

      // Saldo kas kelas terhitung secara penuh 150.000 - 60.000 = 90.000
      final stats = await repo.watchBalanceStats(academicYearId).first;
      expect(stats.totalBalance, 90000);
    });
  });
}
