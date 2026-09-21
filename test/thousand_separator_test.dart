import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:bendahara_app/core/utils/currency_formatter.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/academic_year_repository.dart';
import 'package:bendahara_app/data/repositories/transaction_repository.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/screens/transaction_form_screen.dart';
import 'package:bendahara_app/presentation/screens/dialogs/class_setup_dialog.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  group('Unit Test: CurrencyFormatter.parseAmount & ThousandSeparatorInputFormatter', () {
    test('CurrencyFormatter.parseAmount parses dot-separated thousands correctly', () {
      expect(CurrencyFormatter.parseAmount('1.000'), 1000);
      expect(CurrencyFormatter.parseAmount('2.000'), 2000);
      expect(CurrencyFormatter.parseAmount('10.000'), 10000);
      expect(CurrencyFormatter.parseAmount('100.000'), 100000);
      expect(CurrencyFormatter.parseAmount('1.000.000'), 1000000);
      expect(CurrencyFormatter.parseAmount('Rp 25.000'), 25000);
      expect(CurrencyFormatter.parseAmount(''), 0);
      expect(CurrencyFormatter.parseAmount(null), 0);
      expect(CurrencyFormatter.parseAmount('500'), 500);
    });

    test('ThousandSeparatorInputFormatter formats numbers with dots as thousand separators', () {
      final formatter = ThousandSeparatorInputFormatter();

      // 1000 -> 1.000
      final res1000 = formatter.formatEditUpdate(
        const TextEditingValue(text: '100', selection: TextSelection.collapsed(offset: 3)),
        const TextEditingValue(text: '1000', selection: TextSelection.collapsed(offset: 4)),
      );
      expect(res1000.text, '1.000');
      expect(res1000.selection.end, 5);

      // 10000 -> 10.000
      final res10k = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.000', selection: TextSelection.collapsed(offset: 5)),
        const TextEditingValue(text: '1.0000', selection: TextSelection.collapsed(offset: 6)),
      );
      expect(res10k.text, '10.000');
      expect(res10k.selection.end, 6);

      // 2000 -> 2.000
      final res2k = formatter.formatEditUpdate(
        const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0)),
        const TextEditingValue(text: '2000', selection: TextSelection.collapsed(offset: 4)),
      );
      expect(res2k.text, '2.000');

      // Backspace: 1.000 -> 100
      final resBack = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.000', selection: TextSelection.collapsed(offset: 5)),
        const TextEditingValue(text: '1.00', selection: TextSelection.collapsed(offset: 4)),
      );
      expect(resBack.text, '100');
      expect(resBack.selection.end, 3);
    });
  });

  group('Widget Test: Live Thousand Separator in TransactionFormScreen & ClassSetupDialog', () {
    late AppDatabase db;
    late AcademicYearRepository yearRepo;
    late TransactionRepository txRepo;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      yearRepo = AcademicYearRepository(db);
      txRepo = TransactionRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('TransactionFormScreen formats input live as 10.000 and quick chips format with dots', (tester) async {
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            academicYearRepoProvider.overrideWithValue(yearRepo),
            transactionRepoProvider.overrideWithValue(txRepo),
            activeAcademicYearProvider.overrideWith((ref) => Stream.value(year)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TransactionFormScreen(initialType: 'income'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find nominal TextFormField
      final amountFieldFinder = find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.prefixText == 'Rp '),
      );
      expect(amountFieldFinder, findsOneWidget);

      // Enter '10000'
      await tester.enterText(amountFieldFinder, '10000');
      await tester.pumpAndSettle();

      // Verify that TextField displays '10.000' with dots!
      final textFieldWidget = tester.widget<TextField>(amountFieldFinder);
      expect(textFieldWidget.controller?.text, '10.000');

      // Tap quick chip '+5.000'
      final chip5k = find.text('+5.000');
      expect(chip5k, findsOneWidget);
      await tester.tap(chip5k);
      await tester.pumpAndSettle();

      // 10.000 + 5.000 = 15.000
      expect(textFieldWidget.controller?.text, '15.000');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('ClassSetupDialog displays 5.000 default dues and formats user input with dots', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            academicYearRepoProvider.overrideWithValue(yearRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ClassSetupDialog(isDismissible: true),
            ),
          ),
        ),
      );
      // Find TextField with prefix 'Rp '
      final duesFieldFinder = find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.prefixText == 'Rp '),
      );
      expect(duesFieldFinder, findsOneWidget);

      final initialDuesWidget = tester.widget<TextField>(duesFieldFinder);
      expect(initialDuesWidget.controller?.text, '5.000');

      // Enter '20000'
      await tester.enterText(duesFieldFinder, '20000');
      await tester.pumpAndSettle();

      final duesFieldWidget = tester.widget<TextField>(duesFieldFinder);
      expect(duesFieldWidget.controller?.text, '20.000');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
