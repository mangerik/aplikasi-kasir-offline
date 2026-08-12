import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../providers/theme_providers.dart';
import 'settings_card.dart';

/// Kartu **"Tampilan"** — pemilih mode tema Terang / Gelap / Ikuti Sistem
/// (PRD v1.1 §5.3.A, AC-5.1).
///
/// Letaknya sengaja di ATAS kartu "Profil Toko": ini satu-satunya setelan
/// yang efeknya terlihat seketika di layar yang sedang dipandang, jadi ia
/// juga berfungsi sebagai pratinjau langsung — pengguna menekan "Gelap" dan
/// kartu ini sendiri yang berubah di depan matanya.
///
/// Tidak ada pintasan di AppBar layar lain: mengganti tema bukan aksi
/// harian, dan ikon tambahan di AppBar kasir melanggar prinsip "satu titik
/// fokus" (fondasi §4.1).
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final palette = context.palette;

    return SettingsCard(
      icon: palette.isDark
          ? Icons.dark_mode_outlined
          : Icons.light_mode_outlined,
      title: 'Tampilan',
      subtitle: 'Warna aplikasi saat siang dan saat malam.',
      tone: AppTone.info,
      children: [
        Text('Tema aplikasi', style: context.textStyles.eyebrow),
        const SizedBox(height: AppSizes.spaceSm),
        // SegmentedButton dipilih daripada tiga radio: ketiganya saling
        // eksklusif, jumlahnya sedikit & tetap, dan pilihan aktif terbaca
        // sekilas tanpa membaca label satu per satu.
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Terang'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Gelap'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('Ikuti Sistem'),
              ),
            ],
            selected: <ThemeMode>{mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              ref.read(themeModeProvider.notifier).setMode(selection.first);
            },
            style: SegmentedButton.styleFrom(
              // Target sentuh >= 48dp (PRD §1.3 poin 3).
              minimumSize: const Size(48, AppSizes.minTouchTarget),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spaceSm,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spaceSm),
        Text(
          'Ikuti Sistem mengikuti pengaturan tema HP Anda.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkSecondary),
        ),
      ],
    );
  }
}
