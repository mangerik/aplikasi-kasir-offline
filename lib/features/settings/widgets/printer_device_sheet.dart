import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/services/printing/receipt_printer.dart';
import '../../../domain/entities/printer_settings.dart';
import '../providers/printer_providers.dart';

/// Sheet "Pilih Printer" — daftar perangkat yang **sudah dipasangkan**
/// (bonded) di Pengaturan Bluetooth Android (PRD v1.1 §3.3.A, §3.6).
///
/// Kenapa daftar ini tidak pernah memindai: package yang dipilih sengaja
/// hanya membaca perangkat bonded, dan itu keputusan sadar (K-3.9). Harga
/// yang dibayar — pemasangan awal terjadi di Pengaturan Android — dibayar
/// balik dengan hilangnya SELURUH kelas kegagalan izin pindai & lokasi
/// Android 12+, sekaligus pertanyaan Play Store soal izin lokasi.
///
/// Karena itu layar kosong di sini bukan jalan buntu melainkan **petunjuk
/// arah**: tiga langkah pemasangan + satu tombol yang melompat langsung ke
/// layar Bluetooth Android (AC-3.16).
class PrinterDeviceSheet extends ConsumerWidget {
  const PrinterDeviceSheet({super.key});

  /// Membuka sheet; mengembalikan perangkat yang dipilih, atau `null` bila
  /// pengguna menutup sheet.
  static Future<BondedPrinter?> show(BuildContext context) {
    return showModalBottomSheet<BondedPrinter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PrinterDeviceSheet(),
    );
  }

  /// Pintasan ke layar Pengaturan Bluetooth Android. Gagal membukanya
  /// bukan alasan menampilkan error teknis — panduan tiga langkahnya sudah
  /// cukup untuk dikerjakan manual.
  static Future<void> openAndroidBluetoothSettings() async {
    const channel = MethodChannel('kasir_warung/system');
    try {
      await channel.invokeMethod<void>('openBluetoothSettings');
    } catch (_) {
      // Sengaja diam.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(bondedPrintersProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          0,
          AppSizes.screenPadding,
          AppSizes.spaceMd,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Pilih Printer',
                subtitle: 'Printer yang sudah dipasangkan di HP ini',
                padding: EdgeInsets.only(bottom: AppSizes.spaceMd),
              ),
              devicesAsync.when(
                data: (devices) => devices.isEmpty
                    ? const _PairingGuide()
                    : _DeviceList(devices: devices),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.spaceXl),
                  child: AppLoadingView(message: 'Mencari printer terpasang…', compact: true),
                ),
                error: (error, _) => _DeviceError(error: error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices});

  final List<BondedPrinter> devices;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final device in devices) ...[
          _DeviceTile(device: device),
          const SizedBox(height: AppSizes.spaceSm),
        ],
        const SizedBox(height: AppSizes.spaceSm),
        TextButton.icon(
          onPressed: PrinterDeviceSheet.openAndroidBluetoothSettings,
          icon: const Icon(Icons.bluetooth, size: AppSizes.iconSm),
          label: const Text('Printer tidak ada di daftar?'),
        ),
      ],
    );
  }
}

/// Satu baris perangkat. Tinggi minimalnya 56dp — di atas `minTouchTarget`
/// 48 — karena baris ini ditekan sambil berdiri di depan printer, sering
/// dengan satu tangan (PRD §3.6).
class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final BondedPrinter device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => Navigator.of(context).pop(device),
      color: context.palette.surfaceAlt,
      radius: AppSizes.radiusMd,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceMs,
        vertical: AppSizes.spaceMs,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56 - (AppSizes.spaceMs * 2)),
        child: Row(
          children: [
            const AppIconBadge(
              icon: Icons.print_outlined,
              tone: AppTone.info,
              size: AppIconBadgeSize.sm,
            ),
            const SizedBox(width: AppSizes.spaceMs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(device.displayName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    device.address,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.palette.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: AppSizes.iconMd,
              color: context.palette.inkTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Layar kosong yang mengarahkan (AC-3.16) — bukan tulisan "tidak ada data".
class _PairingGuide extends StatelessWidget {
  const _PairingGuide();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: AppIconBadge(
            icon: Icons.bluetooth,
            tone: AppTone.info,
            size: AppIconBadgeSize.xl,
          ),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        Text(
          'Belum ada printer yang dipasangkan',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSizes.spaceSm),
        Text(
          'Pemasangan printer dilakukan sekali saja di Pengaturan Bluetooth '
          'HP, sama seperti memasangkan speaker atau headset.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: context.palette.inkSecondary),
        ),
        const SizedBox(height: AppSizes.spaceLg),
        const _GuideStep(number: '1', text: 'Nyalakan printer thermal-mu.'),
        const SizedBox(height: AppSizes.spaceSm),
        const _GuideStep(
          number: '2',
          text: 'Pasangkan lewat Pengaturan Bluetooth HP. Kalau diminta PIN, '
              'biasanya 1234 atau 0000.',
        ),
        const SizedBox(height: AppSizes.spaceSm),
        const _GuideStep(number: '3', text: 'Kembali ke sini — printernya akan muncul.'),
        const SizedBox(height: AppSizes.spaceLg),
        SizedBox(
          height: AppSizes.buttonHeight,
          child: FilledButton.icon(
            onPressed: PrinterDeviceSheet.openAndroidBluetoothSettings,
            icon: const Icon(Icons.settings_bluetooth, size: AppSizes.iconMd),
            label: const Text('Buka Pengaturan Bluetooth Android'),
          ),
        ),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.palette.primary100,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: theme.textTheme.labelLarge?.copyWith(color: context.palette.primaryDeep),
          ),
        ),
        const SizedBox(width: AppSizes.spaceMs),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// Kegagalan membaca daftar perangkat — tiap sebab punya tindak lanjut
/// yang berbeda, jadi pesannya pun berbeda (AC-3.5, AC-3.10).
class _DeviceError extends ConsumerWidget {
  const _DeviceError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = error is PrinterException ? (error as PrinterException).failure : null;
    final message = error is PrinterException
        ? (error as PrinterException).message
        : AppErrorMessage.from(error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBanner(
          tone: AppTone.warning,
          icon: failure == PrinterFailure.bluetoothOff
              ? Icons.bluetooth_disabled
              : Icons.lock_outline,
          title: failure == PrinterFailure.bluetoothOff
              ? 'Bluetooth mati'
              : 'Belum bisa membaca daftar printer',
          message: message,
        ),
        const SizedBox(height: AppSizes.spaceMd),
        SizedBox(
          height: AppSizes.buttonHeight,
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(bondedPrintersProvider),
            icon: const Icon(Icons.refresh_rounded, size: AppSizes.iconMd),
            label: const Text('Coba Lagi'),
          ),
        ),
        const SizedBox(height: AppSizes.spaceSm),
        TextButton.icon(
          onPressed: PrinterDeviceSheet.openAndroidBluetoothSettings,
          icon: const Icon(Icons.settings_bluetooth, size: AppSizes.iconSm),
          label: const Text('Buka Pengaturan Bluetooth Android'),
        ),
      ],
    );
  }
}
