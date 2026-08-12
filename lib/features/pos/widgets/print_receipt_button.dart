import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../../data/services/printing/receipt_printer.dart';
import '../../settings/providers/printer_providers.dart';
import '../../settings/widgets/printer_device_sheet.dart';

/// Tombol "Cetak" dengan **status di dalam tombolnya sendiri**
/// (PRD v1.1 §3.3.B): `Menghubungkan… → Mencetak… → Tercetak ✓` atau
/// `Gagal — Coba Lagi`.
///
/// Statusnya sengaja tidak dibuang ke SnackBar: kasir sedang menatap tombol
/// yang baru ia tekan, bukan bagian bawah layar, dan SnackBar menghilang
/// sendiri sebelum sempat dibaca kalau tangan sedang sibuk menghitung uang.
///
/// Tombol dinonaktifkan selama job berjalan — gerbang pertama AC-3.7 (dua
/// tap cepat = satu struk); gerbang keduanya ada di [PrintJobController],
/// gerbang ketiga mutex di transport.
class PrintReceiptButton extends StatelessWidget {
  const PrintReceiptButton({
    super.key,
    required this.job,
    required this.onPressed,
    this.printedOnce = false,
    this.idleLabel = 'Cetak Struk',
    this.reprintLabel = 'Cetak Ulang',
  });

  /// Kunci tombol cetak — stabil walau labelnya berganti-ganti.
  static const Key buttonKey = Key('print-receipt-button');

  final PrintJobState job;
  final VoidCallback onPressed;

  /// `true` bila struk sudah pernah keluar — label berubah jadi
  /// [reprintLabel] supaya kasir tahu ia akan menghasilkan lembar kedua.
  final bool printedOnce;

  final String idleLabel;
  final String reprintLabel;

  bool get _failed => job.stage == PrintStage.failed;

  String get _label => switch (job.stage) {
    PrintStage.connecting => 'Menghubungkan…',
    PrintStage.printing => 'Mencetak…',
    PrintStage.done => 'Tercetak ✓',
    PrintStage.failed => 'Gagal — Coba Lagi',
    PrintStage.idle => printedOnce ? reprintLabel : idleLabel,
  };

  IconData get _icon => switch (job.stage) {
    PrintStage.done => Icons.check_rounded,
    PrintStage.failed => Icons.refresh_rounded,
    _ => Icons.print_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final needsSystemSettings =
        job.failure == PrinterFailure.bluetoothOff ||
        job.failure == PrinterFailure.permissionDenied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppSizes.buttonHeight,
          child: OutlinedButton.icon(
            // Kunci tetap: label tombol berubah-ubah mengikuti status job,
            // jadi test (dan siapa pun yang mencarinya) tidak boleh
            // bergantung pada teksnya.
            key: buttonKey,
            style: OutlinedButton.styleFrom(
              foregroundColor: _failed
                  ? palette.dangerText
                  : (job.stage == PrintStage.done ? palette.successText : null),
              side: BorderSide(color: _failed ? palette.dangerBorder : palette.border),
            ),
            onPressed: job.isRunning ? null : onPressed,
            icon: job.isRunning
                ? const SizedBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_icon, size: AppSizes.iconSm),
            label: Text(_label),
          ),
        ),
        // Kalimat sebab-akibat hanya muncul saat gagal, dan selalu membawa
        // langkah berikutnya — bukan sekadar memberi tahu ada yang salah.
        if (_failed && job.message != null) ...[
          const SizedBox(height: AppSizes.spaceSm),
          Text(
            job.message!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.dangerText),
          ),
          if (needsSystemSettings)
            TextButton.icon(
              onPressed: PrinterDeviceSheet.openAndroidBluetoothSettings,
              icon: const Icon(Icons.settings_bluetooth, size: AppSizes.iconSm),
              label: const Text('Buka Pengaturan Bluetooth Android'),
            ),
        ],
      ],
    );
  }
}
