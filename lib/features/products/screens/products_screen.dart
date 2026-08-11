import 'package:flutter/material.dart';

/// Layar Produk — stub Milestone 0.
///
/// Implementasi penuh (CRUD produk & kategori, pencarian, filter, indikator
/// stok menipis) dikerjakan di Milestone 1, lihat plan.md.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produk')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Daftar produk & kategori akan hadir di sini.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
