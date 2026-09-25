import 'package:bendahara_app/core/update/update_manifest.dart';
import 'package:bendahara_app/core/update/update_service.dart';
import 'package:bendahara_app/presentation/providers/update_notifier.dart';
import 'package:bendahara_app/presentation/screens/dialogs/update_check_sheet.dart';
import 'package:bendahara_app/presentation/widgets/update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ManualFetcher implements UpdateManifestFetcher {
  UpdateManifest? manifestToReturn;
  Object? errorToThrow;

  @override
  Future<UpdateManifest> fetch() async {
    if (errorToThrow != null) throw errorToThrow!;
    return manifestToReturn!;
  }
}

void main() {
  const testManifest = UpdateManifest(
    latestVersion: '1.2.0',
    releaseNotes: 'Catatan perubahan versi 1.2.0',
    apkUrl: 'https://example.com/app-1.2.0.apk',
    releaseNotesUrl: 'https://example.com/notes.html',
  );

  group('UpdateBanner', () {
    testWidgets('renders banner when update is available and dismisses on tap', (tester) async {
      final fetcher = _ManualFetcher()..manifestToReturn = testManifest;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateConfigProvider.overrideWithValue(
              const UpdateConfig(
                manifestUrl: 'https://example.com/manifest.json',
                currentAppVersion: '1.1.4',
              ),
            ),
            updateManifestFetcherProvider.overrideWithValue(fetcher),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return Column(
                    children: [
                      ?UpdateBanner.maybeBuild(context, ref),
                      const Text('Konten Halaman'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Awalnya status idle, banner belum muncul
      expect(find.text('Versi baru tersedia'), findsNothing);

      // Jalankan cek pembaruan
      final element = tester.element(find.text('Konten Halaman'));
      final container = ProviderScope.containerOf(element);
      await container.read(updateNotifierProvider.notifier).checkForUpdate();
      await tester.pumpAndSettle();

      // Banner sekarang muncul
      expect(find.text('Versi baru tersedia'), findsOneWidget);
      expect(find.textContaining('1.2.0'), findsOneWidget);
      expect(find.text('Perbarui'), findsOneWidget);

      // Ketuk tombol tutup notifikasi (X)
      await tester.tap(find.byTooltip('Tutup notifikasi pembaruan'));
      await tester.pumpAndSettle();

      // Banner hilang setelah ditutup
      expect(find.text('Versi baru tersedia'), findsNothing);
    });
  });

  group('UpdateCheckSheet', () {
    testWidgets('shows checking state initially and transitions to upToDate', (tester) async {
      final upToDateManifest = const UpdateManifest(
        latestVersion: '1.1.4',
        releaseNotes: 'Tidak ada',
        apkUrl: 'https://example.com/app.apk',
      );
      final fetcher = _ManualFetcher()..manifestToReturn = upToDateManifest;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateConfigProvider.overrideWithValue(
              const UpdateConfig(
                manifestUrl: 'https://example.com/manifest.json',
                currentAppVersion: '1.1.4',
              ),
            ),
            updateManifestFetcherProvider.overrideWithValue(fetcher),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UpdateCheckSheet(),
            ),
          ),
        ),
      );

      // Settle frame post-callback
      await tester.pumpAndSettle();

      expect(find.text('Aplikasi sudah versi terbaru (1.1.4).'), findsOneWidget);
      expect(find.text('Periksa Ulang'), findsOneWidget);
    });

    testWidgets('shows available state with changelog and download CTA', (tester) async {
      final fetcher = _ManualFetcher()..manifestToReturn = testManifest;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateConfigProvider.overrideWithValue(
              const UpdateConfig(
                manifestUrl: 'https://example.com/manifest.json',
                currentAppVersion: '1.1.4',
              ),
            ),
            updateManifestFetcherProvider.overrideWithValue(fetcher),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UpdateCheckSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Versi 1.2.0 tersedia'), findsOneWidget);
      expect(find.text('Catatan perubahan versi 1.2.0'), findsOneWidget);
      expect(find.text('Baca Catatan Rilis Lengkap'), findsOneWidget);
      expect(find.byKey(const ValueKey('update_download_btn')), findsOneWidget);
    });

    testWidgets('shows error state and allows retry on fetch error', (tester) async {
      final fetcher = _ManualFetcher()..errorToThrow = Exception('Network error');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateConfigProvider.overrideWithValue(
              const UpdateConfig(
                manifestUrl: 'https://example.com/manifest.json',
                currentAppVersion: '1.1.4',
              ),
            ),
            updateManifestFetcherProvider.overrideWithValue(fetcher),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UpdateCheckSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Gagal memeriksa pembaruan'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Perbaiki fetcher lalu ketuk coba lagi
      fetcher.errorToThrow = null;
      fetcher.manifestToReturn = testManifest;

      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Versi 1.2.0 tersedia'), findsOneWidget);
    });

    testWidgets('shows install button in readyToInstall state and triggers onInstall', (tester) async {
      bool installCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateNotifierProvider.overrideWith(() => _PreloadedNotifier(
                  UpdateState(
                    status: UpdateStatus.readyToInstall,
                    currentVersion: '1.1.4',
                    manifest: testManifest,
                    apkPath: '/tmp/test.apk',
                    downloadProgress: 1.0,
                  ),
                )),
            apkInstallTriggerProvider.overrideWithValue((path) async {
              installCalled = true;
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

      await tester.pump();

      expect(find.text('Berkas pembaruan selesai diunduh.'), findsOneWidget);
      expect(find.byKey(const ValueKey('update_install_btn')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('update_install_btn')));
      await tester.pump();

      expect(installCalled, isTrue);
    });
  });
}

class _PreloadedNotifier extends UpdateNotifier {
  final UpdateState preloaded;
  _PreloadedNotifier(this.preloaded);

  @override
  UpdateState build() => preloaded;

  @override
  Future<void> checkForUpdate() async {}
}
