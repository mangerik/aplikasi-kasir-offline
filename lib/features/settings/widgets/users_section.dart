import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/multi_user_settings.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/screens/recovery_code_screen.dart';
import '../../auth/screens/users_screen.dart';
import '../../auth/widgets/user_avatar.dart';
import '../screens/pin_entry_screen.dart';
import 'settings_card.dart';

/// Kartu **"Pengguna & Akses"** di Pengaturan (PRD v1.1 §8.3.A, §8.6).
///
/// Mengikuti pola [SettingsCard] yang sama dengan `pin_section.dart` —
/// termasuk urutan bacanya: keadaan dulu (aktif/nonaktif), baru apa yang
/// bisa dilakukan.
///
/// Multi-user **mati secara default** (K-8.5): warung tanpa karyawan tidak
/// boleh dipaksa berkenalan dengan konsep akun sama sekali.
class UsersSection extends ConsumerWidget {
  const UsersSection({super.key});

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final usecase = ref.read(multiUserUsecaseProvider);

    final name = await _askOwnerName(context);
    if (name == null || !context.mounted) return;

    String? newPin;
    if (!await usecase.hasReusableGlobalPin()) {
      if (!context.mounted) return;
      newPin = await PinEntryScreen.show(
        context,
        title: 'PIN Pemilik',
        subtitle: 'Buat 6 digit PIN untuk akun Pemilik.',
      );
      if (newPin == null || !context.mounted) return;
      final confirm = await PinEntryScreen.show(
        context,
        title: 'Ulangi PIN Pemilik',
        subtitle: 'Masukkan sekali lagi untuk konfirmasi.',
      );
      if (confirm == null || !context.mounted) return;
      if (confirm != newPin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN tidak sama. Coba lagi dari awal.')),
        );
        return;
      }
    }

    try {
      final activation = await usecase.enable(ownerName: name, newPin: newPin);
      _invalidate(ref);
      // Pemilik yang baru menyalakan fitur ini langsung menjadi pengguna
      // aktif — memaksanya masuk lagi detik itu juga hanya membuang waktu
      // dan tidak menambah keamanan apa pun.
      await ref.read(sessionProvider.notifier).refresh();
      await ref.read(sessionProvider.notifier).signIn(activation.owner);
      if (!context.mounted) return;
      await RecoveryCodeScreen.show(context, code: activation.recoveryCode);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMessage.from(e))),
      );
    }
  }

  Future<String?> _askOwnerName(BuildContext context) {
    final controller = TextEditingController(text: 'Pemilik');
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nama Pemilik'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nama ini yang muncul di layar Masuk dan di struk.'),
            const SizedBox(height: AppSizes.spaceMs),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'mis. Pak Budi'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(dialogContext).pop(value.isEmpty ? 'Pemilik' : value);
            },
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }

  Future<void> _disable(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Matikan Multi-Pengguna?'),
        content: const Text(
          'Akun kasir dinonaktifkan dan PIN Pemilik kembali menjadi PIN '
          'kunci biasa. Riwayat siapa yang melayani transaksi lama TETAP '
          'tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Matikan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(multiUserUsecaseProvider).disable();
    _invalidate(ref);
    await ref.read(sessionProvider.notifier).refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Multi-pengguna dimatikan.')),
    );
  }

  Future<void> _setAutoLock(WidgetRef ref, int minutes) async {
    await ref.read(multiUserUsecaseProvider).setAutoLockMinutes(minutes);
    ref.invalidate(multiUserSettingsProvider);
  }

  static void _invalidate(WidgetRef ref) {
    ref
      ..invalidate(multiUserSettingsProvider)
      ..invalidate(activeUsersProvider)
      ..invalidate(allUsersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(multiUserSettingsProvider);
    final currentUser = ref.watch(currentUserProvider);

    return settingsAsync.when(
      loading: () => const SettingsCard(
        icon: Icons.group_outlined,
        title: 'Pengguna & Akses',
        subtitle: 'Satu akun per orang, dengan PIN masing-masing.',
        tone: AppTone.neutral,
        children: [AppLoadingView(compact: true)],
      ),
      error: (e, _) => SettingsCard(
        icon: Icons.group_outlined,
        title: 'Pengguna & Akses',
        subtitle: 'Satu akun per orang, dengan PIN masing-masing.',
        tone: AppTone.neutral,
        children: [
          AppErrorView(
            title: 'Setelan pengguna gagal dimuat',
            message: AppErrorMessage.from(e),
            compact: true,
            onRetry: () => ref.invalidate(multiUserSettingsProvider),
          ),
        ],
      ),
      data: (settings) => SettingsCard(
        icon: settings.enabled ? Icons.groups_rounded : Icons.group_outlined,
        title: 'Pengguna & Akses',
        subtitle: 'Satu akun per orang, dengan PIN masing-masing.',
        tone: settings.enabled ? AppTone.success : AppTone.neutral,
        trailing: AppPill(
          label: settings.enabled ? 'Aktif' : 'Nonaktif',
          tone: settings.enabled ? AppTone.success : AppTone.neutral,
          dense: true,
        ),
        children: [
          if (!settings.enabled)
            _DisabledBody(onEnable: () => _enable(context, ref))
          else ...[
            if (currentUser != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
                child: Row(
                  children: [
                    UserAvatar(user: currentUser, size: 40),
                    const SizedBox(width: AppSizes.spaceMs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sedang bertugas: ${currentUser.name}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSizes.spaceXs),
                          UserRolePill(role: currentUser.role),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            _AutoLockPicker(
              minutes: settings.autoLockMinutes,
              onChanged: (value) => _setAutoLock(ref, value),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            SizedBox(
              height: AppSizes.buttonHeight,
              child: FilledButton.icon(
                onPressed: () => UsersScreen.show(context),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Kelola Pengguna'),
              ),
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppSizes.buttonHeight,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(sessionProvider.notifier).signOut(),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Ganti Kasir'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.spaceSm),
                Expanded(
                  child: SizedBox(
                    height: AppSizes.buttonHeight,
                    child: OutlinedButton.icon(
                      onPressed: () => _disable(context, ref),
                      icon: const Icon(Icons.person_off_outlined),
                      label: const Text('Matikan'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceSm),
            TextButton.icon(
              onPressed: () async {
                final code = await ref
                    .read(multiUserUsecaseProvider)
                    .regenerateRecoveryCode();
                if (!context.mounted) return;
                await RecoveryCodeScreen.show(
                  context,
                  code: code,
                  isReplacement: true,
                );
                ref.invalidate(multiUserSettingsProvider);
              },
              icon: const Icon(Icons.key_outlined, size: AppSizes.iconSm),
              label: const Text('Terbitkan ulang kode pemulihan'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DisabledBody extends StatelessWidget {
  const _DisabledBody({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Punya karyawan? Nyalakan supaya setiap transaksi tercatat atas '
          'nama yang melayani, dan kasir tidak bisa melihat laba atau '
          'membatalkan transaksi.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.palette.inkSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.spaceMs),
        const Wrap(
          spacing: AppSizes.spaceSm,
          runSpacing: AppSizes.spaceSm,
          children: [
            AppPill(label: 'Jejak kasir di struk', icon: Icons.receipt_long_outlined),
            AppPill(label: 'PIN per orang', icon: Icons.pin_outlined),
            AppPill(label: 'Kunci otomatis', icon: Icons.lock_clock_outlined),
          ],
        ),
        const SizedBox(height: AppSizes.spaceMd),
        SizedBox(
          height: AppSizes.buttonHeight,
          child: FilledButton.icon(
            onPressed: onEnable,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Aktifkan Multi-Pengguna'),
          ),
        ),
      ],
    );
  }
}

/// Pemilih kunci otomatis: mati (default) / 1 / 5 / 15 menit (§8.3.B).
class _AutoLockPicker extends StatelessWidget {
  const _AutoLockPicker({required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kunci otomatis', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSizes.spaceXs),
        Text(
          'Layar PIN menutup aplikasi setelah sekian menit tanpa aktivitas. '
          'Keranjang yang sedang berjalan tidak pernah hilang.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.palette.inkSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.spaceMs),
        Wrap(
          spacing: AppSizes.spaceSm,
          runSpacing: AppSizes.spaceSm,
          children: [
            for (final choice in MultiUserSettings.autoLockChoices)
              ChoiceChip(
                label: Text(MultiUserSettings.autoLockLabel(choice)),
                selected: choice == minutes,
                onSelected: (_) => onChanged(choice),
              ),
          ],
        ),
      ],
    );
  }
}
