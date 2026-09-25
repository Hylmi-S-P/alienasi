/// Model data manifest pembaruan yang diambil dari server pembuat aplikasi.
///
/// Manifest adalah berkas JSON sederhana yang di-hosting pembuat (misalnya
/// GitHub Pages atau Google Drive). Isinya versi terbaru, catatan rilis, dan
/// tautan unduhan APK. Format ini satu-satunya kontrak antara aplikasi dan
/// server, jadi pembuat cukup memperbarui berkas JSON saat merilis versi
/// baru tanpa perlu membangun ulang aplikasi.
library;

/// Hasil satu rilis aplikasi dari manifest server.
class UpdateManifest {
  /// Versi terbaru, format `major.minor.patch` (mis. `1.2.0`).
  final String latestVersion;

  /// Catatan perubahan singkat untuk rilis ini.
  final String releaseNotes;

  /// URL berkas APK yang siap diunduh.
  final String apkUrl;

  /// URL halaman catatan rilis lengkap (HTML), ditampilkan di WebView.
  final String? releaseNotesUrl;

  /// Versi minimum yang harus dipakai pengguna; di bawah ini pembaruan
  /// bersifat wajib.
  final String? minRequiredVersion;

  const UpdateManifest({
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkUrl,
    this.releaseNotesUrl,
    this.minRequiredVersion,
  });

  /// Mem-parsing manifest dari JSON mentah. Melempar [FormatException] bila
  /// struktur tidak sesuai.
  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final latestVersion = json['latest_version'] as String?;
    final releaseNotes = json['release_notes'] as String?;
    final apkUrl = json['apk_url'] as String?;

    if (latestVersion == null || latestVersion.isEmpty) {
      throw const FormatException('Field latest_version tidak ada atau kosong.');
    }
    if (releaseNotes == null || releaseNotes.isEmpty) {
      throw const FormatException('Field release_notes tidak ada atau kosong.');
    }
    if (apkUrl == null || apkUrl.isEmpty) {
      throw const FormatException('Field apk_url tidak ada atau kosong.');
    }

    return UpdateManifest(
      latestVersion: latestVersion,
      releaseNotes: releaseNotes,
      apkUrl: apkUrl,
      releaseNotesUrl: json['release_notes_url'] as String?,
      minRequiredVersion: json['min_required_version'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'latest_version': latestVersion,
        'release_notes': releaseNotes,
        'apk_url': apkUrl,
        'release_notes_url': releaseNotesUrl,
        'min_required_version': minRequiredVersion,
      };
}

/// Perbandingan versi semver sederhana tanpa dependensi eksternal.
///
/// Menerima format `major.minor.patch` dengan toleransi sufiks (mis.
/// `1.2.0+13`): sufiks diabaikan saat membandingkan.
class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;

  const Version(this.major, this.minor, this.patch);

  /// Parsing aman: null bila format tidak dikenali, bukan melempar.
  static Version? tryParse(String raw) {
    var clean = raw.trim();
    if (clean.startsWith('v') || clean.startsWith('V')) {
      clean = clean.substring(1).trim();
    }
    final core = clean.split('+').first.split('-').first;
    final parts = core.split('.');
    if (parts.isEmpty || parts.length > 3) return null;

    final numbers = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part.trim());
      if (value == null || value < 0) return null;
      numbers.add(value);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return Version(numbers[0], numbers[1], numbers[2]);
  }

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(Version other) => compareTo(other) > 0;
  bool operator <(Version other) => compareTo(other) < 0;
  bool operator >=(Version other) => compareTo(other) >= 0;
  bool operator <=(Version other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is Version && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// Hasil pengecekan pembaruan untuk versi aplikasi yang sedang berjalan.
class UpdateCheckResult {
  final UpdateManifest manifest;

  /// Versi aplikasi yang sedang berjalan.
  final Version currentVersion;

  /// Versi terbaru dari manifest.
  Version get latestVersion =>
      Version.tryParse(manifest.latestVersion) ??
      const Version(0, 0, 0);

  const UpdateCheckResult({
    required this.manifest,
    required this.currentVersion,
  });

  /// True bila server menawarkan versi lebih baru dari yang terpasang.
  bool get isUpdateAvailable => latestVersion > currentVersion;

  /// True bila versi terpasang berada di bawah [UpdateManifest.minRequiredVersion].
  bool get isMandatory {
    final minRequired = manifest.minRequiredVersion;
    if (minRequired == null) return false;
    final parsed = Version.tryParse(minRequired);
    if (parsed == null) return false;
    return currentVersion < parsed;
  }
}
