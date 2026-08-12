import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/held_cart.dart';
import '../providers/cart_provider.dart';
import '../providers/held_cart_providers.dart';

/// Daftar transaksi yang ditahan/parkir — lanjutkan atau hapus
/// (plan.md Milestone 2 poin 8).
///
/// Desain (docs/ui-redesign-foundation.md): transaksi ditahan memakai nada
/// `AppTone.accent` (gula aren) di seluruh aplikasi — sama seperti badge di
/// AppBar layar Kasir. Tiap kartu memuat empat hal yang dibutuhkan kasir
/// untuk memilih: label, jumlah item, waktu parkir, dan totalnya.
class HeldCartsScreen extends ConsumerWidget {
  const HeldCartsScreen({super.key});

  Future<void> _resume(BuildContext context, WidgetRef ref, HeldCart heldCart) async {
    final currentCart = ref.read(cartProvider);
    if (currentCart.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ganti Keranjang Aktif?'),
          content: const Text(
            'Keranjang yang sedang berjalan berisi item dan akan digantikan oleh '
            'transaksi yang ditahan ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Transaksi Ditahan?'),
        content: const Text('Transaksi yang ditahan ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
            return const EmptyState(
              icon: Icons.pause_circle_outline,
              tone: AppTone.accent,
              title: 'Belum ada transaksi ditahan',
              message: 'Tap "Tahan" di keranjang untuk memarkir transaksi dan '
                  'melayani pembeli lain dulu. Transaksinya menunggu di sini.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.spaceSm,
              AppSizes.screenPadding,
              AppSizes.spaceLg,
            ),
            itemCount: heldCarts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spaceSm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return SectionHeader(
                  eyebrow: 'DIPARKIR',
                  title: '${heldCarts.length} transaksi menunggu',
                  subtitle: 'Tap kartu untuk melanjutkannya ke keranjang.',
                );
              }
              final heldCart = heldCarts[index - 1];
              return _HeldCartCard(
                heldCart: heldCart,
                onResume: () => _resume(context, ref, heldCart),
                onDelete: () => _delete(context, ref, heldCart),
              );
            },
          );
        },
        loading: () => const AppLoadingView(),
        error: (error, stack) => AppErrorView(
          title: 'Gagal memuat transaksi ditahan',
          message: AppErrorMessage.from(error),
          onRetry: () => ref.invalidate(heldCartListProvider),
        ),
      ),
    );
  }
}

class _HeldCartCard extends StatelessWidget {
  const _HeldCartCard({
    required this.heldCart,
    required this.onResume,
    required this.onDelete,
  });

  final HeldCart heldCart;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLabel = heldCart.label?.trim().isNotEmpty ?? false;

    return AppCard(
      onTap: onResume,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Icons.pause_circle_filled_rounded,
            tone: AppTone.accent,
            size: AppIconBadgeSize.lg,
          ),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasLabel ? heldCart.label!.trim() : 'Tanpa label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: hasLabel ? context.palette.ink : context.palette.inkSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceXs),
                Row(
                  children: [
                    AppPill(label: '${heldCart.items.length} item', dense: true),
                    const SizedBox(width: AppSizes.spaceSm),
                    Flexible(
                      child: Text(
                        DateFormatter.formatDateTime(heldCart.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceSm),
                AppMoneyText(CurrencyFormatter.format(heldCart.total)),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spaceSm),
          IconButton(
            tooltip: 'Hapus',
            icon: Icon(Icons.delete_outline_rounded, color: context.palette.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
