import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../widgets/backup_reminder_banner.dart';
import '../widgets/backup_restore_section.dart';
import '../widgets/export_section.dart';
import '../widgets/low_stock_default_section.dart';
import '../widgets/pin_section.dart';
import '../widgets/store_profile_section.dart';

/// Layar Pengaturan (plan.md Milestone 5) — profil toko, threshold stok
/// menipis default, export Excel, backup/restore database, dan kunci PIN.
///
/// Akses ke tab ini sendiri dijaga PIN lewat `MainShell`/`checkPinGate`
/// (architecture.md §5.4) bila kunci sudah diaktifkan.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.spaceMd),
          children: const [
            BackupReminderBanner(),
            StoreProfileSection(),
            SizedBox(height: AppSizes.spaceMd),
            LowStockDefaultSection(),
            SizedBox(height: AppSizes.spaceMd),
            ExportSection(),
            SizedBox(height: AppSizes.spaceMd),
            BackupRestoreSection(),
            SizedBox(height: AppSizes.spaceMd),
            PinSection(),
            SizedBox(height: AppSizes.spaceLg),
          ],
        ),
      ),
    );
  }
}
