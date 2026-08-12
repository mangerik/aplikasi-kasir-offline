import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/app_widgets.dart';

/// Layar **Kode Pemulihan** — ditampilkan SEKALI SAJA (PRD v1.1 §8.3.A,
/// K-8.4, AC-8.3).
///
/// Ini layar paling jujur di seluruh aplikasi: ia harus mengatakan terus
/// terang bahwa tanpa kode ini, PIN Pemilik yang lupa **tidak bisa**
/// dipulihkan oleh siapa pun — tidak ada akun online, tidak ada nomor CS
/// yang bisa mereset. Karena itu tombol "Selesai" sengaja mati sampai
/// pengguna mencentang "Saya sudah mencatat": satu tap tambahan di sini
/// jauh lebih murah daripada data warung yang terkunci selamanya.
class RecoveryCodeScreen extends StatefulWidget {
  const RecoveryCodeScreen({super.key, required this.code, this.isReplacement = false});

  final String code;

  /// `true` bila kode ini MENGGANTIKAN kode lama (kode lama sudah hangus).
  final bool isReplacement;

  static Future<void> show(
    BuildContext context, {
    required String code,
    bool isReplacement = false,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecoveryCodeScreen(code: code, isReplacement: isReplacement),
      ),
    );
  }

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return PopScope(
      // Kode ini tidak akan pernah ditampilkan lagi; menutup layar dengan
      // gestur "kembali" berarti kehilangannya diam-diam.
      canPop: _acknowledged,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kode Pemulihan'),
          automaticallyImplyLeading: false,
        ),
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
                    icon: Icons.key_outlined,
                    tone: AppTone.warning,
                    size: AppIconBadgeSize.xl,
                  ),
                  const SizedBox(height: AppSizes.spaceMl),
                  Text(
                    'Catat kode ini sekarang',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSizes.spaceXs),
                  Text(
                    widget.isReplacement
                        ? 'Kode lama sudah tidak berlaku. Simpan kode baru ini '
                            'di tempat yang aman — kode ini hanya muncul sekali.'
                        : 'Kode ini hanya muncul sekali. Tulis di buku, simpan '
                            'di tempat yang kamu ingat.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceLg),
                  AppCard(
                    color: palette.warningSoft,
                    borderColor: palette.warning,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spaceMd,
                      vertical: AppSizes.spaceLg,
                    ),
                    child: SelectableText(
                      widget.code,
                      textAlign: TextAlign.center,
                      style: context.textStyles.numeric.copyWith(
                        fontSize: 32,
                        letterSpacing: 4,
                        color: palette.warningText,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceMs),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: widget.code),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kode disalin.')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: AppSizes.iconSm),
                          label: const Text('Salin'),
                        ),
                      ),
                      const SizedBox(width: AppSizes.spaceSm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(
                              text: 'Kode pemulihan Kasir Warung: ${widget.code}',
                              subject: 'Kode Pemulihan Kasir Warung',
                            ),
                          ),
                          icon: const Icon(Icons.share_outlined, size: AppSizes.iconSm),
                          label: const Text('Bagikan'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.spaceLg),
                  AppCard(
                    color: palette.surfaceAlt,
                    child: Text(
                      'Tanpa kode ini, PIN Pemilik yang lupa hanya bisa '
                      'dipulihkan dengan memasang ulang aplikasi — dan data '
                      'yang belum dibackup akan hilang.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.inkSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceMs),
                  CheckboxListTile(
                    value: _acknowledged,
                    onChanged: (value) =>
                        setState(() => _acknowledged = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Saya sudah mencatat kode ini'),
                  ),
                  const SizedBox(height: AppSizes.spaceSm),
                  SizedBox(
                    height: AppSizes.buttonHeight,
                    child: FilledButton(
                      onPressed: _acknowledged
                          ? () => Navigator.of(context).pop()
                          : null,
                      child: const Text('Selesai'),
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
