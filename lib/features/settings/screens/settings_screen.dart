import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../license/widgets/license_section.dart';
import '../widgets/appearance_section.dart';
import '../widgets/backup_reminder_banner.dart';
import '../widgets/backup_restore_section.dart';
import '../widgets/export_section.dart';
import '../widgets/low_stock_default_section.dart';
import '../widgets/pin_section.dart';
import '../widgets/printer_section.dart';
import '../widgets/store_profile_section.dart';

/// Layar Pengaturan (plan.md Milestone 5) — profil toko, threshold stok
/// menipis default, export Excel, backup/restore database, dan kunci PIN.
///
/// Akses ke tab ini sendiri dijaga PIN lewat `MainShell`/`checkPinGate`
/// (architecture.md §5.4) bila kunci sudah diaktifkan.
///
/// Struktur visual (docs/ui-redesign-foundation.md §5.2): setelan dipecah
/// jadi lima GRUP bernama — Tampilan, Identitas, Operasional, Data,
/// Keamanan —
/// masing-masing dibuka [SectionHeader] ber-eyebrow dan diisi satu/dua
/// [SettingsCard]. Grup membuat layar panjang ini bisa dipindai sekilas
/// alih-alih jadi tumpukan kartu seragam.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Jangkar untuk melompat dari banner pengingat ke kartu Backup —
  /// pengingat yang tidak bisa langsung ditindaklanjuti hanyalah teguran.
  final GlobalKey _backupKey = GlobalKey();

  void _scrollToBackup() {
    final ctx = _backupKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.spaceSm,
            AppSizes.screenPadding,
            AppSizes.bottomSafePadding,
          ),
          children: [
            BackupReminderBanner(onBackup: _scrollToBackup),

            const SectionHeader(
              eyebrow: 'TAMPILAN',
              title: 'Mata Kamu',
              subtitle: 'Terang untuk siang, gelap untuk warung malam.',
            ),
            const AppearanceSection(),

            const SizedBox(height: AppSizes.spaceXl),
            const SectionHeader(
              eyebrow: 'IDENTITAS',
              title: 'Toko Kamu',
              subtitle: 'Dipakai di kepala struk pembeli.',
            ),
            const StoreProfileSection(),

            const SizedBox(height: AppSizes.spaceXl),
            const SectionHeader(
              eyebrow: 'OPERASIONAL',
              title: 'Aturan Stok',
              subtitle: 'Kapan sebuah barang dianggap mulai menipis.',
            ),
            const LowStockDefaultSection(),

            const SizedBox(height: AppSizes.spaceXl),
            const SectionHeader(
              eyebrow: 'PERANGKAT',
              title: 'Printer Struk',
              subtitle: 'Secarik kertas di tangan pembeli, dalam hitungan detik.',
            ),
            const PrinterSection(),

            const SizedBox(height: AppSizes.spaceXl),
            const SectionHeader(
              eyebrow: 'DATA',
              title: 'Cadangan & Ekspor',
              subtitle: 'Amankan data, atau bawa ke Excel.',
            ),
            KeyedSubtree(key: _backupKey, child: const BackupRestoreSection()),
            const SizedBox(height: AppSizes.spaceMs),
            const ExportSection(),

            const SizedBox(height: AppSizes.spaceXl),
            const SectionHeader(
              eyebrow: 'KEAMANAN',
              title: 'Kunci Akses',
              subtitle: 'Batasi siapa yang boleh melihat uang & membatalkan.',
            ),
            const PinSection(),

            const SizedBox(height: AppSizes.spaceXl),
            const SectionHeader(
              eyebrow: 'LISENSI',
              title: 'Aktivasi Aplikasi',
              subtitle: 'Sekali diaktifkan, jalan terus tanpa internet.',
            ),
            const LicenseSection(),

            const SizedBox(height: AppSizes.space2xl),
            const _SettingsFooter(),
          ],
        ),
      ),
    );
  }
}

/// Penutup layar — kalimat tenang yang mengingatkan janji utama aplikasi
/// (offline, data milik sendiri). Peak-end rule: akhir layar pun mengarahkan.
class _SettingsFooter extends StatelessWidget {
  const _SettingsFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const AppIconBadge(
          icon: Icons.storefront_outlined,
          tone: AppTone.neutral,
          size: AppIconBadgeSize.sm,
        ),
        const SizedBox(height: AppSizes.spaceSm),
        Text('Kasir Warung', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSizes.spaceXs),
        Text(
          'Semua data tersimpan di HP ini dan tetap jalan tanpa internet.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: context.palette.inkSecondary),
        ),
      ],
    );
  }
}
