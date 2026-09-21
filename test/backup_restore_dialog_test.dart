import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/presentation/providers/app_providers.dart';
import 'package:bendahara_app/presentation/screens/dialogs/backup_restore_dialog.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('BackupRestoreDialog renders backup and restore cards properly', (tester) async {
    final db = AppDatabase.forTesting(drift.DatabaseConnection(NativeDatabase.memory()));
    addTearDown(() => db.close());

    final year = AcademicYear(
      id: 'year-1',
      name: 'Kelas 9A Hebat',
      grade: 9,
      treasurerName: 'Siti Rahayu',
      supervisorName: 'Ibu Guru',
      defaultDuesAmount: 5000,
      duesPeriodType: 'weekly',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2027, 6, 30),
      isActive: true,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BackupRestoreDialog.show(context, academicYear: year),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    // Buka dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verifikasi dialog ter-render dengan komponen lengkap
    expect(find.text('Cadangkan & Pulihkan'), findsOneWidget);
    expect(find.text('Kelas: Kelas 9A Hebat'), findsOneWidget);
    expect(find.text('Cadangkan Data (Backup)'), findsOneWidget);
    expect(find.text('Pulihkan Data (Restore)'), findsOneWidget);
    expect(find.text('Cadangkan Data Sekarang'), findsOneWidget);
    expect(find.text('Pilih Berkas Cadangan (.json)'), findsOneWidget);
  });
}
