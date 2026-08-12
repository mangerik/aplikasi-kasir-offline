import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/auth_providers.dart';

/// Layar penolakan akses (PRD v1.1 §8.3.C & §8.6).
///
/// Sengaja memakai pola [EmptyState], bukan dialog error telanjang: kasir
/// yang menabrak batas izin sedang bekerja di depan pembeli, dan yang dia
/// butuhkan adalah jalan keluar ("panggil pemilik") — bukan pemberitahuan
/// bahwa dia salah. Menyembunyikan menu tanpa penjelasan juga ditolak PRD:
/// tombol yang hilang tanpa sebab membuat orang mengira aplikasinya rusak.
class AccessDeniedScreen extends ConsumerWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akses Terbatas')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: EmptyState(
              icon: Icons.lock_outline_rounded,
              tone: AppTone.warning,
              title: 'Fitur ini hanya untuk Pemilik',
              message: 'Minta Pemilik untuk masuk kalau bagian ini memang '
                  'perlu dibuka sekarang.',
              actionLabel: 'Masuk sebagai Pemilik',
              onAction: () async {
                await ref.read(sessionProvider.notifier).signOut();
                if (!context.mounted) return;
                context.go(AppRoutes.login);
              },
              secondaryActionLabel: 'Kembali ke Kasir',
              onSecondaryAction: () => context.go(AppRoutes.pos),
            ),
          ),
        ),
      ),
    );
  }
}
