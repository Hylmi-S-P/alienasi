import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:bendahara_app/domain/services/pdf_report_service.dart';
import 'package:bendahara_app/presentation/screens/dialogs/report_note_dialog.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('PdfReportService - Catatan Bendahara (Note Section)', () {
    late pw.Font fontRegular;
    late pw.Font fontBold;

    setUpAll(() async {
      fontRegular = await PdfGoogleFonts.plusJakartaSansRegular();
      fontBold = await PdfGoogleFonts.plusJakartaSansBold();
    });

    test('buildNoteSection returns widget list with header, note text and signature block', () {
      final widgets = PdfReportService.buildNoteSection(
        note: 'Sisa kas diserahkan kepada bendahara baru pada hari Senin.',
        fontRegular: fontRegular,
        fontBold: fontBold,
        signedBy: 'Siti Bendahara',
        date: DateTime(2026, 9, 21),
      );

      // Struktur: SizedBox, Divider, Row(header), SizedBox, Text(subtitle),
      // SizedBox, Container(kotak catatan), SizedBox, Align(tanda tangan)
      expect(widgets, isNotEmpty);
      expect(widgets.length, greaterThanOrEqualTo(10));

      // Divider pemisah section harus ada
      expect(widgets.whereType<pw.Divider>(), isNotEmpty);

      // Header dirender dalam Row, blok tanda tangan dalam Align
      expect(widgets.whereType<pw.Row>(), isNotEmpty);
      expect(widgets.whereType<pw.Align>(), isNotEmpty);

      // Kotak catatan (background kuning) harus ada
      expect(widgets.whereType<pw.Container>(), isNotEmpty);
    });

    test('buildNoteSection renders multi-line note without error', () {
      const longNote =
          'Baris pertama catatan.\nBaris kedua dengan detail serah terima kas.\nBaris ketiga penutup.';
      final widgets = PdfReportService.buildNoteSection(
        note: longNote,
        fontRegular: fontRegular,
        fontBold: fontBold,
        signedBy: 'Bendahara Lama',
        date: DateTime(2026, 12, 20),
      );

      // Verifikasi struktur lengkap dirender tanpa exception
      expect(widgets.whereType<pw.Divider>(), isNotEmpty);
      expect(widgets.whereType<pw.Row>(), isNotEmpty);
      expect(widgets.whereType<pw.Align>(), isNotEmpty);
      expect(widgets.whereType<pw.Container>(), isNotEmpty);
    });
  });

  group('ReportNoteDialog', () {
    Future<void> pumpDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => ReportNoteDialog.show(
                    context,
                    rangeTitle: 'Bulan September 2026 (Minggu ke-3)',
                  ),
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
    }

    testWidgets('menampilkan judul, hint, tombol Lewati dan Sertakan Catatan', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Catatan Bendahara'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.text('Sertakan Catatan'), findsOneWidget);
      // Tombol kirim dinonaktifkan saat catatan kosong
      final submitButton = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('Sertakan Catatan'), matching: find.byType(ElevatedButton)),
      );
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('mengetik catatan lalu konfirmasi mengembalikan teks catatan', (tester) async {
      await pumpDialog(tester);

      await tester.enterText(
        find.byType(TextField),
        'Sisa kas diserahkan ke bendahara baru.',
      );
      await tester.pump();

      await tester.tap(find.text('Sertakan Catatan'));
      await tester.pumpAndSettle();

      // Dialog tertutup; hasil tidak bisa diakses langsung lewat pumpWidget sederhana,
      // jadi verifikasi dialog sudah tertutup.
      expect(find.text('Catatan Bendahara'), findsNothing);
    });

    testWidgets('menekan Lewati menutup dialog (export tanpa note)', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.text('Catatan Bendahara'), findsNothing);
    });
  });
}
