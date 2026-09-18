import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bendahara_app/main.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/screens/dialogs/class_setup_dialog.dart';
import 'package:bendahara_app/presentation/screens/dialogs/category_management_dialog.dart';
import 'package:bendahara_app/presentation/screens/transaction_form_screen.dart';
import 'package:bendahara_app/presentation/screens/dues_check_screen.dart';
import 'package:bendahara_app/presentation/screens/supervision_report_screen.dart';
import 'package:bendahara_app/presentation/screens/dialogs/advance_grade_dialog.dart';
import 'package:bendahara_app/presentation/screens/dialogs/new_student_dialog.dart';
import 'package:bendahara_app/presentation/widgets/financial_chart_card.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('BendaharaApp builds smoke test and verifies Laporan tab replaces Supervisi Ibu', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(() async => await db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const BendaharaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BendaharaApp), findsOneWidget);

    // Tab Laporan harus ada, sedangkan Supervisi Ibu tidak boleh ada
    expect(find.text('Laporan'), findsOneWidget);
    expect(find.text('Supervisi Ibu'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Tab Laporan dapat dibuka tanpa fatal assertion error dan menampilkan FinancialChartCard', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(() async => await db.close());

    // Siapkan data kelas awal di database
    final now = DateTime.now();
    await db.into(db.academicYears).insert(
      AcademicYearsCompanion.insert(
        id: 'year_test_1',
        name: 'Kelas 7A - SMP Negeri 1',
        grade: 7,
        treasurerName: const Value('Adik Fajar'),
        supervisorName: const Value('Ibu Rina'),
        defaultDuesAmount: const Value(5000),
        startDate: DateTime(now.year, 7, 1),
        endDate: DateTime(now.year + 1, 6, 30),
        isActive: const Value(true),
        createdAt: now,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const BendaharaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Ketuk tab Laporan
    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();

    // Verifikasi layar Laporan terbuka dan menampilkan FinancialChartCard
    expect(find.byType(FinancialChartCard), findsOneWidget);
    expect(find.text('Grafik Analisis Keuangan'), findsOneWidget);
    expect(find.text('Pusat Laporan Kas & Ekspor'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('ClassSetupDialog tidak lagi memiliki opsi isi otomatis 32 daftar siswa contoh', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(() async => await db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ClassSetupDialog(isDismissible: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi checkbox otomatis 32 siswa tidak ada
    expect(find.text('Isi otomatis 32 daftar nama siswa contoh'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('TransactionFormScreen memiliki tombol Back yang berfungsi ketika di-push', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(() async => await db.close());

    final now = DateTime.now();
    await db.into(db.academicYears).insert(
      AcademicYearsCompanion.insert(
        id: 'year_test_2',
        name: 'Kelas 7A',
        grade: 7,
        startDate: DateTime(now.year, 7, 1),
        endDate: DateTime(now.year + 1, 6, 30),
        isActive: const Value(true),
        createdAt: now,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TransactionFormScreen(initialType: 'income'),
                  ),
                );
              },
              child: const Text('Buka Catat Kas'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Buka screen
    await tester.tap(find.text('Buka Catat Kas'));
    await tester.pumpAndSettle();

    // Verifikasi tombol kembali (BackButton / arrow_back) ada di AppBar
    final backBtn = find.byTooltip('Kembali');
    expect(backBtn, findsOneWidget);

    // Ketuk tombol kembali
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Kembali ke screen awal
    expect(find.text('Buka Catat Kas'), findsOneWidget);
    expect(find.byType(TransactionFormScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('CategoryManagementDialog menampilkan pengelolaan kategori dan aturan minimal 1 kategori', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(() async => await db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CategoryManagementDialog(initialType: 'expense'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kelola Kategori'), findsOneWidget);
    expect(find.text('Minimal harus ada 1 kategori dipertahankan. Nama dapat diedit kapan saja.'), findsOneWidget);
    expect(find.text('+ Tambah'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('TransactionFormScreen submission in Tab 2 does not crash/exit app and calls onBackToDashboard', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(() async => await db.close());

    final now = DateTime.now();
    await db.into(db.academicYears).insert(
      AcademicYearsCompanion.insert(
        id: 'year_tab_test',
        name: 'Kelas 7A',
        grade: 7,
        startDate: DateTime(now.year, 7, 1),
        endDate: DateTime(now.year + 1, 6, 30),
        isActive: const Value(true),
        createdAt: now,
      ),
    );

    bool backCalled = false;

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TransactionFormScreen(
              initialType: 'income',
              onBackToDashboard: () => backCalled = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Isi nominal dan judul
    await tester.enterText(find.byType(TextFormField).at(0), '50000');
    await tester.enterText(find.byType(TextFormField).at(1), 'Iuran Tambahan');
    await tester.pumpAndSettle();

    // Tekan tombol simpan
    await tester.tap(find.text('Simpan Pemasukan Kas'));
    await tester.pumpAndSettle();

    // Verifikasi bahwa onBackToDashboard dipanggil dan tidak terjadi error/crash
    expect(backCalled, isTrue);
    expect(find.text('Pemasukan berhasil dicatat!'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('DuesCheckScreen, TransactionFormScreen, and SupervisionReportScreen invoke onBackToDashboard via BackButton', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(() async => await db.close());

    final now = DateTime.now();
    await db.into(db.academicYears).insert(
      AcademicYearsCompanion.insert(
        id: 'year_back_test',
        name: 'Kelas 7A',
        grade: 7,
        startDate: DateTime(now.year, 7, 1),
        endDate: DateTime(now.year + 1, 6, 30),
        isActive: const Value(true),
        createdAt: now,
      ),
    );

    int backPressCount = 0;

    // 1. DuesCheckScreen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: DuesCheckScreen(onBackToDashboard: () => backPressCount++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final backBtnDues = find.byTooltip('Kembali');
    expect(backBtnDues, findsOneWidget);
    await tester.tap(backBtnDues);
    await tester.pumpAndSettle();
    expect(backPressCount, 1);

    // 2. TransactionFormScreen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: TransactionFormScreen(onBackToDashboard: () => backPressCount++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final backBtnTx = find.byTooltip('Kembali');
    expect(backBtnTx, findsOneWidget);
    await tester.tap(backBtnTx);
    await tester.pumpAndSettle();
    expect(backPressCount, 2);

    // 3. SupervisionReportScreen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: SupervisionReportScreen(onBackToDashboard: () => backPressCount++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final backBtnRep = find.byTooltip('Kembali');
    expect(backBtnRep, findsOneWidget);
    await tester.tap(backBtnRep);
    await tester.pumpAndSettle();
    expect(backPressCount, 3);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Dialogs (ClassSetupDialog, AdvanceGradeDialog, NewStudentDialog) have close buttons and dismiss properly', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(() async => await db.close());

    final now = DateTime.now();
    final testYear = AcademicYear(
      id: 'year_dialog_test',
      name: 'Kelas 7A',
      grade: 7,
      treasurerName: 'Fajar',
      supervisorName: 'Pengawas',
      startDate: DateTime(now.year, 7, 1),
      endDate: DateTime(now.year + 1, 6, 30),
      defaultDuesAmount: 5000,
      duesPeriodType: 'weekly',
      isActive: true,
      createdAt: now,
    );

    // 1. ClassSetupDialog close button
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: Scaffold(
            body: ClassSetupDialog(isDismissible: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tutup'), findsOneWidget);

    // 2. AdvanceGradeDialog close button
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: AdvanceGradeDialog(currentYear: testYear),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tutup'), findsOneWidget);

    // 3. NewStudentDialog close button
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: Scaffold(
            body: NewStudentDialog(
              academicYearId: 'year_dialog_test',
              defaultAttendanceNumber: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tutup'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Screens when activeYear is null still have Back buttons and do not trap user', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(() async => await db.close());

    int backCount = 0;

    // 1. DuesCheckScreen with activeYear == null
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: DuesCheckScreen(onBackToDashboard: () => backCount++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Silakan pilih atau atur kelas terlebih dahulu.'), findsOneWidget);
    expect(find.byTooltip('Kembali'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(backCount, 1);

    // 2. TransactionFormScreen with activeYear == null
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: TransactionFormScreen(onBackToDashboard: () => backCount++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kelas belum disetel'), findsOneWidget);
    expect(find.byTooltip('Kembali'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(backCount, 2);

    // 3. SupervisionReportScreen with activeYear == null
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: SupervisionReportScreen(onBackToDashboard: () => backCount++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Silakan atur kelas terlebih dahulu'), findsOneWidget);
    expect(find.byTooltip('Kembali'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(backCount, 3);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('ClassSetupDialog with existingYear edits class without creating duplicate academic years', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(() async => await db.close());

    final now = DateTime.now();
    await db.into(db.academicYears).insert(
      AcademicYearsCompanion.insert(
        id: 'edit_year_1',
        name: 'Kelas 7A Awal',
        grade: 7,
        treasurerName: const Value('Adik'),
        supervisorName: const Value('Ibu'),
        defaultDuesAmount: const Value(5000),
        startDate: DateTime(now.year, 7, 1),
        endDate: DateTime(now.year + 1, 6, 30),
        isActive: const Value(true),
        createdAt: now,
      ),
    );

    final currentYear = await (db.select(db.academicYears)..where((y) => y.id.equals('edit_year_1'))).getSingle();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: ClassSetupDialog(
              isDismissible: true,
              existingYear: currentYear,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi header 'Ubah Info Kelas' dan nilai awal terisi
    expect(find.text('Ubah Info Kelas'), findsOneWidget);
    expect(find.text('Kelas 7A Awal'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);

    // Ubah nama kelas
    await tester.enterText(find.widgetWithText(TextFormField, 'Kelas 7A Awal'), 'Kelas 7A Revisi');
    await tester.pumpAndSettle();

    // Simpan
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    // Verifikasi di DB: hanya ada 1 tahun dan namanya terupdate
    final allYears = await db.select(db.academicYears).get();
    expect(allYears.length, 1);
    expect(allYears.first.id, 'edit_year_1');
    expect(allYears.first.name, 'Kelas 7A Revisi');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
