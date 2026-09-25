import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/dues_repository.dart';
import 'package:bendahara_app/data/repositories/student_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/providers/subscription_notifier.dart';
import 'package:bendahara_app/presentation/screens/dues_check_screen.dart';
import 'package:bendahara_app/presentation/screens/dialogs/new_student_dialog.dart';
import 'package:uuid/uuid.dart';

/// Notifier uji yang selalu mengembalikan [info] tetap.
///
/// Dipakai untuk mensimulasikan status lisensi aktif/nonaktif pada
/// pengujian widget tanpa menyentuh database lisensi maupun jam sistem.
class _StubSubscriptionNotifier extends SubscriptionNotifier {
  _StubSubscriptionNotifier(this.info);

  final SubscriptionInfo info;

  @override
  Future<SubscriptionInfo> build() async => info;
}

SubscriptionInfo _activeInfo() {
  final now = DateTime.utc(2026, 9, 24, 10, 30);
  return SubscriptionInfo(
    status: SubscriptionStatus.active,
    message: 'stub aktif',
    remaining: const Duration(days: 20),
    daysRemaining: 20,
    hoursRemaining: 0,
    expiresAt: now.add(const Duration(days: 20)),
    checkedAt: now,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Requirement 1: One-way transition from Belum Lunas to Lunas', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late StudentRepository studentRepo;
    late DuesRepository duesRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      studentRepo = StudentRepository(db);
      duesRepo = DuesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('DuesRepository.markAsPaid hanya bisa merubah Belum Lunas ke Lunas (one-way lock)', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Bendahara',
        supervisorName: 'Pengawas',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Budi');
      final students = await studentRepo.getStudents(year.id);
      final budi = students.first;

      final period = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 1 Juli 2026',
        targetAmount: 5000,
      );

      // Status awal: belum lunas
      var duesList = await duesRepo.watchStudentDuesList(academicYearId: year.id, duesPeriodId: period.id).first;
      expect(duesList.first.isPaid, isFalse);
      expect(duesList.first.amountPaid, 0);

      // Ubah dari Belum Lunas ke Lunas
      await duesRepo.markAsPaid(
        duesPeriodId: period.id,
        studentId: budi.id,
        targetAmount: 5000,
      );

      duesList = await duesRepo.watchStudentDuesList(academicYearId: year.id, duesPeriodId: period.id).first;
      expect(duesList.first.isPaid, isTrue);
      expect(duesList.first.amountPaid, 5000);

      // Coba panggil lagi -> harus diabaikan dan tetap Lunas (idempotent)
      await duesRepo.markAsPaid(
        duesPeriodId: period.id,
        studentId: budi.id,
        targetAmount: 5000,
      );

      duesList = await duesRepo.watchStudentDuesList(academicYearId: year.id, duesPeriodId: period.id).first;
      expect(duesList.first.isPaid, isTrue, reason: 'Status harus tetap terkunci Lunas');
      expect(duesList.first.amountPaid, 5000, reason: 'Nominal bayar tidak boleh kembali ke 0');
    });

    testWidgets('DuesCheckScreen UI: Tombol Lunas dinonaktifkan (onTap: null) setelah lunas', (tester) async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 7A',
        grade: 7,
        treasurerName: 'Bendahara',
        supervisorName: 'Pengawas',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Siswa Satu');
      final txRepo = TransactionRepository(db);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
          subscriptionNotifierProvider.overrideWith(() => _StubSubscriptionNotifier(_activeInfo())),
        ],
      );
      addTearDown(() => container.dispose());

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DuesCheckScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cari tombol 'Belum' pada baris siswa
      final belumTileFinder = find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Belum'),
      );
      expect(belumTileFinder, findsOneWidget);

      final inkWellBelum = tester.widget<InkWell>(
        find.ancestor(of: belumTileFinder, matching: find.byType(InkWell)).first,
      );
      expect(inkWellBelum.onTap, isNotNull, reason: 'Sebelum lunas, tombol dapat ditekan');

      // Ketuk tombol untuk memilih siswa
      await tester.tap(belumTileFinder);
      await tester.pumpAndSettle();

      // Tombol bawah aktif untuk menyimpan
      final simpanButton = find.widgetWithText(ElevatedButton, 'Simpan & Masukkan ke Kas Kelas (1 Siswa)');
      expect(simpanButton, findsOneWidget);
      await tester.tap(simpanButton);
      await tester.pumpAndSettle();

      // Dialog 1: Konfirmasi Pembayaran Siswa
      expect(find.text('Konfirmasi Pembayaran Siswa'), findsOneWidget);
      await tester.tap(find.text('Ya, Sudah'));
      await tester.pumpAndSettle();

      // Dialog 2: Masukkan ke kas kelas?
      expect(find.text('Masukkan ke kas kelas?'), findsOneWidget);
      await tester.tap(find.text('Ya, Masukkan'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Sekarang tombol berubah menjadi 'Lunas'
      final lunasTileFinder = find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Lunas'),
      );
      expect(lunasTileFinder, findsOneWidget);

      final inkWellLunas = tester.widget<InkWell>(
        find.ancestor(of: lunasTileFinder, matching: find.byType(InkWell)).first,
      );
      expect(inkWellLunas.onTap, isNull, reason: 'Setelah lunas, tombol dinonaktifkan (onTap: null) agar terkunci');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Requirement 2: Bug Fix - Penambahan Siswa Baru & Rekonsiliasi Kas Bersih', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late StudentRepository studentRepo;
    late DuesRepository duesRepo;
    late TransactionRepository txRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      studentRepo = StudentRepository(db);
      duesRepo = DuesRepository(db);
      txRepo = TransactionRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('addStudent otomatis membuat entri dues_payments untuk seluruh periode aktif yang sudah ada', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8A',
        grade: 8,
        treasurerName: 'Bendahara',
        supervisorName: 'Pengawas',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      // Buat 2 periode kas
      final p1 = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 1 Juli 2026',
        targetAmount: 5000,
      );
      final p2 = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 2 Juli 2026',
        targetAmount: 5000,
      );

      // Tambahkan siswa baru
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Ahmad');
      final students = await studentRepo.getStudents(year.id);
      final ahmad = students.first;

      // Cek apakah entri dues_payments sudah dibuat untuk p1 dan p2
      final paymentP1 = await (db.select(db.duesPayments)
            ..where((t) => t.duesPeriodId.equals(p1.id) & t.studentId.equals(ahmad.id)))
          .getSingleOrNull();
      final paymentP2 = await (db.select(db.duesPayments)
            ..where((t) => t.duesPeriodId.equals(p2.id) & t.studentId.equals(ahmad.id)))
          .getSingleOrNull();

      expect(paymentP1, isNotNull);
      expect(paymentP1!.isPaid, isFalse);
      expect(paymentP1.amountPaid, 0);

      expect(paymentP2, isNotNull);
      expect(paymentP2!.isPaid, isFalse);
      expect(paymentP2.amountPaid, 0);
    });

    test('Skenario User: 2 siswa bayar dicatat berulang kali, lalu tambah 1 siswa dan jadikan Lunas -> tombol reconcile tetap aktif & delta tepat', () async {
      // 1. Tahun ajaran & 2 siswa awal
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 9A',
        grade: 9,
        treasurerName: 'Siti',
        supervisorName: 'Pak Guru',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Siswa 1');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Siswa 2');
      var students = await studentRepo.getStudents(year.id);
      expect(students.length, 2);

      // 2. Input kas 2 siswa sebanyak 3 kali (3 periode berbeda)
      final p1 = await duesRepo.getOrCreateActivePeriod(academicYearId: year.id, periodLabel: 'Minggu 1 Juli 2026', targetAmount: 5000);
      await duesRepo.togglePaymentStatus(duesPeriodId: p1.id, studentId: students[0].id, targetAmount: 5000, currentStatus: false);
      await duesRepo.togglePaymentStatus(duesPeriodId: p1.id, studentId: students[1].id, targetAmount: 5000, currentStatus: false);
      final delta1 = await duesRepo.reconcileIntoGeneralCash(period: p1, academicYearId: year.id);
      expect(delta1, 10000);

      final p2 = await duesRepo.getOrCreateActivePeriod(academicYearId: year.id, periodLabel: 'Minggu 2 Juli 2026', targetAmount: 5000);
      await duesRepo.togglePaymentStatus(duesPeriodId: p2.id, studentId: students[0].id, targetAmount: 5000, currentStatus: false);
      await duesRepo.togglePaymentStatus(duesPeriodId: p2.id, studentId: students[1].id, targetAmount: 5000, currentStatus: false);
      final delta2 = await duesRepo.reconcileIntoGeneralCash(period: p2, academicYearId: year.id);
      expect(delta2, 10000);

      final p3 = await duesRepo.getOrCreateActivePeriod(academicYearId: year.id, periodLabel: 'Minggu 3 Juli 2026', targetAmount: 5000);
      await duesRepo.togglePaymentStatus(duesPeriodId: p3.id, studentId: students[0].id, targetAmount: 5000, currentStatus: false);
      await duesRepo.togglePaymentStatus(duesPeriodId: p3.id, studentId: students[1].id, targetAmount: 5000, currentStatus: false);
      final delta3 = await duesRepo.reconcileIntoGeneralCash(period: p3, academicYearId: year.id);
      expect(delta3, 10000);

      // 3. Tambah 1 siswa baru (Siswa 3)
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 3, name: 'Siswa 3');
      students = await studentRepo.getStudents(year.id);
      expect(students.length, 3);
      final s3 = students[2];

      // 4. Ubah Siswa 3 dari Belum Lunas ke Lunas di periode 3
      await duesRepo.togglePaymentStatus(duesPeriodId: p3.id, studentId: s3.id, targetAmount: 5000, currentStatus: false);

      // 5. Verifikasi nilai di periode 3
      final duesListP3 = await duesRepo.watchStudentDuesList(academicYearId: year.id, duesPeriodId: p3.id).first;
      final totalCollectedP3 = duesListP3.where((i) => i.isPaid).fold<int>(0, (sum, i) => sum + i.amountPaid);
      expect(totalCollectedP3, 15000, reason: 'Total terkumpul harus Rp 15.000 (3 siswa x 5.000)');

      final p3Data = await (db.select(db.duesPeriods)..where((t) => t.id.equals(p3.id))).getSingle();
      final unreconciledDeltaP3 = totalCollectedP3 - p3Data.reconciledAmount;
      expect(unreconciledDeltaP3, 5000, reason: 'Delta belum tercatat harus Rp 5.000 untuk Siswa 3');

      // 6. Masukkan kas tambahan Siswa 3 ke kas umum
      final deltaTambahan = await duesRepo.reconcileIntoGeneralCash(period: p3, academicYearId: year.id);
      expect(deltaTambahan, 5000, reason: 'Delta yang dicatat ke kas umum harus Rp 5.000');

      // Verifikasi transaksi di buku kas umum
      final allTx = await (db.select(db.transactions)..where((t) => t.academicYearId.equals(year.id))).get();
      // Total 4 transaksi: 3 periode awal (10rb x 3) + 1 tambahan periode 3 (5rb) = total 35rb
      expect(allTx.length, 4);
      final totalBalance = allTx.fold<int>(0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
      expect(totalBalance, 35000);
    });

    testWidgets('Widget Test: DuesCheckScreen menampilkan tombol Tambahan Kas saat siswa baru ditandai lunas', (tester) async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 7C',
        grade: 7,
        treasurerName: 'Lina',
        supervisorName: 'Pak Joko',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      // 2 siswa awal
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Siswa 1');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Siswa 2');
      final students = await studentRepo.getStudents(year.id);

      // Periode aktif saat ini
      final currentLabel = formatPeriodLabel(DateTime.now(), 'weekly');
      final period = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: currentLabel,
        targetAmount: 5000,
      );

      // Tandai 2 siswa lunas & rekonsiliasi
      await duesRepo.togglePaymentStatus(duesPeriodId: period.id, studentId: students[0].id, targetAmount: 5000, currentStatus: false);
      await duesRepo.togglePaymentStatus(duesPeriodId: period.id, studentId: students[1].id, targetAmount: 5000, currentStatus: false);
      await duesRepo.reconcileIntoGeneralCash(period: period, academicYearId: year.id);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
          subscriptionNotifierProvider.overrideWith(() => _StubSubscriptionNotifier(_activeInfo())),
        ],
      );
      addTearDown(() => container.dispose());

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DuesCheckScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tombol bawah harus menampilkan status sudah dicatat
      expect(find.text('Semua Kas Periode Ini Sudah Dicatat'), findsOneWidget);

      // Tambahkan Siswa 3 lewat NewStudentDialog
      await tester.tap(find.byTooltip('Tambah Siswa Baru'));
      await tester.pumpAndSettle();

      expect(find.byType(NewStudentDialog), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Contoh: Bagas Pratama'), 'Siswa 3');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Siswa'));
      await tester.pumpAndSettle();

      // Dismiss snackbar
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Siswa 3'), findsOneWidget);

      // Siswa 3 awalnya Belum Bayar
      final belumSiswa3 = find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Belum'),
      );
      expect(belumSiswa3, findsOneWidget);

      // Klik Belum -> Siswa 3 dipilih
      await tester.tap(belumSiswa3);
      await tester.pumpAndSettle();

      // Tombol bawah sekarang HARUS aktif dengan label 'Simpan & Masukkan ke Kas Kelas (1 Siswa)'
      final simpanTambahanButton = find.widgetWithText(ElevatedButton, 'Simpan & Masukkan ke Kas Kelas (1 Siswa)');
      expect(simpanTambahanButton, findsOneWidget);

      final btnWidget = tester.widget<ElevatedButton>(simpanTambahanButton);
      expect(btnWidget.enabled, isTrue, reason: 'Tombol tambahan kas harus aktif dan bisa ditekan!');

      // Ketuk tombol simpan tambahan kas
      await tester.tap(simpanTambahanButton);
      await tester.pumpAndSettle();

      // Dialog 1: Konfirmasi Pembayaran Siswa
      expect(find.text('Konfirmasi Pembayaran Siswa'), findsOneWidget);
      expect(find.text('Ya, Sudah'), findsOneWidget);
      await tester.tap(find.text('Ya, Sudah'));
      await tester.pumpAndSettle();

      // Dialog 2: Masukkan ke kas kelas?
      expect(find.text('Masukkan ke kas kelas?'), findsOneWidget);
      expect(find.text('Ya, Masukkan'), findsOneWidget);
      await tester.tap(find.text('Ya, Masukkan'));
      await tester.pumpAndSettle();

      // Dismiss snackbar
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Setelah rekonsiliasi selesai, tombol kembali menampilkan bahwa semua sudah dicatat
      expect(find.text('Semua Kas Periode Ini Sudah Dicatat'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Recovery: Jika terjadi over-reconciled, tombol memunculkan dialog sinkronisasi dan memulihkan keadaan', (tester) async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 7D',
        grade: 7,
        treasurerName: 'Lina',
        supervisorName: 'Pak Joko',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Siswa 1');
      final currentLabel = formatPeriodLabel(DateTime.now(), 'weekly');
      final period = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: currentLabel,
        targetAmount: 5000,
      );

      // Simulasikan data over-reconciled (reconciledAmount: 10.000 sementara siswa lunas: 0)
      await (db.update(db.duesPeriods)..where((t) => t.id.equals(period.id)))
          .write(const DuesPeriodsCompanion(reconciledAmount: Value(10000), isReconciled: Value(true)));

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
          subscriptionNotifierProvider.overrideWith(() => _StubSubscriptionNotifier(_activeInfo())),
        ],
      );
      addTearDown(() => container.dispose());

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DuesCheckScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tombol menampilkan status over-reconciled
      final overReconciledBtn = find.textContaining('Melebihi Total Bayar');
      expect(overReconciledBtn, findsOneWidget);

      // Ketuk tombol over-reconciled
      await tester.tap(overReconciledBtn);
      await tester.pumpAndSettle();

      // Muncul dialog Sesuaikan Kas Tercatat?
      expect(find.text('Sesuaikan Kas Tercatat?'), findsOneWidget);
      await tester.tap(find.text('Ya, Sesuaikan'));
      await tester.pumpAndSettle();

      // Dismiss snackbar
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Sekarang reconciledAmount sudah disesuaikan menjadi 0 di database
      final updatedPeriod = await (db.select(db.duesPeriods)..where((t) => t.id.equals(period.id))).getSingle();
      expect(updatedPeriod.reconciledAmount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    test('Concurrency & Idempotency: Concurrent markAsPaid calls do not fail with UNIQUE constraint', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 9C',
        grade: 9,
        treasurerName: 'Rian',
        supervisorName: 'Pak Hadi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Doni');
      final students = await studentRepo.getStudents(year.id);
      final doni = students.first;

      final period = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 1 Agustus 2026',
        targetAmount: 5000,
      );

      // Jalankan 5 panggilan markAsPaid secara simultan/konkuren
      await Future.wait([
        duesRepo.markAsPaid(duesPeriodId: period.id, studentId: doni.id, targetAmount: 5000),
        duesRepo.markAsPaid(duesPeriodId: period.id, studentId: doni.id, targetAmount: 5000),
        duesRepo.markAsPaid(duesPeriodId: period.id, studentId: doni.id, targetAmount: 5000),
        duesRepo.markAsPaid(duesPeriodId: period.id, studentId: doni.id, targetAmount: 5000),
        duesRepo.markAsPaid(duesPeriodId: period.id, studentId: doni.id, targetAmount: 5000),
      ]);

      final payment = await (db.select(db.duesPayments)
            ..where((t) => t.duesPeriodId.equals(period.id) & t.studentId.equals(doni.id)))
          .getSingle();

      expect(payment.isPaid, isTrue);
      expect(payment.amountPaid, 5000);
    });

    test('Self-healing: getOrCreateActivePeriod otomatis melengkapi dues_payments jika ada siswa baru/siswa lama yang belum tercatat di periode yang sudah ada', () async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 9D',
        grade: 9,
        treasurerName: 'Rian',
        supervisorName: 'Pak Hadi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      // Buat periode p1
      final p1 = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 1 Agustus 2026',
        targetAmount: 5000,
      );

      // Hapus paksa pembayaran p1 untuk simulasi data tidak sinkron
      await (db.delete(db.duesPayments)..where((t) => t.duesPeriodId.equals(p1.id))).go();

      // Tambahkan siswa baru langsung ke tabel students tanpa dues_payments
      const uuid = Uuid();
      final newStudentId = uuid.v4();
      await db.into(db.students).insert(
        StudentsCompanion.insert(
          id: newStudentId,
          academicYearId: year.id,
          attendanceNumber: 5,
          name: 'Siswa Manual',
          status: const Value('active'),
          createdAt: DateTime.now(),
        ),
      );

      // Panggil getOrCreateActivePeriod kembali pada p1 yang sudah ada
      final healedPeriod = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: 'Minggu 1 Agustus 2026',
        targetAmount: 5000,
      );
      expect(healedPeriod.id, p1.id);

      // Verifikasi bahwa data pembayaran di-self heal secara otomatis
      final healedPayment = await (db.select(db.duesPayments)
            ..where((t) => t.duesPeriodId.equals(p1.id) & t.studentId.equals(newStudentId)))
          .getSingleOrNull();

      expect(healedPayment, isNotNull);
      expect(healedPayment!.isPaid, isFalse);
      expect(healedPayment.amountPaid, 0);
    });

    test('copyStudentsToAcademicYear menginisialisasi dues_payments untuk seluruh periode yang sudah ada di kelas tujuan', () async {
      final sourceYear = await yearRepo.createAcademicYear(
        name: 'Kelas 7A Asal',
        grade: 7,
        treasurerName: 'Siti',
        supervisorName: 'Pak Guru',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2025, 7, 1),
        endDate: DateTime(2026, 6, 30),
      );
      await studentRepo.addStudent(academicYearId: sourceYear.id, attendanceNumber: 1, name: 'Siswa A');

      final targetYear = await yearRepo.createAcademicYear(
        name: 'Kelas 8A Tujuan',
        grade: 8,
        treasurerName: 'Siti',
        supervisorName: 'Pak Guru',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      // Di kelas tujuan sudah ada 1 periode berjalan
      final targetPeriod = await duesRepo.getOrCreateActivePeriod(
        academicYearId: targetYear.id,
        periodLabel: 'Minggu 1 Juli 2026',
        targetAmount: 5000,
      );

      // Salin siswa dari kelas 7A ke 8A
      final copied = await studentRepo.copyStudentsToAcademicYear(
        sourceAcademicYearId: sourceYear.id,
        targetAcademicYearId: targetYear.id,
      );
      expect(copied, 1);

      final targetStudents = await studentRepo.getStudents(targetYear.id);
      final copiedStudent = targetStudents.first;

      // Verifikasi entri dues_payments langsung terbentuk di periode target
      final copiedPayment = await (db.select(db.duesPayments)
            ..where((t) => t.duesPeriodId.equals(targetPeriod.id) & t.studentId.equals(copiedStudent.id)))
          .getSingleOrNull();

      expect(copiedPayment, isNotNull);
      expect(copiedPayment!.isPaid, isFalse);
    });

    testWidgets('Widget Test: Multi-period navigation - Rekonsiliasi 2 siswa 3 periode lalu tambah 1 siswa dan lunas di periode lampau', (tester) async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 8E',
        grade: 8,
        treasurerName: 'Budi',
        supervisorName: 'Bu Guru',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Siswa A');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Siswa B');
      final students = await studentRepo.getStudents(year.id);

      final now = DateTime.now();
      final currentLabel = formatPeriodLabel(now, 'weekly');
      final prevDate = DateTime(now.year, now.month, now.day - 7);
      final prevLabel = formatPeriodLabel(prevDate, 'weekly');

      // 1. Rekonsiliasi periode sekarang
      final pCurrent = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: currentLabel,
        targetAmount: 5000,
      );
      await duesRepo.markAsPaid(duesPeriodId: pCurrent.id, studentId: students[0].id, targetAmount: 5000);
      await duesRepo.markAsPaid(duesPeriodId: pCurrent.id, studentId: students[1].id, targetAmount: 5000);
      await duesRepo.reconcileIntoGeneralCash(period: pCurrent, academicYearId: year.id);

      // 2. Rekonsiliasi periode sebelumnya
      final pPrev = await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: prevLabel,
        targetAmount: 5000,
      );
      await duesRepo.markAsPaid(duesPeriodId: pPrev.id, studentId: students[0].id, targetAmount: 5000);
      await duesRepo.markAsPaid(duesPeriodId: pPrev.id, studentId: students[1].id, targetAmount: 5000);
      await duesRepo.reconcileIntoGeneralCash(period: pPrev, academicYearId: year.id);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
          subscriptionNotifierProvider.overrideWith(() => _StubSubscriptionNotifier(_activeInfo())),
        ],
      );
      addTearDown(() => container.dispose());

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DuesCheckScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tambahkan Siswa C via dialog
      await tester.tap(find.byTooltip('Tambah Siswa Baru'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Contoh: Bagas Pratama'), 'Siswa C');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Siswa'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Navigasi ke periode sebelumnya (prevLabel)
      await tester.tap(find.byTooltip('Periode Sebelumnya'));
      await tester.pumpAndSettle();

      expect(find.text(prevLabel), findsOneWidget);
      expect(find.text('Siswa C'), findsOneWidget);

      // Di periode sebelumnya, Siswa C awalnya Belum
      final belumSiswaC = find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Belum'),
      );
      expect(belumSiswaC, findsOneWidget);

      // Ketuk Belum -> Siswa C dipilih
      await tester.tap(belumSiswaC);
      await tester.pumpAndSettle();

      // Tombol bawah harus aktif dengan Simpan & Masukkan ke Kas Kelas (1 Siswa)
      final btnTambahan = find.widgetWithText(ElevatedButton, 'Simpan & Masukkan ke Kas Kelas (1 Siswa)');
      expect(btnTambahan, findsOneWidget);

      final btnWidget = tester.widget<ElevatedButton>(btnTambahan);
      expect(btnWidget.enabled, isTrue);

      await tester.tap(btnTambahan);
      await tester.pumpAndSettle();

      // Dialog 1: Konfirmasi Pembayaran Siswa
      expect(find.text('Konfirmasi Pembayaran Siswa'), findsOneWidget);
      await tester.tap(find.text('Ya, Sudah'));
      await tester.pumpAndSettle();

      // Dialog 2: Masukkan ke kas kelas?
      expect(find.text('Masukkan ke kas kelas?'), findsOneWidget);
      await tester.tap(find.text('Ya, Masukkan'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Semua Kas Periode Ini Sudah Dicatat'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Widget Test: 2-stage multi-pick confirmation - Batal Dialog 1, Batal Dialog 2, dan konfirmasi multi-siswa', (tester) async {
      final year = await yearRepo.createAcademicYear(
        name: 'Kelas 9F',
        grade: 9,
        treasurerName: 'Siti',
        supervisorName: 'Pak Dedi',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 1, name: 'Siswa X');
      await studentRepo.addStudent(academicYearId: year.id, attendanceNumber: 2, name: 'Siswa Y');
      final currentLabel = formatPeriodLabel(DateTime.now(), 'weekly');
      await duesRepo.getOrCreateActivePeriod(
        academicYearId: year.id,
        periodLabel: currentLabel,
        targetAmount: 5000,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          academicYearRepoProvider.overrideWithValue(yearRepo),
          studentRepoProvider.overrideWithValue(studentRepo),
          duesRepoProvider.overrideWithValue(duesRepo),
          transactionRepoProvider.overrideWithValue(txRepo),
          subscriptionNotifierProvider.overrideWith(() => _StubSubscriptionNotifier(_activeInfo())),
        ],
      );
      addTearDown(() => container.dispose());

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DuesCheckScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pilih Siswa X
      final belumX = find.descendant(of: find.byType(InkWell), matching: find.text('Belum')).first;
      await tester.tap(belumX);
      await tester.pumpAndSettle();

      // Tombol bawah menampilkan 1 siswa dipilih
      expect(find.widgetWithText(ElevatedButton, 'Simpan & Masukkan ke Kas Kelas (1 Siswa)'), findsOneWidget);

      // Pilih Siswa Y
      final belumY = find.descendant(of: find.byType(InkWell), matching: find.text('Belum')).first;
      await tester.tap(belumY);
      await tester.pumpAndSettle();

      // Tombol bawah menampilkan 2 siswa dipilih
      final btn2Siswa = find.widgetWithText(ElevatedButton, 'Simpan & Masukkan ke Kas Kelas (2 Siswa)');
      expect(btn2Siswa, findsOneWidget);

      // 1. Ketuk tombol -> Muncul Dialog 1, lalu Batal
      await tester.tap(btn2Siswa);
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi Pembayaran Siswa'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      // Tidak ada yang disimpan ke DB
      expect(find.widgetWithText(ElevatedButton, 'Simpan & Masukkan ke Kas Kelas (2 Siswa)'), findsOneWidget);

      // 2. Ketuk tombol lagi -> Dialog 1 Ya, lalu di Dialog 2 Batal
      await tester.tap(btn2Siswa);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, Sudah'));
      await tester.pumpAndSettle();
      expect(find.text('Masukkan ke kas kelas?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      // Tidak ada yang disimpan ke DB, pilihan masih 2 siswa
      expect(find.widgetWithText(ElevatedButton, 'Simpan & Masukkan ke Kas Kelas (2 Siswa)'), findsOneWidget);

      // 3. Konfirmasi penuh: Dialog 1 Ya, Dialog 2 Ya
      await tester.tap(btn2Siswa);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, Sudah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, Masukkan'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Keduanya sekarang lunas dan terkunci
      expect(find.text('Lunas'), findsNWidgets(2));
      expect(find.text('Semua Kas Periode Ini Sudah Dicatat'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
