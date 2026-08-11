import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/held_cart.dart';
import '../providers/cart_provider.dart';
import '../providers/held_cart_providers.dart';

/// Daftar transaksi yang ditahan/parkir — lanjutkan atau hapus
/// (plan.md Milestone 2 poin 8).
class HeldCartsScreen extends ConsumerWidget {
  const HeldCartsScreen({super.key});

  Future<void> _resume(BuildContext context, WidgetRef ref, HeldCart heldCart) async {
    final currentCart = ref.read(cartProvider);
    if (currentCart.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ganti Keranjang Aktif?'),
          content: const Text(
            'Keranjang yang sedang berjalan berisi item dan akan digantikan oleh '
            'transaksi yang ditahan ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ganti'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    ref.read(cartProvider.notifier).loadHeldCart(heldCart);
    await ref.read(heldCartRepoProvider).delete(heldCart.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, HeldCart heldCart) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Transaksi Ditahan?'),
        content: const Text('Transaksi yang ditahan ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(heldCartRepoProvider).delete(heldCart.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heldCartsAsync = ref.watch(heldCartListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Ditahan')),
      body: heldCartsAsync.when(
        data: (heldCarts) {
          if (heldCarts.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.spaceLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pause_circle_outline,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    Text(
                      'Belum ada transaksi ditahan',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.spaceSm),
                    Text(
                      'Tap "Tahan" di keranjang untuk memarkir transaksi dan '
                      'melayani pembeli lain dulu.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.spaceMd),
            itemCount: heldCarts.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spaceSm),
            itemBuilder: (context, index) {
              final heldCart = heldCarts[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceMd,
                    vertical: AppSizes.spaceSm,
                  ),
                  title: Text(heldCart.label?.isNotEmpty == true ? heldCart.label! : 'Tanpa label'),
                  subtitle: Text(
                    '${heldCart.items.length} item · ${CurrencyFormatter.format(heldCart.total)}\n'
                    '${DateFormatter.formatDateTime(heldCart.createdAt)}',
                  ),
                  isThreeLine: true,
                  onTap: () => _resume(context, ref, heldCart),
                  trailing: IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () => _delete(context, ref, heldCart),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Gagal memuat transaksi ditahan: $error')),
      ),
    );
  }
}
