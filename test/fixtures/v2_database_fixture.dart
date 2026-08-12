import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite3lib;

/// Pembuat **snapshot database skema v2 nyata** untuk uji migrasi 2 → 3
/// (PRD v1.1 AC-10.1: "bukan hanya `createAll()` dari nol").
///
/// DDL di bawah adalah salinan PERSIS `sqlite_master` milik build M12
/// (schemaVersion 2) — sudah punya `customers`/`customer_point_entries`
/// dan `sales.customer_id`, tapi **belum** punya tabel `users`, kolom
/// `sales.user_id`/`user_name`/`voided_by_user_id`, maupun
/// `stock_movements.user_id`.
///
/// Yang paling penting di fixture ini: baris `settings` berisi
/// `pin_hash`/`pin_salt` — PIN global v1.0 yang harus BERUBAH menjadi PIN
/// akun "Pemilik" setelah migrasi (AC-8.2). Fixture tanpa PIN itu tidak
/// akan membuktikan apa pun tentang database pengguna sungguhan yang sudah
/// memasang kunci sejak M5.
abstract final class V2DatabaseFixture {
  /// `PRAGMA user_version` milik build M12.
  static const int schemaVersion = 2;

  /// Hash & salt PIN global yang ditanam di fixture — nilainya sengaja
  /// dibuat mencolok supaya mudah dicocokkan di test.
  static const String pinHash = 'hash-pin-lama-v1';
  static const String pinSalt = 'salt-pin-lama-v1';

