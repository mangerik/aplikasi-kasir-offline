import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/services/printing/receipt_printer.dart';
import '../../../domain/entities/printer_settings.dart';
import '../providers/printer_providers.dart';
import 'printer_device_sheet.dart';
import 'receipt_format_sheet.dart';
import 'settings_card.dart';

/// Kartu "Printer Struk" di Pengaturan (PRD v1.1 §3.3.E, §3.6).
///
/// Susunannya mengikuti urutan pertanyaan pemilik warung, bukan urutan
/// tabel pengaturan: **printernya mana** → **keluar sendiri atau tidak** →
/// **coba dulu** → (jarang) **atur tampilan struknya**. Semua setelan
/// rinci (lebar kertas, salinan, logo, kalimat penutup, baris feed) sengaja
/// disembunyikan satu tap di balik "Atur Tampilan Struk": itu setelan yang
/// disentuh sekali seumur hidup, dan menaruhnya di depan membuat kartu ini
/// jadi formulir yang menakutkan.
class PrinterSection extends ConsumerWidget {
  const PrinterSection({super.key});

  static const String _jobKey = 'settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(printerSettingsProvider);

    return settingsAsync.when(
      loading: () => const SettingsCard(
        icon: Icons.print_outlined,
        title: 'Printer Struk',
        subtitle: 'Cetak struk ke printer thermal Bluetooth 58mm.',
        children: [AppLoadingView(compact: true)],
      ),
      error: (error, _) => SettingsCard(
        icon: Icons.print_outlined,
        title: 'Printer Struk',
        subtitle: 'Cetak struk ke printer thermal Bluetooth 58mm.',
        tone: AppTone.danger,
        children: [
          AppErrorView(
            title: 'Pengaturan printer gagal dimuat',
            message: AppErrorMessage.from(error),
            compact: true,
            onRetry: () => ref.invalidate(printerSettingsProvider),
          ),
        ],
      ),
      data: (settings) => _PrinterCard(settings: settings, jobKey: _jobKey),
    );
  }
}

class _PrinterCard extends ConsumerWidget {
  const _PrinterCard({required this.settings, required this.jobKey});

  final PrinterSettings settings;
  final String jobKey;

