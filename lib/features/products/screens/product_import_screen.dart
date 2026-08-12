import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/db/database_provider.dart';
import '../../../data/services/backup_service.dart';
import '../../../data/services/excel_export_service.dart';
import '../../../data/services/product_import_service.dart';
import '../../../domain/entities/product_import.dart';
import '../../../domain/repositories/import_exceptions.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/product_providers.dart';
import '../widgets/import_preview_row_tile.dart';
import '../widgets/import_summary_card.dart';

/// Wizard impor produk dari Excel — layar PENUH, bukan bottom sheet, karena
/// isinya panjang dan pengguna perlu menggulir sambil membaca (PRD v1.1
/// §4.7).
///
/// Lima langkah PRD §4.4 dipetakan menjadi tiga layar + satu dialog:
/// 1. **Pilih file** (unduh template / pilih `.xlsx`)
/// 2. **Membaca** — parsing di isolate, indikator indeterminate
/// 3. **Pratinjau** — inti fitur: ringkasan angka, tab status, opsi impor
/// 4. **Konfirmasi** — dialog ganda pola restore backup + pintasan
///    "Backup Dulu"
/// 5. **Hasil** — ringkasan + unduh laporan baris bermasalah
///
/// Tidak ada satu baris pun ditulis ke database sebelum langkah 4 selesai;
/// penulisannya sendiri satu transaksi utuh di repository (K-4.5).
class ProductImportScreen extends ConsumerStatefulWidget {
  const ProductImportScreen({super.key});

  @override
  ConsumerState<ProductImportScreen> createState() => _ProductImportScreenState();
}

enum _WizardStep { pilihFile, membaca, pratinjau, hasil }

/// Filter tab pratinjau. `null` = "Semua".
typedef _PreviewFilter = ProductImportAction?;

class _ProductImportScreenState extends ConsumerState<ProductImportScreen> {
  _WizardStep _step = _WizardStep.pilihFile;

  ProductImportParseResult? _parse;
  ProductImportLookup? _lookup;
  ProductImportPlan? _plan;
  ProductImportOptions _options = const ProductImportOptions();
  ProductImportSummary? _summary;

  String? _fileError;
  _PreviewFilter _filter;
  bool _busy = false;
  String _busyLabel = '';

  // -------------------------------------------------------------------
  // Langkah 1 & 2 — pilih file, lalu baca di isolate
  // -------------------------------------------------------------------

