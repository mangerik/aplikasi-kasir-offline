import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

/// Halaman scan barcode via kamera (plan.md Milestone 1 poin 4).
///
/// `Navigator.pop` mengembalikan `String` barcode pertama yang berhasil
/// dibaca, atau `null` bila pengguna membatalkan (tombol kembali).
///
/// Layar ini sengaja TIDAK memakai `AppBar` bertema kertas: di atas gambar
/// kamera, pita krem justru memotong bidang pandang. Sebagai gantinya
/// kontrol mengambang di atas permukaan gelap.
///
/// Sejak mode gelap (PRD v1.1 §5), layar ini **dipaksa memakai
/// `AppTheme.dark()`** di kedua mode aplikasi — bukan pengecualian, justru
/// penerapan aturannya: pratinjau kamera selalu gelap, jadi chrome di
/// atasnya wajib gelap supaya kontrolnya terbaca dan bidang pandang tidak
/// tersilau. Warnanya tetap datang dari `context.palette`, bukan dari nilai
/// mentah.
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({
    super.key,
    this.title = 'Arahkan ke barcode produk',
    this.subtitle = 'Kode akan terisi otomatis begitu terbaca.',
  });

  /// Judul kartu petunjuk di bawah. Layar ini dipakai ulang oleh gerbang
  /// aktivasi lisensi (M10) untuk memindai QR kode aktivasi — kamera,
  /// bingkai bidik, dan lampu senternya sama persis, hanya kalimatnya yang
  /// berbeda. Menulis layar pemindai kedua hanya demi dua baris teks adalah
  /// duplikasi yang tidak dibayar oleh apa pun.
  final String title;
  final String subtitle;

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
    return Theme(
      data: AppTheme.dark(),
      child: Builder(builder: _buildScanner),
    );
  }

  Widget _buildScanner(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
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
                  color: palette.surface,
                  borderColor: palette.borderStrong,
                  padding: const EdgeInsets.all(AppSizes.spaceMs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        color: palette.primary,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: AppSizes.spaceMs),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: AppSizes.spaceXs),
                            Text(
                              widget.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.inkSecondary,
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
                border: Border.all(color: context.palette.ink),
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
          border: Border(
            top: BorderSide(
              color: context.palette.primary,
              width: _ScanFrame._thickness,
            ),
            left: BorderSide(
              color: context.palette.primary,
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
        backgroundColor: active
            ? context.palette.primary
            : context.palette.surface,
        foregroundColor: active
            ? context.palette.onPrimary
            : context.palette.ink,
        minimumSize: const Size.square(AppSizes.minTouchTarget),
        shape: const CircleBorder(),
      ),
    );
  }
}
