import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/repositories/repository_exceptions.dart';
import '../providers/settings_providers.dart';
import '../screens/pin_entry_screen.dart';
import 'settings_card.dart';

/// Seksi Kunci PIN (plan.md Milestone 5 poin 6, architecture.md §5.4):
/// set/ubah/hapus PIN 6 digit, melindungi tab Laporan, Pengaturan, dan
/// void transaksi (`checkPinGate`, `MainShell`).
///
/// Visual: status kunci jadi hal pertama yang terbaca (ikon bernada +
/// [AppPill]), lalu daftar area yang dilindungi sebagai pill — pengguna
/// tahu persis apa yang ia dapat sebelum menekan tombol.
class PinSection extends ConsumerWidget {
  const PinSection({super.key});

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    final newPin = await PinEntryScreen.show(
      context,
      title: 'Buat PIN Baru',
      subtitle: 'Masukkan 6 digit PIN baru.',
    );
    if (newPin == null || !context.mounted) return;

    final confirmPin = await PinEntryScreen.show(
      context,
      title: 'Ulangi PIN Baru',
      subtitle: 'Masukkan sekali lagi untuk konfirmasi.',
    );
    if (confirmPin == null) return;

    if (newPin != confirmPin) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PIN tidak sama. Coba lagi dari awal.')));
      }
      return;
    }

    try {
      await ref.read(setPinUsecaseProvider)(newPin);
      ref.invalidate(pinActiveProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PIN berhasil diaktifkan.')));
      }
    } on PinTidakValidException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMessage.from(e))));
      }
    }
  }

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final oldPin = await PinEntryScreen.show(
      context,
      title: 'Masukkan PIN Lama',
      validator: ref.read(verifyPinUsecaseProvider).call,
    );
    if (oldPin == null) return;
    if (!context.mounted) return;
    await _activate(context, ref);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final pin = await PinEntryScreen.show(
      context,
      title: 'Masukkan PIN untuk Menghapus Kunci',
      validator: ref.read(verifyPinUsecaseProvider).call,
    );
    if (pin == null || !context.mounted) return;

    try {
      await ref.read(removePinUsecaseProvider)(pin);
      ref.invalidate(pinActiveProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Kunci PIN dinonaktifkan.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMessage.from(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(pinActiveProvider);

    return activeAsync.when(
      data: (active) => SettingsCard(
        icon: active ? Icons.lock_rounded : Icons.lock_open_outlined,
        title: 'Kunci PIN',
        subtitle: 'PIN 6 digit untuk area yang menyangkut uang.',
        tone: active ? AppTone.success : AppTone.neutral,
        trailing: AppPill(
          label: active ? 'Aktif' : 'Nonaktif',
          tone: active ? AppTone.success : AppTone.neutral,
          dense: true,
        ),
        children: [
          _PinBody(
            active: active,
            onActivate: () => _activate(context, ref),
            onChange: () => _change(context, ref),
            onRemove: () => _remove(context, ref),
          ),
        ],
      ),
      loading: () => const SettingsCard(
        icon: Icons.lock_outline,
        title: 'Kunci PIN',
        subtitle: 'PIN 6 digit untuk area yang menyangkut uang.',
        tone: AppTone.neutral,
        children: [AppLoadingView(compact: true)],
      ),
      error: (e, _) => SettingsCard(
        icon: Icons.lock_outline,
        title: 'Kunci PIN',
        subtitle: 'PIN 6 digit untuk area yang menyangkut uang.',
        tone: AppTone.neutral,
        children: [
          AppErrorView(
            title: 'Status PIN gagal dimuat',
            message: AppErrorMessage.from(e),
            compact: true,
            onRetry: () => ref.invalidate(pinActiveProvider),
          ),
        ],
      ),
    );
  }
}

class _PinBody extends StatelessWidget {
  const _PinBody({
    required this.active,
    required this.onActivate,
    required this.onChange,
    required this.onRemove,
  });

  final bool active;
  final VoidCallback onActivate;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          active
              ? 'Area di bawah ini minta PIN sebelum bisa dibuka:'
              : 'Aktifkan supaya area di bawah ini tidak bisa dibuka orang lain:',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkSecondary),
        ),
        const SizedBox(height: AppSizes.spaceMs),
        Wrap(
          spacing: AppSizes.spaceSm,
          runSpacing: AppSizes.spaceSm,
          children: [
            AppPill(
              label: 'Laporan',
              icon: Icons.insights_outlined,
              tone: active ? AppTone.success : AppTone.neutral,
            ),
            AppPill(
              label: 'Setelan',
              icon: Icons.tune_rounded,
              tone: active ? AppTone.success : AppTone.neutral,
            ),
            AppPill(
              label: 'Batalkan transaksi',
              icon: Icons.undo_rounded,
              tone: active ? AppTone.success : AppTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceMd),
        if (!active)
          SizedBox(
            height: AppSizes.buttonHeight,
            child: FilledButton.icon(
              onPressed: onActivate,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Aktifkan PIN'),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppSizes.buttonHeight,
                  child: OutlinedButton.icon(
                    onPressed: onChange,
                    icon: const Icon(Icons.password_outlined),
                    label: const Text('Ubah PIN'),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Expanded(
                child: SizedBox(
                  height: AppSizes.buttonHeight,
                  child: OutlinedButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Hapus PIN'),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
