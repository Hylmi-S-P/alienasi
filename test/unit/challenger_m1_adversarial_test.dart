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

  group('CHALLENGER STRESS SUITE: TransactionRepository Sorting (R2 / F5)', () {
    late AppDatabase db;
    late TransactionRepository repo;
    const academicYearId = 'year_stress_test';
    const academicYearIdB = 'year_stress_test_b';
    const catIncome = 'cat_inc_stress';
    const catExpense = 'cat_exp_stress';

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      repo = TransactionRepository(db);
      await db.customSelect('SELECT 1').get(); // trigger beforeOpen

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

      await db.into(db.academicYears).insert(
            AcademicYearsCompanion.insert(
              id: academicYearIdB,
              name: 'Kelas 8B 2026/2027',
              grade: 8,
              startDate: DateTime(2026, 7, 1),
              endDate: DateTime(2027, 6, 30),
              duesPeriodType: const Value('daily'),
              createdAt: DateTime.now(),
            ),
          );

      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: catIncome,
              type: 'income',
              name: 'Kas Masuk Stress',
              iconName: 'payments',
              colorHex: '#16A34A',
              createdAt: DateTime.now(),
            ),
          );
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: catExpense,
              type: 'expense',
              name: 'Kas Keluar Stress',
              iconName: 'receipt',
              colorHex: '#DC2626',
              createdAt: DateTime.now(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('1.1 Chaotic backdated dates stress test: 10 transactions with inverse chronological physical dates', () async {
      // Historical physical transaction dates in random / inverse order:
      // Even though transactionDate ranges from 2015 to 2026,
      // createdAt strictly increases from t0 to t0+9 minutes.
      final baseCreated = DateTime(2026, 9, 20, 10, 0);
      final physicalDates = [
        DateTime(2026, 9, 20), // tx_0: today
        DateTime(2024, 1, 15), // tx_1: 2 years ago
        DateTime(2018, 5, 10), // tx_2: 8 years ago
        DateTime(2025, 12, 1), // tx_3: last year
        DateTime(2020, 3, 3),  // tx_4: 6 years ago
        DateTime(2026, 1, 1),  // tx_5: earlier this year
        DateTime(2019, 8, 20), // tx_6: 7 years ago
        DateTime(2023, 7, 7),  // tx_7: 3 years ago
        DateTime(2022, 11, 11),// tx_8: 4 years ago
        DateTime(2015, 6, 1),  // tx_9: 11 years ago (oldest physical date, but newest createdAt!)
      ];

      for (int i = 0; i < 10; i++) {
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                id: 'tx_stress_$i',
                academicYearId: academicYearId,
                categoryId: catIncome,
                type: 'income',
                amount: (i + 1) * 1000,
                title: 'Stress Tx $i (Physical Date ${physicalDates[i].year})',
                transactionDate: physicalDates[i],
                createdAt: baseCreated.add(Duration(minutes: i)),
                updatedAt: baseCreated.add(Duration(minutes: i)),
              ),
            );
      }

      final recent = await repo.watchRecentTransactions(academicYearId: academicYearId, limit: 10).first;
      expect(recent.length, 10);

      // Verify strict ordering by createdAt DESC: tx_9 must be first, tx_0 must be last!
      for (int i = 0; i < 10; i++) {
        final expectedId = 'tx_stress_${9 - i}';
        expect(recent[i].transaction.id, expectedId,
            reason: 'Position $i must be $expectedId based on createdAt DESC');
      }

      // The top transaction is physically from 2015, but recorded most recently
      expect(recent.first.transaction.id, 'tx_stress_9');
      expect(recent.first.transaction.transactionDate.year, 2015);
      expect(recent.first.transaction.createdAt, baseCreated.add(const Duration(minutes: 9)));
    });

    test('1.2 Futuristic transactionDate vs newly recorded transaction: createdAt DESC prevails', () async {
      // tx_future: transaction date in 2035, but recorded yesterday
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx_futuristic',
              academicYearId: academicYearId,
              categoryId: catIncome,
              type: 'income',
              amount: 100000,
              title: 'Future Scheduled Tx',
              transactionDate: DateTime(2035, 1, 1),
              createdAt: DateTime(2026, 9, 19, 8, 0),
              updatedAt: DateTime(2026, 9, 19, 8, 0),
            ),
          );

      // tx_today: transaction date backdated to 2024, but recorded today (newest input)
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx_just_recorded',
              academicYearId: academicYearId,
              categoryId: catExpense,
              type: 'expense',
              amount: 50000,
              title: 'Backdated Expense Recorded Today',
              transactionDate: DateTime(2024, 5, 20),
              createdAt: DateTime(2026, 9, 20, 14, 0),
              updatedAt: DateTime(2026, 9, 20, 14, 0),
            ),
          );

      final recent = await repo.watchRecentTransactions(academicYearId: academicYearId, limit: 2).first;
      expect(recent.length, 2);
      expect(recent[0].transaction.id, 'tx_just_recorded',
          reason: 'Latest recording (createdAt) must appear above futuristic transactionDate');
      expect(recent[1].transaction.id, 'tx_futuristic');
    });

    test('1.3 Multi-academic-year transaction isolation under high concurrency', () async {
      // Insert interleaved transactions for Year A and Year B
      for (int i = 0; i < 6; i++) {
        final isYearA = i % 2 == 0;
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                id: 'tx_interleaved_$i',
                academicYearId: isYearA ? academicYearId : academicYearIdB,
                categoryId: catIncome,
                type: 'income',
                amount: 10000,
                title: 'Interleaved $i for ${isYearA ? "Year A" : "Year B"}',
                transactionDate: DateTime(2026, 8, i + 1),
                createdAt: DateTime(2026, 9, 20, 10, i),
                updatedAt: DateTime(2026, 9, 20, 10, i),
              ),
            );
      }

      final recentA = await repo.watchRecentTransactions(academicYearId: academicYearId, limit: 10).first;
      final recentB = await repo.watchRecentTransactions(academicYearId: academicYearIdB, limit: 10).first;

      expect(recentA.length, 3);
      expect(recentB.length, 3);

      // Year A should have tx_interleaved_4, tx_interleaved_2, tx_interleaved_0
      expect(recentA.map((e) => e.transaction.id).toList(), ['tx_interleaved_4', 'tx_interleaved_2', 'tx_interleaved_0']);
      // Year B should have tx_interleaved_5, tx_interleaved_3, tx_interleaved_1
      expect(recentB.map((e) => e.transaction.id).toList(), ['tx_interleaved_5', 'tx_interleaved_3', 'tx_interleaved_1']);
    });
  });

  group('CHALLENGER STRESS SUITE: Daily Dues Weekend Exclusions (R5 / F11)', () {
    const service = DuesArrearsService();

    final testAcademicYear = AcademicYear(
      id: 'year_weekend_stress',
      name: 'Kelas 7A Weekend Stress',
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

    final studentA = Student(
      id: 'student_weekend_a',
      academicYearId: testAcademicYear.id,
      attendanceNumber: 1,
      name: 'Aditya Pratama',
      status: 'active',
      createdAt: DateTime(2026, 7, 1),
    );

    final studentB = Student(
      id: 'student_weekend_b',
      academicYearId: testAcademicYear.id,
      attendanceNumber: 2,
      name: 'Bella Safira',
      status: 'active',
      createdAt: DateTime(2026, 7, 1),
    );

    test('2.1 Weekend with actual payments vs non-paying students: strictly 0 arrears for everyone on weekends', () {
      // Saturday 19 Sep 2026 and Sunday 20 Sep 2026
      final sat = DateTime(2026, 9, 19);
      final sun = DateTime(2026, 9, 20);
      expect(sat.weekday, DateTime.saturday);
      expect(sun.weekday, DateTime.sunday);

      final periods = [
        DuesPeriod(
          id: 'p_sat_pay',
          academicYearId: testAcademicYear.id,
          periodLabel: 'Harian 19 September 2026',
          dueDate: sat,
          targetAmount: 2000,
          isReconciled: true,
          reconciledAmount: 2000,
          createdAt: sat,
        ),
        DuesPeriod(
          id: 'p_sun_pay',
          academicYearId: testAcademicYear.id,
          periodLabel: 'Harian 20 September 2026',
          dueDate: sun,
          targetAmount: 2000,
          isReconciled: true,
          reconciledAmount: 2000,
          createdAt: sun,
        ),
      ];

      // Student A PAID both Saturday and Sunday
      // Student B DID NOT PAY either day
      final payments = [
        DuesPayment(id: 'pay_a_sat', duesPeriodId: 'p_sat_pay', studentId: studentA.id, amountPaid: 2000, isPaid: true),
        DuesPayment(id: 'pay_a_sun', duesPeriodId: 'p_sun_pay', studentId: studentA.id, amountPaid: 2000, isPaid: true),
        DuesPayment(id: 'pay_b_sat', duesPeriodId: 'p_sat_pay', studentId: studentB.id, amountPaid: 0, isPaid: false),
        DuesPayment(id: 'pay_b_sun', duesPeriodId: 'p_sun_pay', studentId: studentB.id, amountPaid: 0, isPaid: false),
      ];

      final effectivePeriods = service.filterEffectivePeriods(
        academicYear: testAcademicYear,
        duesPeriods: periods,
        duesPayments: payments,
      );
      expect(effectivePeriods, isEmpty, reason: 'Even if payments were logged on Saturday/Sunday, weekend periods are strictly non-effective for daily dues');

      final arrears = service.calculateArrears(
        students: [studentA, studentB],
        academicYear: testAcademicYear,
        duesPeriods: periods,
        duesPayments: payments,
      );
      expect(arrears, isEmpty, reason: 'Non-paying students must NEVER be penalized with arrears for Saturday or Sunday');
    });

    test('2.2 Non-standard period labels on weekends fall back to dueDate and are strictly excluded', () {
      final sat = DateTime(2026, 9, 19);
      final sun = DateTime(2026, 9, 20);

      final irregularPeriods = [
        DuesPeriod(
          id: 'p_sat_irregular',
          academicYearId: testAcademicYear.id,
          periodLabel: '19/09/2026 - Kas Tambahan', // Non-standard label without "Harian"
          dueDate: sat,
          targetAmount: 2000,
          isReconciled: false,
          reconciledAmount: 0,
          createdAt: sat,
        ),
        DuesPeriod(
          id: 'p_sun_empty',
          academicYearId: testAcademicYear.id,
          periodLabel: '', // Empty label
          dueDate: sun,
          targetAmount: 2000,
          isReconciled: false,
          reconciledAmount: 0,
          createdAt: sun,
        ),
      ];

      expect(DuesArrearsService.isWeekendPeriod(irregularPeriods[0]), true);
      expect(DuesArrearsService.isWeekendPeriod(irregularPeriods[1]), true);

      final effective = service.filterEffectivePeriods(
        academicYear: testAcademicYear,
        duesPeriods: irregularPeriods,
        duesPayments: [],
      );
      expect(effective, isEmpty);
    });
  });

  group('CHALLENGER STRESS SUITE: Activity-Driven Holiday Recognition (R5 / F12)', () {
    const service = DuesArrearsService();

    final testAcademicYear = AcademicYear(
      id: 'year_holiday_stress',
      name: 'Kelas 7A Holiday Stress',
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

    final student1 = Student(
      id: 's_hol_1',
      academicYearId: testAcademicYear.id,
      attendanceNumber: 1,
      name: 'Dimas Anggara',
      status: 'active',
      createdAt: DateTime(2026, 7, 1),
    );
    final student2 = Student(
      id: 's_hol_2',
      academicYearId: testAcademicYear.id,
      attendanceNumber: 2,
      name: 'Eka Putri',
      status: 'active',
      createdAt: DateTime(2026, 7, 1),
    );

    test('3.1 Full vacation week (Monday to Friday, 5 days, 0 collections) produces 0 arrears', () {
      // 2026-07-06 (Mon) to 2026-07-10 (Fri)
      final periods = <DuesPeriod>[];
      for (int d = 6; d <= 10; d++) {
        final date = DateTime(2026, 7, d);
        expect(date.weekday >= 1 && date.weekday <= 5, true);
        periods.add(
          DuesPeriod(
            id: 'p_vac_$d',
            academicYearId: testAcademicYear.id,
            periodLabel: 'Harian $d Juli 2026',
            dueDate: date,
            targetAmount: 2000,
            isReconciled: false,
            reconciledAmount: 0,
            createdAt: date,
          ),
        );
      }

      // Empty payments list (nobody paid anything)
      final arrears = service.calculateArrears(
        students: [student1, student2],
        academicYear: testAcademicYear,
        duesPeriods: periods,
        duesPayments: [],
      );
      expect(arrears, isEmpty, reason: 'All 5 zero-collection weekdays must be treated as activity holidays');

      final summary = service.calculateArrearsSummary(
        students: [student1, student2],
        academicYear: testAcademicYear,
        duesPeriods: periods,
        duesPayments: [],
      );
      expect(summary.totalArrearsAmount, 0);
      expect(summary.totalEffectivePeriods, 0);
      expect(summary.totalStudentsWithArrears, 0);
    });

    test('3.2 Partial payment on a weekday activates the day as effective; underpaying student also gets arrears', () {
      // Wednesday 15 July 2026
      final wed = DateTime(2026, 7, 15);
      final period = DuesPeriod(
        id: 'p_partial',
        academicYearId: testAcademicYear.id,
        periodLabel: 'Harian 15 Juli 2026',
        dueDate: wed,
        targetAmount: 2000,
        isReconciled: false,
        reconciledAmount: 500,
        createdAt: wed,
      );

      // Student 1 paid partial Rp 500 (target is 2000), Student 2 paid 0
      final payments = [
        DuesPayment(id: 'pay_p1', duesPeriodId: 'p_partial', studentId: student1.id, amountPaid: 500, isPaid: false),
        DuesPayment(id: 'pay_p2', duesPeriodId: 'p_partial', studentId: student2.id, amountPaid: 0, isPaid: false),
      ];

      final effective = service.filterEffectivePeriods(
        academicYear: testAcademicYear,
        duesPeriods: [period],
        duesPayments: payments,
      );
      expect(effective.length, 1, reason: 'Day with partial payment > 0 is an active dues day');

      final arrears = service.calculateArrears(
        students: [student1, student2],
        academicYear: testAcademicYear,
        duesPeriods: [period],
        duesPayments: payments,
      );
      // Both students owe arrears because student 1 paid 500 < target 2000 (isPaid: false)
      expect(arrears.length, 2);
      expect(arrears[0].studentName, 'Dimas Anggara');
      expect(arrears[1].studentName, 'Eka Putri');
    });

    test('3.3 Alternating activity holidays (Mon active, Tue holiday, Wed active, Thu holiday, Fri active)', () {
      // 2026-07-13 (Mon) to 2026-07-17 (Fri)
      final periods = <DuesPeriod>[];
      final payments = <DuesPayment>[];

      for (int d = 13; d <= 17; d++) {
        final date = DateTime(2026, 7, d);
        final pId = 'p_alt_$d';
        periods.add(
          DuesPeriod(
            id: pId,
            academicYearId: testAcademicYear.id,
            periodLabel: 'Harian $d Juli 2026',
            dueDate: date,
            targetAmount: 2000,
            isReconciled: true,
            reconciledAmount: (d % 2 == 1) ? 2000 : 0,
            createdAt: date,
          ),
        );

        // Only on odd days (13 Mon, 15 Wed, 17 Fri), Student 1 paid
        // Even days (14 Tue, 16 Thu) have 0 payments -> activity holidays
        if (d % 2 == 1) {
          payments.add(
            DuesPayment(id: 'pay_s1_$d', duesPeriodId: pId, studentId: student1.id, amountPaid: 2000, isPaid: true),
          );
        }
      }

      final effective = service.filterEffectivePeriods(
        academicYear: testAcademicYear,
        duesPeriods: periods,
        duesPayments: payments,
      );
      // Only 3 effective days (13, 15, 17)
      expect(effective.length, 3);
      expect(effective.map((p) => p.periodLabel).toList(), [
        'Harian 13 Juli 2026',
        'Harian 15 Juli 2026',
        'Harian 17 Juli 2026',
      ]);

      final arrears = service.calculateArrears(
        students: [student1, student2],
        academicYear: testAcademicYear,
        duesPeriods: periods,
        duesPayments: payments,
      );
      // Student 1 paid all 3 active days -> 0 arrears
      // Student 2 missed all 3 active days -> owes 6000
      expect(arrears.length, 1);
      final item = arrears.first;
      expect(item.studentName, 'Eka Putri');
      expect(item.unpaidPeriodsCount, 3);
      expect(item.totalArrearsAmount, 6000);
    });
  });

  group('CHALLENGER STRESS SUITE: Range Formatters (Leap Year, Boundaries & Gaps)', () {
    test('4.1 Leap Year formatting: 28 Feb 2028 (Mon) to 2 Mar 2028 (Thu) with leap day 29 Feb', () {
      // 2028 is a leap year!
      final d28 = DateTime(2028, 2, 28); // Mon
      final d29 = DateTime(2028, 2, 29); // Tue (Leap day)
      final d01 = DateTime(2028, 3, 1);  // Wed
      final d02 = DateTime(2028, 3, 2);  // Thu

      expect(d28.weekday, DateTime.monday);
      expect(d29.day, 29);
      expect(d29.month, 2);

      final leapPeriods = [
        DuesPeriod(id: 'lp1', academicYearId: 'y', periodLabel: 'Harian 28 Februari 2028', dueDate: d28, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: d28),
        DuesPeriod(id: 'lp2', academicYearId: 'y', periodLabel: 'Harian 29 Februari 2028', dueDate: d29, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: d29),
        DuesPeriod(id: 'lp3', academicYearId: 'y', periodLabel: 'Harian 1 Maret 2028', dueDate: d01, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: d01),
        DuesPeriod(id: 'lp4', academicYearId: 'y', periodLabel: 'Harian 2 Maret 2028', dueDate: d02, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: d02),
      ];

      final rangeText = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: leapPeriods,
        periodType: 'daily',
        allEffectivePeriods: leapPeriods,
      );

      expect(rangeText, 'Dari 28 Februari s.d. 2 Maret 2028');
    });

    test('4.2 Month boundary: 30 July 2026 (Thu), 31 July 2026 (Fri), 3 August 2026 (Mon) across weekend', () {
      final thu = DateTime(2026, 7, 30);
      final fri = DateTime(2026, 7, 31);
      final mon = DateTime(2026, 8, 3);

      final periods = [
        DuesPeriod(id: 'mb1', academicYearId: 'y', periodLabel: 'Harian 30 Juli 2026', dueDate: thu, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: thu),
        DuesPeriod(id: 'mb2', academicYearId: 'y', periodLabel: 'Harian 31 Juli 2026', dueDate: fri, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: fri),
        DuesPeriod(id: 'mb3', academicYearId: 'y', periodLabel: 'Harian 3 Agustus 2026', dueDate: mon, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: mon),
      ];

      final rangeText = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: periods,
        periodType: 'daily',
        allEffectivePeriods: periods,
      );

      // Friday to Monday over weekend connects consecutively!
      expect(rangeText, 'Dari 30 Juli s.d. 3 Agustus 2026');
    });

    test('4.3 Year boundary: 30 December 2026 (Wed) to 4 January 2027 (Mon)', () {
      final d30 = DateTime(2026, 12, 30); // Wed
      final d31 = DateTime(2026, 12, 31); // Thu
      final d01 = DateTime(2027, 1, 1);   // Fri
      final d04 = DateTime(2027, 1, 4);   // Mon

      final periods = [
        DuesPeriod(id: 'yb1', academicYearId: 'y', periodLabel: 'Harian 30 Desember 2026', dueDate: d30, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: d30),
        DuesPeriod(id: 'yb2', academicYearId: 'y', periodLabel: 'Harian 31 Desember 2026', dueDate: d31, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: d31),
        DuesPeriod(id: 'yb3', academicYearId: 'y', periodLabel: 'Harian 1 Januari 2027', dueDate: d01, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: d01),
        DuesPeriod(id: 'yb4', academicYearId: 'y', periodLabel: 'Harian 4 Januari 2027', dueDate: d04, targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: d04),
      ];

      final rangeText = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: periods,
        periodType: 'daily',
        allEffectivePeriods: periods,
      );

      expect(rangeText, 'Dari 30 Desember 2026 s.d. 4 Januari 2027');
    });

    test('4.4 Disjoint non-consecutive gaps with single dates and multiple clusters', () {
      // 14 Jul (Mon), 16 Jul (Wed), 17 Jul (Thu), 21 Jul (Mon)
      final p14 = DuesPeriod(id: 'd1', academicYearId: 'y', periodLabel: 'Harian 14 Juli 2026', dueDate: DateTime(2026, 7, 14), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 14));
      final p16 = DuesPeriod(id: 'd2', academicYearId: 'y', periodLabel: 'Harian 16 Juli 2026', dueDate: DateTime(2026, 7, 16), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 16));
      final p17 = DuesPeriod(id: 'd3', academicYearId: 'y', periodLabel: 'Harian 17 Juli 2026', dueDate: DateTime(2026, 7, 17), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 17));
      final p21 = DuesPeriod(id: 'd4', academicYearId: 'y', periodLabel: 'Harian 21 Juli 2026', dueDate: DateTime(2026, 7, 21), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 21));

      // All effective periods included 15 Jul (Tuesday) and 20 Jul (Monday)
      final allEffective = [
        p14,
        DuesPeriod(id: 'd_mid1', academicYearId: 'y', periodLabel: 'Harian 15 Juli 2026', dueDate: DateTime(2026, 7, 15), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 15)),
        p16,
        p17,
        DuesPeriod(id: 'd_mid2', academicYearId: 'y', periodLabel: 'Harian 20 Juli 2026', dueDate: DateTime(2026, 7, 20), targetAmount: 2000, isReconciled: true, reconciledAmount: 2000, createdAt: DateTime(2026, 7, 20)),
        p21,
      ];

      final unpaid = [p14, p16, p17, p21];

      final rangeText = DuesArrearsService.formatUnpaidRange(
        unpaidPeriods: unpaid,
        periodType: 'daily',
        allEffectivePeriods: allEffective,
      );

      // Expected clusters:
      // Cluster 1: [14 Jul] -> "14 Juli 2026"
      // Cluster 2: [16 Jul, 17 Jul] -> "Dari 16 Juli s.d. 17 Juli 2026"
      // Cluster 3: [21 Jul] -> "21 Juli 2026"
      expect(rangeText, '14 Juli 2026, Dari 16 Juli s.d. 17 Juli 2026, 21 Juli 2026');
    });

    test('4.5 Weekly and monthly edge formatters (single, multi, empty)', () {
      expect(DuesArrearsService.formatUnpaidRange(unpaidPeriods: [], periodType: 'weekly'), '-');
      expect(DuesArrearsService.formatUnpaidRange(unpaidPeriods: [], periodType: 'daily'), '-');

      // Weekly single
      final wSingle = DuesPeriod(id: 'ws', academicYearId: 'y', periodLabel: 'Minggu 3 Agustus 2026', dueDate: DateTime(2026, 8, 21), targetAmount: 5000, isReconciled: true, reconciledAmount: 5000, createdAt: DateTime(2026, 8, 21));
      expect(DuesArrearsService.formatUnpaidRange(unpaidPeriods: [wSingle], periodType: 'weekly'), 'Minggu 3 Agustus 2026');

      // Weekly multi
      final w1 = DuesPeriod(id: 'w1', academicYearId: 'y', periodLabel: 'Minggu 1 Juli 2026', dueDate: DateTime(2026, 7, 7), targetAmount: 5000, isReconciled: true, reconciledAmount: 5000, createdAt: DateTime(2026, 7, 7));
      final w2 = DuesPeriod(id: 'w2', academicYearId: 'y', periodLabel: 'Minggu 2 Juli 2026', dueDate: DateTime(2026, 7, 14), targetAmount: 5000, isReconciled: true, reconciledAmount: 5000, createdAt: DateTime(2026, 7, 14));
      expect(DuesArrearsService.formatUnpaidRange(unpaidPeriods: [w1, w2], periodType: 'weekly'), 'Minggu 1 Juli s.d. Minggu 2 Juli 2026');
    });
  });

  group('CHALLENGER STRESS SUITE: Unrestricted General Cash Transactions (R5 / F13)', () {
    late AppDatabase db;
    late TransactionRepository repo;
    const academicYearId = 'year_general_stress';
    const catIncome = 'cat_inc_gen';
    const catExpense = 'cat_exp_gen';

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      repo = TransactionRepository(db);
      await db.customSelect('SELECT 1').get();

      await db.into(db.academicYears).insert(
            AcademicYearsCompanion.insert(
              id: academicYearId,
              name: 'Kelas 7A General Stress',
              grade: 7,
              startDate: DateTime(2026, 7, 1),
              endDate: DateTime(2027, 6, 30),
              duesPeriodType: const Value('daily'),
              createdAt: DateTime.now(),
            ),
          );

      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: catIncome,
              type: 'income',
              name: 'Sumbangan & Bazar',
              iconName: 'volunteer_activism',
              colorHex: '#16A34A',
              createdAt: DateTime.now(),
            ),
          );
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: catExpense,
              type: 'expense',
              name: 'Konsumsi & ATK',
              iconName: 'lunch_dining',
              colorHex: '#DC2626',
              createdAt: DateTime.now(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('5.1 Comprehensive weekend & holiday general financial mutasi calculation', () async {
      final now = DateTime.now();
      // Use current month dates to verify monthly stats as well
      final satInCurrentMonth = DateTime(now.year, now.month, 12, 10, 0);
      final sunInCurrentMonth = DateTime(now.year, now.month, 13, 14, 30);
      final holidayInCurrentMonth = DateTime(now.year, now.month, 15, 9, 0);

      // 1. Saturday Bazar Income
      await repo.insertTransaction(
        academicYearId: academicYearId,
        categoryId: catIncome,
        type: 'income',
        amount: 350000,
        title: 'Hasil Penjualan Bazar Sabtu',
        description: 'Bazar Sabtu Pagi',
        transactionDate: satInCurrentMonth,
      );

      // 2. Sunday Competition Lunch Expense
      await repo.insertTransaction(
        academicYearId: academicYearId,
        categoryId: catExpense,
        type: 'expense',
        amount: 120000,
        title: 'Konsumsi Lomba Minggu',
        description: 'Makan siang peserta lomba hari Minggu',
        transactionDate: sunInCurrentMonth,
      );

      // 3. Holiday Donation Income
      await repo.insertTransaction(
        academicYearId: academicYearId,
        categoryId: catIncome,
        type: 'income',
        amount: 200000,
        title: 'Donasi Wali Murid Hari Libur Nasional',
        description: 'Sumbangan fasilitas',
        transactionDate: holidayInCurrentMonth,
      );

      // 4. Holiday Expense
      await repo.insertTransaction(
        academicYearId: academicYearId,
        categoryId: catExpense,
        type: 'expense',
        amount: 50000,
        title: 'Beli Cat untuk Dekorasi',
        description: 'Cat dinding kelas',
        transactionDate: holidayInCurrentMonth,
      );

      final stats = await repo.watchBalanceStats(academicYearId).first;
      // Total Balance: 350.000 - 120.000 + 200.000 - 50.000 = 380.000
      expect(stats.totalBalance, 380000);
      expect(stats.monthlyIncome, 550000);
      expect(stats.monthlyExpense, 170000);

      final allTxs = await repo.getAllTransactions(academicYearId: academicYearId);
      expect(allTxs.length, 4);
    });

    test('5.2 Deletion of custom category re-assigns weekend transaction to fallback category cleanly', () async {
      // Create a custom category
      final customCat = await repo.createCategory(
        name: 'Kategori Khusus Weekend',
        type: 'expense',
      );

      // Insert transaction using custom category on a Sunday
      final sunday = DateTime(2026, 9, 20, 11, 0);
      await repo.insertTransaction(
        academicYearId: academicYearId,
        categoryId: customCat.id,
        type: 'expense',
        amount: 75000,
        title: 'Biaya Sewa Tenda Minggu',
        transactionDate: sunday,
      );

      // Delete custom category -> must reassign to catExpense
      await repo.deleteCategory(id: customCat.id, type: 'expense');

      final txs = await repo.getAllTransactions(academicYearId: academicYearId);
      expect(txs.length, 1);
      expect(txs.first.category.type, 'expense');
      expect(txs.first.category.id != customCat.id, true);
      expect(txs.first.transaction.amount, 75000);
    });
  });
}
