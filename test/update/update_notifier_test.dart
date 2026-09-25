import 'dart:io';

import 'package:bendahara_app/core/update/update_manifest.dart';
import 'package:bendahara_app/core/update/update_service.dart';
import 'package:bendahara_app/presentation/providers/update_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _StubFetcher implements UpdateManifestFetcher {
  final Future<UpdateManifest> Function() onFetch;
  _StubFetcher(this.onFetch);

  @override
  Future<UpdateManifest> fetch() => onFetch();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('update_notifier_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('UpdateNotifier', () {
    test('initial state has status idle and current version', () {
      final container = ProviderContainer(
        overrides: [
          updateConfigProvider.overrideWithValue(
            const UpdateConfig(
              manifestUrl: 'https://example.com/manifest.json',
              currentAppVersion: '1.1.4',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(updateNotifierProvider);
      expect(state.status, UpdateStatus.idle);
      expect(state.currentVersion, '1.1.4');
      expect(state.isUpdateAvailable, isFalse);
    });

    test('checkForUpdate sets status to available when server version is higher', () async {
      final container = ProviderContainer(
        overrides: [
          updateConfigProvider.overrideWithValue(
            const UpdateConfig(
              manifestUrl: 'https://example.com/manifest.json',
              currentAppVersion: '1.1.4',
            ),
          ),
          updateManifestFetcherProvider.overrideWithValue(
            _StubFetcher(() async => const UpdateManifest(
                  latestVersion: '1.2.0',
                  releaseNotes: 'Pembaruan tersedia',
                  apkUrl: 'https://example.com/app-1.2.0.apk',
                )),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateNotifierProvider.notifier).checkForUpdate();

      final state = container.read(updateNotifierProvider);
      expect(state.status, UpdateStatus.available);
      expect(state.isUpdateAvailable, isTrue);
      expect(state.manifest?.latestVersion, '1.2.0');
      expect(state.errorMessage, isNull);
    });

    test('checkForUpdate sets status to upToDate when server version matches current', () async {
      final container = ProviderContainer(
        overrides: [
          updateConfigProvider.overrideWithValue(
            const UpdateConfig(
              manifestUrl: 'https://example.com/manifest.json',
              currentAppVersion: '1.1.4',
            ),
          ),
          updateManifestFetcherProvider.overrideWithValue(
            _StubFetcher(() async => const UpdateManifest(
                  latestVersion: '1.1.4',
                  releaseNotes: 'Tidak ada pembaruan',
                  apkUrl: 'https://example.com/app-1.1.4.apk',
                )),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateNotifierProvider.notifier).checkForUpdate();

      final state = container.read(updateNotifierProvider);
      expect(state.status, UpdateStatus.upToDate);
      expect(state.isUpdateAvailable, isFalse);
      expect(state.manifest?.latestVersion, '1.1.4');
    });

    test('checkForUpdate sets status to downloadFailed on network error', () async {
      final container = ProviderContainer(
        overrides: [
          updateConfigProvider.overrideWithValue(
            const UpdateConfig(
              manifestUrl: 'https://example.com/manifest.json',
              currentAppVersion: '1.1.4',
            ),
          ),
          updateManifestFetcherProvider.overrideWithValue(
            _StubFetcher(() async => throw const HttpException('Jaringan putus')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateNotifierProvider.notifier).checkForUpdate();

      final state = container.read(updateNotifierProvider);
      expect(state.status, UpdateStatus.downloadFailed);
      expect(state.errorMessage, contains('Gagal memeriksa pembaruan'));
    });

    test('downloadApk transitions to readyToInstall upon successful download', () async {
      final fakeBytes = List<int>.filled(1024, 42);
      final mockClient = MockClient.streaming((req, stream) async {
        return http.StreamedResponse(
          Stream.value(fakeBytes),
          200,
          contentLength: fakeBytes.length,
        );
      });

      final container = ProviderContainer(
        overrides: [
          updateConfigProvider.overrideWithValue(
            const UpdateConfig(
              manifestUrl: 'https://example.com/manifest.json',
              currentAppVersion: '1.1.4',
            ),
          ),
          updateManifestFetcherProvider.overrideWithValue(
            _StubFetcher(() async => const UpdateManifest(
                  latestVersion: '1.2.0',
                  releaseNotes: 'Fitur baru',
                  apkUrl: 'https://example.com/app-1.2.0.apk',
                )),
          ),
          apkDownloadDirectoryProvider.overrideWithValue(() async => tempDir),
          httpClientFactoryProvider.overrideWithValue(() => mockClient),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(updateNotifierProvider.notifier);
      await notifier.checkForUpdate();
      await notifier.downloadApk();

      final state = container.read(updateNotifierProvider);
      expect(state.status, UpdateStatus.readyToInstall);
      expect(state.apkPath, isNotNull);
      expect(await File(state.apkPath!).exists(), isTrue);
      expect(state.downloadProgress, 1.0);
    });

    test('downloadApk transitions to downloadFailed on download error', () async {
      final mockClient = MockClient.streaming((req, stream) async {
        return http.StreamedResponse(
          Stream.error(const HttpException('Server error 500')),
          500,
        );
      });

      final container = ProviderContainer(
        overrides: [
          updateConfigProvider.overrideWithValue(
            const UpdateConfig(
              manifestUrl: 'https://example.com/manifest.json',
              currentAppVersion: '1.1.4',
            ),
          ),
          updateManifestFetcherProvider.overrideWithValue(
            _StubFetcher(() async => const UpdateManifest(
                  latestVersion: '1.2.0',
                  releaseNotes: 'Fitur baru',
                  apkUrl: 'https://example.com/app-1.2.0.apk',
                )),
          ),
          apkDownloadDirectoryProvider.overrideWithValue(() async => tempDir),
          httpClientFactoryProvider.overrideWithValue(() => mockClient),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(updateNotifierProvider.notifier);
      await notifier.checkForUpdate();
      await notifier.downloadApk();

      final state = container.read(updateNotifierProvider);
      expect(state.status, UpdateStatus.downloadFailed);
      expect(state.errorMessage, contains('Gagal mengunduh'));
    });

    test('installApk triggers apkInstallTriggerProvider and maintains state', () async {
      String? invokedPath;
      final fakeBytes = List<int>.filled(512, 1);
      final mockClient = MockClient.streaming((req, stream) async {
        return http.StreamedResponse(
          Stream.value(fakeBytes),
          200,
          contentLength: fakeBytes.length,
        );
      });

      final container = ProviderContainer(
        overrides: [
          updateConfigProvider.overrideWithValue(
            const UpdateConfig(
              manifestUrl: 'https://example.com/manifest.json',
              currentAppVersion: '1.1.4',
            ),
          ),
          updateManifestFetcherProvider.overrideWithValue(
            _StubFetcher(() async => const UpdateManifest(
                  latestVersion: '1.2.0',
                  releaseNotes: 'Fitur baru',
                  apkUrl: 'https://example.com/app-1.2.0.apk',
                )),
          ),
          apkDownloadDirectoryProvider.overrideWithValue(() async => tempDir),
          httpClientFactoryProvider.overrideWithValue(() => mockClient),
          apkInstallTriggerProvider.overrideWithValue((path) async {
            invokedPath = path;
            return true;
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(updateNotifierProvider.notifier);
      await notifier.checkForUpdate();
      await notifier.downloadApk();

      final launched = await notifier.installApk();
      expect(launched, isTrue);
      expect(invokedPath, isNotNull);
      expect(container.read(updateNotifierProvider).status, UpdateStatus.readyToInstall);
    });
  });
}
