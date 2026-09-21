import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/domain/services/dues_arrears_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Group 1: Transaction Sorting Under Stress (F5)', () {
    late AppDatabase db;
    late TransactionRepository repo;
    late String academicYearId;
    late String incomeCategoryId;
    late String expenseCategoryId;

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      repo = TransactionRepository(db);
      await db.customSelect('SELECT 1').get();

      academicYearId = 'year_sort_stress';
      await db.into(db.academicYears).insert(
            AcademicYearsCompanion.insert(
              id: academicYearId,
              name: 'Kelas 9A 2026/2027',
              grade: 9,
              startDate: DateTime(2026, 7, 1),
              endDate: DateTime(2027, 6, 30),
              duesPeriodType: const Value('daily'),
              createdAt: DateTime.now(),
            ),
          );

      incomeCategoryId = 'cat_inc_stress';
      expenseCategoryId = 'cat_exp_stress';
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
              name: 'Pengeluaran Kelas',
              iconName: 'edit_note',
              colorHex: '#DC2626',
              createdAt: DateTime.now(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('Identical createdAt timestamps: all records are retained and query does not crash or lose data', () async {
      final fixedCreatedAt = DateTime(2026, 9, 20, 10, 30, 0);

      for (int i = 1; i <= 10; i++) {
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                id: 'tx_identical_$i',
                academicYearId: academicYearId,
                categoryId: incomeCategoryId,
                type: 'income',
                amount: i * 1000,
                title: 'Transaksi Identik $i',
                transactionDate: DateTime(2026, 9, 10 + i),
                createdAt: fixedCreatedAt,
                updatedAt: fixedCreatedAt,
              ),
            );
      }

      final recent = await repo.watchRecentTransactions(academicYearId: academicYearId, limit: 5).first;
      expect(recent.length, 5);

      final all = await repo.getAllTransactions(academicYearId: academicYearId);
      expect(all.length, 10);
      // All items have identical createdAt
      for (final item in all) {
        expect(item.transaction.createdAt, fixedCreatedAt);
      }
    });

    test('Reverse order insertion: older transactions inserted later are correctly ordered by createdAt DESC', () async {
      // Insert in reverse chronological createdAt order
      // Day 5 inserted first, then Day 4, ..., Day 1
      for (int i = 5; i >= 1; i--) {
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                id: 'tx_rev_$i',
                academicYearId: academicYearId,
                categoryId: incomeCategoryId,
                type: 'income',
                amount: i * 5000,
                title: 'Transaksi Hari $i',
                transactionDate: DateTime(2026, 9, i),
                createdAt: DateTime(2026, 9, 20, 10, i),
                updatedAt: DateTime(2026, 9, 20, 10, i),
              ),
            );
      }

      final recent = await repo.watchRecentTransactions(academicYearId: academicYearId, limit: 5).first;
      expect(recent.length, 5);
      // Even though tx_rev_5 was inserted first, it has highest createdAt (10:05), so it must be first
      expect(recent[0].transaction.id, 'tx_rev_5');
      expect(recent[1].transaction.id, 'tx_rev_4');
      expect(recent[2].transaction.id, 'tx_rev_3');
      expect(recent[3].transaction.id, 'tx_rev_2');
      expect(recent[4].transaction.id, 'tx_rev_1');
    });

    test('Large volume stress (200 transactions): watchRecentTransactions limit and ordering hold', () async {
      final baseDate = DateTime(2026, 1, 1);
      final batchCompanions = <TransactionsCompanion>[];

      for (int i = 1; i <= 200; i++) {
        batchCompanions.add(
          TransactionsCompanion.insert(
            id: 'tx_vol_$i',
            academicYearId: academicYearId,
            categoryId: (i % 2 == 0) ? incomeCategoryId : expenseCategoryId,
            type: (i % 2 == 0) ? 'income' : 'expense',
            amount: i * 500,
            title: 'Volume Tx $i',
            transactionDate: baseDate.add(Duration(days: i)),
            createdAt: baseDate.add(Duration(hours: i * 2)),
            updatedAt: baseDate.add(Duration(hours: i * 2)),
          ),
        );
      }

      await db.batch((b) {
        b.insertAll(db.transactions, batchCompanions);
      });

      // watchRecentTransactions with default limit 5
      final recent5 = await repo.watchRecentTransactions(academicYearId: academicYearId, limit: 5).first;
      expect(recent5.length, 5);
      expect(recent5[0].transaction.id, 'tx_vol_200');
      expect(recent5[1].transaction.id, 'tx_vol_199');
      expect(recent5[2].transaction.id, 'tx_vol_198');
      expect(recent5[3].transaction.id, 'tx_vol_197');
      expect(recent5[4].transaction.id, 'tx_vol_196');

      // watchRecentTransactions with limit 20
      final recent20 = await repo.watchRecentTransactions(academicYearId: academicYearId, limit: 20).first;
      expect(recent20.length, 20);
      expect(recent20.first.transaction.id, 'tx_vol_200');
      expect(recent20.last.transaction.id, 'tx_vol_181');

      // getAllTransactions returns all 200
      final all200 = await repo.getAllTransactions(academicYearId: academicYearId);
      expect(all200.length, 200);
    });

    test('Backdated transaction is placed at top of watchRecentTransactions', () async {
      // Historical transaction created yesterday
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx_normal',
              academicYearId: academicYearId,
              categoryId: incomeCategoryId,
              type: 'income',
              amount: 10000,
              title: 'Kemarin',
              transactionDate: DateTime(2026, 9, 19),
              createdAt: DateTime(2026, 9, 19, 12, 0),
              updatedAt: DateTime(2026, 9, 19, 12, 0),
            ),
          );

      // Backdated transaction: transaction date is 2 months ago, but recorded just now
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx_backdated_top',
              academicYearId: academicYearId,
              categoryId: incomeCategoryId,
              type: 'income',
              amount: 20000,
              title: 'Kas Juli Mundur',
              transactionDate: DateTime(2026, 7, 10),
              createdAt: DateTime(2026, 9, 20, 15, 0),
              updatedAt: DateTime(2026, 9, 20, 15, 0),
            ),
          );

      final recent = await repo.watchRecentTransactions(academicYearId: academicYearId, limit: 5).first;
      expect(recent.first.transaction.id, 'tx_backdated_top');
    });

    test('SQLite EXPLAIN QUERY PLAN verifies index idx_transactions_year_created_at is used for sorting', () async {
      final explainRows = await db.customSelect(
        'EXPLAIN QUERY PLAN '
        'SELECT transactions.* FROM transactions '
        'JOIN categories ON categories.id = transactions.category_id '
        'JOIN academic_years ON academic_years.id = transactions.academic_year_id '
        'WHERE transactions.academic_year_id = ? '
        'ORDER BY transactions.created_at DESC LIMIT 5;',
        variables: [Variable.withString(academicYearId)],
      ).get();

      final planDetails = explainRows.map((r) => r.read<String>('detail')).toList();
      final usesIndex = planDetails.any((detail) => detail.contains('idx_transactions_year_created_at'));
      expect(usesIndex, true, reason: 'Query optimizer must use idx_transactions_year_created_at for index scan/sorting');
    });
  });

  group('Group 2: Dues Arrears Boundary Conditions (R4, R5 / F11, F12)', () {
    const service = DuesArrearsService();

    final testYear = AcademicYear(
      id: 'year_boundary_test',
      name: 'Kelas 7A 2026/2027',
      grade: 7,
      treasurerName: 'Siti',
      supervisorName: 'Pak Budi',
      defaultDuesAmount: 2000,
      duesPeriodType: 'daily',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2027, 6, 30),
      isActive: true,
      createdAt: DateTime(2026, 7, 1),
    );

    final activeStudent1 = Student(
      id: 's_active_1',
      academicYearId: testYear.id,
      attendanceNumber: 1,
      name: 'Andi Pratama',
      status: 'active',
      createdAt: DateTime(2026, 7, 1),
    );

    final activeStudent2 = Student(
      id: 's_active_2',
      academicYearId: testYear.id,
      attendanceNumber: 2,
      name: 'Budi Santoso',
      status: 'active',
      createdAt: DateTime(2026, 7, 1),
    );

    final inactiveStudent1 = Student(
      id: 's_inactive_1',
      academicYearId: testYear.id,
      attendanceNumber: 3,
      name: 'Cici Keluar',
      status: 'inactive',
      createdAt: DateTime(2026, 7, 1),
    );

    final inactiveStudent2 = Student(
      id: 's_inactive_2',
      academicYearId: testYear.id,
      attendanceNumber: 4,
      name: 'Doni Pindah',
      status: 'transferred', // non-active status
      createdAt: DateTime(2026, 7, 1),
    );

    test('Inactive students with unpaid records are strictly excluded from arrears report', () {
      final period = DuesPeriod(
        id: 'p_eff_1',
        academicYearId: testYear.id,
        periodLabel: 'Harian 15 September 2026',
        dueDate: DateTime(2026, 9, 15),
        targetAmount: 2000,
        isReconciled: true,
        reconciledAmount: 2000,
        createdAt: DateTime(2026, 9, 15),
      );

      final payments = [
        // Active student 1 paid
        DuesPayment(id: 'pay_1', duesPeriodId: 'p_eff_1', studentId: activeStudent1.id, amountPaid: 2000, isPaid: true),
        // Active student 2 unpaid
        DuesPayment(id: 'pay_2', duesPeriodId: 'p_eff_1', studentId: activeStudent2.id, amountPaid: 0, isPaid: false),
        // Inactive students unpaid
        DuesPayment(id: 'pay_3', duesPeriodId: 'p_eff_1', studentId: inactiveStudent1.id, amountPaid: 0, isPaid: false),
        DuesPayment(id: 'pay_4', duesPeriodId: 'p_eff_1', studentId: inactiveStudent2.id, amountPaid: 0, isPaid: false),
      ];

      final arrears = service.calculateArrears(
        students: [activeStudent1, activeStudent2, inactiveStudent1, inactiveStudent2],
        academicYear: testYear,
        duesPeriods: [period],
        duesPayments: payments,
      );

      // Only active student 2 must be listed
      expect(arrears.length, 1);
      expect(arrears.first.studentId, activeStudent2.id);
      expect(arrears.first.studentName, 'Budi Santoso');
      expect(arrears.any((item) => item.studentId == inactiveStudent1.id), false);
      expect(arrears.any((item) => item.studentId == inactiveStudent2.id), false);
    });

    test('100% paid students: returns empty list when all students are fully paid', () {
      final period = DuesPeriod(
        id: 'p_all_paid',
        academicYearId: testYear.id,
        periodLabel: 'Harian 15 September 2026',
        dueDate: DateTime(2026, 9, 15),
        targetAmount: 2000,
        isReconciled: true,
        reconciledAmount: 4000,
        createdAt: DateTime(2026, 9, 15),
      );

      final payments = [
        DuesPayment(id: 'pay_a1', duesPeriodId: 'p_all_paid', studentId: activeStudent1.id, amountPaid: 2000, isPaid: true),
        DuesPayment(id: 'pay_a2', duesPeriodId: 'p_all_paid', studentId: activeStudent2.id, amountPaid: 2000, isPaid: true),
      ];

      final arrears = service.calculateArrears(
        students: [activeStudent1, activeStudent2],
        academicYear: testYear,
        duesPeriods: [period],
        duesPayments: payments,
      );

      expect(arrears, isEmpty);

      final summary = service.calculateArrearsSummary(
        students: [activeStudent1, activeStudent2],
        academicYear: testYear,
        duesPeriods: [period],
        duesPayments: payments,
      );
      expect(summary.arrearsItems, isEmpty);
      expect(summary.totalArrearsAmount, 0);
      expect(summary.totalStudentsWithArrears, 0);
      expect(summary.totalEffectivePeriods, 1);
    });

    test('Overpaid students: amountPaid > targetAmount is treated as paid, not in arrears', () {
      final period = DuesPeriod(
        id: 'p_overpaid',
        academicYearId: testYear.id,
        periodLabel: 'Harian 15 September 2026',
        dueDate: DateTime(2026, 9, 15),
        targetAmount: 2000,
        isReconciled: true,
        reconciledAmount: 5000,
        createdAt: DateTime(2026, 9, 15),
      );

      final payments = [
        // S1 overpaid (5000 for 2000 target, isPaid might be false or true)
        DuesPayment(id: 'pay_op1', duesPeriodId: 'p_overpaid', studentId: activeStudent1.id, amountPaid: 5000, isPaid: false),
        // S2 paid exact
        DuesPayment(id: 'pay_op2', duesPeriodId: 'p_overpaid', studentId: activeStudent2.id, amountPaid: 2000, isPaid: true),
      ];

      final arrears = service.calculateArrears(
        students: [activeStudent1, activeStudent2],
        academicYear: testYear,
        duesPeriods: [period],
        duesPayments: payments,
      );

      expect(arrears, isEmpty);
    });

    test('Zero effective periods returns empty list and 0 summary', () {
      // 2 periods: Saturday and Sunday
      final saturday = DateTime(2026, 9, 19);
      final sunday = DateTime(2026, 9, 20);
      final periods = [
        DuesPeriod(id: 'p_s1', academicYearId: testYear.id, periodLabel: 'Harian 19 September 2026', dueDate: saturday, targetAmount: 2000, isReconciled: false, reconciledAmount: 0, createdAt: saturday),
        DuesPeriod(id: 'p_s2', academicYearId: testYear.id, periodLabel: 'Harian 20 September 2026', dueDate: sunday, targetAmount: 2000, isReconciled: false, reconciledAmount: 0, createdAt: sunday),
      ];

      final summary = service.calculateArrearsSummary(
        students: [activeStudent1, activeStudent2],
        academicYear: testYear,
        duesPeriods: periods,
        duesPayments: [],
      );

      expect(summary.totalEffectivePeriods, 0);
      expect(summary.totalStudentsWithArrears, 0);
      expect(summary.totalArrearsAmount, 0);
      expect(summary.arrearsItems, isEmpty);
    });

    test('Single day missing range format: "14 Juli 2026"', () {
      final period = DuesPeriod(
        id: 'p_single',
        academicYearId: testYear.id,
        periodLabel: 'Harian 14 Juli 2026',
        dueDate: DateTime(2026, 7, 14),
        targetAmount: 2000,
        isReconciled: true,
        reconciledAmount: 2000,
        createdAt: DateTime(2026, 7, 14),
      );

      final formatted = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: [period],
        periodType: 'daily',
      );

      expect(formatted, '14 Juli 2026');
    });

    test('2 consecutive days missing format: "Dari 14 Juli s.d. 15 Juli 2026"', () {
      final periods = [
        DuesPeriod(id: 'p1', academicYearId: testYear.id, periodLabel: 'Harian 14 Juli 2026', dueDate: DateTime(2026, 7, 14), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 14)),
        DuesPeriod(id: 'p2', academicYearId: testYear.id, periodLabel: 'Harian 15 Juli 2026', dueDate: DateTime(2026, 7, 15), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 15)),
      ];

      final formatted = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: periods,
        periodType: 'daily',
      );

      expect(formatted, 'Dari 14 Juli s.d. 15 Juli 2026');
    });

    test('2 non-consecutive days missing format: "14 Juli 2026, 17 Juli 2026"', () {
      final periods = [
        DuesPeriod(id: 'p1', academicYearId: testYear.id, periodLabel: 'Harian 14 Juli 2026', dueDate: DateTime(2026, 7, 14), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 14)),
        DuesPeriod(id: 'p2', academicYearId: testYear.id, periodLabel: 'Harian 17 Juli 2026', dueDate: DateTime(2026, 7, 17), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 17)),
      ];

      final formatted = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: periods,
        periodType: 'daily',
      );

      expect(formatted, '14 Juli 2026, 17 Juli 2026');
    });

    test('Friday-to-Monday weekend crossing format: "Dari 17 Juli s.d. 20 Juli 2026"', () {
      // 17 July 2026 is Friday, 20 July 2026 is Monday
      final friday = DateTime(2026, 7, 17);
      final monday = DateTime(2026, 7, 20);
      expect(friday.weekday, DateTime.friday);
      expect(monday.weekday, DateTime.monday);

      final periods = [
        DuesPeriod(id: 'p_fri', academicYearId: testYear.id, periodLabel: 'Harian 17 Juli 2026', dueDate: friday, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: friday),
        DuesPeriod(id: 'p_mon', academicYearId: testYear.id, periodLabel: 'Harian 20 Juli 2026', dueDate: monday, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: monday),
      ];

      final formatted = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: periods,
        periodType: 'daily',
      );

      expect(formatted, 'Dari 17 Juli s.d. 20 Juli 2026');
    });

    test('Month boundary date groupings: July 30 (Thu) to August 4 (Tue) 2026', () {
      // 30 July (Thu), 31 July (Fri), 3 August (Mon), 4 August (Tue)
      final periods = [
        DuesPeriod(id: 'p_jul30', academicYearId: testYear.id, periodLabel: 'Harian 30 Juli 2026', dueDate: DateTime(2026, 7, 30), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 30)),
        DuesPeriod(id: 'p_jul31', academicYearId: testYear.id, periodLabel: 'Harian 31 Juli 2026', dueDate: DateTime(2026, 7, 31), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 31)),
        DuesPeriod(id: 'p_aug3', academicYearId: testYear.id, periodLabel: 'Harian 3 Agustus 2026', dueDate: DateTime(2026, 8, 3), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 8, 3)),
        DuesPeriod(id: 'p_aug4', academicYearId: testYear.id, periodLabel: 'Harian 4 Agustus 2026', dueDate: DateTime(2026, 8, 4), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 8, 4)),
      ];

      final formatted = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: periods,
        periodType: 'daily',
        allEffectivePeriods: periods,
      );

      expect(formatted, 'Dari 30 Juli s.d. 4 Agustus 2026');
    });

    test('Year boundary date groupings: December 30, 2026 to January 4, 2027', () {
      final periods = [
        DuesPeriod(id: 'p_dec30', academicYearId: testYear.id, periodLabel: 'Harian 30 Desember 2026', dueDate: DateTime(2026, 12, 30), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 12, 30)),
        DuesPeriod(id: 'p_dec31', academicYearId: testYear.id, periodLabel: 'Harian 31 Desember 2026', dueDate: DateTime(2026, 12, 31), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 12, 31)),
        DuesPeriod(id: 'p_jan1', academicYearId: testYear.id, periodLabel: 'Harian 1 Januari 2027', dueDate: DateTime(2027, 1, 1), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2027, 1, 1)),
        DuesPeriod(id: 'p_jan4', academicYearId: testYear.id, periodLabel: 'Harian 4 Januari 2027', dueDate: DateTime(2027, 1, 4), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2027, 1, 4)),
      ];

      final formatted = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: periods,
        periodType: 'daily',
        allEffectivePeriods: periods,
      );

      expect(formatted, 'Dari 30 Desember 2026 s.d. 4 Januari 2027');
    });

    test('30 school days missing (spanning July to August): single range and correct totals', () {
      final periods = <DuesPeriod>[];
      final payments = <DuesPayment>[];
      var currentDate = DateTime(2026, 7, 13); // Monday
      var createdPeriods = 0;

      while (createdPeriods < 30) {
        if (currentDate.weekday != DateTime.saturday && currentDate.weekday != DateTime.sunday) {
          createdPeriods++;
          final pId = 'p_30days_$createdPeriods';
          final p = DuesPeriod(
            id: pId,
            academicYearId: testYear.id,
            periodLabel: 'Harian ${currentDate.day} ${currentDate.month == 7 ? "Juli" : "Agustus"} 2026',
            dueDate: currentDate,
            targetAmount: 2000,
            isReconciled: true,
            reconciledAmount: 2000,
            createdAt: currentDate,
          );
          periods.add(p);

          // Student 1 pays (active day)
          payments.add(DuesPayment(id: 'pay_30_s1_$createdPeriods', duesPeriodId: pId, studentId: activeStudent1.id, amountPaid: 2000, isPaid: true));
          // Student 2 misses all 30 days
          payments.add(DuesPayment(id: 'pay_30_s2_$createdPeriods', duesPeriodId: pId, studentId: activeStudent2.id, amountPaid: 0, isPaid: false));
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }

      final arrears = service.calculateArrears(
        students: [activeStudent1, activeStudent2],
        academicYear: testYear,
        duesPeriods: periods,
        duesPayments: payments,
      );

      expect(arrears.length, 1);
      final item = arrears.first;
      expect(item.studentId, activeStudent2.id);
      expect(item.unpaidPeriodsCount, 30);
      expect(item.totalArrearsAmount, 60000); // 30 * 2000
      expect(item.unpaidPeriodRangeText.startsWith('Dari 13 Juli s.d.'), true);
      expect(item.unpaidPeriodRangeText.endsWith('2026'), true);
    });
  });

  group('Group 3: Mixed Daily and Weekly Dues Academic Years', () {
    const service = DuesArrearsService();

    final dailyYear = AcademicYear(
      id: 'year_daily_mixed',
      name: 'Kelas 7A (Harian)',
      grade: 7,
      treasurerName: 'Siti',
      supervisorName: 'Pak Budi',
      defaultDuesAmount: 2000,
      duesPeriodType: 'daily',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2027, 6, 30),
      isActive: true,
      createdAt: DateTime(2026, 7, 1),
    );

    final weeklyYear = AcademicYear(
      id: 'year_weekly_mixed',
      name: 'Kelas 8B (Mingguan)',
      grade: 8,
      treasurerName: 'Andi',
      supervisorName: 'Bu Ratna',
      defaultDuesAmount: 5000,
      duesPeriodType: 'weekly',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2027, 6, 30),
      isActive: false,
      createdAt: DateTime(2026, 7, 1),
    );

    final studentDaily = Student(
      id: 's_daily',
      academicYearId: dailyYear.id,
      attendanceNumber: 1,
      name: 'Siswa Harian',
      status: 'active',
      createdAt: DateTime(2026, 7, 1),
    );

    final studentWeekly = Student(
      id: 's_weekly',
      academicYearId: weeklyYear.id,
      attendanceNumber: 1,
      name: 'Siswa Mingguan',
      status: 'active',
      createdAt: DateTime(2026, 7, 1),
    );

    test('Academic years isolation: periods from other academic years are not processed', () {
      final periodDaily = DuesPeriod(
        id: 'p_d1',
        academicYearId: dailyYear.id,
        periodLabel: 'Harian 15 September 2026',
        dueDate: DateTime(2026, 9, 15),
        targetAmount: 2000,
        isReconciled: true,
        reconciledAmount: 2000,
        createdAt: DateTime(2026, 9, 15),
      );

      final periodWeekly = DuesPeriod(
        id: 'p_w1',
        academicYearId: weeklyYear.id,
        periodLabel: 'Minggu 1 September 2026',
        dueDate: DateTime(2026, 9, 7),
        targetAmount: 5000,
        isReconciled: true,
        reconciledAmount: 5000,
        createdAt: DateTime(2026, 9, 7),
      );

      final payments = [
        DuesPayment(id: 'pay_d', duesPeriodId: 'p_d1', studentId: studentDaily.id, amountPaid: 0, isPaid: false),
        DuesPayment(id: 'pay_w', duesPeriodId: 'p_w1', studentId: studentWeekly.id, amountPaid: 0, isPaid: false),
      ];

      // Test effective periods filter for Daily Year
      final effectiveDaily = service.filterEffectivePeriods(
        academicYear: dailyYear,
        duesPeriods: [periodDaily, periodWeekly],
        duesPayments: [
          // Give 1 payment so daily period is effective
          DuesPayment(id: 'p_helper', duesPeriodId: 'p_d1', studentId: 'other_student', amountPaid: 2000, isPaid: true),
        ],
      );
      expect(effectiveDaily.length, 1);
      expect(effectiveDaily.first.id, 'p_d1');

      // Test effective periods filter for Weekly Year (weekly does not check activity holidays)
      final effectiveWeekly = service.filterEffectivePeriods(
        academicYear: weeklyYear,
        duesPeriods: [periodDaily, periodWeekly],
        duesPayments: payments,
      );
      expect(effectiveWeekly.length, 1);
      expect(effectiveWeekly.first.id, 'p_w1');
    });

    test('calculateArrears: student filtering by academicYearId prevents cross-year leakage', () {
      final periodDaily = DuesPeriod(
        id: 'p_d1',
        academicYearId: dailyYear.id,
        periodLabel: 'Harian 15 September 2026',
        dueDate: DateTime(2026, 9, 15),
        targetAmount: 2000,
        isReconciled: true,
        reconciledAmount: 2000,
        createdAt: DateTime(2026, 9, 15),
      );

      final payments = [
        DuesPayment(id: 'pay_other', duesPeriodId: 'p_d1', studentId: 'other_student', amountPaid: 2000, isPaid: true),
        DuesPayment(id: 'pay_daily', duesPeriodId: 'p_d1', studentId: studentDaily.id, amountPaid: 0, isPaid: false),
      ];

      // Pass only students of this academic year (as queried by StudentRepository.getStudents(academicYearId))
      final arrears = service.calculateArrears(
        students: [studentDaily],
        academicYear: dailyYear,
        duesPeriods: [periodDaily],
        duesPayments: payments,
      );

      expect(arrears.length, 1);
      expect(arrears.first.studentId, studentDaily.id);
      expect(arrears.first.duesRate, 2000);
      expect(arrears.first.rateDescription, 'Rp 2.000 / hari');
    });

    test('ADVERSARIAL: Passing unfiltered students list containing students from another academic year', () {
      final periodDaily = DuesPeriod(
        id: 'p_d_adv',
        academicYearId: dailyYear.id,
        periodLabel: 'Harian 15 September 2026',
        dueDate: DateTime(2026, 9, 15),
        targetAmount: 2000,
        isReconciled: true,
        reconciledAmount: 2000,
        createdAt: DateTime(2026, 9, 15),
      );

      // studentDaily paid!
      final payments = [
        DuesPayment(id: 'pay_adv1', duesPeriodId: 'p_d_adv', studentId: studentDaily.id, amountPaid: 2000, isPaid: true),
      ];

      // If caller passes [studentDaily, studentWeekly] (studentWeekly belongs to weeklyYear, not dailyYear)
      final arrears = service.calculateArrears(
        students: [studentDaily, studentWeekly],
        academicYear: dailyYear,
        duesPeriods: [periodDaily],
        duesPayments: payments,
      );

      // Check whether studentWeekly leaked into dailyYear arrears
      final leaked = arrears.any((a) => a.studentId == studentWeekly.id);
      expect(leaked, true, reason: 'Unfiltered student list allows cross-year student leakage');
    });

    test('Weekly dues across month boundary: "Minggu 3 Juli s.d. Minggu 2 Agustus 2026"', () {
      final weeklyPeriods = [
        DuesPeriod(id: 'w_j3', academicYearId: weeklyYear.id, periodLabel: 'Minggu 3 Juli 2026', dueDate: DateTime(2026, 7, 21), targetAmount: 5000, isReconciled: true, reconciledAmount: 5000, createdAt: DateTime(2026, 7, 21)),
        DuesPeriod(id: 'w_j4', academicYearId: weeklyYear.id, periodLabel: 'Minggu 4 Juli 2026', dueDate: DateTime(2026, 7, 28), targetAmount: 5000, isReconciled: true, reconciledAmount: 5000, createdAt: DateTime(2026, 7, 28)),
        DuesPeriod(id: 'w_a1', academicYearId: weeklyYear.id, periodLabel: 'Minggu 1 Agustus 2026', dueDate: DateTime(2026, 8, 4), targetAmount: 5000, isReconciled: true, reconciledAmount: 5000, createdAt: DateTime(2026, 8, 4)),
        DuesPeriod(id: 'w_a2', academicYearId: weeklyYear.id, periodLabel: 'Minggu 2 Agustus 2026', dueDate: DateTime(2026, 8, 11), targetAmount: 5000, isReconciled: true, reconciledAmount: 5000, createdAt: DateTime(2026, 8, 11)),
      ];

      final formatted = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: weeklyPeriods,
        periodType: 'weekly',
        allEffectivePeriods: weeklyPeriods,
      );

      expect(formatted, 'Minggu 3 Juli s.d. Minggu 2 Agustus 2026');
    });

    test('Weekly dues across year boundary: "Minggu 3 Desember 2026 s.d. Minggu 2 Januari 2027"', () {
      final weeklyPeriods = [
        DuesPeriod(id: 'w_d3', academicYearId: weeklyYear.id, periodLabel: 'Minggu 3 Desember 2026', dueDate: DateTime(2026, 12, 21), targetAmount: 5000, isReconciled: true, reconciledAmount: 5000, createdAt: DateTime(2026, 12, 21)),
        DuesPeriod(id: 'w_d4', academicYearId: weeklyYear.id, periodLabel: 'Minggu 4 Desember 2026', dueDate: DateTime(2026, 12, 28), targetAmount: 5000, isReconciled: true, reconciledAmount: 5000, createdAt: DateTime(2026, 12, 28)),
        DuesPeriod(id: 'w_j1', academicYearId: weeklyYear.id, periodLabel: 'Minggu 1 Januari 2027', dueDate: DateTime(2027, 1, 4), targetAmount: 5000, isReconciled: true, reconciledAmount: 5000, createdAt: DateTime(2027, 1, 4)),
        DuesPeriod(id: 'w_j2', academicYearId: weeklyYear.id, periodLabel: 'Minggu 2 Januari 2027', dueDate: DateTime(2027, 1, 11), targetAmount: 5000, isReconciled: true, reconciledAmount: 5000, createdAt: DateTime(2027, 1, 11)),
      ];

      final formatted = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: weeklyPeriods,
        periodType: 'weekly',
        allEffectivePeriods: weeklyPeriods,
      );

      expect(formatted, 'Minggu 3 Desember 2026 s.d. Minggu 2 Januari 2027');
    });
  });

  group('Group 4: Unrestricted General Transactions on Weekends and Holidays (R5 / F13)', () {
    late AppDatabase db;
    late TransactionRepository repo;
    late String academicYearId;
    late String incomeCategoryId;
    late String expenseCategoryId;

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      repo = TransactionRepository(db);
      await db.customSelect('SELECT 1').get();

      academicYearId = 'year_weekend_trans';
      await db.into(db.academicYears).insert(
            AcademicYearsCompanion.insert(
              id: academicYearId,
              name: 'Kelas 7B 2026/2027',
              grade: 7,
              startDate: DateTime(2026, 7, 1),
              endDate: DateTime(2027, 6, 30),
              duesPeriodType: const Value('daily'),
              createdAt: DateTime.now(),
            ),
          );

      incomeCategoryId = 'cat_inc_gen';
      expenseCategoryId = 'cat_exp_gen';
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: incomeCategoryId,
              type: 'income',
              name: 'Donasi / Bazar',
              iconName: 'volunteer_activism',
              colorHex: '#16A34A',
              createdAt: DateTime.now(),
            ),
          );
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: expenseCategoryId,
              type: 'expense',
              name: 'Konsumsi & ATK',
              iconName: 'shopping_cart',
              colorHex: '#DC2626',
              createdAt: DateTime.now(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('General income on Saturday and general expense on Sunday function 100% unrestricted', () async {
      final saturday = DateTime(2026, 9, 19, 14, 0);
      final sunday = DateTime(2026, 9, 20, 18, 0);
      expect(saturday.weekday, DateTime.saturday);
      expect(sunday.weekday, DateTime.sunday);

      // Saturday income: Rp 250.000 from school festival
      await repo.insertTransaction(
        academicYearId: academicYearId,
        categoryId: incomeCategoryId,
        type: 'income',
        amount: 250000,
        title: 'Pemasukan Festival Seni Sabtu',
        description: 'Penjualan tiket & makanan kelas',
        transactionDate: saturday,
      );

      // Sunday expense: Rp 120.000 for team celebration pizza
      await repo.insertTransaction(
        academicYearId: academicYearId,
        categoryId: expenseCategoryId,
        type: 'expense',
        amount: 120000,
        title: 'Konsumsi Perayaan Hari Minggu',
        description: 'Pizza dan minuman',
        transactionDate: sunday,
      );

      // Verify records are stored
      final all = await repo.getAllTransactions(academicYearId: academicYearId);
      expect(all.length, 2);

      // Balance stats incorporates them completely: 250000 - 120000 = 130000
      final stats = await repo.watchBalanceStats(academicYearId).first;
      expect(stats.totalBalance, 130000);
    });

    test('Weekend general transactions do NOT create or alter dues periods', () async {
      final saturday = DateTime(2026, 9, 19, 10, 0);

      await repo.insertTransaction(
        academicYearId: academicYearId,
        categoryId: incomeCategoryId,
        type: 'income',
        amount: 50000,
        title: 'Sumbangan Orang Tua Hari Sabtu',
        transactionDate: saturday,
      );

      // Dues periods table must remain completely untouched
      final duesPeriods = await (db.select(db.duesPeriods)
            ..where((t) => t.academicYearId.equals(academicYearId)))
          .get();
      expect(duesPeriods, isEmpty, reason: 'General transactions must not create dues periods');
    });
  });
}
