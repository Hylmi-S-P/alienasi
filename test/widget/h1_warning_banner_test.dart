import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';

import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/student_repository.dart';
import 'package:bendahara_app/data/repositories/dues_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/providers/subscription_notifier.dart';
import 'package:bendahara_app/presentation/screens/dashboard_screen.dart';
import 'package:bendahara_app/presentation/screens/dialogs/h1_backup_dialog.dart';
import 'package:bendahara_app/presentation/widgets/h1_warning_banner.dart';

/// Notifier uji yang selalu mengembalikan [info] tetap.
///
/// Dipakai untuk mengendalikan status lisensi pada pengujian widget tanpa
/// menyentuh database lisensi maupun jam sistem.
class _StubSubscriptionNotifier extends SubscriptionNotifier {
  _StubSubscriptionNotifier(this.info);

  final SubscriptionInfo info;

  @override
  Future<SubscriptionInfo> build() async => info;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('H-1 Warning Banner & Backup Hook', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late TransactionRepository txRepo;
    late StudentRepository studentRepo;
    late DuesRepository duesRepo;
    late AcademicYear activeYear;

    final now = DateTime.utc(2026, 9, 24, 10, 30);

    SubscriptionInfo buildInfo(SubscriptionStatus status) {
      final remaining = switch (status) {
        SubscriptionStatus.unactivated => null,
        SubscriptionStatus.expired => const Duration(hours: -2),
        SubscriptionStatus.expiringSoon => const Duration(hours: 20),
        SubscriptionStatus.active => const Duration(days: 10),
      };
      final expiresAt = now.add(remaining ?? Duration.zero);
      final negative = remaining != null && remaining.isNegative;
      final days = remaining == null
          ? null
          : negative
          ? -remaining.inDays
          : remaining.inDays;
      final hours = remaining == null
          ? null
          : remaining.inHours - (negative ? -days! : days!) * 24;
      return SubscriptionInfo(
        status: status,
        message: 'stub',
        remaining: remaining,
        daysRemaining: days,
        hoursRemaining: hours,
        expiresAt: expiresAt,
        checkedAt: now,
      );
    }

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      txRepo = TransactionRepository(db);
      studentRepo = StudentRepository(db);
      duesRepo = DuesRepository(db);

      activeYear = await yearRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Adik',
        supervisorName: 'Ibu',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildTestApp(SubscriptionInfo info) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          activeAcademicYearProvider.overrideWith(
            (ref) => Stream.value(activeYear),
          ),
          subscriptionNotifierProvider.overrideWith(
            () => _StubSubscriptionNotifier(info),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      );
    }

    testWidgets('1. Banner tidak tampil saat status active (sisa > 24 jam)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(buildInfo(SubscriptionStatus.active)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(H1WarningBanner), findsNothing);
      expect(find.text('Lisensi Akan Berakhir'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('2. Banner tidak tampil saat status unactivated', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(buildInfo(SubscriptionStatus.unactivated)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(H1WarningBanner), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('3. Banner tidak tampil saat status expired', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(buildInfo(SubscriptionStatus.expired)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(H1WarningBanner), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets(
      '4. Banner tampil saat expiringSoon (sisa <= 24 jam) dengan teks dan CTA',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final info = buildInfo(SubscriptionStatus.expiringSoon);
        expect(info.remaining!.inHours, lessThanOrEqualTo(24));

        await tester.pumpWidget(buildTestApp(info));
        await tester.pumpAndSettle();

        expect(find.byType(H1WarningBanner), findsOneWidget);
        expect(find.text('Lisensi Akan Berakhir'), findsOneWidget);
        expect(find.textContaining('Sisa 20 jam lagi'), findsOneWidget);
        expect(find.text('Cadangkan Data Sekarang'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      '5. Tap CTA membuka dialog cadangan data dengan opsi PDF, Excel, dan CSV',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestApp(buildInfo(SubscriptionStatus.expiringSoon)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cadangkan Data Sekarang'));
        await tester.pumpAndSettle();

        expect(find.byType(H1BackupDialog), findsOneWidget);
        expect(find.text('Cadangkan Data Segera'), findsOneWidget);
        expect(find.text('Laporan PDF (Semua Transaksi)'), findsOneWidget);
        expect(find.text('Berkas Excel (Buku Kas)'), findsOneWidget);
        expect(find.text('Berkas CSV (Buku Kas)'), findsOneWidget);
        expect(find.text('Simpan PDF'), findsOneWidget);
        expect(find.text('Simpan Excel'), findsOneWidget);
        expect(find.text('Simpan CSV'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets('6. Tap tombol tutup menyembunyikan banner pada sesi ini', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(buildInfo(SubscriptionStatus.expiringSoon)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(H1WarningBanner), findsOneWidget);

      await tester.tap(find.byTooltip('Sembunyikan banner'));
      await tester.pumpAndSettle();

      expect(find.byType(H1WarningBanner), findsNothing);
      expect(find.text('Lisensi Akan Berakhir'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('7. Banner tampil juga tepat pada batas 24 jam persis', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final info = buildInfo(SubscriptionStatus.expiringSoon);
      final exact24 = SubscriptionInfo(
        status: SubscriptionStatus.expiringSoon,
        message: 'stub',
        remaining: const Duration(hours: 24),
        daysRemaining: 1,
        hoursRemaining: 0,
        expiresAt: now.add(const Duration(hours: 24)),
        checkedAt: now,
      );

      await tester.pumpWidget(buildTestApp(exact24));
      await tester.pumpAndSettle();

      expect(find.byType(H1WarningBanner), findsOneWidget);
      expect(info.isExpiringSoon, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
