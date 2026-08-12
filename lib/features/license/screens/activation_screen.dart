import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/license/license_verifier.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../products/widgets/barcode_scanner_page.dart';
import '../providers/license_providers.dart';
import '../widgets/device_code_card.dart';
import '../widgets/license_code_field.dart';

/// Gerbang aktivasi (rute `/aktivasi`, di luar shell) — PRD v1.1 §6.3.A.
///
/// Satu titik fokus, dibaca dari atas ke bawah persis seperti urutan
/// pekerjaan pembeli: **ini kode saya → saya kirim ke penjual → saya
/// masukkan balasannya → saya tekan AKTIFKAN.** Tidak ada satu pun elemen
/// yang tidak melayani urutan itu.
///
/// Yang sengaja TIDAK ada di layar ini: istilah teknis (Ed25519, tanda
/// tangan, token), hitungan mundur dramatis, dan segala nada menghukum.
/// Pembeli di sini adalah orang yang baru saja memutuskan membayar; layar
/// pertama yang dilihatnya harus terasa seperti sambutan.
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key, this.asRenewal = false});

  /// `true` bila layar dibuka dari kartu Lisensi / banner masa tenggang
  /// (perpanjangan), bukan sebagai gerbang. Bedanya cuma satu: ke mana
  /// layar ini pergi setelah kode diterima.
  final bool asRenewal;

  /// Buka sebagai halaman biasa di atas layar yang sedang aktif — dipakai
  /// alur perpanjangan (§6.3.H). Mengembalikan `true` bila aktivasi
  /// berhasil.
  static Future<bool?> show(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ActivationScreen(asRenewal: true),
      ),
    );
  }

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _checking = false;
  LicenseRejection? _rejection;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setCode(String code) {
    // Lewat formatter supaya normalisasi & pengelompokan berlaku sama untuk
    // hasil pindai, hasil tempel, dan ketikan tangan (AC-6.9).
    _controller.value = LicenseCodeInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: code),
    );
    setState(() => _rejection = null);
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerPage(
          title: 'Arahkan ke QR kode aktivasi',
          subtitle: 'Kode akan terisi otomatis begitu terbaca.',
        ),
      ),
    );
    if (code == null || !mounted) return;
    _setCode(code);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada teks yang disalin.')),
      );
      return;
    }
    _setCode(text);
  }

  void _type() {
    _focusNode.requestFocus();
  }

  Future<void> _activate() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _rejection = null;
    });

    final result = await ref
        .read(licenseStatusProvider.notifier)
        .activate(_controller.text);
    if (!mounted) return;

    if (result is LicenseAccepted) {
      HapticFeedback.mediumImpact();
      final label = result.payload.type.label;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Aktif — Lisensi $label.')));
      if (widget.asRenewal && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        context.go(AppRoutes.pos);
      }
      return;
    }

    // Kode salah: getaran + pesan SPESIFIK. Menuduh pengguna memakai kode
    // bajakan padahal ia cuma salah ketik satu karakter adalah cara
    // tercepat kehilangan pembeli yang sudah membayar (§6.3.D).
    HapticFeedback.heavyImpact();
    setState(() {
      _checking = false;
      _rejection = (result as LicenseRejected).reason;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: widget.asRenewal
          ? AppBar(title: const Text('Masukkan Kode'))
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.spaceLg,
                AppSizes.screenPadding,
                AppSizes.spaceXl,
              ),
              children: [
                if (!widget.asRenewal) ...[
                  const Center(
                    child: AppIconBadge(
                      icon: Icons.lock_outline_rounded,
                      tone: AppTone.primary,
                      size: AppIconBadgeSize.xl,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceMl),
                  Text(
                    'Aktifkan Kasir Warung',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSizes.spaceXs),
                  Text(
                    'Sekali saja, dan tetap tanpa internet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceXl),
                ],

                const DeviceCodeCard(),

                const SizedBox(height: AppSizes.spaceLg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: AppSizes.iconSm,
                      color: palette.inkSecondary,
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      child: Text(
                        'Kirim kode perangkat di atas ke penjual, lalu '
                        'masukkan kode aktivasi yang dikirim balik.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: _EntryPathButton(
                        icon: Icons.qr_code_scanner,
                        label: 'Pindai QR',
                        onTap: _checking ? null : _scan,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      child: _EntryPathButton(
                        icon: Icons.content_paste,
                        label: 'Tempel',
                        onTap: _checking ? null : _paste,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      child: _EntryPathButton(
                        icon: Icons.keyboard_outlined,
                        label: 'Ketik',
                        onTap: _checking ? null : _type,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.spaceMd),
                LicenseCodeField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_checking,
                  hasError: _rejection != null,
                  onSubmitted: _activate,
                ),

                const SizedBox(height: AppSizes.spaceMd),
                _StatusLine(checking: _checking, rejection: _rejection),

                const SizedBox(height: AppSizes.spaceMd),
                SizedBox(
                  height: AppSizes.buttonHeightLarge,
                  child: FilledButton(
                    onPressed: _checking ? null : _activate,
                    child: const Text('AKTIFKAN'),
                  ),
                ),

                const SizedBox(height: AppSizes.spaceLg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: AppSizes.iconSm,
                      color: palette.inkSecondary,
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      child: Text(
                        'Aktivasi berjalan di dalam HP ini. Kode ditukar '
                        'lewat WhatsApp dari HP mana pun — aplikasi tidak '
                        'pernah menghubungi internet.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu jalur masuk kode. Ketiganya sengaja SEBERAT yang sama secara visual
/// supaya pengguna memilih yang paling cocok dengan situasinya, bukan yang
/// paling menonjol.
class _EntryPathButton extends StatelessWidget {
  const _EntryPathButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: AppSizes.buttonHeight + AppSizes.spaceMd,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceXs),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppSizes.iconMd, color: palette.primary),
            const SizedBox(height: AppSizes.spaceXs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris status verifikasi.
///
/// Mengikuti pola `pin_entry_screen.dart`: tombol TIDAK diganti spinner
/// (bikin layar melompat saat tinggi tombolnya berubah), melainkan
/// dinonaktifkan sambil baris ini berubah.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.checking, required this.rejection});

  final bool checking;
  final LicenseRejection? rejection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    if (checking) {
      return Row(
        children: [
          const SizedBox(
            width: AppSizes.iconSm,
            height: AppSizes.iconSm,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSizes.spaceSm),
          Text('Memeriksa kode…', style: theme.textTheme.bodyMedium),
        ],
      );
    }

    if (rejection == null) {
      return Text(
        'Kode aktivasi panjangnya 24 kelompok. Paling gampang: pindai QR '
        'atau tempel dari WhatsApp.',
        style: theme.textTheme.bodySmall?.copyWith(color: palette.inkSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPill(
          label: switch (rejection!) {
            LicenseRejection.salahKetik => 'Kode salah ketik',
            LicenseRejection.perangkatLain => 'Perangkat lain',
            LicenseRejection.tidakSah => 'Kode tidak sah',
            LicenseRejection.versiTerlaluBaru => 'Perlu versi baru',
          },
          tone: AppTone.danger,
          icon: Icons.error_outline_rounded,
        ),
        const SizedBox(height: AppSizes.spaceSm),
        Text(
          rejection!.message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.dangerText,
          ),
        ),
      ],
    );
  }
}
