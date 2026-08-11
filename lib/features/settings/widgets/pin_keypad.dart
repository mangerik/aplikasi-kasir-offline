import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

/// Keypad PIN besar (plan.md Milestone 5 poin 6: "Layar input PIN dengan
/// keypad besar") — 6 indikator titik + tombol angka 0-9 & hapus, tombol
/// ≥ 48dp (PRD §6).
///
/// Dipakai [PinEntryScreen] dan bisa dipakai ulang di layar lain yang
/// butuh input PIN cepat tanpa keyboard sistem.
class PinKeypad extends StatefulWidget {
  const PinKeypad({super.key, required this.onCompleted, this.digitCount = 6, this.errorText});

  /// Dipanggil sekali setiap kali PIN mencapai [digitCount] digit — TIDAK
  /// otomatis mereset input (pemanggil bertanggung jawab me-reset via
  /// [PinKeypadController]/`key` baru bila PIN salah).
  final ValueChanged<String> onCompleted;

  final int digitCount;

  /// Pesan error (mis. "PIN salah") ditampilkan di atas keypad bila
  /// terisi, dan input otomatis direset.
  final String? errorText;

  @override
  State<PinKeypad> createState() => _PinKeypadState();
}

class _PinKeypadState extends State<PinKeypad> {
  String _input = '';

  @override
  void didUpdateWidget(PinKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != null && widget.errorText != oldWidget.errorText) {
      _input = '';
    }
  }

  void _onDigit(String digit) {
    if (_input.length >= widget.digitCount) return;
    setState(() => _input += digit);
    if (_input.length == widget.digitCount) {
      final completed = _input;
      // Reset TAMPILAN titik setelah jeda singkat supaya pengguna sempat
      // melihat titik terakhir terisi sebelum layar berpindah/berubah.
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _input = '');
      });
      widget.onCompleted(completed);
    }
  }

  void _onBackspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.digitCount, (i) {
            final filled = i < _input.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.primary : Colors.transparent,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
            );
          }),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: AppSizes.spaceSm),
          Text(
            widget.errorText!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: AppSizes.spaceLg),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final d in row) _KeypadButton(label: d, onTap: () => _onDigit(d))],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72, height: 72),
            _KeypadButton(label: '0', onTap: () => _onDigit('0')),
            SizedBox(
              width: 72,
              height: 72,
              child: IconButton(
                onPressed: _input.isEmpty ? null : _onBackspace,
                iconSize: 28,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceSm),
      child: Material(
        color: AppColors.primaryLight,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
