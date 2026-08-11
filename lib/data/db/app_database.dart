import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/categories_table.dart';
import 'tables/held_carts_table.dart';
import 'tables/products_table.dart';
import 'tables/sale_items_table.dart';
import 'tables/sales_table.dart';
import 'tables/settings_table.dart';
import 'tables/stock_movements_table.dart';

part 'app_database.g.dart';

/// Database aplikasi (SQLite via Drift). Lihat architecture.md §4.
///
/// - Mode **WAL** diaktifkan saat koneksi dibuka (ketahanan crash & baca
///   konkuren, lihat architecture.md §7).
/// - `schemaVersion` = 1 (Milestone 0). Migrasi berikutnya wajib menambah
///   `MigrationStrategy.onUpgrade` di sini, tidak boleh mengubah tabel lama
///   secara destruktif.
/// - Index penting & partial unique index barcode dibuat manual lewat SQL
///   mentah di `onCreate` karena melibatkan klausa `WHERE` (partial index)
///   yang belum didukung langsung oleh anotasi `@TableIndex` drift.
@DriftDatabase(
  tables: [
    Categories,
    Products,
    Sales,
    SaleItems,
    StockMovements,
    HeldCarts,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Nama file database: `kasir_warung.sqlite` di folder dokumen aplikasi.
  static const String _dbName = 'kasir_warung';

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createIndexes() async {
    // Pencarian & scan cepat.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)',
    );
    // Barcode unik hanya jika terisi (partial unique index).
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode_unique '
      'ON products(barcode) WHERE barcode IS NOT NULL',
    );

    // Filter riwayat & laporan.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(status)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_product_created '
      'ON stock_movements(product_id, created_at)',
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: _dbName,
      native: DriftNativeOptions(
        setup: (database) {
          database.execute('PRAGMA journal_mode=WAL;');
        },
      ),
    );
  }
}
