import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/license/license_status.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/license_providers.dart';
import '../screens/activation_screen.dart';
import '../../settings/widgets/settings_card.dart';
import 'device_code_card.dart';

/// Kartu "Lisensi" di layar Pengaturan (PRD v1.1 §6.6).
///
/// Ditempatkan **paling bawah**, di bawah kartu Data & Keamanan: ini bukan
/// pengaturan harian, dan menaruhnya di atas akan membuat layar Pengaturan
/// terasa seperti halaman tagihan.
///
/// Isinya menjawab empat pertanyaan yang benar-benar ditanyakan pemilik
/// warung, berurutan: *masih aktif?* → *jenisnya apa?* → *habis kapan?* →
/// *kalau ganti HP bagaimana?*
class LicenseSection extends ConsumerWidget {
  const LicenseSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final status = ref.watch(licenseStatusProvider);
    final tone = _toneOf(status.state);

    return SettingsCard(
      icon: status.state.canSell ? Icons.verified_outlined : Icons.lock_clock,
      title: 'Lisensi',
      subtitle: 'Status aktivasi aplikasi di HP ini.',
      tone: tone,
      trailing: AppPill(label: _labelOf(status.state), tone: tone, dense: true),
      children: [
        AppKeyValueRow(label: 'Jenis', value: status.typeLabel),
        if (status.activatedAt != null)
          AppKeyValueRow(
            label: 'Diaktifkan',
            value: DateFormatter.formatDate(status.activatedAt!),
          ),
        AppKeyValueRow(label: 'Berakhir', value: _expiryText(status)),

        const SizedBox(height: AppSizes.spaceMd),
        const DeviceCodeCard(showShareButton: false, compact: true),

        const SizedBox(height: AppSizes.spaceMd),
        SizedBox(
          height: AppSizes.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: () => ActivationScreen.show(context),
            icon: const Icon(Icons.vpn_key_outlined),
            label: const Text('Masukkan Kode Baru'),
          ),
        ),
        const SizedBox(height: AppSizes.spaceMs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: AppSizes.iconSm,
              color: palette.inkSecondary,
            ),
            const SizedBox(width: AppSizes.spaceSm),
            Expanded(
              child: Text(
                'Ganti HP atau reset pabrik membuat kode perangkat berubah. '
                'Kirim kode perangkat baru Anda ke penjual — pembelian lama '
                'tercatat di sisi penjual.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static AppTone _toneOf(LicenseState state) => switch (state) {
    LicenseState.aktif => AppTone.success,
    LicenseState.akanBerakhir => AppTone.warning,
    LicenseState.masaTenggang ||
    LicenseState.kedaluwarsaTahunan ||
    LicenseState.kedaluwarsaTrial => AppTone.danger,
    LicenseState.belumAktif => AppTone.neutral,
  };

  static String _labelOf(LicenseState state) => switch (state) {
    LicenseState.aktif => 'Aktif',
    LicenseState.akanBerakhir => 'Akan berakhir',
    LicenseState.masaTenggang => 'Masa tenggang',
    LicenseState.kedaluwarsaTahunan ||
    LicenseState.kedaluwarsaTrial => 'Berakhir',
    LicenseState.belumAktif => 'Belum aktif',
  };

  static String _expiryText(LicenseStatus status) {
    if (status.payload == null) return '—';
    if (status.isLifetime) return 'Selamanya';
    final date = DateFormatter.formatDate(status.expiresAt!);
    return switch (status.state) {
      LicenseState.masaTenggang =>
        '$date · tenggang ${status.graceRemainingDays} hari lagi',
      LicenseState.kedaluwarsaTahunan ||
      LicenseState.kedaluwarsaTrial => '$date · sudah lewat',
      _ => '$date · ${status.remainingDays} hari lagi',
    };
  }
}
