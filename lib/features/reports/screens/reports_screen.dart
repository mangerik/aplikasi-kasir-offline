import 'package:flutter/material.dart';

/// Layar Laporan — stub Milestone 0.
///
/// Implementasi penuh (ringkasan harian, laba kotor, produk terlaris,
/// daftar hutang) dikerjakan di Milestone 4, lihat plan.md.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Laporan penjualan akan hadir di sini.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
