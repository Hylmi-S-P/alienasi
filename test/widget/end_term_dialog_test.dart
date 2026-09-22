import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/domain/services/pdf_report_service.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/screens/dialogs/end_term_dialog.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      return Directory.systemTemp.path;
    });

    // Panaskan cache font aset (bukan unduhan jaringan) agar dialog dapat
    // merender laporan PDF tanpa koneksi internet.
    await PdfReportService.loadReportFonts();
  });

  late AppDatabase db;
  late AcademicYear year;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.academicYears).insert(
      AcademicYearsCompanion.insert(
        id: 'test_year_endterm',
        name: 'Kelas 7A - SMP Negeri 1',
        grade: 7,
        treasurerName: const Value('Siti Bendahara'),
        supervisorName: const Value('Pak Wali'),
        defaultDuesAmount: const Value(5000),
        duesPeriodType: const Value('daily'),
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
        isActive: const Value(true),
        createdAt: DateTime(2026, 7, 1),
      ),
    );
    year = await (db.select(db.academicYears)
          ..where((t) => t.id.equals('test_year_endterm')))
        .getSingle();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => EndTermDialog.show(context, academicYear: year),
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('intro step menampilkan ringkasan kelas dan tombol mulai', (tester) async {
    await pumpDialog(tester);

    expect(find.text('Akhiri Jabatan Bendahara'), findsOneWidget);
    expect(find.text('Mulai Pengamanan Data'), findsOneWidget);
    expect(find.text('Saldo Kas Saat Ini'), findsOneWidget);
    expect(find.text('Kelas 7A - SMP Negeri 1'), findsWidgets);
  });

  testWidgets('tombol tutup (X) pada dialog note mengembalikan ke intro, bukan stuck loading', (tester) async {
    await pumpDialog(tester);

    // Mulai proses backup (dialog catatan langsung muncul)
    await tester.tap(find.text('Mulai Pengamanan Data'));
    await tester.pumpAndSettle();

    // Dialog catatan harus terlihat
    expect(find.text('Catatan Bendahara'), findsOneWidget);

    // Tekan X (close) pada dialog note
    await tester.tap(find.byTooltip('Batal'));
    await tester.pumpAndSettle();

    // Harus kembali ke intro, bukan stuck di loading
    expect(find.text('Mulai Pengamanan Data'), findsOneWidget);
    expect(find.text('Menyiapkan berkas pengamanan data...'), findsNothing);
    expect(find.text('Catatan Bendahara'), findsNothing);
  });

  testWidgets('tombol Lewati lanjut ke tahap 1/2 PDF, lalu lanjut ke 2/2 JSON, hingga konfirmasi HAPUS', (tester) async {
    await pumpDialog(tester);

    // 1. Mulai pengamanan
    await tester.tap(find.text('Mulai Pengamanan Data'));
    await tester.pumpAndSettle();
    expect(find.text('Catatan Bendahara'), findsOneWidget);

    // 2. Tekan Lewati
    await tester.tap(find.text('Lewati'));
    await tester.pump(const Duration(milliseconds: 300)); // dismisses dialog, shows working state

    // Poll until PDF generation completes and Tahap 1/2 renders
    for (int i = 0; i < 50; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Simpan PDF Laporan Lengkap').evaluate().isNotEmpty) break;
    }

    // Harus berada di Tahap 1/2 Simpan PDF Laporan Lengkap
    expect(find.text('Simpan PDF Laporan Lengkap'), findsOneWidget);
    expect(find.text('Pratinjau PDF'), findsOneWidget);
    expect(find.text('Simpan / Bagikan'), findsOneWidget);
    expect(find.text('Lanjut ke Cadangan Data (2/2)'), findsOneWidget);

    // 3. Tekan Lanjut ke Cadangan Data (2/2)
    await tester.tap(find.text('Lanjut ke Cadangan Data (2/2)'));
    await tester.pump(const Duration(milliseconds: 300));

    // Poll until JSON backup completes and Tahap 2/2 renders
    for (int i = 0; i < 30; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Simpan Berkas Cadangan Data (JSON)').evaluate().isNotEmpty) break;
    }

    // Harus berada di Tahap 2/2 Simpan Berkas Cadangan Data (JSON)
    expect(find.text('Simpan Berkas Cadangan Data (JSON)'), findsOneWidget);
    expect(find.text('Simpan / Bagikan'), findsOneWidget);
    expect(find.text('Lanjut ke Konfirmasi Reset'), findsOneWidget);

    // 4. Tekan Lanjut ke Konfirmasi Reset
    await tester.tap(find.text('Lanjut ke Konfirmasi Reset'));
    await tester.pumpAndSettle();

    // Harus berada di tahap konfirmasi reset (ketik HAPUS)
    expect(find.text('Hapus Semua Data & Akhiri Jabatan'), findsOneWidget);
    expect(find.text('Ketik HAPUS di sini'), findsOneWidget);
  });

  testWidgets('setelah ketik HAPUS muncul 2 modal konfirmasi berurutan lalu menampilkan layar sukses sebelum onboarding', (tester) async {
    await pumpDialog(tester);

    // 1. Lewati note
    await tester.tap(find.text('Mulai Pengamanan Data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lewati'));
    await tester.pump(const Duration(milliseconds: 300));

    // Tunggu PDF selesai dibuat
    for (int i = 0; i < 50; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Simpan PDF Laporan Lengkap').evaluate().isNotEmpty) break;
    }

    // Lanjut ke JSON
    await tester.tap(find.text('Lanjut ke Cadangan Data (2/2)'));
    await tester.pump(const Duration(milliseconds: 300));
    for (int i = 0; i < 30; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Simpan Berkas Cadangan Data (JSON)').evaluate().isNotEmpty) break;
    }

    // Lanjut ke konfirmasi HAPUS
    await tester.tap(find.text('Lanjut ke Konfirmasi Reset'));
    await tester.pumpAndSettle();

    // Tombol nonaktif jika belum ketik HAPUS
    final deleteButtonFinder = find.widgetWithText(ElevatedButton, 'Hapus Semua Data & Akhiri Jabatan');
    expect(tester.widget<ElevatedButton>(deleteButtonFinder).onPressed, isNull);

    // Ketik HAPUS
    await tester.enterText(find.byType(TextField), 'HAPUS');
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(deleteButtonFinder).onPressed, isNotNull);

    // Tekan tombol Hapus -> Muncul Modal Konfirmasi 1 / 2
    await tester.tap(deleteButtonFinder);
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi Penghapusan (1/2)'), findsOneWidget);
    expect(find.text('Lanjut ke Peringatan Akhir'), findsOneWidget);

    // Uji batal pada modal 1
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi Penghapusan (1/2)'), findsNothing);
    expect(find.text('Hapus Semua Data & Akhiri Jabatan'), findsOneWidget);

    // Buka lagi modal 1 -> Lanjut ke Modal Konfirmasi 2 / 2
    await tester.tap(deleteButtonFinder);
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi Penghapusan (1/2)'), findsOneWidget);
    await tester.tap(find.text('Lanjut ke Peringatan Akhir'));
    await tester.pumpAndSettle();

    // Modal 2 muncul
    expect(find.text('Peringatan Terakhir (2/2)'), findsOneWidget);
    expect(find.text('Hapus Permanen Sekarang'), findsOneWidget);

    // Uji batal pada modal 2
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Peringatan Terakhir (2/2)'), findsNothing);
    expect(find.text('Hapus Semua Data & Akhiri Jabatan'), findsOneWidget);

    // Buka modal 1 -> buka modal 2 -> setujui Hapus Permanen
    await tester.tap(deleteButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut ke Peringatan Akhir'));
    await tester.pumpAndSettle();
    expect(find.text('Peringatan Terakhir (2/2)'), findsOneWidget);

    // Konfirmasi penghapusan permanen
    await tester.tap(find.text('Hapus Permanen Sekarang'));
    await tester.pumpAndSettle();

    // Harus menampilkan layar sukses "Data Berhasil Dihapus", BUKAN langsung menutup/onboarding
    expect(find.text('Data Berhasil Dihapus'), findsOneWidget);
    expect(find.text('Lanjut ke Pengaturan Kelas Baru'), findsOneWidget);

    // Tekan "Lanjut ke Pengaturan Kelas Baru" -> Dialog tertutup
    await tester.tap(find.text('Lanjut ke Pengaturan Kelas Baru'));
    await tester.pumpAndSettle();

    // Dialog sudah tertutup
    expect(find.text('Data Berhasil Dihapus'), findsNothing);
    expect(find.text('Buka'), findsOneWidget);
  });
}
