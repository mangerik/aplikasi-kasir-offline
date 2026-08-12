import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/app_user.dart';
import '../../settings/screens/pin_entry_screen.dart';
import '../providers/auth_providers.dart';
import '../widgets/user_avatar.dart';

/// Manajemen pengguna (PRD v1.1 §8.2 poin 1 & 6, §8.3.E).
///
/// Hanya bisa dibuka Pemilik — pintunya sudah dijaga di Pengaturan (kartu
/// "Pengguna & Akses" tidak dirender untuk Kasir) dan layar ini memeriksa
/// perannya sekali lagi, karena penjagaan yang hanya satu lapis adalah
/// penjagaan yang belum diuji.
///
/// Kasir **tidak pernah dihapus keras** — hanya dinonaktifkan, supaya
/// jejaknya di transaksi lama tetap bisa dibaca (AC-8.13).
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const UsersScreen()),
    );
  }

  Future<void> _addCashier(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context, title: 'Kasir Baru');
    if (name == null || !context.mounted) return;

    final pin = await PinEntryScreen.show(
      context,
      title: 'PIN untuk $name',
      subtitle: 'Buat 6 digit PIN. Beri tahu hanya kepada orangnya.',
    );
    if (pin == null || !context.mounted) return;

    await _run(context, ref, () async {
      await ref.read(userRepoProvider).createUser(
            name: name,
            role: UserRole.cashier,
            pin: pin,
          );
    }, success: '$name ditambahkan.');
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, AppUser user) async {
    final name = await _askName(context, title: 'Ubah Nama', initial: user.name);
    if (name == null || !context.mounted) return;
    await _run(context, ref, () async {
      await ref.read(userRepoProvider).rename(userId: user.id, name: name);
    },
        success: 'Nama diperbarui. Transaksi lama tetap memakai nama '
            'sebelumnya.');
  }

  Future<void> _resetPin(BuildContext context, WidgetRef ref, AppUser user) async {
    final pin = await PinEntryScreen.show(
      context,
      title: 'PIN Baru ${user.name}',
      subtitle: 'Buat 6 digit PIN pengganti.',
    );
    if (pin == null || !context.mounted) return;
    await _run(context, ref, () async {
      await ref.read(userRepoProvider).setPin(userId: user.id, pin: pin);
    }, success: 'PIN ${user.name} berhasil direset.');
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    await _run(context, ref, () async {
      await ref
          .read(userRepoProvider)
          .setActive(userId: user.id, isActive: !user.isActive);
    },
        success: user.isActive
            ? '${user.name} dinonaktifkan. Riwayatnya tetap tersimpan.'
            : '${user.name} diaktifkan kembali.');
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action, {
    required String success,
  }) async {
    try {
      await action();
      ref
        ..invalidate(allUsersProvider)
        ..invalidate(activeUsersProvider);
      await ref.read(sessionProvider.notifier).refresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppErrorMessage.from(e))));
    }
  }

  Future<String?> _askName(
    BuildContext context, {
    required String title,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama',
            hintText: 'mis. Ani',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengguna')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCashier(context, ref),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Tambah Kasir'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: usersAsync.when(
              loading: () => const AppLoadingView(),
              error: (e, _) => AppErrorView(
                title: 'Daftar pengguna gagal dimuat',
                message: AppErrorMessage.from(e),
                onRetry: () => ref.invalidate(allUsersProvider),
              ),
              data: (users) {
                if (users.isEmpty) {
                  return EmptyState(
                    icon: Icons.group_add_outlined,
                    title: 'Belum ada kasir',
                    message: 'Tambahkan akun untuk setiap orang yang '
                        'bergantian menjaga warung.',
                    actionLabel: 'Tambah Kasir',
                    onAction: () => _addCashier(context, ref),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenPadding,
                    AppSizes.spaceMd,
                    AppSizes.screenPadding,
                    AppSizes.bottomSafePadding,
                  ),
                  children: [
                    for (final user in users)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.spaceMs),
                        child: _UserTile(
                          user: user,
                          isCurrent: user.id == currentUser?.id,
                          onRename: () => _rename(context, ref, user),
                          onResetPin: () => _resetPin(context, ref, user),
                          onToggleActive: () => _toggleActive(context, ref, user),
                        ),
                      ),
                    const SizedBox(height: AppSizes.spaceMs),
                    Text(
                      'Pengguna tidak pernah dihapus, hanya dinonaktifkan — '
                      'supaya riwayat siapa melayani transaksi lama tetap utuh.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.palette.inkSecondary,
                          ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isCurrent,
    required this.onRename,
    required this.onResetPin,
    required this.onToggleActive,
  });

  final AppUser user;
  final bool isCurrent;
  final VoidCallback onRename;
  final VoidCallback onResetPin;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(user: user, size: 48),
              const SizedBox(width: AppSizes.spaceMs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSizes.spaceXs),
                    Wrap(
                      spacing: AppSizes.spaceSm,
                      runSpacing: AppSizes.spaceXs,
                      children: [
                        UserRolePill(role: user.role),
                        if (isCurrent)
                          const AppPill(
                            label: 'Sedang bertugas',
                            tone: AppTone.success,
                            dense: true,
                          ),
                        if (!user.isActive)
                          const AppPill(
                            label: 'Nonaktif',
                            tone: AppTone.neutral,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMs),
          Wrap(
            spacing: AppSizes.spaceSm,
            children: [
              TextButton.icon(
                onPressed: onRename,
                icon: const Icon(Icons.edit_outlined, size: AppSizes.iconSm),
                label: const Text('Ubah nama'),
              ),
              TextButton.icon(
                onPressed: onResetPin,
                icon: const Icon(Icons.password_outlined, size: AppSizes.iconSm),
                label: const Text('Reset PIN'),
              ),
              TextButton.icon(
                onPressed: onToggleActive,
                icon: Icon(
                  user.isActive
                      ? Icons.person_off_outlined
                      : Icons.person_add_alt_outlined,
                  size: AppSizes.iconSm,
                ),
                label: Text(user.isActive ? 'Nonaktifkan' : 'Aktifkan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
