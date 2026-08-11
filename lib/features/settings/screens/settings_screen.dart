import 'package:flutter/material.dart';

/// Layar Pengaturan — stub Milestone 0.
///
/// Implementasi penuh (profil toko, export Excel, backup/restore, kunci
/// PIN) dikerjakan di Milestone 5, lihat plan.md.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Pengaturan toko, backup & export akan hadir di sini.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
