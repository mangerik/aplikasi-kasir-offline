import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/recovery_code.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/app_user.dart';
import '../../settings/screens/pin_entry_screen.dart';
import '../providers/auth_providers.dart';
import 'recovery_code_screen.dart';

/// Pemulihan PIN Pemilik lewat **kode pemulihan offline** (PRD v1.1
/// §8.3.E, K-8.4).
///
/// Satu-satunya jalan keluar yang tidak menyandera data. Kalau kodenya pun
/// hilang, layar ini mengatakannya terus terang alih-alih memberi harapan
/// palsu: tidak ada pihak yang bisa mereset dari luar karena memang tidak
/// ada akun online — konsekuensi jujur dari janji "jalan tanpa internet".
class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key, required this.owner});

  final AppUser owner;

  static Future<void> show(BuildContext context, {required AppUser owner}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ForgotPinScreen(owner: owner)),
    );
  }

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _controller.text;
    if (!RecoveryCode.isWellFormed(input)) {
      setState(() => _error = 'Kode pemulihan terdiri dari 8 karakter.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final usecase = ref.read(multiUserUsecaseProvider);
    final matched = await usecase.verifyRecoveryCode(input);
    if (!mounted) return;
    if (!matched) {
      setState(() {
        _busy = false;
        _error = 'Kode pemulihan tidak cocok. Periksa lagi catatanmu.';
      });
      return;
    }

    setState(() => _busy = false);

    // Kode sudah terbukti benar → langsung buat PIN baru. Keypad yang sama
    // dengan seluruh alur PIN lain, supaya tidak ada "layar asing" di saat
    // pengguna sedang panik.
    final newPin = await PinEntryScreen.show(
      context,
      title: 'PIN Pemilik Baru',
      subtitle: 'Buat 6 digit PIN baru untuk ${widget.owner.name}.',
    );
    if (!mounted || newPin == null) return;

    try {
      final replacement = await usecase.resetOwnerPinWithRecoveryCode(
        code: input,
        newPin: newPin,
        ownerId: widget.owner.id,
      );
      if (!mounted) return;
      await ref.read(sessionProvider.notifier).clearThrottle();
      if (!mounted) return;
      await RecoveryCodeScreen.show(context, code: replacement, isReplacement: true);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Lupa PIN Pemilik')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.spaceLg,
                AppSizes.screenPadding,
                AppSizes.spaceXl,
              ),
              children: [
                const AppIconBadge(
                  icon: Icons.vpn_key_outlined,
                  tone: AppTone.warning,
                  size: AppIconBadgeSize.xl,
                ),
                const SizedBox(height: AppSizes.spaceMl),
                Text(
                  'Masukkan kode pemulihan',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSizes.spaceXs),
                Text(
                  'Kode 8 karakter yang kamu catat saat menyalakan '
                  'multi-pengguna. Huruf besar-kecil tidak berpengaruh.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.inkSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceLg),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: context.textStyles.numeric.copyWith(
                    fontSize: 24,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XXXX-XXXX',
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSizes.spaceMd),
                SizedBox(
                  height: AppSizes.buttonHeight,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Memeriksa…' : 'Lanjutkan'),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceLg),
                AppCard(
                  color: palette.surfaceAlt,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kodenya juga hilang?', style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSizes.spaceXs),
                      Text(
                        'Tidak ada pihak yang bisa mereset PIN dari luar — '
                        'aplikasi ini memang tidak punya akun online. Yang '
                        'masih bisa diselamatkan adalah datanya: pasang ulang '
                        'aplikasi lalu restore file backup terakhirmu.',
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
    );
  }
}
