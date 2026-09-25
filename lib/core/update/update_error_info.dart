import 'dart:io';

/// Informasi terstruktur mengenai kendala pembaruan dan log teknisnya.
class UpdateErrorInfo {
  final String title;
  final String userMessage;
  final String technicalLog;
  final String? targetUrl;
  final int? statusCode;
  final DateTime timestamp;

  const UpdateErrorInfo({
    required this.title,
    required this.userMessage,
    required this.technicalLog,
    this.targetUrl,
    this.statusCode,
    required this.timestamp,
  });

  /// Menganalisis exception dan menghasilkan [UpdateErrorInfo] yang informatif.
  factory UpdateErrorInfo.fromError(
    Object error, {
    required String targetUrl,
    StackTrace? stackTrace,
    bool isDownload = false,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final errString = error.toString();
    int? statusCode;
    String title = isDownload ? 'Gagal Mengunduh Berkas' : 'Gagal Memeriksa Pembaruan';
    String userMessage = '';
    String diagnosis = '';

    if (error is HttpException || errString.contains('HttpException')) {
      final match = RegExp(r'(\d{3})').firstMatch(errString);
      if (match != null) {
        statusCode = int.tryParse(match.group(1)!);
      }

      final actionVerb = isDownload ? 'mengunduh berkas' : 'memeriksa';
      if (statusCode == 404) {
        title = isDownload
            ? 'Berkas APK Belum Tersedia (HTTP 404)'
            : 'Manifest Rilis Belum Ada di Server (HTTP 404)';
        userMessage = isDownload
            ? 'Gagal mengunduh berkas pembaruan: Berkas APK belum diunggah ke server hosting (HTTP 404 Not Found).'
            : 'Gagal memeriksa pembaruan: Berkas manifest belum dipublikasikan oleh pengembang di server hosting (HTTP 404 Not Found). Koneksi internet perangkat Anda aktif normal.';
        diagnosis =
            'Server web merespons normal, namun berkas manifest.json belum dibuat atau belum di-deploy pada endpoint yang dituju.';
      } else if (statusCode != null && statusCode >= 500) {
        title = 'Server Pembaruan Bermasalah (HTTP $statusCode)';
        userMessage =
            'Gagal $actionVerb pembaruan: Server hosting sedang mengalami gangguan internal (HTTP $statusCode). Silakan coba lagi beberapa saat lagi.';
        diagnosis = 'Server sedang kelebihan beban atau mengalami downtime.';
      } else {
        title = 'Respon Server Tidak Sesuai (HTTP $statusCode)';
        userMessage =
            'Gagal $actionVerb pembaruan: Server membalas kode status $statusCode.';
        diagnosis = 'Server menolak permintaan atau memerlukan autentikasi.';
      }
    } else if (errString.contains('SocketException') ||
        errString.contains('Failed host lookup') ||
        errString.contains('Network is unreachable')) {
      final actionVerb = isDownload ? 'mengunduh berkas' : 'memeriksa';
      title = 'Koneksi ke Server Terputus';
      userMessage =
          'Gagal $actionVerb pembaruan: Tidak dapat menghubungi server hosting. Periksa koneksi internet atau status DNS Anda.';
      diagnosis =
          'Gagal melakukan resolusi DNS atau soket jaringan tidak dapat tersambung ke host target.';
    } else if (errString.contains('TimeoutException') ||
        errString.contains('timed out')) {
      final actionVerb = isDownload ? 'mengunduh berkas' : 'memeriksa';
      title = 'Waktu Permintaan Habis (Timeout)';
      userMessage =
          'Gagal $actionVerb pembaruan: Server tidak merespons dalam batas waktu 15 detik. Jaringan atau server sedang lambat.';
      diagnosis = 'Batas waktu koneksi terlampaui sebelum respon selesai diterima.';
    } else if (error is FormatException || errString.contains('FormatException')) {
      title = 'Format Manifest Tidak Valid';
      userMessage =
          'Gagal memeriksa pembaruan: Berkas manifest di server bukan format JSON yang valid.';
      diagnosis = 'Respon server bukan merupakan data JSON yang diharapkan.';
    } else {
      userMessage = isDownload
          ? 'Gagal mengunduh berkas pembaruan: $errString'
          : 'Gagal memeriksa pembaruan: $errString';
      diagnosis = 'Galat lokal atau platform yang tidak terduga.';
    }

    final buffer = StringBuffer();
    buffer.writeln('=== LOG DIAGNOSTIK PEMBARUAN BENDAHARA ALIEN ===');
    buffer.writeln('Waktu (UTC)    : ${timestamp.toUtc().toIso8601String()}');
    buffer.writeln('Waktu Lokal    : ${timestamp.toLocal()}');
    if (statusCode != null) {
      buffer.writeln('Status HTTP    : $statusCode');
    }
    buffer.writeln('Target URL     : $targetUrl');
    buffer.writeln('Tipe Galat     : ${error.runtimeType}');
    buffer.writeln('Pesan Detail   : $errString');
    buffer.writeln('Analisis Awal  : $diagnosis');
    if (stackTrace != null) {
      final topTrace = stackTrace.toString().split('\n').take(3).join('\n');
      buffer.writeln('Jejak Singkat  :\n$topTrace');
    }
    buffer.writeln('=================================================');

    return UpdateErrorInfo(
      title: title,
      userMessage: userMessage,
      technicalLog: buffer.toString().trim(),
      targetUrl: targetUrl,
      statusCode: statusCode,
      timestamp: timestamp,
    );
  }
}
