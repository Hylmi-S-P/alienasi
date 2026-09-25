import 'dart:async';

import 'package:bendahara_app/core/license/license_engine.dart';
import 'package:bendahara_app/data/database/app_database.dart';
import 'package:bendahara_app/data/repositories/license_repository.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_license.dart' as license_tool;

void main() {
  late AppDatabase db;
  late LicenseRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    repo = LicenseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('tool/generate_license.dart outputs valid 28-day token that activates repo', () async {
    final printedLines = <String>[];
    runZoned(
      () => license_tool.main([]),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          printedLines.add(line);
        },
      ),
    );

    final fullOutput = printedLines.join('\n');
    expect(fullOutput, contains('BENDAHARA APP — 28-DAY LICENSE GENERATOR'));
    expect(fullOutput, contains('Kode Aktivasi : BNDH-'));

    // Ekstrak token dari output
    final match = RegExp(r'Kode Aktivasi : (BNDH-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4})').firstMatch(fullOutput);
    expect(match, isNotNull);
    final token = match!.group(1)!;

    // Verifikasi mesin lisensi menerima token tersebut
    final validation = LicenseEngine.validate(token: token);
    expect(validation.isValid, isTrue);
    expect(validation.validity?.inDays, 28);

    // Verifikasi token berhasil mengaktivasi aplikasi via LicenseRepository
    final activationResult = await repo.activate(token);
    expect(activationResult.saved, isTrue);

    final current = await repo.getCurrent();
    expect(current, isNotNull);
    expect(LicenseEngine.normalize(current!.activationCode), LicenseEngine.normalize(token));
  });
}
