import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';
import '../widgets/pin_keypad.dart';

/// Layar input PIN dengan keypad besar (plan.md Milestone 5 poin 6).
///
/// Dipakai untuk SEMUA alur PIN: verifikasi (gerbang Laporan/Pengaturan/
/// void — lihat `features/transactions/utils/pin_gate.dart`), dan
/// set/ubah/hapus PIN (lihat `features/settings/widgets/pin_section.dart`).
/// Satu widget dipakai ulang di semua tempat supaya UX konsisten.
///
/// Desain (docs/ui-redesign-foundation.md): satu titik fokus — gembok,
/// judul, titik indikator — lalu keypad menempel di sepertiga bawah layar
/// (zona jempol). Saat PIN sedang diverifikasi keypad TIDAK diganti
/// spinner (bikin layar melompat), hanya dinonaktifkan sambil menampilkan
/// baris status kecil.
class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key, required this.title, this.subtitle, this.validator});

  final String title;
  final String? subtitle;

  /// Bila diisi, PIN yang dimasukkan diverifikasi lewat callback ini
  /// SEBELUM layar ditutup — balikan `false` menampilkan "PIN salah" dan
  /// membiarkan pengguna mencoba lagi (layar TIDAK tertutup). `null`
  /// berarti PIN apa pun langsung diterima (dipakai alur "buat PIN baru").
  final Future<bool> Function(String pin)? validator;

  /// Menampilkan layar sebagai route baru, mengembalikan PIN yang berhasil
  /// dimasukkan (lolos [validator] bila ada), atau `null` bila dibatalkan
  /// (tombol kembali).
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    Future<bool> Function(String pin)? validator,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PinEntryScreen(title: title, subtitle: subtitle, validator: validator),
      ),
    );
  }

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String? _errorText;
  bool _checking = false;

  Future<void> _onCompleted(String pin) async {
    if (widget.validator == null) {
      Navigator.of(context).pop(pin);
      return;
    }
    setState(() {
      _checking = true;
      _errorText = null;
    });
    final ok = await widget.validator!(pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(pin);
    } else {
      setState(() {
        _checking = false;
        _errorText = 'PIN salah, coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // Judul sengaja TIDAK ditaruh di AppBar: di layar sefokus ini judul
      // besar di badan layar lebih terbaca, dan menghindari teks kembar.
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.spaceLg,
                AppSizes.screenPadding,
                AppSizes.spaceXl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIconBadge(
                    icon: Icons.lock_outline_rounded,
                    tone: AppTone.primary,
                    size: AppIconBadgeSize.xl,
                  ),
                  const SizedBox(height: AppSizes.spaceMl),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSizes.spaceXs),
                  Text(
                    widget.subtitle ?? 'Masukkan 6 digit PIN kamu.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkSecondary),
                  ),
                  const SizedBox(height: AppSizes.spaceXl),
                  PinKeypad(onCompleted: _onCompleted, errorText: _errorText, enabled: !_checking),
                  const SizedBox(height: AppSizes.spaceMd),
                  SizedBox(
                    height: AppSizes.minTouchTarget,
                    child: _checking
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: AppSizes.iconSm,
                                height: AppSizes.iconSm,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: AppSizes.spaceSm),
                              Text('Memeriksa PIN…', style: theme.textTheme.bodySmall),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                size: AppSizes.iconSm,
                                color: AppColors.inkSecondary,
                              ),
                              const SizedBox(width: AppSizes.spaceXs + 2),
                              Flexible(
                                child: Text(
                                  'PIN hanya tersimpan di HP ini, tidak dikirim ke mana pun.',
                                  style: theme.textTheme.bodySmall,
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
    );
  }
}
