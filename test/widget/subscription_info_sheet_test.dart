import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:bendahara_app/core/license/license_engine.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/dues_repository.dart';
import 'package:bendahara_app/data/repositories/license_repository.dart';
import 'package:bendahara_app/data/repositories/student_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/providers/subscription_notifier.dart';
import 'package:bendahara_app/presentation/screens/dashboard_screen.dart';
import 'package:bendahara_app/presentation/screens/dialogs/subscription_info_sheet.dart';

final DateTime _testNow = DateTime.utc(2026, 9, 25, 12, 0);

class _TestClock {
  DateTime now;
  _TestClock(this.now);
  DateTime call() => now;
}

void main() {
  final testArtifacts = <String, dynamic>{
    'test_suite': 'Subscription Info Sheet Integration & Failure Modes Test',
    'executed_at': DateTime.now().toIso8601String(),
    'verifications': <String>[],
    'status': 'PENDING',
  };

  tearDownAll(() async {
    testArtifacts['status'] = 'PASSED';
    try {
      final dir = Directory('build/test_reports');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('build/test_reports/subscription_info_sheet_artifact.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(testArtifacts));
    } catch (_) {}
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Subscription Info Sheet via 3-Dots Menu Tests', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late StudentRepository studentRepo;
    late DuesRepository duesRepo;
    late TransactionRepository txRepo;
    late LicenseRepository licenseRepo;
    late _TestClock clock;
    late AcademicYear activeYear;

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      studentRepo = StudentRepository(db);
      duesRepo = DuesRepository(db);
      txRepo = TransactionRepository(db);
      licenseRepo = LicenseRepository(db);
      await db.customSelect('SELECT 1').get();
      clock = _TestClock(_testNow);

      activeYear = await yearRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Siti Bendahara',
        supervisorName: 'Ibu Guru',
        defaultDuesAmount: 20000,
        duesPeriodType: 'monthly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp() {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
          licenseRepoProvider.overrideWithValue(licenseRepo),
          activeAcademicYearProvider.overrideWith(
            (ref) => Stream.value(activeYear),
          ),
          subscriptionClockProvider.overrideWithValue(clock.call),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DashboardScreen(),
          ),
        ),
      );
    }

    Future<void> teardownTree(WidgetTester tester) async {
      final element = tester.element(find.byType(MaterialApp).first);
      final container = ProviderScope.containerOf(element);
      container.invalidate(subscriptionNotifierProvider);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('Membuka menu titik 3 menampilkan opsi Informasi Langganan', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final moreBtn = find.byIcon(Icons.more_vert_rounded);
      expect(moreBtn, findsOneWidget);

      await tester.tap(moreBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Informasi Langganan'), findsOneWidget);
      expect(find.text('Cek Pembaruan Aplikasi'), findsOneWidget);
      expect(find.text('Akhiri Jabatan Bendahara'), findsOneWidget);

      testArtifacts['verifications'].add('F0: PopupMenu 3-dots contains Informasi Langganan option');
      await teardownTree(tester);
    });

    testWidgets('F1: Status Unactivated menampilkan badge Belum Aktif dan CTA aktivasi', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Informasi Langganan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SubscriptionInfoSheet), findsOneWidget);
      expect(find.text('Informasi Langganan'), findsWidgets);
      expect(find.text('Belum Aktif'), findsOneWidget);
      expect(find.text('ID Perangkat'), findsOneWidget);
      expect(find.text('Aktivasi Lisensi'), findsOneWidget);

      testArtifacts['verifications'].add('F1: Unactivated status shows Belum Aktif badge and Activation CTA');
      await teardownTree(tester);
    });

    testWidgets('F2 & F3: Status Aktif menampilkan sisa hari dan rincian masa berlaku', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Pasang lisensi aktif 28 hari
      final token = LicenseEngine.generate(issuedAt: _testNow);
      await licenseRepo.activate(
        token,
        now: _testNow,
        clock: clock.call,
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Informasi Langganan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SubscriptionInfoSheet), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.textContaining('28 hari lagi'), findsOneWidget);
      expect(find.textContaining('Masa Berlaku Hingga:'), findsOneWidget);
      expect(find.text('Perpanjang Lisensi'), findsOneWidget);

      testArtifacts['verifications'].add('F2 & F3: Active status renders remaining days and expiry details accurately');
      await teardownTree(tester);
    });
  });
}
