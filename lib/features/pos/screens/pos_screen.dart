import 'package:flutter/material.dart';

/// Layar Kasir (POS) — stub Milestone 0.
///
/// Implementasi penuh (grid produk, keranjang, pembayaran) dikerjakan di
/// Milestone 2, lihat plan.md.
class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kasir')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Layar Kasir akan hadir di sini.\nTap barang untuk mulai transaksi.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
