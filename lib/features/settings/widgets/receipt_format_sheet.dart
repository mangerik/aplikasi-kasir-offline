import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/printer_settings.dart';
import '../../../domain/entities/sale_result.dart';
import '../../pos/widgets/receipt_widget.dart';
import '../providers/printer_providers.dart';

/// Sheet "Atur Tampilan Struk" (PRD v1.1 §3.3.E).
///
/// Setiap setelan di sini punya pratinjau di bawahnya, karena tidak seorang
/// pun bisa membayangkan efek "baris kosong: 4" tanpa melihatnya. Pratinjau
/// memakai `ReceiptWidget` yang sudah ada — widget itu **memaksa dirinya
/// bertema terang** (K-5.3), jadi struk tetap tampil di atas kertas putih
/// walau aplikasi sedang mode gelap. Itu bukan kelalaian tema melainkan
/// kenyataan fisik: kertas thermal tidak punya mode gelap.
class ReceiptFormatSheet extends ConsumerStatefulWidget {
  const ReceiptFormatSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ReceiptFormatSheet(),
    );
  }

  @override
  ConsumerState<ReceiptFormatSheet> createState() => _ReceiptFormatSheetState();
}

class _ReceiptFormatSheetState extends ConsumerState<ReceiptFormatSheet> {
  PrinterSettings? _draft;
  late final TextEditingController _footerController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _footerController.dispose();
    super.dispose();
  }

  void _ensureDraft(PrinterSettings loaded) {
    if (_draft != null) return;
    _draft = loaded;
    _footerController.text = loaded.footerText;
  }

  void _update(PrinterSettings Function(PrinterSettings) change) {
    setState(() => _draft = change(_draft!));
  }

  Future<void> _pickLogo() async {
    // file_picker 12.x: API static langsung di kelas `FilePicker`
    // (tidak lagi lewat `FilePicker.platform`) — sama seperti
    // `backup_restore_section.dart`.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp'],
      dialogTitle: 'Pilih gambar logo toko',
    );
    final path = result?.files.single.path;
    if (path == null) return;
    _update((d) => d.copyWith(logoPath: path, printLogo: true));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final value = _draft!.copyWith(footerText: _footerController.text.trim());
    await ref.read(printerSettingsStoreProvider).save(value);
    ref.invalidate(printerSettingsProvider);
    if (!mounted) return;
    // Messenger & navigator diambil SEBELUM pop: sesudah sheet ditutup,
    // `context` milik sheet sudah dilepas dari pohon dan pencarian
    // ancestor-nya tidak lagi dijamin berhasil.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Tampilan struk disimpan.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(printerSettingsProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            0,
            AppSizes.screenPadding,
            AppSizes.spaceMd,
          ),
          child: settingsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.space2xl),
              child: AppLoadingView(compact: true),
            ),
            // Sheet ini tidak punya jalan keluar lain selain ditutup, jadi
            // cabang error WAJIB menawarkan "Coba Lagi" — sama seperti
            // `printer_section.dart`. Teks telanjang membuat sheet-nya buntu.
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceMd),
              child: AppErrorView(
                title: 'Pengaturan struk gagal dimuat',
                message: AppErrorMessage.from(e),
                compact: true,
                onRetry: () => ref.invalidate(printerSettingsProvider),
              ),
            ),
            data: (loaded) {
              _ensureDraft(loaded);
              final draft = _draft!;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'Atur Tampilan Struk',
                      subtitle: 'Ubah setelan, lihat hasilnya di pratinjau bawah',
                      padding: EdgeInsets.only(bottom: AppSizes.spaceMd),
                    ),

                    Text('LEBAR KERTAS', style: context.textStyles.eyebrow),
                    const SizedBox(height: AppSizes.spaceSm),
                    SegmentedButton<PrinterPaperWidth>(
                      segments: const [
                        ButtonSegment(
                          value: PrinterPaperWidth.mm58,
                          label: Text('58mm'),
                          icon: Icon(Icons.receipt_outlined, size: AppSizes.iconSm),
                        ),
                        ButtonSegment(
                          value: PrinterPaperWidth.mm80,
                          label: Text('80mm'),
                          icon: Icon(Icons.receipt_long_outlined, size: AppSizes.iconSm),
                        ),
                      ],
                      selected: {draft.paperWidth},
                      onSelectionChanged: (s) => _update((d) => d.copyWith(paperWidth: s.first)),
                    ),
                    const SizedBox(height: AppSizes.spaceXs),
                    Text(
                      '58mm adalah ukuran paling umum di Indonesia dan satu-satunya '
                      'yang diuji resmi.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.palette.inkSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSizes.spaceLg),
                    Text('JUMLAH SALINAN', style: context.textStyles.eyebrow),
                    const SizedBox(height: AppSizes.spaceSm),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('1')),
                        ButtonSegment(value: 2, label: Text('2')),
                        ButtonSegment(value: 3, label: Text('3')),
                      ],
                      selected: {draft.copies},
                      onSelectionChanged: (s) => _update((d) => d.copyWith(copies: s.first)),
                    ),

                    const SizedBox(height: AppSizes.spaceLg),
                    Text('BARIS KOSONG SETELAH STRUK', style: context.textStyles.eyebrow),
                    const SizedBox(height: AppSizes.spaceXs),
                    Text(
                      'Perbesar kalau struk susah disobek, perkecil kalau kertas terbuang.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.palette.inkSecondary,
                      ),
                    ),
                    Slider(
                      value: draft.feedLines.toDouble(),
                      min: 0,
                      max: PrinterSettings.maxFeedLines.toDouble(),
                      divisions: PrinterSettings.maxFeedLines,
                      label: '${draft.feedLines} baris',
                      onChanged: (v) => _update((d) => d.copyWith(feedLines: v.round())),
                    ),

                    const SizedBox(height: AppSizes.spaceSm),
                    Text('KALIMAT PENUTUP', style: context.textStyles.eyebrow),
                    const SizedBox(height: AppSizes.spaceSm),
                    TextField(
                      controller: _footerController,
                      maxLines: 2,
                      maxLength: draft.paperWidth.columns * 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Terima kasih sudah belanja :)',
                        prefixIcon: Icon(Icons.favorite_outline),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: AppSizes.spaceSm),
                    _LogoRow(
                      settings: draft,
                      onPick: _pickLogo,
                      onToggle: (value) => _update(
                        (d) => value
                            ? d.copyWith(printLogo: true)
                            : d.copyWith(printLogo: false),
                      ),
                      onRemove: () => _update((d) => d.copyWith(clearLogoPath: true)),
                    ),

                    const SizedBox(height: AppSizes.spaceLg),
                    Text('PRATINJAU', style: context.textStyles.eyebrow),
                    const SizedBox(height: AppSizes.spaceSm),
                    AppCard(
                      color: context.palette.surfaceAlt,
                      padding: const EdgeInsets.all(AppSizes.spaceMs),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ReceiptWidget(sale: _sampleSale()),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSizes.spaceLg),
                    SizedBox(
                      height: AppSizes.buttonHeightLarge,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(_saving ? 'Menyimpan…' : 'Simpan'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Transaksi contoh untuk pratinjau — sengaja memuat item ber-diskon dan
  /// nama panjang, dua kasus yang paling sering bikin struk berantakan.
  SaleResult _sampleSale() {
    return SaleResult(
      saleId: 0,
      invoiceNumber: '20260812-0007',
      subtotal: 15000,
      discount: 1000,
      total: 14000,
      paymentMethod: 'cash',
      paidAmount: 20000,
      changeAmount: 6000,
      createdAt: DateTime.now(),
      items: const [
        SaleResultItem(
          name: 'Indomie Goreng',
          unit: 'pcs',
          qty: 2,
          sellPrice: 3500,
          discount: 0,
          lineTotal: 7000,
        ),
        SaleResultItem(
          name: 'Gula Pasir Curah',
          unit: 'kg',
          qty: 0.5,
          sellPrice: 16000,
          discount: 0,
          lineTotal: 8000,
        ),
      ],
    );
  }
}

class _LogoRow extends StatelessWidget {
  const _LogoRow({
    required this.settings,
    required this.onPick,
    required this.onToggle,
    required this.onRemove,
  });

  final PrinterSettings settings;
  final VoidCallback onPick;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = settings.logoPath?.trim().isNotEmpty ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          value: settings.printLogo && hasFile,
          onChanged: hasFile ? onToggle : null,
          contentPadding: EdgeInsets.zero,
          title: Text('Cetak logo toko', style: theme.textTheme.titleSmall),
          subtitle: Text(
            hasFile
                ? settings.logoPath!.split('/').last
                : 'Pilih gambar hitam-putih dulu. Foto berwarna tidak cocok '
                      'untuk kertas thermal.',
            style: theme.textTheme.bodySmall?.copyWith(color: context.palette.inkSecondary),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.image_outlined, size: AppSizes.iconSm),
                label: Text(hasFile ? 'Ganti Gambar' : 'Pilih Gambar'),
              ),
            ),
            if (hasFile) ...[
              const SizedBox(width: AppSizes.spaceSm),
              TextButton(onPressed: onRemove, child: const Text('Hapus')),
            ],
          ],
        ),
      ],
    );
  }
}
