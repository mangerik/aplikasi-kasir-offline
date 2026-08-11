import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../domain/repositories/repository_exceptions.dart';
import '../providers/settings_providers.dart';
import '../screens/pin_entry_screen.dart';
import 'settings_card.dart';

/// Seksi Kunci PIN (plan.md Milestone 5 poin 6, architecture.md §5.4):
/// set/ubah/hapus PIN 6 digit, melindungi tab Laporan, Pengaturan, dan
/// void transaksi (`checkPinGate`, `MainShell`).
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(pinActiveProvider);
    return SettingsCard(
      title: 'Kunci PIN',
      subtitle: 'Melindungi tab Laporan, Pengaturan, dan pembatalan transaksi.',
      children: [
        activeAsync.when(
          data: (active) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(active ? 'Status: AKTIF' : 'Status: nonaktif'),
              const SizedBox(height: AppSizes.spaceSm),
              if (!active)
                SizedBox(
                  height: AppSizes.minTouchTarget,
                  child: FilledButton.icon(
                    onPressed: () => _activate(context, ref),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Aktifkan PIN'),
                  ),
                )
              else ...[
                SizedBox(
                  height: AppSizes.minTouchTarget,
                  child: OutlinedButton.icon(
                    onPressed: () => _change(context, ref),
                    icon: const Icon(Icons.password_outlined),
                    label: const Text('Ubah PIN'),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceSm),
                SizedBox(
                  height: AppSizes.minTouchTarget,
                  child: OutlinedButton.icon(
                    onPressed: () => _remove(context, ref),
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Hapus PIN'),
                  ),
                ),
              ],
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Gagal memuat status PIN: $e'),
        ),
      ],
    );
  }
}
