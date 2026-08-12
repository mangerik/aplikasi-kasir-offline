import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_widgets.dart';

/// Keypad PIN besar (plan.md Milestone 5 poin 6: "Layar input PIN dengan
/// keypad besar") — indikator titik + tombol angka 0-9 & hapus, tinggi
/// tombol jauh di atas 48dp (PRD §6).
///
/// Dipakai [PinEntryScreen] dan bisa dipakai ulang di layar lain yang
/// butuh input PIN cepat tanpa keyboard sistem.
///
/// Desain (docs/ui-redesign-foundation.md): tombol berupa kartu "kertas"
/// putih hangat dengan garis tipis dan angka `headlineLarge`, bukan
/// lingkaran tonal generik. Indikator titik membesar halus saat terisi,
/// dan seluruh baris titik BERGETAR + berubah merah saat PIN salah —
/// feedback yang terbaca sekejap tanpa harus membaca teks error.
class PinKeypad extends StatefulWidget {
  const PinKeypad({
    super.key,
    required this.onCompleted,
    this.digitCount = 6,
    this.errorText,
    this.enabled = true,
  });

  /// Dipanggil sekali setiap kali PIN mencapai [digitCount] digit — TIDAK
  /// otomatis mereset input (pemanggil bertanggung jawab me-reset via
  /// [errorText] baru bila PIN salah).
  final ValueChanged<String> onCompleted;

  final int digitCount;

  /// Pesan error (mis. "PIN salah") ditampilkan di atas keypad bila
  /// terisi, dan input otomatis direset.
  final String? errorText;

  /// `false` saat PIN sedang diverifikasi — tombol mati supaya pengguna
  /// tidak menumpuk input di atas proses yang sedang jalan.
  final bool enabled;

  @override
  State<PinKeypad> createState() => _PinKeypadState();
}

class _PinKeypadState extends State<PinKeypad> with SingleTickerProviderStateMixin {
  String _input = '';
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: AppDurations.medium);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PinKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != null && widget.errorText != oldWidget.errorText) {
      _input = '';
      _shakeController.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  void _onDigit(String digit) {
    if (_input.length >= widget.digitCount) return;
    HapticFeedback.selectionClick();
    setState(() => _input += digit);
    if (_input.length == widget.digitCount) {
      final completed = _input;
      // Reset TAMPILAN titik setelah jeda singkat supaya pengguna sempat
      // melihat titik terakhir terisi sebelum layar berpindah/berubah.
      Future.delayed(AppDurations.instant, () {
        if (mounted) setState(() => _input = '');
      });
      widget.onCompleted(completed);
    }
  }

  void _onBackspace() {
    if (_input.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            // Getar meredam: 3 ayunan yang mengecil, selesai < 320ms.
            final t = _shakeController.value;
            final offset = t == 0 ? 0.0 : (1 - t) * 10 * _sin3(t);
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: _PinDots(count: widget.digitCount, filled: _input.length, hasError: hasError),
        ),
        SizedBox(height: hasError ? AppSizes.spaceMs : AppSizes.spaceLg),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spaceMs),
            child: AppPill(
              label: widget.errorText!,
              tone: AppTone.danger,
              icon: Icons.error_outline_rounded,
            ),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spaceMs),
                  child: Row(
                    children: [
                      for (final d in row)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceXs),
                            child: _KeypadButton(
                              label: d,
                              onTap: widget.enabled ? () => _onDigit(d) : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                children: [
                  const Expanded(child: SizedBox(height: _keyHeight)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceXs),
                      child: _KeypadButton(
                        label: '0',
                        onTap: widget.enabled ? () => _onDigit('0') : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceXs),
                      child: _KeypadButton(
                        icon: Icons.backspace_outlined,
                        semanticLabel: 'Hapus satu angka',
                        muted: true,
                        onTap: widget.enabled && _input.isNotEmpty ? _onBackspace : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tiga ayunan penuh sepanjang animasi (tanpa impor `dart:math` demi
  /// menjaga file ini ringan) — cukup mendekati sinus untuk efek getar.
  static double _sin3(double t) {
    final x = (t * 3) % 1.0;
    // Segitiga -1..1..-1, terasa sebagai getaran cepat kiri-kanan.
    return x < 0.5 ? (x * 4 - 1) : (3 - x * 4);
  }
}

const double _keyHeight = 64;

/// Deretan titik indikator jumlah digit yang sudah dimasukkan.
class _PinDots extends StatelessWidget {
  const _PinDots({required this.count, required this.filled, required this.hasError});

  final int count;
  final int filled;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final active = hasError ? AppColors.danger : AppColors.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: AppDurations.instant,
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: AppSizes.spaceSm),
          width: isFilled ? 16 : 12,
          height: isFilled ? 16 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? active : AppColors.surface,
            border: Border.all(color: isFilled ? active : AppColors.borderStrong, width: 1.5),
          ),
        );
      }),
    );
  }
}

/// Satu tombol keypad: kartu kertas dengan angka besar.
class _KeypadButton extends StatefulWidget {
  const _KeypadButton({
    this.label,
    this.icon,
    this.semanticLabel,
    this.muted = false,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final String? semanticLabel;

  /// Tombol pendukung (hapus) — tanpa permukaan kartu supaya angka tetap
  /// jadi bintang layar.
  final bool muted;

  final VoidCallback? onTap;

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppSizes.radiusLg);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedContainer(
        duration: AppDurations.instant,
        curve: Curves.easeOutCubic,
        height: _keyHeight,
        decoration: BoxDecoration(
          color: widget.muted
              ? Colors.transparent
              : (_pressed ? AppColors.primary50 : AppColors.surface),
          borderRadius: borderRadius,
          border: widget.muted
              ? null
              : Border.all(
                  color: _pressed ? AppColors.primary200 : AppColors.border,
                  width: AppSizes.hairline,
                ),
          boxShadow: widget.muted || _pressed ? AppShadows.level0 : AppShadows.level1,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            borderRadius: borderRadius,
            splashColor: AppColors.primary.withValues(alpha: 0.06),
            highlightColor: AppColors.primary.withValues(alpha: 0.04),
            child: Center(
              child: widget.icon != null
                  ? Icon(
                      widget.icon,
                      size: AppSizes.iconLg,
                      color: enabled ? AppColors.inkSecondary : AppColors.inkTertiary,
                    )
                  : Text(
                      widget.label!,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: enabled ? AppColors.ink : AppColors.inkTertiary,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
