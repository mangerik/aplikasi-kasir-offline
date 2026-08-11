import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';

/// Kartu pembungkus seragam untuk tiap seksi layar Pengaturan (profil
/// toko, stok, export, backup/restore, PIN) — plan.md Milestone 5.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
              ),
            ],
            const SizedBox(height: AppSizes.spaceMd),
            ...children,
          ],
        ),
      ),
    );
  }
}
