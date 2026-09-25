import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bendahara_app/core/update/update_error_info.dart';
import 'package:bendahara_app/core/update/update_manifest.dart';
import 'package:bendahara_app/presentation/providers/update_notifier.dart';
import 'package:bendahara_app/presentation/screens/dialogs/update_check_sheet.dart';

class _ManualNotifier extends UpdateNotifier {
  _ManualNotifier(this.initial);
  final UpdateState initial;

  @override
  UpdateState build() => initial;

  @override
  Future<void> checkForUpdate() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateErrorInfo Diagnostics', () {
    test('parses HTTP 404 with accurate diagnosis and user message', () {
      final info = UpdateErrorInfo.fromError(
        const HttpException('Server manifest membalas kode 404.'),
        targetUrl: 'https://bendahara-kelas.github.io/app/manifest.json',
      );

      expect(info.statusCode, 404);
      expect(info.title, contains('404'));
      expect(info.userMessage, contains('HTTP 404 Not Found'));
      expect(info.userMessage, contains('Koneksi internet perangkat Anda aktif normal'));
      expect(info.technicalLog, contains('Target URL     : https://bendahara-kelas.github.io/app/manifest.json'));
      expect(info.technicalLog, contains('Status HTTP    : 404'));
    });

    test('parses SocketException for network unreachable', () {
      final info = UpdateErrorInfo.fromError(
        const SocketException('Failed host lookup: bendahara-kelas.github.io'),
        targetUrl: 'https://bendahara-kelas.github.io/app/manifest.json',
      );

      expect(info.title, 'Koneksi ke Server Terputus');
      expect(info.userMessage, contains('Tidak dapat menghubungi server hosting'));
      expect(info.technicalLog, contains('Failed host lookup'));
    });
  });

  group('UpdateCheckSheet 4 States UI Verification', () {
    testWidgets('1. Empty State: Displays up to date state with current version', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateNotifierProvider.overrideWith(
              () => _ManualNotifier(
                const UpdateState(
                  status: UpdateStatus.upToDate,
                  currentVersion: '1.0.0',
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

      await tester.pumpAndSettle();

      expect(find.text('Aplikasi sudah versi terbaru (1.0.0).'), findsOneWidget);
      expect(find.text('Periksa Ulang'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('2. Require State: Displays available update with release notes & download button', (tester) async {
      const manifest = UpdateManifest(
        latestVersion: '1.1.0',
        releaseNotes: 'Fitur baru rekap kas dan perbaikan bug.',
        apkUrl: 'https://example.com/app-1.1.0.apk',
        minRequiredVersion: '1.0.0',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateNotifierProvider.overrideWith(
              () => _ManualNotifier(
                const UpdateState(
                  status: UpdateStatus.available,
                  currentVersion: '1.0.0',
                  manifest: manifest,
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

      await tester.pumpAndSettle();

      expect(find.text('Versi 1.1.0 tersedia'), findsOneWidget);
      expect(find.text('Fitur baru rekap kas dan perbaikan bug.'), findsOneWidget);
      expect(find.byKey(const ValueKey('update_download_btn')), findsOneWidget);
      expect(find.text('Unduh APK Pembaruan'), findsOneWidget);
    });

    testWidgets('Downloading State: Displays cloud download icon, percentage, and MB counter', (tester) async {
      const manifest = UpdateManifest(
        latestVersion: '1.1.0',
        releaseNotes: 'Fitur baru rekap kas dan perbaikan bug.',
        apkUrl: 'https://example.com/app-1.1.0.apk',
        minRequiredVersion: '1.0.0',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateNotifierProvider.overrideWith(
              () => _ManualNotifier(
                const UpdateState(
                  status: UpdateStatus.downloading,
                  currentVersion: '1.0.0',
                  manifest: manifest,
                  downloadProgress: 0.65,
                  receivedBytes: 46347059,
                  totalBytes: 71303168,
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

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_download_rounded), findsOneWidget);
      expect(find.text('Mengunduh Berkas APK...'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.text('44.2 MB / 68.0 MB'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('Proses unduh berjalan di latar belakang'), findsOneWidget);
    });

    testWidgets('3. Success State: Displays APK downloaded and install button', (tester) async {
      const manifest = UpdateManifest(
        latestVersion: '1.1.0',
        releaseNotes: 'Catatan rilis.',
        apkUrl: 'https://example.com/app-1.1.0.apk',
      );

      bool installed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateNotifierProvider.overrideWith(
              () => _ManualNotifier(
                const UpdateState(
                  status: UpdateStatus.readyToInstall,
                  currentVersion: '1.0.0',
                  manifest: manifest,
                  apkPath: '/data/user/0/com.bendahara.app.alien/cache/BendaharaAlien-1.1.0.apk',
                  downloadProgress: 1.0,
                ),
              ),
            ),
            apkInstallTriggerProvider.overrideWithValue((path) async {
              installed = true;
              return true;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UpdateCheckSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pembaruan Berhasil Diunduh!'), findsOneWidget);
      expect(find.text('Berkas pembaruan selesai diunduh.'), findsOneWidget);
      expect(find.byKey(const ValueKey('update_install_btn')), findsOneWidget);
      expect(find.text('Pasang Pembaruan Sekarang'), findsOneWidget);
      expect(find.text('BendaharaAlien-1.1.0.apk'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('update_install_btn')));
      await tester.pump();
      expect(installed, isTrue);
    });

    testWidgets('4. Error / Failed State: Displays clean technical log and copy button', (tester) async {
      final errorInfo = UpdateErrorInfo.fromError(
        const HttpException('Server manifest membalas kode 404.'),
        targetUrl: 'https://bendahara-kelas.github.io/app/manifest.json',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateNotifierProvider.overrideWith(
              () => _ManualNotifier(
                UpdateState(
                  status: UpdateStatus.downloadFailed,
                  currentVersion: '1.0.0',
                  errorMessage: errorInfo.userMessage,
                  errorInfo: errorInfo,
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

      await tester.pumpAndSettle();

      expect(find.text(errorInfo.title), findsOneWidget);
      expect(find.text(errorInfo.userMessage), findsOneWidget);
      expect(find.text('Log Diagnostik Teknis'), findsOneWidget);
      expect(find.text('Salin Log'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Verify that technical log contains key diagnostic lines
      expect(find.textContaining('Target URL     : https://bendahara-kelas.github.io/app/manifest.json'), findsOneWidget);
      expect(find.textContaining('Status HTTP    : 404'), findsOneWidget);
    });

    testWidgets('Simulation Toolbar allows switching across all 4 states', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateConfigProvider.overrideWithValue(
              const UpdateConfig(
                manifestUrl: 'https://example.com/manifest.json',
                currentAppVersion: '1.0.0',
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UpdateCheckSheet(showSimulatorToolbar: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test switching to Require state (2. Ada Update Baru)
      await tester.tap(find.text('2. Ada Update Baru'));
      await tester.pumpAndSettle();
      expect(find.text('Versi 1.1.0 tersedia'), findsOneWidget);

      // Test switching to Downloading state (Simulasi Unduh (65%))
      await tester.tap(find.text('Simulasi Unduh (65%)'));
      await tester.pumpAndSettle();
      expect(find.text('Mengunduh Berkas APK...'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_download_rounded), findsOneWidget);

      // Test switching to Success state (3. Siap Pasang)
      await tester.tap(find.text('3. Siap Pasang'));
      await tester.pumpAndSettle();
      expect(find.text('Pembaruan Berhasil Diunduh!'), findsOneWidget);

      // Test switching to Error state (4. Galat (Log 404))
      await tester.tap(find.text('4. Galat (Log 404)'));
      await tester.pumpAndSettle();
      expect(find.text('Manifest Rilis Belum Ada di Server (HTTP 404)'), findsOneWidget);
      expect(find.text('Log Diagnostik Teknis'), findsOneWidget);

      // Test switching to Empty state (1. Tidak Ada Update)
      await tester.tap(find.text('1. Tidak Ada Update'));
      await tester.pumpAndSettle();
      expect(find.text('Aplikasi sudah versi terbaru (1.0.0).'), findsOneWidget);
    });
  });
}
