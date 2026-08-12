import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/points_settings.dart';
import '../../../domain/entities/sale_result.dart';
import '../../customers/widgets/customer_picker_sheet.dart';
import '../../license/providers/license_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/cart_provider.dart';
import '../providers/sale_providers.dart';

/// Jenis non-tunai yang bisa dipilih kasir (plan.md Milestone 3 poin 1:
/// "dicatat jenisnya, mis. QRIS/transfer — tanpa integrasi"). Disimpan ke
/// `sales.note` (tidak ada kolom terpisah di skema, lihat
/// docs/laporan-m3.md §3).
const List<String> _noncashTypes = ['QRIS', 'Transfer Bank', 'Kartu', 'Lainnya'];

/// Pecahan uang yang paling sering diterima warung — tombol tambah cepat.
const List<int> _quickAmounts = [10000, 20000, 50000, 100000];

/// Sheet pembayaran (plan.md Milestone 2 poin 5 & Milestone 3 poin 1):
/// pilih metode Tunai/Non-tunai/Hutang, lalu form sesuai metode:
/// - **Tunai:** input uang diterima, pecahan cepat, kembalian otomatis.
/// - **Non-tunai:** pilih jenis (QRIS/Transfer/Kartu/Lainnya) — TANPA
///   integrasi, hanya dicatat.
/// - **Hutang:** nama pelanggan WAJIB diisi, status tersimpan
///   `debt_unpaid`.
///
/// Desain (docs/ui-redesign-foundation.md): total belanja tampil sebagai
/// panel hero di atas, metode bayar berupa tiga kartu besar (target sentuh
/// jauh di atas 48dp), pecahan cepat sebagai tombol tonal, dan kembalian
/// diberi panel bernada (`success` cukup / `danger` kurang) dengan angka
/// `AppMoneySize.lg` supaya terbaca dari jarak satu lengan.
///
/// Mengembalikan `SaleResult` lewat `Navigator.pop` bila pembayaran
/// berhasil disimpan, atau `null` bila dibatalkan.
class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key});

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  String _paymentMethod = 'cash';
  String _noncashType = _noncashTypes.first;

  final _paidController = TextEditingController();
  final _noncashOtherController = TextEditingController();
  final _noteController = TextEditingController();

  /// Pelanggan terpilih — `null` berarti transaksi tanpa pelanggan, dan
  /// itulah keadaan default: alur kasir tunai tidak bertambah satu tap pun
  /// dibanding v1.0 (AC-7.5).
  CustomerListItem? _customer;

  /// Poin yang ditukar pada transaksi ini (K-7.6).
  int _pointsRedeemed = 0;

  bool _saving = false;
  bool _customerTouched = false;
  String? _errorMessage;

  @override
  void dispose() {
    _paidController.dispose();
    _noncashOtherController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  PointsSettings get _points =>
      ref.read(pointsSettingsProvider).valueOrNull ?? const PointsSettings();

  Future<void> _pickCustomer() async {
    final picked = await showCustomerPicker(context, points: _points);
    if (picked == null || !mounted) return;
    setState(() {
      _customer = picked;
      _customerTouched = true;
      // Saldo pelanggan berbeda → pilihan penukaran sebelumnya tidak
      // otomatis berlaku lagi.
      _pointsRedeemed = 0;
      _errorMessage = null;
    });
  }

  void _clearCustomer() {
    setState(() {
      _customer = null;
      _pointsRedeemed = 0;
    });
  }

  int get _paidAmount => CurrencyFormatter.parse(_paidController.text);

  void _addQuickAmount(int amount) {
    setState(() => _paidController.text = (_paidAmount + amount).toString());
  }

  void _setExact(int total) {
    setState(() => _paidController.text = total.toString());
  }

  void _selectMethod(String method) {
    setState(() {
      _paymentMethod = method;
      _errorMessage = null;
    });
  }

  bool _isFormValid(int total) {
    switch (_paymentMethod) {
      case 'cash':
        return _paidAmount >= total;
      case 'debt':
        // Hutang WAJIB punya pelanggan — perilaku v1.0 dipertahankan,
        // hanya cara memilihnya yang berubah (AC-7.4).
        return _customer != null;
      case 'noncash':
      default:
        return true;
    }
  }

  Future<void> _confirm(int total) async {
    if (_paymentMethod == 'debt' && _customer == null) {
      setState(() => _customerTouched = true);
      return;
    }
    if (!_isFormValid(total)) return;

    final cart = ref.read(cartProvider);
    int paidAmount;
    String? customerName;
    String? note;
    // Nama pelanggan tetap ditulis ke `sales.customer_name` sebagai
    // SNAPSHOT historis untuk semua metode bayar (K-7.1) — mengganti nama
    // pelanggan nanti tidak boleh mengubah struk yang sudah tercetak.
    customerName = _customer?.name;
    switch (_paymentMethod) {
      case 'cash':
        paidAmount = _paidAmount;
      case 'debt':
        paidAmount = 0;
        note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
      case 'noncash':
      default:
        paidAmount = total;
        note = _noncashType == 'Lainnya'
            ? (_noncashOtherController.text.trim().isEmpty
                  ? 'Lainnya'
                  : 'Lainnya: ${_noncashOtherController.text.trim()}')
            : _noncashType;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final usecase = ref.read(saveSaleUsecaseProvider);
      final SaleResult result = await usecase(
        items: cart.items,
        transactionDiscount: cart.transactionDiscount,
        paymentMethod: _paymentMethod,
        paidAmount: paidAmount,
        customerName: customerName,
        customerId: _customer?.id,
        pointsRedeemed: _pointsRedeemed,
        points: _points,
        note: note,
      );
      ref.read(cartProvider.notifier).clear();
      // Saksi jam monoton (PRD v1.1 §6.3.G): setiap penjualan yang tersimpan
      // memajukan `license_last_seen_at`, sehingga memundurkan jam HP tidak
      // pernah menambah sisa masa berlaku. Sengaja dijalankan SETELAH
      // transaksi tersimpan & tanpa `await` — lisensi tidak boleh pernah
      // memutus alur pembayaran (K-6.10, AC-6.18).
      unawaited(ref.read(licenseStatusProvider.notifier).revalidate());
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = AppErrorMessage.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final points = ref.watch(pointsSettingsProvider).valueOrNull ?? const PointsSettings();
    // Penukaran poin adalah diskon transaksi biasa (K-7.6), jadi ia
    // mengurangi total yang harus dibayar persis seperti diskon lain.
    final redeemValue = points.rupiahFor(_pointsRedeemed).clamp(0, cart.total).toInt();
    final total = cart.total - redeemValue;
    final theme = Theme.of(context);
    final isValid = _isFormValid(total);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            0,
            AppSizes.screenPadding,
            AppSizes.spaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pembayaran', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSizes.spaceMd),
              AppCard(
                color: context.palette.primary50,
                borderColor: context.palette.primary100,
                padding: const EdgeInsets.all(AppSizes.spaceMl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL BELANJA', style: context.textStyles.eyebrow),
                    const SizedBox(height: AppSizes.spaceXs),
                    AppMoneyText(
                      CurrencyFormatter.format(total),
                      size: AppMoneySize.lg,
                      color: context.palette.primary,
                    ),
                    const SizedBox(height: AppSizes.spaceXs),
                    Text(
                      '${cart.lineCount} item di keranjang',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (redeemValue > 0) ...[
                      const SizedBox(height: AppSizes.spaceXs),
                      Text(
                        'Sudah dipotong $_pointsRedeemed poin '
                        '(−${CurrencyFormatter.format(redeemValue)})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.palette.accentText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.spaceLg),
              _buildCustomerSelector(),
              if (points.enabled && _customer != null) ...[
                const SizedBox(height: AppSizes.spaceMd),
                _buildPointsSection(points, cart.total),
              ],
              const SizedBox(height: AppSizes.spaceLg),
              Text('Metode pembayaran', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSizes.spaceSm),
              _buildMethodSelector(),
              const SizedBox(height: AppSizes.spaceLg),
              switch (_paymentMethod) {
                'cash' => _buildCashForm(total),
                'noncash' => _buildNoncashForm(),
                'debt' => _buildDebtForm(),
                _ => const SizedBox.shrink(),
              },
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSizes.spaceMd),
                AppBanner(
                  tone: AppTone.danger,
                  icon: Icons.error_outline_rounded,
                  title: 'Pembayaran gagal disimpan',
                  message: _errorMessage!,
                ),
              ],
              const SizedBox(height: AppSizes.spaceLg),
              _ConfirmButton(
                enabled: !_saving && isValid,
                saving: _saving,
                onPressed: () => _confirm(total),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pemilih pelanggan (PRD v1.1 §7.3.B).
  ///
  /// Bentuknya sengaja **satu baris**: tombol saat kosong, chip saat
  /// terisi. Tidak ada field teks bebas lagi — teks bebas itulah yang
  /// melahirkan "Bu Ani" / "bu ani" / "Bu Ani " sebagai tiga penghutang
  /// berbeda di v1.0.
  Widget _buildCustomerSelector() {
    final theme = Theme.of(context);
    final customer = _customer;
    final isRequired = _paymentMethod == 'debt';
    final showError = isRequired && customer == null && _customerTouched;

    if (customer == null) {
      return SizedBox(
        height: AppSizes.minTouchTarget,
        child: OutlinedButton.icon(
          onPressed: _pickCustomer,
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: Text(
            isRequired ? 'Pilih Pelanggan *' : 'Pilih Pelanggan (opsional)',
          ),
          style: showError
              ? OutlinedButton.styleFrom(
                  foregroundColor: context.palette.dangerText,
                  side: BorderSide(color: context.palette.dangerBorder),
                )
              : null,
        ),
      );
    }

    return AppCard(
      onTap: _pickCustomer,
      color: context.palette.primary50,
      borderColor: context.palette.primary100,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          const AppIconBadge(icon: Icons.person_outline_rounded, tone: AppTone.primary),
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
                if (customer.hasDebt) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Hutang berjalan ${CurrencyFormatter.format(customer.totalDebt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.palette.accentText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Lepas pelanggan',
            onPressed: _clearCustomer,
          ),
        ],
      ),
    );
  }

  /// Penukaran poin — muncul HANYA bila program poin menyala DAN pelanggan
  /// sudah dipilih (AC-7.6).
  ///
  /// Pilihan disajikan sebagai chip, bukan field angka: kasir memilih
  /// sambil berdiri, dan setiap keyboard yang muncul di alur pembayaran
  /// adalah satu kesempatan lagi untuk salah ketik.
  Widget _buildPointsSection(PointsSettings points, int cartTotal) {
    final theme = Theme.of(context);
    final customer = _customer!;
    final maxRedeem = points.maxRedeemable(
      balance: customer.points,
      total: cartTotal,
    );
    final canRedeem = maxRedeem >= points.minRedeem;

    final options = <int>{
      points.minRedeem,
      points.minRedeem * 2,
      points.minRedeem * 5,
      maxRedeem,
    }.where((value) => value >= points.minRedeem && value <= maxRedeem).toList()
      ..sort();

    return AppCard(
      color: context.palette.accent50,
      borderColor: context.palette.accent100,
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                icon: Icons.stars_rounded,
                tone: AppTone.accent,
                size: AppIconBadgeSize.sm,
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Expanded(child: Text('TUKAR POIN', style: context.textStyles.eyebrow)),
              AppPill(
                label: '${customer.points} poin',
                tone: AppTone.accent,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSm),
          if (!canRedeem)
            Text(
              'Poin belum cukup ditukar — minimum ${points.minRedeem} poin '
              '(1 poin = ${CurrencyFormatter.format(points.valuePerPoint)}).',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            Text(
              '1 poin = ${CurrencyFormatter.format(points.valuePerPoint)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Wrap(
              spacing: AppSizes.spaceSm,
              runSpacing: AppSizes.spaceSm,
              children: [
                ChoiceChip(
                  label: const Text('Tidak menukar'),
                  selected: _pointsRedeemed == 0,
                  onSelected: (_) => setState(() => _pointsRedeemed = 0),
                ),
                for (final option in options)
                  ChoiceChip(
                    label: Text(
                      '$option poin · −${CurrencyFormatter.format(points.rupiahFor(option))}',
                    ),
                    selected: _pointsRedeemed == option,
                    onSelected: (_) => setState(() => _pointsRedeemed = option),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Row(
      children: [
        Expanded(
          child: _MethodCard(
            label: 'Tunai',
            icon: Icons.payments_outlined,
            value: 'cash',
            selected: _paymentMethod,
            onSelect: _selectMethod,
          ),
        ),
        const SizedBox(width: AppSizes.spaceSm),
        Expanded(
          child: _MethodCard(
            label: 'Non-tunai',
            icon: Icons.qr_code_2_rounded,
            value: 'noncash',
            selected: _paymentMethod,
            onSelect: _selectMethod,
          ),
        ),
        const SizedBox(width: AppSizes.spaceSm),
        Expanded(
          child: _MethodCard(
            label: 'Hutang',
            icon: Icons.receipt_long_outlined,
            value: 'debt',
            selected: _paymentMethod,
            onSelect: _selectMethod,
          ),
        ),
      ],
    );
  }

  Widget _buildCashForm(int total) {
    final paid = _paidAmount;
    final change = paid - total;
    final isEnough = paid >= total;
    final tone = isEnough ? AppTone.success : AppTone.danger;
    final toneColors = tone.colorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _paidController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: context.textStyles.moneyLarge,
          decoration: const InputDecoration(
            labelText: 'Uang diterima',
            prefixText: 'Rp ',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSizes.spaceMs),
        // Dua kolom (bukan empat) supaya tiap pecahan punya lebar penuh
        // untuk jempol — kasir menekannya sambil melihat uang di tangan.
        for (var row = 0; row < _quickAmounts.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSizes.spaceSm),
          Row(
            children: [
              for (var i = row; i < row + 2 && i < _quickAmounts.length; i++) ...[
                if (i > row) const SizedBox(width: AppSizes.spaceSm),
                Expanded(
                  child: _QuickButton(
                    label: CurrencyFormatter.format(_quickAmounts[i]),
                    onTap: () => _addQuickAmount(_quickAmounts[i]),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: AppSizes.spaceSm),
        _QuickButton(
          label: 'Uang Pas',
          tone: AppTone.accent,
          icon: Icons.done_all_rounded,
          onTap: () => _setExact(total),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        AppCard(
          color: toneColors.bg,
          borderColor: toneColors.border,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spaceMd,
            vertical: AppSizes.spaceMs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isEnough ? 'Kembalian' : 'Kurang bayar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: toneColors.fg,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              AppMoneyText(
                CurrencyFormatter.format(isEnough ? change : -change),
                size: AppMoneySize.lg,
                color: toneColors.fg,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoncashForm() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Jenis pembayaran', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSizes.spaceSm),
        Wrap(
          spacing: AppSizes.spaceSm,
          runSpacing: AppSizes.spaceSm,
          children: [
            for (final type in _noncashTypes)
              ChoiceChip(
                label: Text(type),
                selected: _noncashType == type,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spaceMs,
                  vertical: AppSizes.spaceSm,
                ),
                onSelected: (_) => setState(() => _noncashType = type),
              ),
          ],
        ),
        if (_noncashType == 'Lainnya') ...[
          const SizedBox(height: AppSizes.spaceMd),
          TextField(
            controller: _noncashOtherController,
            decoration: const InputDecoration(labelText: 'Sebutkan jenisnya'),
          ),
        ],
        const SizedBox(height: AppSizes.spaceMd),
        const AppBanner(
          tone: AppTone.info,
          icon: Icons.info_outline_rounded,
          message: 'Pembayaran non-tunai HANYA dicatat jenisnya — tidak ada '
              'integrasi/pengecekan otomatis ke penyedia QRIS/bank.',
        ),
      ],
    );
  }

  Widget _buildDebtForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_customer == null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
            child: AppBanner(
              tone: _customerTouched ? AppTone.danger : AppTone.warning,
              icon: Icons.person_search_outlined,
              title: 'Pelanggan wajib dipilih',
              message: 'Hutang harus punya nama supaya bisa ditagih. Pakai '
                  'tombol "Pilih Pelanggan" di atas.',
              actionLabel: 'Pilih Pelanggan',
              onAction: _pickCustomer,
            ),
          ),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Catatan (opsional)',
            prefixIcon: Icon(Icons.sticky_note_2_outlined),
          ),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        const AppBanner(
          tone: AppTone.accent,
          icon: Icons.schedule_rounded,
          message: 'Transaksi ini tersimpan sebagai HUTANG (belum lunas) — '
              'bisa ditandai lunas nanti dari layar Riwayat.',
        ),
      ],
    );
  }
}

/// Kartu pilihan metode bayar — target sentuh besar (>= 72dp) dengan ikon
/// yang berganti outlined→filled saat terpilih, konsisten dengan dock nav.
class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final IconData icon;
  final String value;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final fg = isSelected ? context.palette.primary : context.palette.inkSecondary;

    return AppCard(
      selected: isSelected,
      onTap: () => onSelect(value),
      radius: AppSizes.radiusMd,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceSm,
        vertical: AppSizes.spaceMs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconLg, color: fg),
          const SizedBox(height: AppSizes.spaceSm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Tombol pecahan cepat / uang pas. Bernada brand (atau aksen untuk "Uang
/// Pas", satu-satunya pintasan yang menyelesaikan input sekali tap).
class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.label,
    required this.onTap,
    this.tone = AppTone.primary,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final AppTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = tone.colorsOf(context);
    return AppCard(
      onTap: onTap,
      radius: AppSizes.radiusMd,
      color: c.bg,
      borderColor: c.border,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceSm,
        vertical: AppSizes.spaceMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconSm, color: c.fg),
            const SizedBox(width: AppSizes.spaceSm),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.enabled,
    required this.saving,
    required this.onPressed,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: AppSizes.buttonHeightLarge,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        child: saving
            ? SizedBox(
                width: AppSizes.iconMd,
                height: AppSizes.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.palette.onPrimary,
                ),
              )
            : const Text('Selesaikan Pembayaran'),
      ),
    );
    if (!enabled) return button;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: AppShadows.of(context).primaryGlow,
      ),
      child: button,
    );
  }
}
