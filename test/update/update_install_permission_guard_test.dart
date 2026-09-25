import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bendahara_app/core/update/update_manifest.dart';
import 'package:bendahara_app/presentation/providers/update_notifier.dart';
import 'package:bendahara_app/presentation/screens/dialogs/update_check_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const manifest = UpdateManifest(
    latestVersion: '1.0.3',
    releaseNotes: 'Perbaikan bug dan penguncian tombol instalasi.',
    apkUrl: 'https://example.com/app.apk',
  );

  testWidgets(
      'ReadyToInstall: Install button is LOCKED and disabled when permission is not active',
      (tester) async {
    bool canInstallMock = false;
    bool openedSettings = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          canRequestPackageInstallsProvider
              .overrideWithValue(() async => canInstallMock),
          openUnknownAppsSettingsProvider.overrideWithValue(() async {
            openedSettings = true;
            return true;
          }),
          updateNotifierProvider.overrideWith(
            () => _ReadyTestNotifier(
              const UpdateState(
                status: UpdateStatus.readyToInstall,
                currentVersion: '1.0.2',
                manifest: manifest,
                apkPath: '/dummy/path/BendaharaAlien-1.0.3.apk',
                downloadProgress: 1.0,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: UpdateCheckSheet(),
          ),
        ),
      ),
    );

    // Initial check triggers
    await tester.pump();

    // Verify permission warning card is shown
    expect(find.text('Langkah Wajib: Izinkan Sumber Ini'), findsOneWidget);
    expect(find.byKey(const ValueKey('open_install_permission_btn')),
        findsOneWidget);

    // Verify install button is present but LOCKED (disabled onPressed == null)
    final installBtnFinder = find.byKey(const ValueKey('update_install_btn'));
    expect(installBtnFinder, findsOneWidget);

    final outlinedBtn = tester.widget<OutlinedButton>(installBtnFinder);
    expect(outlinedBtn.onPressed, isNull,
        reason:
            'Install button MUST be null (disabled) until permission is granted');
    expect(
        find.text('2. Pasang Pembaruan (Terkunci)'), findsOneWidget);

    // Tap open settings
    await tester.tap(find.byKey(const ValueKey('open_install_permission_btn')));
    expect(openedSettings, isTrue);

    // Now simulate user granting permission in settings and returning to app (resumed)
    canInstallMock = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Verify permission card switches to active
    expect(find.text('Izin pemasangan dari sumber ini sudah aktif.'),
        findsOneWidget);

    // Verify install button UNLOCKS and becomes active ElevatedButton
    final unlockedBtnFinder = find.byKey(const ValueKey('update_install_btn'));
    expect(unlockedBtnFinder, findsOneWidget);

    final elevatedBtn = tester.widget<ElevatedButton>(unlockedBtnFinder);
    expect(elevatedBtn.onPressed, isNotNull,
        reason: 'Install button MUST unlock once permission requirement is met');
    expect(find.text('Pasang Pembaruan Sekarang'), findsOneWidget);
  });
}

class _ReadyTestNotifier extends UpdateNotifier {
  final UpdateState _initial;
  _ReadyTestNotifier(this._initial);

  @override
  UpdateState build() => _initial;

  @override
  Future<void> checkForUpdate() async {}
}
