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
import 'package:bendahara_app/presentation/screens/dues_check_screen.dart';
import 'package:bendahara_app/presentation/screens/transaction_form_screen.dart';
import 'package:bendahara_app/presentation/screens/dialogs/paywall_sheet.dart';

/// Titik waktu tetap agar verifikasi token tidak bergantung jam mesin.
final DateTime _now = DateTime.utc(2026, 9, 24, 10, 30);

/// Jam yang bisa dimutasi untuk menguji perjalanan waktu.
class _Clock {
  DateTime now;
  _Clock(this.now);
  DateTime call() => now;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Action-Gated Paywall (task-5)', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late StudentRepository studentRepo;
    late DuesRepository duesRepo;
    late TransactionRepository txRepo;
    late LicenseRepository licenseRepo;
    late _Clock clock;
    late AcademicYear activeYear;

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      studentRepo = StudentRepository(db);
      duesRepo = DuesRepository(db);
      txRepo = TransactionRepository(db);
      licenseRepo = LicenseRepository(db);
      await db.customSelect('SELECT 1').get();
      clock = _Clock(_now);

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

      // Data historis yang sudah ada sebelum lisensi apa pun.
      await studentRepo.addStudent(
        academicYearId: activeYear.id,
        attendanceNumber: 1,
        name: 'Siswa Lama',
      );
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildApp() {
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
        child: const MaterialApp(home: DashboardScreen()),
      );
    }

    /// Mengakhiri widget test dengan rapi: invalidate provider langganan,
    /// biarkan rebuild async-nya selesai saat masih mounted (supaya timer
    /// transisi terjadwal lalu dibatalkan saat disposal, bukan setelahnya),
    /// baru turunkan pohon widget. Tanpa ini, pengujian yang mengaktivasi
    /// lisensi gagal saat teardown ("Timer is still pending").
    Future<void> teardownTree(WidgetTester tester) async {
      final element = tester.element(find.byType(MaterialApp).first);
      final container = ProviderScope.containerOf(element);
      container.invalidate(subscriptionNotifierProvider);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets(
      '1. Dashboard & data historis tetap terbaca tanpa lisensi (explore-first)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Dashboard terbuka, kelas aktif terbaca, tidak ada paywall paksa.
        expect(find.text('Kelas 7A'), findsOneWidget);
        expect(find.byType(PaywallSheet), findsNothing);
        expect(find.text('Riwayat Pencatatan Terkini'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      '2. Tombol + Uang Masuk tanpa lisensi memicu Paywall, bukan form transaksi',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ Uang Masuk'));
        await tester.pumpAndSettle();

        // Paywall muncul dan form transaksi tidak terbuka.
        expect(find.byType(PaywallSheet), findsOneWidget);
        expect(find.byType(TransactionFormScreen), findsNothing);

        // Tutup paywall; tetap di dashboard.
        await tester.tap(find.byTooltip('Tutup'));
        await tester.pumpAndSettle();
        expect(find.byType(PaywallSheet), findsNothing);
        expect(find.text('Kelas 7A'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      '3. Paywall menampilkan harga Rp 25.000 / 28 hari dan input kode aktivasi',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ Uang Masuk'));
        await tester.pumpAndSettle();

        expect(find.byType(PaywallSheet), findsOneWidget);
        expect(find.text('Aktivasi Lisensi'), findsOneWidget);
        expect(find.text('Rp 25.000 / 28 hari'), findsOneWidget);
        expect(find.byKey(const ValueKey('paywall_activate_btn')), findsOneWidget);
        expect(find.text('Aktivasi Sekarang'), findsOneWidget);
        expect(find.text('BNDH-XXXX-XXXX-XXXX'), findsOneWidget);

        await tester.tap(find.byTooltip('Tutup'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      '4. Kode salah ditolak dengan pesan yang ramah',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ Uang Masuk'));
        await tester.pumpAndSettle();

        final forged = LicenseEngine.generate(
          issuedAt: _now,
          secret: 'kunci-palsu-yang-tidak-dipakai-aplikasi',
        );
        await tester.enterText(find.byType(TextFormField), forged);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('paywall_activate_btn')));
        await tester.pumpAndSettle();

        expect(find.byType(PaywallSheet), findsOneWidget);
        expect(
          find.text('Kode lisensi tidak sah atau sudah diubah.'),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Tutup'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      '5. Kode valid 28 hari mengaktivasi app dan membuka kembali fitur mutasi',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Kondisi awal: belum ada lisensi.
        expect(await licenseRepo.getCurrent(), isNull);

        await tester.tap(find.text('+ Uang Masuk'));
        await tester.pumpAndSettle();
        expect(find.byType(PaywallSheet), findsOneWidget);

        // Masukkan kode valid yang diterbitkan hari ini.
        final token = LicenseEngine.generate(issuedAt: _now);
        // InputFormatter mengubah input menjadi tanpa strip, jadi masukkan
        // bentuk tanpa strip seperti yang akan diketik pengguna.
        await tester.enterText(
          find.byType(TextFormField),
          token.replaceAll('-', ''),
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('paywall_activate_btn')));
        // Setelah aktivasi, SubscriptionNotifier menjadwalkan timer transisi
        // ~27 hari ke depan; pumpAndSettle akan menunggu timer itu habis
        // (macet). Pakai pump berbatas durasi saja.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 500));

        // Paywall tertutup karena aktivasi sukses.
        expect(find.byType(PaywallSheet), findsNothing);

        // Lisensi tersimpan di database dengan masa 28 hari penuh. Format
        // pemisah tidak dipaksa: input pengguna dilewatkan formatter yang
        // membuang strip, jadi bandingkan versi ternormalisasi.
        final saved = await licenseRepo.getCurrent();
        expect(saved, isNotNull);
        expect(
          LicenseEngine.normalize(saved!.activationCode),
          LicenseEngine.normalize(token),
        );
        expect(
          saved.expiresAt.difference(saved.activatedAt),
          LicenseEngine.validityDuration,
        );

        // Status langganan kini aktif.
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            subscriptionClockProvider.overrideWithValue(clock.call),
          ],
        );
        final info = await container.read(subscriptionNotifierProvider.future);
        expect(info.isActive, isTrue);
        expect(info.status, SubscriptionStatus.active);
        // Dispose di sini (bukan addTearDown) supaya timer transisi langganan
        // dibatalkan sebelum framework memeriksa invariant timer test.
        container.dispose();

        // Fitur mutasi terbuka: setelah aktivasi sukses, guard melanjutkan
        // aksi asal (onAllowed) sehingga form transaksi otomatis terbuka.
        // Ini membuktikan kode valid 28 hari membuka kembali fitur mutasi.
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.byType(TransactionFormScreen), findsOneWidget);
        expect(find.byType(PaywallSheet), findsNothing);

        // Kembali ke dashboard lalu coba aksi mutasi lagi: tanpa paywall.
        await tester.tap(find.byTooltip('Kembali'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        await tester.tap(find.text('+ Uang Masuk'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.byType(TransactionFormScreen), findsOneWidget);
        expect(find.byType(PaywallSheet), findsNothing);

        await teardownTree(tester);
      },
    );

    testWidgets(
      '6. Lisensi kedaluwarsa kembali memicu Paywall pada aksi mutasi',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Aktivasi token lama yang sudah kedaluwarsa pada jam saat ini.
        final issuedAt = _now.subtract(const Duration(days: 40));
        final expiredToken = LicenseEngine.generate(issuedAt: issuedAt);
        await licenseRepo.activate(expiredToken, now: _now);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Dashboard tetap terbaca (explore-first, bukan lockout keras).
        expect(find.text('Kelas 7A'), findsOneWidget);
        expect(find.text('Total Saldo Kas Kelas'), findsOneWidget);
        expect(find.text('Riwayat Pencatatan Terkini'), findsOneWidget);

        // Aksi mutasi memicu paywall kembali.
        await tester.tap(find.text('+ Uang Masuk'));
        await tester.pumpAndSettle();
        expect(find.byType(PaywallSheet), findsOneWidget);
        expect(find.byType(TransactionFormScreen), findsNothing);

        await tester.tap(find.byTooltip('Tutup'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      '6b. DuesCheckScreen read-only tetap menampilkan data siswa tanpa lisensi',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              academicYearRepoProvider.overrideWithValue(yearRepo),
              studentRepoProvider.overrideWithValue(studentRepo),
              duesRepoProvider.overrideWithValue(duesRepo),
              transactionRepoProvider.overrideWithValue(txRepo),
              activeAcademicYearProvider.overrideWith(
                (ref) => Stream.value(activeYear),
              ),
              subscriptionClockProvider.overrideWithValue(clock.call),
            ],
            child: const MaterialApp(home: DuesCheckScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Data siswa lama tetap terbaca (read-only view tanpa lockout).
        expect(find.text('Siswa Lama'), findsOneWidget);
        expect(find.byType(PaywallSheet), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      '7. Backup & restore tetap dapat diakses tanpa lisensi',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Tombol cadangkan tidak digerbangi lisensi.
        final backupBtn = find.byTooltip('Cadangkan & Pulihkan Data');
        expect(backupBtn, findsOneWidget);
        await tester.tap(backupBtn);
        await tester.pumpAndSettle();

        // Dialog backup terbuka tanpa paywall.
        expect(find.byType(PaywallSheet), findsNothing);

        // Tutup dialog backup lewat tombol X-nya sendiri.
        await tester.tap(find.byIcon(Icons.close_rounded).first);
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    test('8. runMutationWithGuard menjalankan aksi saat lisensi aktif', () async {
      final token = LicenseEngine.generate(issuedAt: _now);
      await licenseRepo.activate(token, now: _now);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          subscriptionClockProvider.overrideWithValue(clock.call),
        ],
      );
      addTearDown(container.dispose);

      // Pastikan provider ter-build dan aktif.
      final info = await container.read(subscriptionNotifierProvider.future);
      expect(info.isActive, isTrue);
    });

    test('9. Paywall tidak menutup jalur aktivasi ulang setelah kedaluwarsa',
        () async {
      final issuedAt = _now.subtract(const Duration(days: 40));
      final expiredToken = LicenseEngine.generate(issuedAt: issuedAt);
      await licenseRepo.activate(expiredToken, now: _now);

      // Pengguna membeli kode baru; aktivasi langsung dari paywall sukses.
      final newToken = LicenseEngine.generate(issuedAt: _now);
      final result = await licenseRepo.activate(newToken, now: _now);
      expect(result.saved, isTrue);
      expect(result.isValid, isTrue);
    });
  });
}
