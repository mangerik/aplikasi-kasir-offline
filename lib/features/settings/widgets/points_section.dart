import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/points_settings.dart';
import '../../customers/providers/customer_providers.dart';
import '../providers/settings_providers.dart';
import 'settings_card.dart';

/// Kartu **Program Poin** (PRD v1.1 §7.3.C).
///
/// **Default mati.** Saat mati, seluruh pengaturan turunannya disembunyikan
/// — bukan sekadar dinonaktifkan — karena warung yang tidak menjalankan
/// program poin tidak perlu tahu ada empat angka yang bisa diatur (AC-7.6).
///
/// Aksi pemeliharaan "hitung ulang saldo dari buku besar" ada di kartu ini
/// juga: saldo `customers.points` hanyalah cache, dan pemilik perlu satu
/// tombol yang bisa dipakai bila ada sengketa poin dengan pembeli (K-7.2).
class PointsSection extends ConsumerStatefulWidget {
  const PointsSection({super.key});

  @override
  ConsumerState<PointsSection> createState() => _PointsSectionState();
}

class _PointsSectionState extends ConsumerState<PointsSection> {
  bool _busy = false;
  String? _message;
  String? _error;

  Future<void> _setValue(String key, String value) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(settingsRepoProvider).setValue(key, value);
      ref.invalidate(pointsSettingsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = AppErrorMessage.from(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recalculate() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final fixed =
          await ref.read(customerRepoProvider).recalculatePointsFromLedger();
      ref
        ..invalidate(customerListProvider)
        ..invalidate(customerDebtOverviewProvider);
      if (mounted) {
        setState(() {
          _message = fixed == 0
              ? 'Semua saldo poin sudah cocok dengan buku besar.'
              : '$fixed pelanggan saldonya dikoreksi agar cocok dengan buku '
                  'besar. Koreksinya tercatat di riwayat poin masing-masing.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppErrorMessage.from(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(pointsSettingsProvider);

    return SettingsCard(
      icon: Icons.stars_rounded,
      title: 'Program Poin',
      subtitle: 'Hadiah sederhana untuk pembeli langganan.',
      tone: AppTone.accent,
      children: [
        settingsAsync.when(
          data: _buildBody,
          loading: () => const AppLoadingView(compact: true),
          error: (e, _) => AppErrorView(
            title: 'Pengaturan poin gagal dimuat',
            message: AppErrorMessage.from(e),
            compact: true,
            onRetry: () => ref.invalidate(pointsSettingsProvider),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: AppSizes.spaceMs),
          AppBanner(
            tone: AppTone.success,
            icon: Icons.check_circle_outline_rounded,
            message: _message!,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSizes.spaceMs),
          AppBanner(
            tone: AppTone.danger,
            icon: Icons.error_outline_rounded,
            message: _error!,
          ),
        ],
      ],
    );
  }

  Widget _buildBody(PointsSettings settings) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: settings.enabled,
          onChanged: _busy
              ? null
              : (value) =>
                  _setValue(PointsSettings.keyEnabled, value ? '1' : '0'),
          title: const Text('Program poin aktif'),
          subtitle: Text(
            settings.enabled
                ? 'Poin diberikan otomatis setiap transaksi tersimpan.'
                : 'Mati — tidak ada elemen poin yang muncul di layar mana pun.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (settings.enabled) ...[
          const SizedBox(height: AppSizes.spaceSm),
          _NumberField(
            label: 'Rupiah per 1 poin',
            helper: 'Belanja ${CurrencyFormatter.format(settings.rupiahPerPoint)} '
                'dapat 1 poin (pembulatan ke bawah).',
            value: settings.rupiahPerPoint,
            enabled: !_busy,
            onSubmit: (value) =>
                _setValue(PointsSettings.keyRupiahPerPoint, '$value'),
          ),
          const SizedBox(height: AppSizes.spaceMs),
          _NumberField(
            label: 'Nilai tukar 1 poin (Rp)',
            helper: '${settings.minRedeem} poin = '
                '${CurrencyFormatter.format(settings.rupiahFor(settings.minRedeem))} '
                'potongan.',
            value: settings.valuePerPoint,
            enabled: !_busy,
            onSubmit: (value) =>
                _setValue(PointsSettings.keyValuePerPoint, '$value'),
          ),
          const SizedBox(height: AppSizes.spaceMs),
          _NumberField(
            label: 'Minimum poin untuk ditukar',
            helper: 'Di bawah ini, tombol tukar poin tidak muncul di kasir.',
            value: settings.minRedeem,
            enabled: !_busy,
            onSubmit: (value) => _setValue(PointsSettings.keyMinRedeem, '$value'),
          ),
          const SizedBox(height: AppSizes.spaceMd),
          const AppBanner(
            tone: AppTone.info,
            icon: Icons.info_outline_rounded,
            message: 'Poin TIDAK diberikan surut untuk transaksi sebelum '
                'program dinyalakan, dan tidak pernah dihitung dari potongan '
                'hasil penukaran poin.',
          ),
          const SizedBox(height: AppSizes.spaceMd),
          SizedBox(
            // `buttonHeight` (52), bukan `minTouchTarget` (48): tema sudah
            // menetapkan 52 untuk OutlinedButton, dan SizedBox 48 justru
            // MENGECILKAN tombol di bawah tinggi baku tombol lain.
            height: AppSizes.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _recalculate,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Hitung Ulang Saldo dari Buku Besar'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Field angka yang menyimpan saat selesai diketik — bukan tiap ketukan,
/// supaya angka setengah jadi tidak pernah ikut tersimpan.
class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.helper,
    required this.value,
    required this.enabled,
    required this.onSubmit,
  });

  final String label;
  final String helper;
  final int value;
  final bool enabled;
  final ValueChanged<int> onSubmit;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed <= 0) {
      _controller.text = '${widget.value}';
      return;
    }
    if (parsed != widget.value) widget.onSubmit(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 2,
      ),
      onTapOutside: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
        _submit();
      },
      onSubmitted: (_) => _submit(),
    );
  }
}