  static const List<String> _ddl = <String>[
    'CREATE TABLE "categories" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        '"name" TEXT NOT NULL UNIQUE, "created_at" INTEGER NOT NULL)',
    'CREATE TABLE "products" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        '"name" TEXT NOT NULL, "barcode" TEXT NULL, '
        '"category_id" INTEGER NULL REFERENCES categories (id), '
        '"sell_price" INTEGER NOT NULL, "cost_price" INTEGER NULL, '
        '"stock" REAL NOT NULL DEFAULT 0.0, "unit" TEXT NOT NULL DEFAULT \'pcs\', '
        '"low_stock_threshold" REAL NULL, "image_path" TEXT NULL, '
        '"is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)), '
        '"created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL)',
    'CREATE TABLE "customers" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        '"name" TEXT NOT NULL, "phone" TEXT NULL, "note" TEXT NULL, '
        '"points" INTEGER NOT NULL DEFAULT 0, '
        '"is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)), '
        '"merged_into_id" INTEGER NULL, "created_at" INTEGER NOT NULL, '
        '"updated_at" INTEGER NOT NULL)',
    'CREATE TABLE "sales" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        '"invoice_number" TEXT NOT NULL UNIQUE, "subtotal" INTEGER NOT NULL, '
        '"discount" INTEGER NOT NULL DEFAULT 0, "total" INTEGER NOT NULL, '
        '"payment_method" TEXT NOT NULL, "paid_amount" INTEGER NOT NULL DEFAULT 0, '
        '"change_amount" INTEGER NOT NULL DEFAULT 0, "customer_name" TEXT NULL, '
        '"customer_id" INTEGER NULL REFERENCES customers (id), '
        '"status" TEXT NOT NULL, "note" TEXT NULL, "created_at" INTEGER NOT NULL, '
        '"voided_at" INTEGER NULL, "debt_paid_at" INTEGER NULL)',
    'CREATE TABLE "sale_items" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        '"sale_id" INTEGER NOT NULL REFERENCES sales (id), '
        '"product_id" INTEGER NULL REFERENCES products (id), '
        '"product_name" TEXT NOT NULL, "unit" TEXT NOT NULL, "qty" REAL NOT NULL, '
        '"sell_price" INTEGER NOT NULL, "cost_price" INTEGER NULL, '
        '"discount" INTEGER NOT NULL DEFAULT 0, "line_total" INTEGER NOT NULL)',
    'CREATE TABLE "stock_movements" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        '"product_id" INTEGER NOT NULL REFERENCES products (id), "type" TEXT NOT NULL, '
        '"qty_change" REAL NOT NULL, "stock_after" REAL NOT NULL, '
        '"reference_sale_id" INTEGER NULL REFERENCES sales (id), "note" TEXT NULL, '
        '"created_at" INTEGER NOT NULL)',
    'CREATE TABLE "customer_point_entries" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        '"customer_id" INTEGER NOT NULL REFERENCES customers (id), '
        '"type" TEXT NOT NULL, "points" INTEGER NOT NULL, '
        '"balance_after" INTEGER NOT NULL, '
        '"sale_id" INTEGER NULL REFERENCES sales (id), "note" TEXT NULL, '
        '"created_at" INTEGER NOT NULL)',
    'CREATE TABLE "held_carts" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        '"label" TEXT NULL, "cart_json" TEXT NOT NULL, "created_at" INTEGER NOT NULL)',
    'CREATE TABLE "settings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, '
        'PRIMARY KEY ("key"))',
    'CREATE INDEX idx_products_name ON products(name)',
    'CREATE INDEX idx_products_barcode ON products(barcode)',
    'CREATE UNIQUE INDEX idx_products_barcode_unique ON products(barcode) '
        'WHERE barcode IS NOT NULL',
    'CREATE INDEX idx_sales_created_at ON sales(created_at)',
    'CREATE INDEX idx_sales_status ON sales(status)',
    'CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id)',
    'CREATE INDEX idx_stock_movements_product_created '
        'ON stock_movements(product_id, created_at)',
    'CREATE UNIQUE INDEX idx_customers_name_nocase ON customers(name COLLATE NOCASE) '
        'WHERE is_active = 1',
    'CREATE INDEX idx_sales_customer ON sales(customer_id, created_at)',
    'CREATE INDEX idx_point_entries_customer '
        'ON customer_point_entries(customer_id, created_at)',
  ];

  /// Tabel yang sudah ada di skema v2 — dipakai membuktikan migrasi tidak
  /// menghilangkan satu baris pun (AC-10.3, AC-10.4).
  static const List<String> tables = [
    'categories',
    'products',
    'customers',
    'sales',
    'sale_items',
    'stock_movements',
    'customer_point_entries',
    'held_carts',
    'settings',
  ];

  /// Membuat file database v2 di [path] berisi data warung yang sudah
  /// berjalan: satu pelanggan berpoin, transaksi tunai & hutang, satu
  /// transaksi batal, pergerakan stok, dan **PIN global yang aktif**.
  ///
  /// [withGlobalPin] `false` mensimulasikan warung yang belum pernah
  /// memasang kunci PIN — migrasi tidak boleh melahirkan akun Pemilik
  /// tanpa PIN untuk kasus itu.
  static void create(String path, {bool withGlobalPin = true}) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();

    final db = sqlite3lib.sqlite3.open(path);
    try {
      for (final statement in _ddl) {
        db.execute(statement);
      }
      db.execute('PRAGMA user_version = $schemaVersion');

      db.execute(
        'INSERT INTO products (name, sell_price, cost_price, stock, unit, '
        'is_active, created_at, updated_at) '
        "VALUES ('Gula 1kg', 15000, 12000, 20.0, 'pcs', 1, 1000, 1000)",
      );
      db.execute(
        'INSERT INTO customers (name, points, is_active, created_at, updated_at) '
        "VALUES ('Bu Ani', 12, 1, 1000, 1000)",
      );

      void sale(String invoice, int total, String method, String status,
          {int? customerId, String? customerName}) {
        db.execute(
          'INSERT INTO sales (invoice_number, subtotal, discount, total, '
          'payment_method, paid_amount, change_amount, customer_name, '
          'customer_id, status, note, created_at, voided_at, debt_paid_at) '
          'VALUES (?, ?, 0, ?, ?, ?, 0, ?, ?, ?, NULL, ?, NULL, NULL)',
          [
            invoice,
            total,
            total,
            method,
            method == 'cash' ? total : 0,
            customerName,
            customerId,
            status,
            1_700_000_000_000,
          ],
        );
      }

      sale('20260901-0001', 30000, 'cash', 'completed',
          customerId: 1, customerName: 'Bu Ani');
      sale('20260901-0002', 15000, 'debt', 'debt_unpaid',
          customerId: 1, customerName: 'Bu Ani');
      sale('20260901-0003', 5000, 'cash', 'completed');

      db.execute(
        'INSERT INTO sale_items (sale_id, product_id, product_name, unit, qty, '
        "sell_price, cost_price, discount, line_total) "
        "VALUES (1, 1, 'Gula 1kg', 'pcs', 2.0, 15000, 12000, 0, 30000)",
      );
      db.execute(
        'INSERT INTO stock_movements (product_id, type, qty_change, stock_after, '
        "reference_sale_id, note, created_at) "
        "VALUES (1, 'sale', -2.0, 18.0, 1, NULL, 1700000000000)",
      );
      db.execute(
        'INSERT INTO customer_point_entries (customer_id, type, points, '
        "balance_after, sale_id, note, created_at) "
        "VALUES (1, 'earn', 12, 12, 1, NULL, 1700000000000)",
      );

      db.execute(
        "INSERT INTO settings (key, value) VALUES ('store_name', 'Warung Bu Ani')",
      );
      if (withGlobalPin) {
        db.execute(
          "INSERT INTO settings (key, value) VALUES ('pin_hash', '$pinHash')",
        );
        db.execute(
          "INSERT INTO settings (key, value) VALUES ('pin_salt', '$pinSalt')",
        );
      }
    } finally {
      db.close();
    }
  }

  /// Jumlah baris seluruh tabel v2.
  static Map<String, int> rowCounts(String path) {
    final db = sqlite3lib.sqlite3.open(path, mode: sqlite3lib.OpenMode.readOnly);
    try {
      return {
        for (final table in tables)
          table: db.select('SELECT COUNT(*) AS c FROM $table').first['c'] as int,
      };
    } finally {
      db.close();
    }
  }
}
