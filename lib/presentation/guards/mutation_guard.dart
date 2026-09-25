import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/subscription_notifier.dart';
import '../screens/dialogs/paywall_sheet.dart';

/// Pintasan untuk menampilkan paywall ketika SubscriptionInfo belum aktif.
///
/// Aturannya sederhana:
///   * bila info aktif (active atau expiringSoon), jalankan aksi langsung.
///   * bila tidak aktif (unactivated atau expired), tampilkan paywall dan
///     hanya jalankan aksi kalau pengguna berhasil memasukkan kode valid.
///
/// Dipakai oleh titik masuk mutasi (form transaksi, toggle iuran, tambah
/// siswa) sehingga logika gating terpusat dan konsisten.
///
/// Mengembalikan true bila aksi akhirnya dijalankan, false bila pengguna
/// menutup paywall tanpa aktivasi.
Future<bool> runMutationWithGuard(
  BuildContext context,
  WidgetRef ref, {
  required String mutationLabel,
  required Future<void> Function() onAllowed,
}) async {
  // Menunggu future (bukan sekadar .value) supaya nilai tersedia juga saat
  // provider baru dibangun secara lazy di layar ini.
  SubscriptionInfo info;
  try {
    info = await ref.read(subscriptionNotifierProvider.future);
  } catch (_) {
    info = SubscriptionInfo(
      status: SubscriptionStatus.unactivated,
      message: 'Status lisensi belum terbaca.',
      checkedAt: DateTime.now(),
    );
  }
  if (!context.mounted) return false;

  if (info.isActive) {
    await onAllowed();
    return true;
  }
  final outcome = await PaywallSheet.show(
    context,
    mutationLabel: mutationLabel,
  );
  if (outcome != PaywallOutcome.activated) return false;
  // Setelah aktivasi, status sudah aktif; jalankan aksi yang diminta.
  await onAllowed();
  return true;
}