  Future<void> _downloadTemplate() async {
    setState(() {
      _busy = true;
      _busyLabel = 'Menyiapkan template…';
    });
    try {
      final path = await ProductImportService.saveTemplate();
      await ExcelExportService.share(path, subject: 'Template Impor Produk');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template produk berhasil dibuat.')),
      );
    } catch (e) {
      _showError('Gagal membuat template: ${AppErrorMessage.from(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFile() async {
    // file_picker 12.x: API static langsung di kelas `FilePicker`
    // (`FilePicker.platform` sudah dihapus) — sama seperti restore backup.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      dialogTitle: 'Pilih file produk (.xlsx)',
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    await _readFile(path);
  }

  Future<void> _readFile(String path) async {
    setState(() {
      _step = _WizardStep.membaca;
      _fileError = null;
    });
    try {
      // Parsing di ISOLATE (K-4.2); pembacaan database tetap di isolate
      // utama karena koneksi Drift tidak bisa menyeberang isolate.
      final parse = await ProductImportService.parseFile(path);
      final lookup = await ref.read(productRepoProvider).loadImportLookup();
      if (!mounted) return;
      setState(() {
        _parse = parse;
        _plan = ProductImportService.buildPlan(
          parse: parse,
          options: _options,
          lookup: lookup,
        );
        _lookup = lookup;
        _filter = null;
        _step = _WizardStep.pratinjau;
      });
    } on ImporProdukException catch (e) {
      if (!mounted) return;
      setState(() {
        _fileError = e.toString();
        _step = _WizardStep.pilihFile;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fileError =
            'File tidak bisa dibaca. Pastikan filenya benar-benar .xlsx dan '
            'tidak sedang dibuka aplikasi lain.';
        _step = _WizardStep.pilihFile;
      });
    }
  }

  // -------------------------------------------------------------------
  // Langkah 3 — opsi pratinjau
  // -------------------------------------------------------------------

  void _updateOptions(ProductImportOptions options) {
    final parse = _parse;
    final lookup = _lookup;
    if (parse == null || lookup == null) return;
    setState(() {
      _options = options;
      // Perencanaan ulang murni operasi memori — database tidak disentuh
      // sampai pengguna menekan "Impor Sekarang".
      _plan = ProductImportService.buildPlan(
        parse: parse,
        options: options,
        lookup: lookup,
      );
    });
  }

  // -------------------------------------------------------------------
  // Langkah 4 — konfirmasi ganda + pintasan backup
  // -------------------------------------------------------------------

  Future<void> _confirmAndImport() async {
    final plan = _plan;
    if (plan == null || plan.importableCount == 0) return;

    final firstAnswer = await showDialog<_ConfirmAnswer>(
      context: context,
      builder: (dialogContext) => _ImportConfirmDialog(plan: plan),
    );
    if (firstAnswer == null || !mounted) return;

    if (firstAnswer == _ConfirmAnswer.backupDulu) {
      await _backupNow();
      return;
    }

    final confirmedTwice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const AppIconBadge(
          icon: Icons.warning_amber_rounded,
          tone: AppTone.danger,
          size: AppIconBadgeSize.lg,
        ),
        title: const Text('Konfirmasi sekali lagi'),
        content: Text(
          _options.overwriteStock
              ? 'Impor ini juga akan MENIMPA stok produk yang sudah ada '
                    'dengan angka dari file. Lanjutkan?'
              : 'Yakin menjalankan impor sekarang? Perubahannya tidak bisa '
                    'dibatalkan.',
        ),
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
            child: const Text('Ya, Impor Sekarang'),
          ),
        ],
      ),
    );
    if (confirmedTwice != true || !mounted) return;

    await _runImport(plan);
  }

  Future<void> _backupNow() async {
    setState(() {
      _busy = true;
      _busyLabel = 'Menyiapkan file backup…';
    });
    try {
      final database = ref.read(databaseProvider);
      final path = await BackupService.createBackup(database);
      await ref
          .read(settingsRepoProvider)
          .setValue(
            'last_backup_at',
            DateFormatter.toEpochMillis(DateTime.now()).toString(),
          );
      ref.invalidate(lastBackupAtProvider);
      await BackupService.share(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup selesai. Impor bisa dijalankan sekarang.'),
        ),
      );
    } catch (e) {
      _showError('Gagal backup: ${AppErrorMessage.from(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runImport(ProductImportPlan plan) async {
    setState(() {
      _busy = true;
      _busyLabel = 'Menyimpan ${plan.importableCount} produk…';
    });
    try {
      final summary = await ref
          .read(productRepoProvider)
          .importProducts(
            rows: plan.importableRows,
            columns: plan.parse.columns,
            options: _options,
            fileName: plan.fileName,
          );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _step = _WizardStep.hasil;
      });
    } on ImporProdukException catch (e) {
      _showError(e.toString());
    } catch (e) {
      _showError('Impor dibatalkan dan tidak ada produk yang tersimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------------------------------------------------------------------
  // Langkah 5 — laporan
  // -------------------------------------------------------------------

  Future<void> _downloadIssueReport() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _busy = true;
      _busyLabel = 'Menyiapkan laporan…';
    });
    try {
      final path = await ProductImportService.saveIssueReport(plan);
      await ExcelExportService.share(path, subject: 'Laporan Baris Bermasalah');
    } catch (e) {
      _showError('Gagal membuat laporan: ${AppErrorMessage.from(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmLeave() async {
    if (_step != _WizardStep.pratinjau) return true;
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const AppIconBadge(
          icon: Icons.help_outline_rounded,
          tone: AppTone.warning,
          size: AppIconBadgeSize.lg,
        ),
        title: const Text('Batalkan impor?'),
        content: const Text(
          'Belum ada data yang masuk. Kalau keluar sekarang, filenya perlu '
          'dipilih ulang dari awal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Lanjut Impor'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  // -------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step != _WizardStep.pratinjau,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Impor Produk dari Excel')),
        body: Column(
          children: [
            _StepIndicator(step: _step),
            Expanded(child: _buildBody()),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_step) {
      _WizardStep.pilihFile => _PickFileView(
        error: _fileError,
        busy: _busy,
        busyLabel: _busyLabel,
        onDownloadTemplate: _downloadTemplate,
      ),
      _WizardStep.membaca => const AppLoadingView(
        message: 'Membaca file… ini bisa beberapa detik untuk file besar.',
      ),
      _WizardStep.pratinjau => _PreviewView(
        plan: _plan!,
        options: _options,
        filter: _filter,
        onFilterChanged: (value) => setState(() => _filter = value),
        onOptionsChanged: _updateOptions,
      ),
      _WizardStep.hasil => _ResultView(
        summary: _summary!,
        plan: _plan!,
        busy: _busy,
        busyLabel: _busyLabel,
        onDownloadReport: _downloadIssueReport,
      ),
    };
  }

  Widget? _buildBottomBar() {
    final label = switch (_step) {
      _WizardStep.pilihFile => 'Pilih File .xlsx',
      _WizardStep.membaca => null,
      _WizardStep.pratinjau => _plan == null || _plan!.importableCount == 0
          ? 'Tidak ada baris yang bisa diimpor'
          : 'Impor ${_plan!.importableCount} Produk',
      _WizardStep.hasil => 'Lihat Produk',
    };
    if (label == null) return null;

    final enabled = switch (_step) {
      _WizardStep.pilihFile => !_busy,
      _WizardStep.pratinjau => !_busy && (_plan?.importableCount ?? 0) > 0,
      _ => !_busy,
    };
    final onPressed = switch (_step) {
      _WizardStep.pilihFile => _pickFile,
      _WizardStep.pratinjau => _confirmAndImport,
      _ => () => Navigator.of(context).pop(),
    };

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        0,
        AppSizes.screenPadding,
        AppSizes.spaceMd,
      ),
      child: Container(
        decoration: AppDecorations.floating(context),
        padding: const EdgeInsets.all(AppSizes.spaceMs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy && _busyLabel.isNotEmpty) ...[
              Row(
                children: [
                  const SizedBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSizes.spaceMs),
                  Expanded(
                    child: Text(
                      _busyLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceSm),
            ],
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeightLarge,
              child: FilledButton.icon(
                onPressed: enabled ? onPressed : null,
                icon: Icon(
                  switch (_step) {
                    _WizardStep.pilihFile => Icons.upload_file_rounded,
                    _WizardStep.pratinjau => Icons.download_done_rounded,
                    _ => Icons.inventory_2_outlined,
                  },
                ),
                label: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Indikator langkah
// =====================================================================

/// `1 Pilih file · 2 Pratinjau · 3 Selesai` (PRD §4.7). Langkah "membaca"
/// & "konfirmasi" tidak diberi nomor sendiri: keduanya keadaan sesaat,
/// bukan tempat pengguna berhenti dan memutuskan sesuatu.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final _WizardStep step;

  @override
  Widget build(BuildContext context) {
    final current = switch (step) {
      _WizardStep.pilihFile || _WizardStep.membaca => 1,
      _WizardStep.pratinjau => 2,
      _WizardStep.hasil => 3,
    };
    const labels = ['Pilih file', 'Pratinjau', 'Selesai'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.spaceMs,
        AppSizes.screenPadding,
        AppSizes.spaceMs,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceSm,
                  ),
                  color: i + 1 <= current
                      ? context.palette.primary200
                      : context.palette.border,
                ),
              ),
            AppPill(
              label: '${i + 1} ${labels[i]}',
              tone: i + 1 == current
                  ? AppTone.primary
                  : (i + 1 < current ? AppTone.success : AppTone.neutral),
              icon: i + 1 < current ? Icons.check_rounded : null,
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// Langkah 1 — pilih file
// =====================================================================

class _PickFileView extends StatelessWidget {
  const _PickFileView({
    required this.error,
    required this.busy,
    required this.busyLabel,
    required this.onDownloadTemplate,
  });

  final String? error;
  final bool busy;
  final String busyLabel;
  final VoidCallback onDownloadTemplate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.spaceSm,
        AppSizes.screenPadding,
        AppSizes.bottomSafePadding,
      ),
      children: [
        if (error != null) ...[
          AppBanner(
            tone: AppTone.danger,
            icon: Icons.error_outline_rounded,
            title: 'File tidak bisa diimpor',
            message: error!,
          ),
          const SizedBox(height: AppSizes.spaceMd),
        ],
        AppCard(
          elevated: true,
          padding: const EdgeInsets.all(AppSizes.spaceMl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIconBadge(
                icon: Icons.table_view_outlined,
                tone: AppTone.primary,
                size: AppIconBadgeSize.lg,
              ),
              const SizedBox(height: AppSizes.spaceMd),
              Text('Masukkan katalog sekali jalan', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSizes.spaceSm),
              Text(
                'Isi daftar barang di laptop, lalu impor filenya ke sini. '
                'File hasil "Export Produk & Stok" dari aplikasi ini juga '
                'bisa langsung dipakai — cocok untuk mengubah harga banyak '
                'barang sekaligus.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.palette.inkSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.spaceMd),
              SizedBox(
                height: AppSizes.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onDownloadTemplate,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Unduh Template'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spaceLg),
        const SectionHeader(
          title: 'Yang perlu diketahui',
          subtitle: 'Tiga aturan yang paling sering ditanyakan',
        ),
        const _RuleTile(
          icon: Icons.description_outlined,
          title: 'Hanya file .xlsx',
          message:
              'Maksimal 5.000 baris sekali impor. Katalog lebih besar dipecah '
              'menjadi beberapa file.',
        ),
        const _RuleTile(
          icon: Icons.qr_code_2_rounded,
          title: 'Barcode yang menentukan produk lama',
          message:
              'Barcode yang sudah terdaftar akan memperbarui produk itu. '
              'Baris tanpa barcode selalu masuk sebagai produk baru.',
        ),
        const _RuleTile(
          icon: Icons.inventory_outlined,
          title: 'Stok tidak ditimpa',
          message:
              'Stok berjalan di aplikasi biasanya lebih baru daripada file '
              'Excel, jadi impor tidak mengubahnya kecuali kamu memintanya.',
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSizes.spaceMs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconBadge(icon: icon, tone: AppTone.neutral, size: AppIconBadgeSize.sm),
            const SizedBox(width: AppSizes.spaceMs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.palette.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Langkah 3 — pratinjau
// =====================================================================

class _PreviewView extends StatelessWidget {
  const _PreviewView({
    required this.plan,
    required this.options,
    required this.filter,
    required this.onFilterChanged,
    required this.onOptionsChanged,
  });

  final ProductImportPlan plan;
  final ProductImportOptions options;
  final _PreviewFilter filter;
  final ValueChanged<_PreviewFilter> onFilterChanged;
  final ValueChanged<ProductImportOptions> onOptionsChanged;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final row in plan.rows)
        if (filter == null || row.action == filter) row,
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.spaceSm,
            AppSizes.screenPadding,
            0,
          ),
          sliver: SliverList.list(
            children: [
              ImportSummaryCard(
                eyebrow: 'PRATINJAU',
                title: plan.fileName,
                subtitle:
                    '${plan.totalCount} baris dibaca dari sheet '
                    '"${plan.parse.sheetName}"',
                stats: [
                  ImportStat(
                    value: plan.createCount,
                    label: 'Baru',
                    tone: AppTone.success,
                  ),
                  ImportStat(
                    value: plan.updateCount,
                    label: 'Diperbarui',
                    tone: AppTone.info,
                  ),
                  if (plan.skipCount > 0)
                    ImportStat(value: plan.skipCount, label: 'Dilewati'),
                  ImportStat(
                    value: plan.errorCount,
                    label: 'Bermasalah',
                    tone: AppTone.danger,
                  ),
                ],
              ),
              if (plan.warningCount > 0) ...[
                const SizedBox(height: AppSizes.spaceMd),
                AppBanner(
                  tone: AppTone.warning,
                  icon: Icons.info_outline_rounded,
                  message:
                      '${plan.warningCount} baris tetap diimpor tapi perlu '
                      'dicek — lihat catatan kuning di daftar bawah.',
                ),
              ],
              if (plan.newCategoryNames.isNotEmpty) ...[
                const SizedBox(height: AppSizes.spaceMd),
                AppBanner(
                  tone: AppTone.info,
                  icon: Icons.sell_outlined,
                  message:
                      '${plan.newCategoryNames.length} kategori baru akan '
                      'dibuat: ${plan.newCategoryNames.take(3).join(', ')}'
                      '${plan.newCategoryNames.length > 3 ? ', …' : ''}',
                ),
              ],
              const SizedBox(height: AppSizes.spaceLg),
              _OptionsPanel(options: options, onChanged: onOptionsChanged),
              const SizedBox(height: AppSizes.spaceLg),
              SectionHeader(
                title: 'Daftar baris',
                trailing: AppPill(
                  label: visible.length == 1
                      ? '1 baris'
                      : '${visible.length} baris',
                  dense: true,
                ),
                padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: _FilterChips(
            plan: plan,
            filter: filter,
            onChanged: onFilterChanged,
          ),
        ),
        if (visible.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: AppSizes.spaceLg),
              child: EmptyState(
                icon: Icons.filter_alt_off_outlined,
                tone: AppTone.neutral,
                compact: true,
                title: 'Tidak ada baris di tab ini',
                message:
                    'Pilih tab lain untuk melihat baris yang statusnya berbeda.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.spaceSm,
              AppSizes.screenPadding,
              AppSizes.bottomSafePadding,
            ),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spaceSm),
              itemBuilder: (context, index) =>
                  ImportPreviewRowTile(planRow: visible[index]),
            ),
          ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.plan,
    required this.filter,
    required this.onChanged,
  });

  final ProductImportPlan plan;
  final _PreviewFilter filter;
  final ValueChanged<_PreviewFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, _PreviewFilter value, int count})>[
      (label: 'Semua', value: null, count: plan.totalCount),
      (label: 'Baru', value: ProductImportAction.create, count: plan.createCount),
      (
        label: 'Diperbarui',
        value: ProductImportAction.update,
        count: plan.updateCount,
      ),
      if (plan.skipCount > 0)
        (label: 'Dilewati', value: ProductImportAction.skip, count: plan.skipCount),
      (
        label: 'Bermasalah',
        value: ProductImportAction.error,
        count: plan.errorCount,
      ),
    ];

    return SizedBox(
      height: AppSizes.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.spaceSm),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final selected = filter == entry.value;
          return Center(
            child: ChoiceChip(
              label: Text('${entry.label} (${entry.count})'),
              selected: selected,
              onSelected: (_) => onChanged(entry.value),
            ),
          );
        },
      ),
    );
  }
}

/// Opsi impor. Ketiganya sengaja tampil terbuka (bukan di balik menu):
/// keputusan "stok ditimpa atau tidak" terlalu mahal untuk disembunyikan.
class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({required this.options, required this.onChanged});

  final ProductImportOptions options;
  final ValueChanged<ProductImportOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      color: context.palette.surfaceAlt,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSizes.spaceXs),
            child: Text('PRODUK YANG SUDAH ADA', style: context.textStyles.eyebrow),
          ),
          RadioGroup<ProductImportDuplicateMode>(
            groupValue: options.duplicateMode,
            onChanged: (value) =>
                onChanged(options.copyWith(duplicateMode: value)),
            child: Column(
              children: [
                RadioListTile<ProductImportDuplicateMode>(
                  value: ProductImportDuplicateMode.update,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Perbarui produk yang sudah ada'),
                  subtitle: Text(
                    'Dicocokkan lewat barcode. Nama, kategori, dan harganya '
                    'ikut diperbarui.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                RadioListTile<ProductImportDuplicateMode>(
                  value: ProductImportDuplicateMode.skip,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lewati produk yang sudah ada'),
                  subtitle: Text(
                    'Hanya produk yang benar-benar baru yang dibuat.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: AppSizes.spaceLg),
          SwitchListTile(
            value: options.overwriteStock,
            onChanged: (value) => onChanged(options.copyWith(overwriteStock: value)),
            contentPadding: EdgeInsets.zero,
            title: const Text('Timpa stok dari file'),
            subtitle: Text(
              'Mati secara default. Kalau dinyalakan, setiap perubahan stok '
              'tercatat di riwayat stok produk.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          SwitchListTile(
            value: options.autoCreateCategory,
            onChanged: (value) =>
                onChanged(options.copyWith(autoCreateCategory: value)),
            contentPadding: EdgeInsets.zero,
            title: const Text('Buat kategori baru otomatis'),
            subtitle: Text(
              'Kategori di file yang belum ada akan dibuat sekali saja.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Langkah 4 — dialog konfirmasi
// =====================================================================

enum _ConfirmAnswer { lanjut, backupDulu }

class _ImportConfirmDialog extends StatelessWidget {
  const _ImportConfirmDialog({required this.plan});

  final ProductImportPlan plan;

  @override
  Widget build(BuildContext context) {
    final updateLine = plan.updateCount == 0
        ? ''
        : ' ${plan.updateCount} produk yang sudah ada akan diperbarui.';

    return AlertDialog(
      icon: const AppIconBadge(
        icon: Icons.warning_amber_rounded,
        tone: AppTone.warning,
        size: AppIconBadgeSize.lg,
      ),
      title: Text('Impor ${plan.importableCount} produk?'),
      content: Text(
        'Sebanyak ${plan.createCount} produk baru akan dibuat.$updateLine '
        'Tindakan ini tidak bisa dibatalkan — disarankan backup dulu.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ConfirmAnswer.backupDulu),
          child: const Text('Backup Dulu'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ConfirmAnswer.lanjut),
          child: const Text('Impor Sekarang'),
        ),
      ],
    );
  }
}

// =====================================================================
// Langkah 5 — hasil
// =====================================================================

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.summary,
    required this.plan,
    required this.busy,
    required this.busyLabel,
    required this.onDownloadReport,
  });

  final ProductImportSummary summary;
  final ProductImportPlan plan;
  final bool busy;
  final String busyLabel;
  final VoidCallback onDownloadReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problems = plan.errorCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.spaceSm,
        AppSizes.screenPadding,
        AppSizes.bottomSafePadding,
      ),
      children: [
        Center(
          child: AppIconBadge(
            icon: Icons.check_rounded,
            tone: AppTone.success,
            size: AppIconBadgeSize.xl,
            filled: true,
          ),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        Text(
          summary.totalWritten == 1
              ? '1 produk berhasil diimpor'
              : '${summary.totalWritten} produk berhasil diimpor',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSizes.spaceLg),
        ImportSummaryCard(
          eyebrow: 'HASIL IMPOR',
          title: plan.fileName,
          stats: [
            ImportStat(
              value: summary.createdCount,
              label: 'Baru',
              tone: AppTone.success,
            ),
            ImportStat(
              value: summary.updatedCount,
              label: 'Diperbarui',
              tone: AppTone.info,
            ),
            ImportStat(
              value: summary.skippedCount + problems,
              label: 'Dilewati',
              tone: (summary.skippedCount + problems) > 0
                  ? AppTone.warning
                  : AppTone.neutral,
            ),
          ],
        ),
        if (summary.categoriesCreatedCount > 0) ...[
          const SizedBox(height: AppSizes.spaceMd),
          AppBanner(
            tone: AppTone.info,
            icon: Icons.sell_outlined,
            message:
                '${summary.categoriesCreatedCount} kategori baru ikut dibuat.',
          ),
        ],
        if (summary.stockMovementCount > 0) ...[
          const SizedBox(height: AppSizes.spaceMd),
          AppBanner(
            tone: AppTone.info,
            icon: Icons.inventory_outlined,
            message:
                '${summary.stockMovementCount} perubahan stok tercatat di '
                'riwayat stok dengan catatan nama file.',
          ),
        ],
        if (plan.problemRows.isNotEmpty) ...[
          const SizedBox(height: AppSizes.spaceMd),
          AppBanner(
            tone: problems > 0 ? AppTone.warning : AppTone.info,
            icon: Icons.report_gmailerrorred_outlined,
            title: problems > 0
                ? '$problems baris tidak ikut masuk'
                : 'Ada baris yang perlu dicek',
            message:
                'Unduh laporannya untuk melihat nomor baris, isi aslinya, dan '
                'alasannya — lalu perbaiki di laptop dan impor ulang.',
          ),
          const SizedBox(height: AppSizes.spaceMd),
          SizedBox(
            height: AppSizes.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onDownloadReport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Unduh Laporan Baris Bermasalah'),
            ),
          ),
          if (busy && busyLabel.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceSm),
            Text(busyLabel, style: theme.textTheme.bodySmall),
          ],
        ],
      ],
    );
  }
}
