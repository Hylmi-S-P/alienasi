import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/domain/services/dues_arrears_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('DuesArrearsService - Core Logic, Weekend/Holiday Rules & Formatting', () {
    const service = DuesArrearsService();

    final testAcademicYearDaily = AcademicYear(
      id: 'year_daily_1',
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

    final testAcademicYearWeekly = AcademicYear(
      id: 'year_weekly_1',
      name: 'Kelas 8B 2026/2027',
      grade: 8,
      treasurerName: 'Andi',
      supervisorName: 'Ibu Ratna',
      defaultDuesAmount: 5000,
      duesPeriodType: 'weekly',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2027, 6, 30),
      isActive: true,
      createdAt: DateTime(2026, 7, 1),
    );

    final student1 = Student(
      id: 'student_1',
      academicYearId: 'year_daily_1',
      attendanceNumber: 1,
      name: 'Ahmad Fauzi',
      status: 'active',
      createdAt: DateTime(2026, 7, 1),
    );

    final student2 = Student(
      id: 'student_2',
      academicYearId: 'year_daily_1',
      attendanceNumber: 2,
      name: 'Budi Santoso',
      status: 'active',
      createdAt: DateTime(2026, 7, 1),
    );

    final inactiveStudent = Student(
      id: 'student_inactive',
      academicYearId: 'year_daily_1',
      attendanceNumber: 3,
      name: 'Candra Pindah',
      status: 'inactive',
      createdAt: DateTime(2026, 7, 1),
    );

    test('F11: Saturday and Sunday periods are strictly excluded from daily dues and generate 0 arrears', () {
      // 19 September 2026 is Saturday, 20 September 2026 is Sunday
      final saturday = DateTime(2026, 9, 19);
      final sunday = DateTime(2026, 9, 20);

      expect(saturday.weekday, DateTime.saturday);
      expect(sunday.weekday, DateTime.sunday);

      final periods = [
        DuesPeriod(
          id: 'p_sat',
          academicYearId: testAcademicYearDaily.id,
          periodLabel: 'Harian 19 September 2026',
          dueDate: saturday,
          targetAmount: 2000,
          isReconciled: false,
          reconciledAmount: 0,
          createdAt: saturday,
        ),
        DuesPeriod(
          id: 'p_sun',
          academicYearId: testAcademicYearDaily.id,
          periodLabel: 'Harian 20 September 2026',
          dueDate: sunday,
          targetAmount: 2000,
          isReconciled: false,
          reconciledAmount: 0,
          createdAt: sunday,
        ),
      ];

      // Even if payments exist with isPaid: false
      final payments = [
        DuesPayment(
          id: 'pay_1',
          duesPeriodId: 'p_sat',
          studentId: student1.id,
          amountPaid: 0,
          isPaid: false,
        ),
        DuesPayment(
          id: 'pay_2',
          duesPeriodId: 'p_sun',
          studentId: student1.id,
          amountPaid: 0,
          isPaid: false,
        ),
      ];

      final arrears = service.calculateArrears(
        students: [student1, student2],
        academicYear: testAcademicYearDaily,
        duesPeriods: periods,
        duesPayments: payments,
      );

      expect(arrears, isEmpty, reason: 'Weekend periods must not generate any arrears');
      final effective = service.filterEffectivePeriods(
        academicYear: testAcademicYearDaily,
        duesPeriods: periods,
        duesPayments: payments,
      );
      expect(effective, isEmpty);
    });

    test('F12: Weekdays (Mon-Fri) with 0 collections are recognized as activity holidays with 0 arrears', () {
      // Monday 14 September 2026 (Weekday)
      final monday = DateTime(2026, 9, 14);
      expect(monday.weekday, DateTime.monday);

      final period = DuesPeriod(
        id: 'p_mon',
        academicYearId: testAcademicYearDaily.id,
        periodLabel: 'Harian 14 September 2026',
        dueDate: monday,
        targetAmount: 2000,
        isReconciled: false,
        reconciledAmount: 0,
        createdAt: monday,
      );

      // 0 students paid (both isPaid: false, amountPaid: 0)
      final payments = [
        DuesPayment(
          id: 'pay_m1',
          duesPeriodId: 'p_mon',
          studentId: student1.id,
          amountPaid: 0,
          isPaid: false,
        ),
        DuesPayment(
          id: 'pay_m2',
          duesPeriodId: 'p_mon',
          studentId: student2.id,
          amountPaid: 0,
          isPaid: false,
        ),
      ];

      final arrears = service.calculateArrears(
        students: [student1, student2],
        academicYear: testAcademicYearDaily,
        duesPeriods: [period],
        duesPayments: payments,
      );

      expect(arrears, isEmpty, reason: 'Weekday with 0 collections is an activity holiday and produces 0 arrears');
    });

    test('Effective Dues Day: When >= 1 student paid, non-paying students are in arrears', () {
      // Tuesday 15 September 2026 (Weekday)
      final tuesday = DateTime(2026, 9, 15);
      expect(tuesday.weekday, DateTime.tuesday);

      final period = DuesPeriod(
        id: 'p_tue',
        academicYearId: testAcademicYearDaily.id,
        periodLabel: 'Harian 15 September 2026',
        dueDate: tuesday,
        targetAmount: 2000,
        isReconciled: true,
        reconciledAmount: 2000,
        createdAt: tuesday,
      );

      // Student 1 paid, Student 2 did not pay
      final payments = [
        DuesPayment(
          id: 'pay_t1',
          duesPeriodId: 'p_tue',
          studentId: student1.id,
          amountPaid: 2000,
          isPaid: true,
          paidAt: tuesday,
        ),
        DuesPayment(
          id: 'pay_t2',
          duesPeriodId: 'p_tue',
          studentId: student2.id,
          amountPaid: 0,
          isPaid: false,
        ),
      ];

      final arrears = service.calculateArrears(
        students: [student1, student2],
        academicYear: testAcademicYearDaily,
        duesPeriods: [period],
        duesPayments: payments,
      );

      // Student 1 paid -> not in list
      // Student 2 unpaid -> owes 2000 for 1 period
      expect(arrears.length, 1);
      final item = arrears.first;
      expect(item.studentNumber, 2);
      expect(item.studentName, 'Budi Santoso');
      expect(item.unpaidPeriodsCount, 1);
      expect(item.duesRate, 2000);
      expect(item.totalArrearsAmount, 2000);
      expect(item.unpaidPeriodRangeText, '15 September 2026');
      expect(item.rateDescription, 'Rp 2.000 / hari');
    });

    test('Consecutive range formatting for daily dues: "Dari 14 Juli s.d. 18 Juli 2025"', () {
      // In 2025, July 14 to 18 are Monday through Friday (all 5 weekdays)
      final academicYear2025 = AcademicYear(
        id: 'year_daily_2025',
        name: 'Kelas 7A 2025/2026',
        grade: 7,
        treasurerName: 'Siti',
        supervisorName: 'Pak Budi',
        defaultDuesAmount: 2000,
        duesPeriodType: 'daily',
        startDate: DateTime(2025, 7, 1),
        endDate: DateTime(2026, 6, 30),
        isActive: true,
        createdAt: DateTime(2025, 7, 1),
      );

      final periods = <DuesPeriod>[];
      final payments = <DuesPayment>[];

      for (int day = 14; day <= 18; day++) {
        final date = DateTime(2025, 7, day);
        expect(date.weekday >= 1 && date.weekday <= 5, true, reason: 'Must be Monday to Friday');
        final pId = 'p_july2025_$day';
        periods.add(
          DuesPeriod(
            id: pId,
            academicYearId: academicYear2025.id,
            periodLabel: 'Harian $day Juli 2025',
            dueDate: date,
            targetAmount: 2000,
            isReconciled: true,
            reconciledAmount: 2000,
            createdAt: date,
          ),
        );

        // Student 1 paid every day (so day is active)
        payments.add(
          DuesPayment(
            id: 'pay_s1_$day',
            duesPeriodId: pId,
            studentId: student1.id,
            amountPaid: 2000,
            isPaid: true,
          ),
        );

        // Student 2 missed every day
        payments.add(
          DuesPayment(
            id: 'pay_s2_$day',
            duesPeriodId: pId,
            studentId: student2.id,
            amountPaid: 0,
            isPaid: false,
          ),
        );
      }

      final arrears = service.calculateArrears(
        students: [student1, student2],
        academicYear: academicYear2025,
        duesPeriods: periods,
        duesPayments: payments,
      );

      expect(arrears.length, 1);
      final item = arrears.first;
      expect(item.studentName, 'Budi Santoso');
      expect(item.unpaidPeriodsCount, 5);
      expect(item.totalArrearsAmount, 10000);
      expect(item.unpaidPeriodRangeText, 'Dari 14 Juli s.d. 18 Juli 2025');
      expect(item.unpaidPeriodRangeText.contains('Dari 14 Juli s.d. 18 Juli'), true);
    });

    test('Disjoint unpaid daily periods formatting (comma-separated)', () {
      // Days: 14, 15, 16 July and 20 July (17 July paid, 18-19 weekend)
      final periods = [
        DuesPeriod(
          id: 'p14',
          academicYearId: testAcademicYearDaily.id,
          periodLabel: 'Harian 14 Juli 2026',
          dueDate: DateTime(2026, 7, 14),
          targetAmount: 2000,
          isReconciled: true,
          reconciledAmount: 2000,
          createdAt: DateTime(2026, 7, 14),
        ),
        DuesPeriod(
          id: 'p15',
          academicYearId: testAcademicYearDaily.id,
          periodLabel: 'Harian 15 Juli 2026',
          dueDate: DateTime(2026, 7, 15),
          targetAmount: 2000,
          isReconciled: true,
          reconciledAmount: 2000,
          createdAt: DateTime(2026, 7, 15),
        ),
        DuesPeriod(
          id: 'p16',
          academicYearId: testAcademicYearDaily.id,
          periodLabel: 'Harian 16 Juli 2026',
          dueDate: DateTime(2026, 7, 16),
          targetAmount: 2000,
          isReconciled: true,
          reconciledAmount: 2000,
          createdAt: DateTime(2026, 7, 16),
        ),
        DuesPeriod(
          id: 'p17',
          academicYearId: testAcademicYearDaily.id,
          periodLabel: 'Harian 17 Juli 2026',
          dueDate: DateTime(2026, 7, 17),
          targetAmount: 2000,
          isReconciled: true,
          reconciledAmount: 4000,
          createdAt: DateTime(2026, 7, 17),
        ),
        DuesPeriod(
          id: 'p20',
          academicYearId: testAcademicYearDaily.id,
          periodLabel: 'Harian 20 Juli 2026',
          dueDate: DateTime(2026, 7, 20),
          targetAmount: 2000,
          isReconciled: true,
          reconciledAmount: 2000,
          createdAt: DateTime(2026, 7, 20),
        ),
      ];

      final payments = [
        // 14: S1 paid, S2 unpaid
        DuesPayment(id: 'p1', duesPeriodId: 'p14', studentId: student1.id, amountPaid: 2000, isPaid: true),
        DuesPayment(id: 'p2', duesPeriodId: 'p14', studentId: student2.id, amountPaid: 0, isPaid: false),
        // 15: S1 paid, S2 unpaid
        DuesPayment(id: 'p3', duesPeriodId: 'p15', studentId: student1.id, amountPaid: 2000, isPaid: true),
        DuesPayment(id: 'p4', duesPeriodId: 'p15', studentId: student2.id, amountPaid: 0, isPaid: false),
        // 16: S1 paid, S2 unpaid
        DuesPayment(id: 'p5', duesPeriodId: 'p16', studentId: student1.id, amountPaid: 2000, isPaid: true),
        DuesPayment(id: 'p6', duesPeriodId: 'p16', studentId: student2.id, amountPaid: 0, isPaid: false),
        // 17: Both paid!
        DuesPayment(id: 'p7', duesPeriodId: 'p17', studentId: student1.id, amountPaid: 2000, isPaid: true),
        DuesPayment(id: 'p8', duesPeriodId: 'p17', studentId: student2.id, amountPaid: 2000, isPaid: true),
        // 20: S1 paid, S2 unpaid
        DuesPayment(id: 'p9', duesPeriodId: 'p20', studentId: student1.id, amountPaid: 2000, isPaid: true),
        DuesPayment(id: 'p10', duesPeriodId: 'p20', studentId: student2.id, amountPaid: 0, isPaid: false),
      ];

      final arrears = service.calculateArrears(
        students: [student1, student2],
        academicYear: testAcademicYearDaily,
        duesPeriods: periods,
        duesPayments: payments,
      );

      expect(arrears.length, 1);
      final item = arrears.first;
      expect(item.unpaidPeriodsCount, 4);
      expect(item.totalArrearsAmount, 8000);
      expect(item.unpaidPeriodRangeText, 'Dari 14 Juli s.d. 16 Juli 2026, 20 Juli 2026');
    });

    test('Weekly range formatting: "Minggu 2 Juli s.d. Minggu 4 Juli 2026"', () {
      final weeklyPeriods = [
        DuesPeriod(
          id: 'w1',
          academicYearId: testAcademicYearWeekly.id,
          periodLabel: 'Minggu 1 Juli 2026',
          dueDate: DateTime(2026, 7, 7),
          targetAmount: 5000,
          isReconciled: true,
          reconciledAmount: 10000,
          createdAt: DateTime(2026, 7, 7),
        ),
        DuesPeriod(
          id: 'w2',
          academicYearId: testAcademicYearWeekly.id,
          periodLabel: 'Minggu 2 Juli 2026',
          dueDate: DateTime(2026, 7, 14),
          targetAmount: 5000,
          isReconciled: true,
          reconciledAmount: 5000,
          createdAt: DateTime(2026, 7, 14),
        ),
        DuesPeriod(
          id: 'w3',
          academicYearId: testAcademicYearWeekly.id,
          periodLabel: 'Minggu 3 Juli 2026',
          dueDate: DateTime(2026, 7, 21),
          targetAmount: 5000,
          isReconciled: true,
          reconciledAmount: 5000,
          createdAt: DateTime(2026, 7, 21),
        ),
        DuesPeriod(
          id: 'w4',
          academicYearId: testAcademicYearWeekly.id,
          periodLabel: 'Minggu 4 Juli 2026',
          dueDate: DateTime(2026, 7, 28),
          targetAmount: 5000,
          isReconciled: true,
          reconciledAmount: 5000,
          createdAt: DateTime(2026, 7, 28),
        ),
      ];

      final payments = [
        // Week 1: Both paid
        DuesPayment(id: 'wp1', duesPeriodId: 'w1', studentId: student1.id, amountPaid: 5000, isPaid: true),
        DuesPayment(id: 'wp2', duesPeriodId: 'w1', studentId: student2.id, amountPaid: 5000, isPaid: true),
        // Week 2: S1 paid, S2 unpaid
        DuesPayment(id: 'wp3', duesPeriodId: 'w2', studentId: student1.id, amountPaid: 5000, isPaid: true),
        DuesPayment(id: 'wp4', duesPeriodId: 'w2', studentId: student2.id, amountPaid: 0, isPaid: false),
        // Week 3: S1 paid, S2 unpaid
        DuesPayment(id: 'wp5', duesPeriodId: 'w3', studentId: student1.id, amountPaid: 5000, isPaid: true),
        DuesPayment(id: 'wp6', duesPeriodId: 'w3', studentId: student2.id, amountPaid: 0, isPaid: false),
        // Week 4: S1 paid, S2 unpaid
        DuesPayment(id: 'wp7', duesPeriodId: 'w4', studentId: student1.id, amountPaid: 5000, isPaid: true),
        DuesPayment(id: 'wp8', duesPeriodId: 'w4', studentId: student2.id, amountPaid: 0, isPaid: false),
      ];

      final arrears = service.calculateArrears(
        students: [student1, student2],
        academicYear: testAcademicYearWeekly,
        duesPeriods: weeklyPeriods,
        duesPayments: payments,
      );

      expect(arrears.length, 1);
      final item = arrears.first;
      expect(item.studentName, 'Budi Santoso');
      expect(item.unpaidPeriodsCount, 3);
      expect(item.totalArrearsAmount, 15000);
      expect(item.unpaidPeriodRangeText, 'Minggu 2 Juli s.d. Minggu 4 Juli 2026');
      expect(item.unpaidPeriodRangeText.contains('Minggu 2 Juli s.d. Minggu 4 Juli'), true);
      expect(item.rateDescription, 'Rp 5.000 / minggu');
    });

    test('Inactive students are excluded from arrears calculation', () {
      final period = DuesPeriod(
        id: 'p_tue',
        academicYearId: testAcademicYearDaily.id,
        periodLabel: 'Harian 15 September 2026',
        dueDate: DateTime(2026, 9, 15),
        targetAmount: 2000,
        isReconciled: true,
        reconciledAmount: 2000,
        createdAt: DateTime(2026, 9, 15),
      );

      final payments = [
        DuesPayment(id: 'pay_1', duesPeriodId: 'p_tue', studentId: student1.id, amountPaid: 2000, isPaid: true),
        DuesPayment(id: 'pay_in', duesPeriodId: 'p_tue', studentId: inactiveStudent.id, amountPaid: 0, isPaid: false),
      ];

      final arrears = service.calculateArrears(
        students: [student1, inactiveStudent],
        academicYear: testAcademicYearDaily,
        duesPeriods: [period],
        duesPayments: payments,
      );

      expect(arrears, isEmpty, reason: 'Inactive students must not be billed or listed in arrears');
    });

    test('DuesArrearsSummary calculates aggregate class totals accurately', () {
      final period = DuesPeriod(
        id: 'p_act',
        academicYearId: testAcademicYearDaily.id,
        periodLabel: 'Harian 15 September 2026',
        dueDate: DateTime(2026, 9, 15),
        targetAmount: 2000,
        isReconciled: true,
        reconciledAmount: 2000,
        createdAt: DateTime(2026, 9, 15),
      );

      final student3 = Student(
        id: 'student_3',
        academicYearId: 'year_daily_1',
        attendanceNumber: 3,
        name: 'Citra Kirana',
        status: 'active',
        createdAt: DateTime(2026, 7, 1),
      );

      // S1 paid, S2 and S3 unpaid
      final payments = [
        DuesPayment(id: 'pay_s1', duesPeriodId: 'p_act', studentId: student1.id, amountPaid: 2000, isPaid: true),
        DuesPayment(id: 'pay_s2', duesPeriodId: 'p_act', studentId: student2.id, amountPaid: 0, isPaid: false),
        DuesPayment(id: 'pay_s3', duesPeriodId: 'p_act', studentId: student3.id, amountPaid: 0, isPaid: false),
      ];

      final summary = service.calculateArrearsSummary(
        students: [student1, student2, student3],
        academicYear: testAcademicYearDaily,
        duesPeriods: [period],
        duesPayments: payments,
      );

      expect(summary.totalEffectivePeriods, 1);
      expect(summary.totalStudentsWithArrears, 2);
      expect(summary.totalArrearsAmount, 4000);
      expect(summary.formattedTotalArrears, 'Rp 4.000');
      expect(summary.arrearsItems.length, 2);
    });
  });
}
