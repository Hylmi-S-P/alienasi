import 'dart:convert';
import 'dart:io';

import 'package:bendahara_app/core/update/update_manifest.dart';
import 'package:bendahara_app/core/update/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeFetcher implements UpdateManifestFetcher {
  final UpdateManifest Function() onFetch;
  _FakeFetcher(this.onFetch);

  @override
  Future<UpdateManifest> fetch() async => onFetch();
}

void main() {
  group('HttpUpdateManifestFetcher', () {
    test('fetches and decodes valid manifest JSON', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/manifest.json');
        return http.Response(
          jsonEncode({
            'latest_version': '1.3.0',
            'release_notes': 'Update catatan',
            'apk_url': 'https://example.com/app-1.3.0.apk',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final fetcher = HttpUpdateManifestFetcher(
        url: 'https://example.com/manifest.json',
        client: mockClient,
      );

      final manifest = await fetcher.fetch();
      expect(manifest.latestVersion, '1.3.0');
      expect(manifest.releaseNotes, 'Update catatan');
      expect(manifest.apkUrl, 'https://example.com/app-1.3.0.apk');
    });

    test('throws HttpException on non-200 status code', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final fetcher = HttpUpdateManifestFetcher(
        url: 'https://example.com/manifest.json',
        client: mockClient,
      );

      expect(() => fetcher.fetch(), throwsA(isA<HttpException>()));
    });

    test('throws FormatException on malformed non-map JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response('["array", "bukan", "object"]', 200);
      });

      final fetcher = HttpUpdateManifestFetcher(
        url: 'https://example.com/manifest.json',
        client: mockClient,
      );

      expect(() => fetcher.fetch(), throwsFormatException);
    });
  });

  group('UpdateService.checkForUpdate', () {
    test('returns UpdateCheckResult comparing manifest and current version', () async {
      final fetcher = _FakeFetcher(() => const UpdateManifest(
            latestVersion: '1.2.0',
            releaseNotes: 'Fitur baru',
            apkUrl: 'https://example.com/app.apk',
          ));

      final service = UpdateService(
        fetcher: fetcher,
        currentAppVersion: '1.1.4',
      );

      final result = await service.checkForUpdate();
      expect(result.currentVersion, const Version(1, 1, 4));
      expect(result.latestVersion, const Version(1, 2, 0));
      expect(result.isUpdateAvailable, isTrue);
    });

    test('throws FormatException when currentAppVersion cannot be parsed', () async {
      final fetcher = _FakeFetcher(() => const UpdateManifest(
            latestVersion: '1.2.0',
            releaseNotes: 'Fitur baru',
            apkUrl: 'https://example.com/app.apk',
          ));

      final service = UpdateService(
        fetcher: fetcher,
        currentAppVersion: 'unparseable',
      );

      expect(() => service.checkForUpdate(), throwsFormatException);
    });
  });

  group('UpdateService.downloadApk', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('apk_download_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('downloads chunks to file and reports progress', () async {
      final chunk1 = List<int>.filled(512, 65);
      final chunk2 = List<int>.filled(512, 66);
      final totalBytes = chunk1.length + chunk2.length;

      final mockClient = MockClient.streaming((request, stream) async {
        final byteStream = Stream.fromIterable([chunk1, chunk2]);
        return http.StreamedResponse(
          byteStream,
          200,
          contentLength: totalBytes,
        );
      });

      final destination = '${tempDir.path}/subfolder/test_app.apk';
      final service = UpdateService(
        fetcher: _FakeFetcher(() => throw UnimplementedError()),
        currentAppVersion: '1.1.4',
      );

      final progressList = <ApkDownloadProgress>[];
      final file = await service.downloadApk(
        apkUrl: 'https://example.com/test_app.apk',
        destinationPath: destination,
        client: mockClient,
        onProgress: (p) => progressList.add(p),
      );

      expect(await file.exists(), isTrue);
      expect(await file.length(), totalBytes);
      expect(progressList, isNotEmpty);
      expect(progressList.last.received, totalBytes);
      expect(progressList.last.fraction, 1.0);
    });

    test('throws HttpException on non-200 response and cleans up file', () async {
      final mockClient = MockClient.streaming((request, stream) async {
        return http.StreamedResponse(
          Stream.fromIterable([utf8.encode('Error 500')]),
          500,
        );
      });

      final destination = '${tempDir.path}/failed_app.apk';
      final service = UpdateService(
        fetcher: _FakeFetcher(() => throw UnimplementedError()),
        currentAppVersion: '1.1.4',
      );

      expect(
        () => service.downloadApk(
          apkUrl: 'https://example.com/failed.apk',
          destinationPath: destination,
          client: mockClient,
        ),
        throwsA(isA<HttpException>()),
      );

      expect(await File(destination).exists(), isFalse);
    });

    test('throws HttpException when received bytes are 0 and cleans up file', () async {
      final mockClient = MockClient.streaming((request, stream) async {
        return http.StreamedResponse(
          Stream.value(<int>[]),
          200,
          contentLength: 0,
        );
      });

      final destination = '${tempDir.path}/empty_app.apk';
      final service = UpdateService(
        fetcher: _FakeFetcher(() => throw UnimplementedError()),
        currentAppVersion: '1.1.4',
      );

      expect(
        () => service.downloadApk(
          apkUrl: 'https://example.com/empty.apk',
          destinationPath: destination,
          client: mockClient,
        ),
        throwsA(isA<HttpException>()),
      );

      expect(await File(destination).exists(), isFalse);
    });
  });
}
