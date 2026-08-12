import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/customer.dart';
import '../providers/customer_providers.dart';

/// Membuka sheet penggabungan pelanggan. Mengembalikan `true` bila
/// penggabungan benar-benar dijalankan.
Future<bool?> showMergeCustomers(
  BuildContext context, {
  required List<CustomerListItem> candidates,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => MergeCustomersSheet(candidates: candidates),
  );
}

/// Penggabungan pelanggan kembar (PRD v1.1 §7.3.D, K-7.7).
///
/// Aksinya **satu arah dan tidak bisa dibatalkan**, jadi sheet ini
/// menampilkan pratinjau dampaknya lebih dulu — berapa transaksi, berapa
/// poin, berapa hutang yang akan berpindah — sebelum tombol konfirmasi
/// bisa ditekan. Pelanggan sumber tidak dihapus, hanya ditandai nonaktif
/// dan dicatat "digabung ke `<id>`" supaya jejaknya tetap ada.
class MergeCustomersSheet extends ConsumerStatefulWidget {
  const MergeCustomersSheet({super.key, required this.candidates});

  final List<CustomerListItem> candidates;

  @override
  ConsumerState<MergeCustomersSheet> createState() => _MergeCustomersSheetState();
}

class _MergeCustomersSheetState extends ConsumerState<MergeCustomersSheet> {
  late int _targetId;
  late final Future<CustomerMergePreview> _preview;
  bool _merging = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pratinjau dihitung SEKALI saat sheet dibuka: memilih nama yang
    // dipertahankan tidak mengubah angka gabungannya sedikit pun.
    _preview = ref
        .read(customerRepoProvider)
        .previewMerge(widget.candidates.map((c) => c.id).toList());
    // Nama yang dipertahankan defaultnya pelanggan dengan transaksi
    // terakhir paling baru — biasanya ejaan yang paling sering dipakai.
    final sorted = [...widget.candidates]..sort((a, b) {
        final aTime = a.lastTransactionAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.lastTransactionAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
    _targetId = sorted.first.id;
  }

  Future<void> _merge() async {
    if (_merging) return;
    setState(() {
      _merging = true;
      _error = null;
    });
    try {
      await ref.read(customerRepoProvider).merge(
            targetId: _targetId,
            sourceIds: widget.candidates
                .map((c) => c.id)
                .where((id) => id != _targetId)
                .toList(),
          );
      ref
        ..invalidate(customerListProvider)
        ..invalidate(customerDebtOverviewProvider)
        ..invalidate(customerDetailProvider(_targetId))
        ..invalidate(customerSummaryProvider(_targetId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorMessage.from(e);
          _merging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.spaceMd,
          AppSizes.screenPadding,
          AppSizes.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Gabungkan Pelanggan', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSizes.spaceXs),
            Text(
              'Pilih nama mana yang dipertahankan. Sisanya dinonaktifkan dan '
              'seluruh riwayat serta poinnya pindah ke nama itu.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSizes.spaceLg),
            for (final candidate in widget.candidates) ...[
              _TargetOption(
                candidate: candidate,
                selected: candidate.id == _targetId,
                onTap: () => setState(() => _targetId = candidate.id),
              ),
              const SizedBox(height: AppSizes.spaceSm),
            ],
            const SizedBox(height: AppSizes.spaceMs),
            FutureBuilder<CustomerMergePreview>(
              future: _preview,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppErrorView(
                    title: 'Pratinjau gagal dihitung',
                    message: AppErrorMessage.from(snapshot.error!),
                    compact: true,
                  );
                }
                final preview = snapshot.data;
                if (preview == null) return const AppLoadingView(compact: true);
                return _PreviewCard(preview: preview);
              },
            ),
            const SizedBox(height: AppSizes.spaceMd),
            const AppBanner(
              tone: AppTone.warning,
              icon: Icons.warning_amber_rounded,
              title: 'Tidak bisa dibatalkan',
              message: 'Penggabungan bersifat satu arah. Nama yang digabung '
                  'tetap tersimpan sebagai catatan, tapi tidak bisa dipisah '
                  'lagi.',
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.spaceMd),
              AppBanner(
                tone: AppTone.danger,
                icon: Icons.error_outline_rounded,
                title: 'Gagal menggabungkan',
                message: _error!,
              ),
            ],
            const SizedBox(height: AppSizes.spaceLg),
            SizedBox(
              height: AppSizes.buttonHeight,
              child: FilledButton.icon(
                onPressed: _merging ? null : _merge,
                icon: _merging
                    ? SizedBox(
                        width: AppSizes.iconSm,
                        height: AppSizes.iconSm,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: context.palette.onPrimary,
                        ),
                      )
                    : const Icon(Icons.merge_rounded),
                label: const Text('Gabungkan Sekarang'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetOption extends StatelessWidget {
  const _TargetOption({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final CustomerListItem candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      selected: selected,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? context.palette.primary : context.palette.inkTertiary,
          ),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  candidate.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${candidate.points} poin'
                  '${candidate.hasDebt ? ' · hutang ${CurrencyFormatter.format(candidate.totalDebt)}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (selected)
            const AppPill(label: 'Dipertahankan', tone: AppTone.primary, dense: true),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final CustomerMergePreview preview;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.palette.surfaceAlt,
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HASIL PENGGABUNGAN', style: context.textStyles.eyebrow),
          const SizedBox(height: AppSizes.spaceSm),
          AppKeyValueRow(
            label: 'Pelanggan digabung',
            value: '${preview.customerCount} nama',
          ),
          AppKeyValueRow(
            label: 'Transaksi berpindah',
            value: '${preview.transactionCount}',
          ),
          AppKeyValueRow(label: 'Saldo poin gabungan', value: '${preview.totalPoints}'),
          AppKeyValueRow(
            label: 'Sisa hutang gabungan',
            value: CurrencyFormatter.format(preview.totalDebt),
            valueColor: context.palette.accentText,
          ),
        ],
      ),
    );
  }
}
