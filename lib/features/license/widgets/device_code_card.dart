import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/license/device_code.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/license_providers.dart';

/// Kartu kode perangkat — satu-satunya hal yang perlu dibaca & dikirim
/// pengguna saat membeli (PRD v1.1 §6.6).
///
/// Prinsip "angka lebih penting dari labelnya" diterapkan harfiah di sini:
/// eyebrow kecil di atas, lalu kode dengan angka tabular berukuran besar.
/// Dua tombol di bawahnya menghapus satu-satunya pekerjaan yang tersisa
/// (menyalin & mengirim), sehingga pembeli tidak pernah perlu mengetik ulang
/// kode perangkatnya sendiri.
class DeviceCodeCard extends ConsumerWidget {
  const DeviceCodeCard({
    super.key,
    this.showShareButton = true,
    this.compact = false,
  });

  /// Tombol "Kirim ke Penjual" (lembar berbagi sistem). Dimatikan di kartu
  /// Pengaturan yang cuma perlu tombol Salin.
  final bool showShareButton;

  /// Versi rapat untuk di dalam `SettingsCard`.
  final bool compact;

  /// Teks siap kirim ke penjual lewat WhatsApp/SMS.
  static String shareText(String display) =>
      'Halo, saya mau aktivasi Kasir Warung. Kode perangkat saya:\n$display';

  Future<void> _copy(BuildContext context, String display) async {
    await Clipboard.setData(ClipboardData(text: display));
    if (!context.mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kode perangkat disalin.')));
  }

  Future<void> _share(String display) async {
    await SharePlus.instance.share(
      ShareParams(text: shareText(display), subject: 'Aktivasi Kasir Warung'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final display = DeviceCode.format(ref.watch(deviceCodeProvider));

    return AppCard(
      elevated: !compact,
      color: compact ? palette.surfaceAlt : null,
      padding: EdgeInsets.all(compact ? AppSizes.spaceMs : AppSizes.spaceMl),
      radius: compact ? AppSizes.radiusMd : AppSizes.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('KODE PERANGKAT ANDA', style: context.textStyles.eyebrow),
          const SizedBox(height: AppSizes.spaceSm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SelectableText(
              display,
              style: context.textStyles.numeric.copyWith(
                fontSize: compact ? 22 : 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          SizedBox(height: compact ? AppSizes.spaceMs : AppSizes.spaceMd),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppSizes.buttonHeight,
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(context, display),
                    icon: const Icon(Icons.content_copy_rounded),
                    label: const Text('Salin'),
                  ),
                ),
              ),
              if (showShareButton) ...[
                const SizedBox(width: AppSizes.spaceSm),
                Expanded(
                  child: SizedBox(
                    height: AppSizes.buttonHeight,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _share(display),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Kirim'),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: AppSizes.spaceMs),
            Text(
              'Kode ini hanya berlaku di HP ini. Ganti HP atau reset pabrik '
              'berarti kode perangkatnya berubah dan Anda perlu kode aktivasi '
              'baru dari penjual.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
