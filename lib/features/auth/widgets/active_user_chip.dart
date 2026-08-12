import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../pos/providers/cart_provider.dart';
import '../providers/auth_providers.dart';

/// Penanda pengguna aktif di AppBar layar Kasir (PRD v1.1 §8.6).
///
/// Sengaja **tenang**: kapsul netral berisi inisial + nama pendek, bukan
/// pil beraksen. Satu-satunya elemen aksen di layar Kasir tetap milik CTA
/// "Bayar" — siapa yang sedang bertugas itu informasi, bukan ajakan
/// bertindak.
///
/// Tap → "Ganti Kasir" dengan konfirmasi bila keranjang sedang berisi
/// (AC-8.11): keranjang TIDAK ikut dibuang, tapi orang yang menerima
/// giliran berhak tahu ada transaksi yang belum selesai.
class ActiveUserChip extends ConsumerWidget {
  const ActiveUserChip({super.key});

  static Future<void> switchUser(BuildContext context, WidgetRef ref) async {
    final cartFilled = ref.read(cartProvider).isNotEmpty;
    if (cartFilled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ganti kasir sekarang?'),
          content: const Text(
            'Ada keranjang yang belum dibayar. Keranjangnya TIDAK akan '
            'hilang — kasir berikutnya bisa melanjutkan transaksi ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ganti Kasir'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    // Keranjang sengaja TIDAK disentuh (AC-8.11/AC-8.12).
    await ref.read(sessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final palette = context.palette;
    return Tooltip(
      message: 'Ganti kasir',
      child: SizedBox(
        // Sapu M15: sebelumnya 44dp (`minTouchTarget - 4`). Chip ini bisa
        // ditap (→ Ganti Kasir), jadi ia tunduk pada aturan ≥48dp yang sama
        // dengan tombol mana pun — dan 48dp masih muat di AppBar 56dp tanpa
        // membuatnya menyaingi CTA "Bayar" (§8.6): yang menahan penekanannya
        // adalah warna `surfaceAlt` & teks sekunder, bukan tingginya.
        height: AppSizes.minTouchTarget,
        child: AppCard(
          onTap: () => switchUser(context, ref),
          radius: AppSizes.radiusPill,
          color: palette.surfaceAlt,
          borderColor: palette.border,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceSm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  user.initials,
                  // 11px = `labelSmall`, ukuran terkecil pada skala
                  // tipografi (fondasi §3.1). Nilai 10px sebelumnya berada
                  // di luar skala dan menjadi titik terlemah keterbacaan di
                  // layar Kasir.
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: palette.inkSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spaceXs + 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  user.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: palette.inkSecondary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
