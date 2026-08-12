import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/db/database_provider.dart';
import '../../../data/services/backup_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../settings/providers/settings_providers.dart';
import '../../transactions/utils/pin_gate.dart';
import '../widgets/device_code_card.dart';
import 'activation_screen.dart';

/// Layar "Masa coba berakhir" (rute `/lisensi-berakhir`) — PRD v1.1 §6.3.E.
///
/// Nada layar ini adalah keputusan desain, bukan selera: **tidak ada yang
/// menghukum di sini.** Pengguna yang masa cobanya habis belum tentu
/// menolak membeli — ia bisa saja belum sempat. Yang perlu ia dengar
/// pertama kali adalah "datamu aman", bukan "kamu terkunci".
///
/// Karena itu tombol **"Cadangkan Data" tetap ada** (K-6.11): pengguna yang
/// memutuskan tidak jadi membeli tetap bisa membawa pergi catatan warungnya
/// sendiri. Itu tidak melemahkan gerbang penjualan sama sekali — data tiga
/// hari tidak bernilai bagi pembajak, sementara "aplikasi menyandera catatan
/// warung saya" adalah kerusakan reputasi yang jauh lebih mahal daripada
/// satu lisensi.
class LicenseExpiredScreen extends ConsumerStatefulWidget {
  const LicenseExpiredScreen({super.key});

  @override
  ConsumerState<LicenseExpiredScreen> createState() =>
      _LicenseExpiredScreenState();
}

class _LicenseExpiredScreenState extends ConsumerState<LicenseExpiredScreen> {
  bool _busy = false;

  Future<void> _backup() async {
    // Gerbang PIN yang sudah ada tetap berlaku (AC-6.15): data warung tidak
    // boleh keluar hanya karena lisensinya habis.
    final allowed = await checkPinGate(context, ref);
    if (!allowed || !mounted) return;

    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      final path = await BackupService.createBackup(db);
      final nowMillis = DateFormatter.toEpochMillis(DateTime.now());
      await ref
          .read(settingsRepoProvider)
          .setValue('last_backup_at', nowMillis.toString());
      ref.invalidate(lastBackupAtProvider);
      await BackupService.share(path);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup berhasil dibuat.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal backup: ${AppErrorMessage.from(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.space2xl,
                AppSizes.screenPadding,
                AppSizes.spaceXl,
              ),
              children: [
                const Center(
                  child: AppIconBadge(
                    icon: Icons.lock_clock,
                    tone: AppTone.accent,
                    size: AppIconBadgeSize.xl,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceMl),
                Text(
                  'Masa coba 3 hari sudah berakhir',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSizes.spaceSm),
                Text(
                  'Semua data Anda masih tersimpan aman dan akan langsung '
                  'kembali setelah aplikasi diaktifkan.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.inkSecondary,
                  ),
                ),

                const SizedBox(height: AppSizes.spaceXl),
                const DeviceCodeCard(),

                const SizedBox(height: AppSizes.spaceLg),
                SizedBox(
                  height: AppSizes.buttonHeightLarge,
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => ActivationScreen.show(context),
                    icon: const Icon(Icons.vpn_key_outlined),
                    label: const Text('Masukkan Kode Aktivasi'),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceSm),
                SizedBox(
                  height: AppSizes.buttonHeight,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _backup,
                    icon: const Icon(Icons.backup_outlined),
                    label: Text(
                      _busy ? 'Menyiapkan file backup…' : 'Cadangkan Data',
                    ),
                  ),
                ),

                const SizedBox(height: AppSizes.spaceLg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: AppSizes.iconSm,
                      color: palette.inkSecondary,
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      child: Text(
                        'Tidak ada satu pun produk, transaksi, atau catatan '
                        'hutang yang dihapus. Anda juga tetap bisa membawa '
                        'salinan datanya kapan saja lewat "Cadangkan Data".',
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
