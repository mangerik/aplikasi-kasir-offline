import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/categories_table.dart';
import 'tables/customer_point_entries_table.dart';
import 'tables/customers_table.dart';
import 'tables/held_carts_table.dart';
import 'tables/products_table.dart';
import 'tables/sale_items_table.dart';
import 'tables/sales_table.dart';
import 'tables/settings_table.dart';
import 'tables/stock_movements_table.dart';

part 'app_database.g.dart';

/// Versi skema database yang dipahami build aplikasi ini — **satu-satunya
/// sumber kebenaran**. Dipakai [AppDatabase.schemaVersion] (yang menuliskannya
/// ke `PRAGMA user_version`) **dan** `BackupService.validateBackupFile`, yang
/// membandingkannya dengan `user_version` file backup untuk menolak backup
/// dari aplikasi yang lebih baru (PRD v1.1 AC-10.2).
///
/// Menaikkan angka ini WAJIB dibarengi `MigrationStrategy.onUpgrade` dan uji
/// migrasi atas snapshot database versi sebelumnya (AC-10.1).
///
/// Riwayat:
/// - **1** — MVP v1.0 (M0): 7 tabel dasar.
/// - **2** — v1.2 Tier 2 / M12 (PRD v1.1 §7.5): `customers`,
///   `customer_point_entries`, `sales.customer_id`, 3 index baru, plus
///   backfill pelanggan dari `sales.customer_name`.
const int kAppSchemaVersion = 2;

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
    Customers,
    CustomerPointEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Nama file database: `kasir_warung.sqlite` di folder dokumen aplikasi.
  static const String _dbName = 'kasir_warung';

  @override
  int get schemaVersion => kAppSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
          await _createCustomerIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // AC-10.5: seluruh langkah migrasi berjalan dalam SATU transaksi —
          // gagal di tengah jalan mengembalikan database persis ke keadaan
          // semula. AC-10.4: tidak ada DROP/penulisan ulang tabel, hanya
          // CREATE TABLE, ADD COLUMN, CREATE INDEX, dan UPDATE backfill.
          await transaction(() async {
            if (from < 2) {
              await _upgradeToV2(m);
            }
          });
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Migrasi 1 → 2 (PRD v1.1 §7.3.E & §7.5): pelanggan menjadi entitas
  /// nyata, dan seluruh nama pelanggan lama dipindahkan ke tabel
  /// `customers` **tanpa menyentuh** `sales.customer_name` (K-7.1, AC-7.3).
  ///
  /// Pengelompokan backfill:
  /// - nama di-`TRIM` dulu, nama kosong diabaikan;
  /// - dikelompokkan **case-insensitive** (`"Bu Ani"`, `"bu ani"`,
  ///   `"BU ANI "` → satu pelanggan);
  /// - ejaan yang dipakai adalah yang **paling sering muncul**; bila seri,
  ///   yang transaksinya paling awal (AC-7.1).
  ///
  /// Poin **tidak** diberikan surut (K-7.4): seluruh pelanggan hasil
  /// backfill lahir dengan `points = 0` dan buku besar kosong.
  Future<void> _upgradeToV2(Migrator m) async {
    await m.createTable(customers);
    await m.createTable(customerPointEntries);
    await m.addColumn(sales, sales.customerId);
    await _createCustomerIndexes();

    final now = DateTime.now().millisecondsSinceEpoch;

    // Satu baris per KELOMPOK nama (case-insensitive setelah trim), berisi
    // ejaan pemenang. Diurutkan: frekuensi terbanyak dulu, lalu transaksi
    // paling awal — persis aturan PRD §7.3.E poin 3.
    final groups = await customSelect(
      "SELECT LOWER(TRIM(customer_name)) AS key_name, "
      "       TRIM(customer_name) AS spelling, "
      "       COUNT(*) AS freq, "
      "       MIN(created_at) AS first_at "
      "FROM sales "
      "WHERE customer_name IS NOT NULL AND TRIM(customer_name) != '' "
      "GROUP BY LOWER(TRIM(customer_name)), TRIM(customer_name) "
      "ORDER BY key_name ASC, freq DESC, first_at ASC",
    ).get();

    final winners = <String, String>{};
    for (final row in groups) {
      final key = row.read<String>('key_name');
      if (winners.containsKey(key)) continue;
      winners[key] = row.read<String>('spelling');
    }

    for (final entry in winners.entries) {
      final customerId = await into(customers).insert(
        CustomersCompanion.insert(createdAt: now, updatedAt: now, name: entry.value),
      );
      await customStatement(
        'UPDATE sales SET customer_id = ?1 '
        "WHERE customer_name IS NOT NULL AND LOWER(TRIM(customer_name)) = ?2",
        [customerId, entry.key],
      );
    }
  }

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

  /// Index pelanggan & poin (PRD v1.1 §7.5). Dipanggil dari `onCreate`
  /// (database baru) MAUPUN dari migrasi 1 → 2 — semuanya `IF NOT EXISTS`
  /// supaya idempoten.
  ///
  /// `idx_customers_name_nocase` sengaja **parsial** (hanya pelanggan
  /// aktif): pelanggan yang dinonaktifkan/digabung tidak boleh menghalangi
  /// pembuatan nama yang sama lagi.
  Future<void> _createCustomerIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_name_nocase '
      'ON customers(name COLLATE NOCASE) WHERE is_active = 1',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sales_customer '
      'ON sales(customer_id, created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_point_entries_customer '
      'ON customer_point_entries(customer_id, created_at)',
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