  Future<void> _connectPrinter(BuildContext context, WidgetRef ref) async {
    final device = await PrinterDeviceSheet.show(context);
    if (device == null) return;
    await ref.read(printerSettingsStoreProvider).save(
      settings.copyWith(
        address: device.address,
        name: device.displayName,
        type: PrinterSettings.typeClassic,
      ),
    );
    ref.invalidate(printerSettingsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${device.displayName} tersimpan. Coba "Cetak Uji" sekarang.'),
      ),
    );
  }

  Future<void> _forgetPrinter(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lepas Printer?'),
        content: Text(
          '${settings.displayName} tidak akan dipakai lagi untuk mencetak struk. '
          'Perangkatnya tetap terpasang di Bluetooth HP, jadi kamu bisa '
          'menghubungkannya lagi kapan saja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Lepas'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(receiptPrinterProvider).disconnect();
    await ref.read(printerSettingsStoreProvider).save(
      settings.copyWith(clearDevice: true, autoPrint: false),
    );
    ref.invalidate(printerSettingsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Printer dilepas.')));
  }

  Future<void> _setAutoPrint(WidgetRef ref, bool value) async {
    await ref.read(printerSettingsStoreProvider).save(settings.copyWith(autoPrint: value));
    ref.invalidate(printerSettingsProvider);
  }

  Future<void> _testPrint(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(printJobProvider(jobKey).notifier).printTest();
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Struk uji terkirim. Cek kertasnya.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(printJobProvider(jobKey));
    final configured = settings.isConfigured;

    return SettingsCard(
      icon: Icons.print_outlined,
      title: 'Printer Struk',
      subtitle: 'Cetak struk ke printer thermal Bluetooth 58mm.',
      tone: configured ? AppTone.success : AppTone.neutral,
      trailing: AppPill(
        label: configured
            ? (job.failure == null ? 'Terpasang' : 'Gagal terhubung')
            : 'Belum terpasang',
        tone: configured
            ? (job.failure == null ? AppTone.success : AppTone.danger)
            : AppTone.neutral,
        dense: true,
      ),
      children: [
        if (!configured)
          EmptyState(
            icon: Icons.print_disabled_outlined,
            title: 'Belum ada printer terpasang',
            message: 'Hubungkan printer thermal Bluetooth agar struk bisa '
                'langsung dicetak untuk pembeli.',
            actionLabel: 'Hubungkan Printer',
            onAction: () => _connectPrinter(context, ref),
            compact: true,
          )
        else ...[
          _ConnectedDeviceRow(
            settings: settings,
            onChange: () => _connectPrinter(context, ref),
          ),
          const SizedBox(height: AppSizes.spaceMs),
          _AutoPrintRow(
            value: settings.autoPrint,
            onChanged: (value) => _setAutoPrint(ref, value),
          ),
          if (job.stage == PrintStage.failed && job.message != null) ...[
            const SizedBox(height: AppSizes.spaceMs),
            _PrintFailureBanner(job: job),
          ],
          const SizedBox(height: AppSizes.spaceMs),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppSizes.buttonHeight,
                  child: FilledButton.icon(
                    onPressed: job.isRunning ? null : () => _testPrint(context, ref),
                    icon: job.isRunning
                        ? const SizedBox(
                            width: AppSizes.iconSm,
                            height: AppSizes.iconSm,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined, size: AppSizes.iconSm),
                    label: Text(_testLabel(job)),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              SizedBox(
                height: AppSizes.buttonHeight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.palette.dangerText,
                    side: BorderSide(color: context.palette.dangerBorder),
                  ),
                  onPressed: job.isRunning ? null : () => _forgetPrinter(context, ref),
                  child: const Text('Lepas'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMs),
          _FormatTile(
            settings: settings,
            onTap: () => ReceiptFormatSheet.show(context),
          ),
        ],
      ],
    );
  }

  static String _testLabel(PrintJobState job) => switch (job.stage) {
    PrintStage.connecting => 'Menghubungkan…',
    PrintStage.printing => 'Mencetak…',
    PrintStage.done => 'Tercetak ✓',
    PrintStage.failed => 'Coba Lagi',
    PrintStage.idle => 'Cetak Uji',
  };
}

/// Baris identitas printer terpasang: nama besar, alamat MAC kecil.
/// Alamat MAC ditampilkan karena dua printer bermerek sama di satu warung
/// tidak bisa dibedakan dari namanya.
class _ConnectedDeviceRow extends StatelessWidget {
  const _ConnectedDeviceRow({required this.settings, required this.onChange});

  final PrinterSettings settings;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: context.palette.surfaceAlt,
      radius: AppSizes.radiusMd,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Icons.bluetooth,
            tone: AppTone.info,
            size: AppIconBadgeSize.sm,
          ),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(settings.displayName, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${settings.address} · kertas ${settings.paperWidth.millimeters}mm',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.palette.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Ganti')),
        ],
      ),
    );
  }
}

class _AutoPrintRow extends StatelessWidget {
  const _AutoPrintRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text('Cetak otomatis', style: theme.textTheme.titleSmall),
      subtitle: Text(
        'Struk langsung keluar begitu transaksi tersimpan, tanpa tap tambahan.',
        style: theme.textTheme.bodySmall?.copyWith(color: context.palette.inkSecondary),
      ),
    );
  }
}

/// Pesan kegagalan cetak beserta **tindak lanjut yang tepat** untuk
/// sebabnya — bukan satu SnackBar merah seragam (AC-3.5, AC-3.10).
class _PrintFailureBanner extends StatelessWidget {
  const _PrintFailureBanner({required this.job});

  final PrintJobState job;

  @override
  Widget build(BuildContext context) {
    final needsBluetooth = job.failure == PrinterFailure.bluetoothOff;
    final needsPermission = job.failure == PrinterFailure.permissionDenied;
    return AppBanner(
      tone: AppTone.danger,
      icon: needsBluetooth ? Icons.bluetooth_disabled : Icons.print_disabled_outlined,
      title: 'Struk belum tercetak',
      message: job.message!,
      actionLabel: (needsBluetooth || needsPermission)
          ? 'Buka Pengaturan Android'
          : null,
      onAction: (needsBluetooth || needsPermission)
          ? PrinterDeviceSheet.openAndroidBluetoothSettings
          : null,
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({required this.settings, required this.onTap});

  final PrinterSettings settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      color: context.palette.surfaceAlt,
      radius: AppSizes.radiusMd,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Icons.receipt_long_outlined,
            tone: AppTone.primary,
            size: AppIconBadgeSize.sm,
          ),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Atur Tampilan Struk', style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${settings.copies} salinan · ${settings.paperWidth.millimeters}mm · '
                  '${settings.feedLines} baris kosong',
                  style: theme.textTheme.bodySmall,
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
    );
  }
}
