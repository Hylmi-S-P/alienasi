import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/domain/services/pdf_report_service.dart';

/// Test khusus untuk memastikan fitur ekspor laporan bekerja TANPA jaringan.
///
/// Latar belakang bug: generator PDF sebelumnya memakai `PdfGoogleFonts`
/// yang mengunduh berkas font dari `fonts.gstatic.com`. Mobile test dan CI
/// tetap lulus karena mesinnya punya internet, tetapi di HP pengguna tanpa
/// koneksi seluruh ekspor PDF gagal. Test ini menutup celah tersebut dengan
/// memastikan font benar-benar berasal dari aset yang dibundle di APK.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Ekspor Offline - Font Bundled', () {
    test('1. Aset font Plus Jakarta Sans benar-benar terdaftar di AssetManifest', () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();

      expect(
        assets,
        contains('assets/fonts/PlusJakartaSans-Regular.ttf'),
        reason: 'Font regular wajib dibundle agar PDF dapat dibuat offline',
      );
      expect(
        assets,
        contains('assets/fonts/PlusJakartaSans-Bold.ttf'),
        reason: 'Font bold wajib dibundle agar PDF dapat dibuat offline',
      );
      expect(
        assets,
        contains('assets/fonts/PlusJakartaSans-SemiBold.ttf'),
        reason: 'Font semi-bold wajib dibundle agar PDF dapat dibuat offline',
      );
    });

    test('2. loadReportFonts memuat font dari aset lokal tanpa jaringan', () async {
      final fonts = await PdfReportService.loadReportFonts();

      expect(fonts.regular, isA<pw.Font>());
      expect(fonts.bold, isA<pw.Font>());
      expect(fonts.semiBold, isA<pw.Font>());
    });

    test('3. generateReportPdf menghasilkan PDF valid dari aset lokal', () async {
      final year = AcademicYear(
        id: 'year_offline',
        name: 'Kelas 7A - SMP Negeri 1',
        grade: 7,
        treasurerName: 'Siti Bendahara',
        supervisorName: 'Ibu Pengawas',
        defaultDuesAmount: 5000,
        duesPeriodType: 'weekly',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

      final category = Category(
        id: 'cat_offline',
        type: 'expense',
        name: 'Alat Tulis & Spidol',
        iconName: 'edit_note_rounded',
        colorHex: '#DC2626',
        isDefault: true,
        createdAt: DateTime(2026, 7, 1),
      );

      final items = [
        TransactionWithCategory(
          transaction: Transaction(
            id: 'tx_offline_1',
            academicYearId: year.id,
            categoryId: category.id,
            type: 'income',
            amount: 150000,
            title: 'Iuran kas minggu ke-1',
            description: 'Dari 30 siswa',
            transactionDate: DateTime(2026, 7, 6),
            createdAt: DateTime(2026, 7, 6),
            updatedAt: DateTime(2026, 7, 6),
          ),
          category: category,
          academicYear: year,
        ),
        TransactionWithCategory(
          transaction: Transaction(
            id: 'tx_offline_2',
            academicYearId: year.id,
            categoryId: category.id,
            type: 'expense',
            amount: 25000,
            title: 'Beli 2 spidol hitam & 1 penghapus papan',
            description: 'Nota terlampir',
            transactionDate: DateTime(2026, 7, 10),
            createdAt: DateTime(2026, 7, 10),
            updatedAt: DateTime(2026, 7, 10),
          ),
          category: category,
          academicYear: year,
        ),
      ];

      final bytes = await PdfReportService.generateReportPdf(
        academicYear: year,
        periodRangeTitle: '1 Bulan (Juli 2026)',
        items: items,
      );

      // PDF valid selalu diawali magic number %PDF-
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
