import 'package:bendahara_app/core/update/update_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateManifest', () {
    test('parses complete valid json correctly', () {
      final json = {
        'latest_version': '1.2.0',
        'release_notes': 'Perbaikan performa dan fitur baru',
        'apk_url': 'https://example.com/app-1.2.0.apk',
        'release_notes_url': 'https://example.com/release-notes-1.2.0.html',
        'min_required_version': '1.1.0',
      };

      final manifest = UpdateManifest.fromJson(json);

      expect(manifest.latestVersion, '1.2.0');
      expect(manifest.releaseNotes, 'Perbaikan performa dan fitur baru');
      expect(manifest.apkUrl, 'https://example.com/app-1.2.0.apk');
      expect(manifest.releaseNotesUrl, 'https://example.com/release-notes-1.2.0.html');
      expect(manifest.minRequiredVersion, '1.1.0');
    });

    test('parses minimal valid json with nullable fields', () {
      final json = {
        'latest_version': '2.0.0',
        'release_notes': 'Rilis besar',
        'apk_url': 'https://example.com/app-2.0.0.apk',
      };

      final manifest = UpdateManifest.fromJson(json);

      expect(manifest.latestVersion, '2.0.0');
      expect(manifest.releaseNotes, 'Rilis besar');
      expect(manifest.apkUrl, 'https://example.com/app-2.0.0.apk');
      expect(manifest.releaseNotesUrl, isNull);
      expect(manifest.minRequiredVersion, isNull);
    });

    test('throws FormatException when latest_version is missing or empty', () {
      expect(
        () => UpdateManifest.fromJson({
          'release_notes': 'notes',
          'apk_url': 'https://example.com/app.apk',
        }),
        throwsFormatException,
      );

      expect(
        () => UpdateManifest.fromJson({
          'latest_version': '',
          'release_notes': 'notes',
          'apk_url': 'https://example.com/app.apk',
        }),
        throwsFormatException,
      );
    });

    test('throws FormatException when release_notes is missing or empty', () {
      expect(
        () => UpdateManifest.fromJson({
          'latest_version': '1.0.0',
          'apk_url': 'https://example.com/app.apk',
        }),
        throwsFormatException,
      );

      expect(
        () => UpdateManifest.fromJson({
          'latest_version': '1.0.0',
          'release_notes': '',
          'apk_url': 'https://example.com/app.apk',
        }),
        throwsFormatException,
      );
    });

    test('throws FormatException when apk_url is missing or empty', () {
      expect(
        () => UpdateManifest.fromJson({
          'latest_version': '1.0.0',
          'release_notes': 'notes',
        }),
        throwsFormatException,
      );

      expect(
        () => UpdateManifest.fromJson({
          'latest_version': '1.0.0',
          'release_notes': 'notes',
          'apk_url': '',
        }),
        throwsFormatException,
      );
    });

    test('toJson serializes correctly', () {
      final manifest = UpdateManifest(
        latestVersion: '1.2.0',
        releaseNotes: 'Catatan',
        apkUrl: 'https://example.com/app.apk',
        releaseNotesUrl: 'https://example.com/notes.html',
        minRequiredVersion: '1.1.0',
      );

      final map = manifest.toJson();

      expect(map['latest_version'], '1.2.0');
      expect(map['release_notes'], 'Catatan');
      expect(map['apk_url'], 'https://example.com/app.apk');
      expect(map['release_notes_url'], 'https://example.com/notes.html');
      expect(map['min_required_version'], '1.1.0');
    });
  });

  group('Version', () {
    test('parses standard semver format', () {
      final v = Version.tryParse('1.2.3');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
      expect(v.toString(), '1.2.3');
    });

    test('parses versions with prefix v or V', () {
      final v1 = Version.tryParse('v1.2.3');
      expect(v1, const Version(1, 2, 3));

      final v2 = Version.tryParse('V2.0.1');
      expect(v2, const Version(2, 0, 1));
    });

    test('strips build metadata and prerelease tags', () {
      final v1 = Version.tryParse('1.1.4+13');
      expect(v1, const Version(1, 1, 4));

      final v2 = Version.tryParse('2.0.0-beta.1');
      expect(v2, const Version(2, 0, 0));
    });

    test('pads missing minor/patch parts with 0', () {
      final v1 = Version.tryParse('1');
      expect(v1, const Version(1, 0, 0));

      final v2 = Version.tryParse('1.2');
      expect(v2, const Version(1, 2, 0));
    });

    test('returns null on invalid input', () {
      expect(Version.tryParse(''), isNull);
      expect(Version.tryParse('invalid'), isNull);
      expect(Version.tryParse('1.2.3.4'), isNull);
      expect(Version.tryParse('-1.0.0'), isNull);
    });

    test('compares versions correctly', () {
      const v100 = Version(1, 0, 0);
      const v110 = Version(1, 1, 0);
      const v114 = Version(1, 1, 4);
      const v120 = Version(1, 2, 0);
      const v200 = Version(2, 0, 0);

      expect(v120 > v114, isTrue);
      expect(v114 < v120, isTrue);
      expect(v114 <= v120, isTrue);
      expect(v120 >= v114, isTrue);
      expect(v200 > v120, isTrue);
      expect(v100 < v110, isTrue);
      expect(v114 == const Version(1, 1, 4), isTrue);
      expect(v114.hashCode, const Version(1, 1, 4).hashCode);
    });
  });

  group('UpdateCheckResult', () {
    const current = Version(1, 1, 4);

    test('isUpdateAvailable is true when server version is higher', () {
      final result = UpdateCheckResult(
        manifest: const UpdateManifest(
          latestVersion: '1.2.0',
          releaseNotes: 'Baru',
          apkUrl: 'https://example.com/app.apk',
        ),
        currentVersion: current,
      );

      expect(result.isUpdateAvailable, isTrue);
      expect(result.latestVersion, const Version(1, 2, 0));
    });

    test('isUpdateAvailable is false when server version is equal or lower', () {
      final resultSame = UpdateCheckResult(
        manifest: const UpdateManifest(
          latestVersion: '1.1.4',
          releaseNotes: 'Sama',
          apkUrl: 'https://example.com/app.apk',
        ),
        currentVersion: current,
      );
      expect(resultSame.isUpdateAvailable, isFalse);

      final resultOlder = UpdateCheckResult(
        manifest: const UpdateManifest(
          latestVersion: '1.0.9',
          releaseNotes: 'Lama',
          apkUrl: 'https://example.com/app.apk',
        ),
        currentVersion: current,
      );
      expect(resultOlder.isUpdateAvailable, isFalse);
    });

    test('isMandatory evaluates against minRequiredVersion', () {
      final resultMandatory = UpdateCheckResult(
        manifest: const UpdateManifest(
          latestVersion: '2.0.0',
          releaseNotes: 'Wajib',
          apkUrl: 'https://example.com/app.apk',
          minRequiredVersion: '1.2.0',
        ),
        currentVersion: current, // 1.1.4 < 1.2.0 -> mandatory
      );
      expect(resultMandatory.isMandatory, isTrue);

      final resultOptional = UpdateCheckResult(
        manifest: const UpdateManifest(
          latestVersion: '2.0.0',
          releaseNotes: 'Opsional',
          apkUrl: 'https://example.com/app.apk',
          minRequiredVersion: '1.1.0',
        ),
        currentVersion: current, // 1.1.4 >= 1.1.0 -> not mandatory
      );
      expect(resultOptional.isMandatory, isFalse);

      final resultNoMin = UpdateCheckResult(
        manifest: const UpdateManifest(
          latestVersion: '2.0.0',
          releaseNotes: 'Tanpa min',
          apkUrl: 'https://example.com/app.apk',
        ),
        currentVersion: current,
      );
      expect(resultNoMin.isMandatory, isFalse);
    });
  });
}
