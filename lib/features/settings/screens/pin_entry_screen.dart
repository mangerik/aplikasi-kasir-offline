import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../widgets/pin_keypad.dart';

/// Layar input PIN dengan keypad besar (plan.md Milestone 5 poin 6).
///
/// Dipakai untuk SEMUA alur PIN: verifikasi (gerbang Laporan/Pengaturan/
/// void — lihat `features/transactions/utils/pin_gate.dart`), dan
/// set/ubah/hapus PIN (lihat `features/settings/widgets/pin_section.dart`).
/// Satu widget dipakai ulang di semua tempat supaya UX konsisten.
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.subtitle != null) ...[
                  Text(
                    widget.subtitle!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSizes.spaceLg),
                ],
                if (_checking)
                  const Padding(
                    padding: EdgeInsets.all(AppSizes.spaceLg),
                    child: CircularProgressIndicator(),
                  )
                else
                  PinKeypad(onCompleted: _onCompleted, errorText: _errorText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
