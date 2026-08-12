import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/points_settings.dart';
import '../providers/customer_providers.dart';

/// Membuka pemilih pelanggan (PRD v1.1 §7.3.B & §7.6) dan mengembalikan
/// pelanggan yang dipilih, atau `null` bila kasir menutup sheet.
///
/// Dipakai sheet pembayaran (wajib untuk hutang, opsional untuk tunai/
/// non-tunai) dan layar Pelanggan (tombol tambah).
Future<CustomerListItem?> showCustomerPicker(
  BuildContext context, {
  PointsSettings points = const PointsSettings(),
}) {
  return showModalBottomSheet<CustomerListItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CustomerPickerSheet(points: points),
  );
}

/// Pemilih pelanggan: satu field pencarian yang langsung fokus, hasil
/// sebagai baris besar, dan jalan keluar "Buat pelanggan baru" tepat di
/// tempat kasir sudah mengetik namanya.
///
/// Keputusan desain (docs/ui-redesign-foundation.md): sheet ini muncul
/// HANYA bila ditekan. Alur kasir tunai tanpa pelanggan tidak bertambah
/// satu tap pun (AC-7.5) — tombol pemilih ada di sheet pembayaran, bukan
/// di jalur "Bayar → Selesai".
class CustomerPickerSheet extends ConsumerStatefulWidget {
  const CustomerPickerSheet({super.key, this.points = const PointsSettings()});

  final PointsSettings points;

  @override
  ConsumerState<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createAndPick(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty || _creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final created = await ref.read(customerRepoProvider).create(name: name);
      ref.invalidate(customerListProvider);
      ref.invalidate(customerDebtOverviewProvider);
      if (!mounted) return;
      Navigator.of(context).pop(
        CustomerListItem(
          id: created.id,
          name: created.name,
          phone: created.phone,
          points: created.points,
          totalDebt: 0,
          debtTransactionCount: 0,
          isActive: created.isActive,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorMessage.from(e);
          _creating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resultsAsync = ref.watch(customerPickerResultsProvider(_query));
    final trimmed = _query.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSizes.spaceMs),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.border,
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.spaceMd,
                AppSizes.screenPadding,
                AppSizes.spaceSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Pilih Pelanggan', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSizes.spaceMs),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Ketik nama atau no. HP…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  0,
                  AppSizes.screenPadding,
                  AppSizes.spaceSm,
                ),
                child: AppBanner(
                  tone: AppTone.danger,
                  icon: Icons.error_outline_rounded,
                  message: _error!,
                ),
              ),
            Expanded(
              child: resultsAsync.when(
                data: (results) => _buildResults(results, trimmed),
                loading: () => const AppLoadingView(),
                error: (e, _) => AppErrorView(
                  title: 'Daftar pelanggan gagal dimuat',
                  message: AppErrorMessage.from(e),
                  onRetry: () => ref.invalidate(customerPickerResultsProvider(_query)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(List<CustomerListItem> results, String trimmed) {
    final hasExact =
        results.any((c) => c.name.toLowerCase() == trimmed.toLowerCase());
    final showCreate = trimmed.isNotEmpty && !hasExact;

    if (results.isEmpty && !showCreate) {
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: trimmed.isEmpty ? 'Belum ada pelanggan' : 'Tidak ada yang cocok',
        message: trimmed.isEmpty
            ? 'Ketik nama pembeli langganan untuk membuat data pelanggan '
                  'pertama kamu.'
            : 'Coba kata kunci lain, atau ketik nama lengkapnya untuk '
                  'membuat pelanggan baru.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        0,
        AppSizes.screenPadding,
        AppSizes.spaceXl,
      ),
      itemCount: results.length + (showCreate ? 1 : 0),
      itemBuilder: (context, index) {
        if (showCreate && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
            child: _CreateTile(
              name: trimmed,
              busy: _creating,
              onTap: () => _createAndPick(trimmed),
            ),
          );
        }
        final customer = results[index - (showCreate ? 1 : 0)];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
          child: CustomerPickerTile(
            customer: customer,
            points: widget.points,
            onTap: () => Navigator.of(context).pop(customer),
          ),
        );
      },
    );
  }
}

/// Baris "Buat pelanggan baru: `<ketikan>`" — satu tap, nama saja; nomor HP
/// bisa dilengkapi belakangan dari layar Pelanggan (PRD §7.3.B).
class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.name, required this.busy, required this.onTap});

  final String name;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: busy ? null : onTap,
      color: context.palette.primary50,
      borderColor: context.palette.primary100,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          const AppIconBadge(icon: Icons.person_add_alt_1_outlined, tone: AppTone.primary),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Buat pelanggan baru', style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: context.palette.primary,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            SizedBox(
              width: AppSizes.iconSm,
              height: AppSizes.iconSm,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.palette.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Satu baris pelanggan di pemilih — tinggi jauh di atas 56dp, dengan
/// dua penanda yang paling menentukan keputusan kasir: sisa hutang
/// (aksen) dan saldo poin (hanya bila program poin menyala, AC-7.6).
class CustomerPickerTile extends StatelessWidget {
  const CustomerPickerTile({
    super.key,
    required this.customer,
    required this.onTap,
    this.points = const PointsSettings(),
  });

  final CustomerListItem customer;
  final VoidCallback onTap;
  final PointsSettings points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = <String>[
      if (customer.phone != null && customer.phone!.isNotEmpty) customer.phone!,
      if (customer.hasDebt)
        'Hutang ${CurrencyFormatter.format(customer.totalDebt)}',
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          AppIconBadge(
            icon: Icons.person_outline_rounded,
            tone: customer.hasDebt ? AppTone.accent : AppTone.neutral,
          ),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (points.enabled) ...[
            const SizedBox(width: AppSizes.spaceSm),
            AppPill(
              label: '${customer.points} poin',
              tone: AppTone.accent,
              icon: Icons.stars_rounded,
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}
