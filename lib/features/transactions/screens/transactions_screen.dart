import 'package:flutter/material.dart';

/// Layar Riwayat transaksi — stub Milestone 0.
///
/// Implementasi penuh (filter tanggal/metode/status, detail, void,
/// pelunasan hutang) dikerjakan di Milestone 3, lihat plan.md.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Riwayat transaksi akan hadir di sini.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
