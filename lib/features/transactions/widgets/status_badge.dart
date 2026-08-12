import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';

/// Label status transaksi (`sales.status`:
/// `'completed' | 'debt_unpaid' | 'voided'`) dalam bentuk [AppPill].
///
/// Pemetaan nada mengikuti `docs/ui-redesign-foundation.md` §2.5 supaya
/// status yang sama berwarna sama di layar manapun:
/// lunas → `success`, hutang → `accent` (gula aren), batal → `danger`.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.dense = false, this.showIcon = true});

  final String status;

  /// Versi rapat untuk dipakai di dalam list padat.
  final bool dense;

  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final style = SaleStatusStyle.of(status);
    return AppPill(
      label: style.label,
      tone: style.tone,
      icon: showIcon ? style.icon : null,
      dense: dense,
      // "Batal" adalah satu-satunya status yang butuh penekanan maksimal:
      // transaksi ini tidak lagi dihitung sebagai penjualan.
      filled: status == 'voided',
    );
  }
}

/// Label, nada, dan ikon Bahasa Indonesia untuk satu nilai `sales.status`.
class SaleStatusStyle {
  const SaleStatusStyle({required this.label, required this.tone, required this.icon});

  final String label;
  final AppTone tone;
  final IconData icon;

  static SaleStatusStyle of(String status) => switch (status) {
    'completed' => const SaleStatusStyle(
      label: 'Lunas',
      tone: AppTone.success,
      icon: Icons.check_circle_outline,
    ),
    'debt_unpaid' => const SaleStatusStyle(
      label: 'Hutang',
      tone: AppTone.accent,
      icon: Icons.schedule_outlined,
    ),
    'voided' => const SaleStatusStyle(
      label: 'Batal',
      tone: AppTone.danger,
      icon: Icons.block_outlined,
    ),
    _ => SaleStatusStyle(label: status, tone: AppTone.neutral, icon: Icons.help_outline),
  };
}

/// Label Bahasa Indonesia untuk `sales.payment_method`
/// (`'cash' | 'noncash' | 'debt'`).
String paymentMethodLabel(String method) {
  return switch (method) {
    'cash' => 'Tunai',
    'noncash' => 'Non-tunai',
    'debt' => 'Hutang',
    _ => method,
  };
}

/// Nada warna metode bayar (foundation §2.5): tunai hijau, non-tunai biru,
/// hutang gula aren.
AppTone paymentMethodTone(String method) {
  return switch (method) {
    'cash' => AppTone.success,
    'noncash' => AppTone.info,
    'debt' => AppTone.accent,
    _ => AppTone.neutral,
  };
}

/// Ikon metode bayar — dipakai sebagai [AppIconBadge] di baris riwayat
/// supaya metode bisa dikenali tanpa membaca teks.
IconData paymentMethodIcon(String method) {
  return switch (method) {
    'cash' => Icons.payments_outlined,
    'noncash' => Icons.qr_code_2_outlined,
    'debt' => Icons.account_balance_wallet_outlined,
    _ => Icons.receipt_long_outlined,
  };
}
