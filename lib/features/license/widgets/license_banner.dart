import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/license/license_status.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/license_providers.dart';
import '../screens/activation_screen.dart';

/// Banner peringatan lisensi ditutup untuk sesi berjalan.
///
/// Sengaja `StateProvider` (hidup selama proses), bukan `shared_preferences`:
/// peringatan yang bisa dimatikan selamanya bukan peringatan.
final StateProvider<bool> licenseBannerDismissedProvider = StateProvider<bool>(
  (ref) => false,
);

/// Banner lisensi di layar Kasir (PRD v1.1 §6.6).
///
/// Aturan yang mengikat penempatannya: banner **tidak pernah** menutupi bar
/// keranjang atau tombol "Bayar". Kasir yang sedang melayani antrian tidak
/// boleh kehilangan satu pun piksel dari jalur uangnya demi pesan
/// administratif — jadi banner hidup di atas daftar produk, bukan
/// mengambang.
class LicenseBanner extends ConsumerWidget {
  const LicenseBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(licenseStatusProvider);
    final dismissed = ref.watch(licenseBannerDismissedProvider);

    final banners = <Widget>[];

    switch (status.state) {
      case LicenseState.akanBerakhir:
        if (!dismissed) {
          banners.add(
            AppBanner(
              tone: AppTone.warning,
              icon: Icons.schedule_rounded,
              message: _willExpireMessage(status),
              actionLabel: 'Perpanjang',
              onAction: () => ActivationScreen.show(context),
              onDismiss: () =>
                  ref.read(licenseBannerDismissedProvider.notifier).state =
                      true,
            ),
          );
        }
      case LicenseState.masaTenggang:
        // Menetap — TIDAK bisa ditutup. Ini satu-satunya keadaan di mana
        // aplikasi masih berfungsi penuh sementara pembayaran sudah lewat
        // jatuh tempo; menyembunyikannya berarti mengejutkan kasir pada
        // pagi hari saat antrian panjang.
        banners.add(
          AppBanner(
            tone: AppTone.danger,
            icon: Icons.error_outline_rounded,
            title: 'Lisensi sudah berakhir',
            message:
                'Sisa masa tenggang ${status.graceRemainingDays} hari. '
                'Setelah itu layar Kasir terkunci, tapi seluruh data & '
                'laporan tetap bisa dibuka.',
            actionLabel: 'Perpanjang',
            onAction: () => ActivationScreen.show(context),
          ),
        );
      case LicenseState.belumAktif:
      case LicenseState.aktif:
      case LicenseState.kedaluwarsaTahunan:
      case LicenseState.kedaluwarsaTrial:
        break;
    }

    if (status.clockRolledBack) {
      banners.add(
        const AppBanner(
          tone: AppTone.info,
          icon: Icons.access_time_rounded,
          message:
              'Jam HP Anda tampaknya mundur. Betulkan tanggal & jam agar '
              'laporan dan lisensi tetap akurat.',
        ),
      );
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.spaceSm,
        AppSizes.screenPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < banners.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSizes.spaceSm),
            banners[i],
          ],
        ],
      ),
    );
  }

  static String _willExpireMessage(LicenseStatus status) {
    final days = status.remainingDays ?? 0;
    if (days <= 1) return 'Lisensi berakhir besok.';
    return 'Lisensi berakhir $days hari lagi.';
  }
}

/// Layar Kasir terkunci — lisensi tahunan setelah masa tenggang habis
/// (AC-6.14).
///
/// Ditampilkan **di dalam shell**, sehingga navigasi bawah tetap ada dan
/// tetap berfungsi. Itu pesan visual yang penting: yang terkunci adalah
/// jualannya, bukan datanya. Riwayat, Laporan, Export Excel, Backup, dan
/// Pengaturan tetap terbuka satu tap dari sini.
class PosLockedView extends StatelessWidget {
  const PosLockedView({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.lock_clock,
      tone: AppTone.accent,
      title: 'Lisensi sudah berakhir',
      message:
          'Transaksi baru dijeda sampai lisensi diperpanjang. Riwayat, '
          'Laporan, Export Excel, dan Backup tetap bisa dibuka lewat menu '
          'di bawah — data Anda utuh.',
      actionLabel: 'Masukkan Kode Baru',
      onAction: () => ActivationScreen.show(context),
    );
  }
}
