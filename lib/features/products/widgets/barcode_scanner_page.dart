import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/widgets/app_widgets.dart';

/// Halaman scan barcode via kamera (plan.md Milestone 1 poin 4).
///
/// `Navigator.pop` mengembalikan `String` barcode pertama yang berhasil
/// dibaca, atau `null` bila pengguna membatalkan (tombol kembali).
///
/// Layar ini sengaja TIDAK memakai `AppBar` bertema kertas: di atas gambar
/// kamera, pita krem justru memotong bidang pandang. Sebagai gantinya
/// kontrol mengambang di atas permukaan gelap ([AppColors.surfaceDark]) —
/// satu-satunya konteks gelap di area Produk, dan tetap memakai token warna
/// fondasi.
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Bingkai bidik di tengah — memberi tahu "arahkan ke sini".
          const Center(child: _ScanFrame()),

          // Kontrol atas: tutup + lampu.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spaceMd),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _OverlayIconButton(
                    tooltip: 'Tutup',
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, state, child) {
                      final isOn = state.torchState == TorchState.on;
                      return _OverlayIconButton(
                        tooltip: isOn ? 'Matikan lampu' : 'Nyalakan lampu',
                        icon: isOn
                            ? Icons.flashlight_on_rounded
                            : Icons.flashlight_off_rounded,
                        active: isOn,
                        onPressed: () => _controller.toggleTorch(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Kartu petunjuk di bawah (zona jempol).
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.spaceMd),
                child: AppCard(
                  color: AppColors.surfaceDark,
                  borderColor: AppColors.inkSecondary,
                  padding: const EdgeInsets.all(AppSizes.spaceMs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primary200,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: AppSizes.spaceMs),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Arahkan ke barcode produk',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.onDark,
                              ),
                            ),
                            const SizedBox(height: AppSizes.spaceXs),
                            Text(
                              'Kode akan terisi otomatis begitu terbaca.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.primary200,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bingkai bidik: kotak transparan bergaris terang dengan empat sudut tebal.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  static const double _size = AppSizes.space3xl * 4;
  static const double _corner = AppSizes.spaceXl;
  static const double _thickness = AppSizes.spaceXs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.onDark),
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
            ),
          ),
          const Align(alignment: Alignment.topLeft, child: _Corner()),
          const Align(
            alignment: Alignment.topRight,
            child: _Corner(quarterTurns: 1),
          ),
          const Align(
            alignment: Alignment.bottomRight,
            child: _Corner(quarterTurns: 2),
          ),
          const Align(
            alignment: Alignment.bottomLeft,
            child: _Corner(quarterTurns: 3),
          ),
        ],
      ),
    );
  }
}

/// Satu sudut bingkai (bentuk "L"), diputar untuk keempat penjuru.
class _Corner extends StatelessWidget {
  const _Corner({this.quarterTurns = 0});

  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: Container(
        width: _ScanFrame._corner,
        height: _ScanFrame._corner,
        decoration: BoxDecoration(
          border: const Border(
            top: BorderSide(
              color: AppColors.primary200,
              width: _ScanFrame._thickness,
            ),
            left: BorderSide(
              color: AppColors.primary200,
              width: _ScanFrame._thickness,
            ),
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppSizes.radiusXl),
          ),
        ),
      ),
    );
  }
}

/// Tombol ikon mengambang di atas gambar kamera.
class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: active ? AppColors.primary : AppColors.surfaceDark,
        foregroundColor: AppColors.onDark,
        minimumSize: const Size.square(AppSizes.minTouchTarget),
        shape: const CircleBorder(),
      ),
    );
  }
}
