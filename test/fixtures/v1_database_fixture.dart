import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite3lib;

/// Pembuat **snapshot database skema v1 nyata** untuk uji migrasi 1 → 2
/// (PRD v1.1 AC-10.1: "bukan hanya `createAll()` dari nol").
///
/// DDL di bawah adalah salinan PERSIS `sqlite_master` milik build v1.0
/// (schemaVersion 1) — tanpa tabel `customers`/`customer_point_entries`,
/// tanpa kolom `sales.customer_id`, dan tanpa tiga index M12. Menyalinnya
/// apa adanya penting: uji migrasi yang berjalan di atas skema "kira-kira
/// mirip" tidak membuktikan apa pun tentang database pengguna sungguhan.
abstract final class V1DatabaseFixture {
  /// `PRAGMA user_version` milik build v1.0.
  static const int schemaVersion = 1;

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
    'CREATE TABLE "sales" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        '"invoice_number" TEXT NOT NULL UNIQUE, "subtotal" INTEGER NOT NULL, '
        '"discount" INTEGER NOT NULL DEFAULT 0, "total" INTEGER NOT NULL, '
        '"payment_method" TEXT NOT NULL, "paid_amount" INTEGER NOT NULL DEFAULT 0, '
        '"change_amount" INTEGER NOT NULL DEFAULT 0, "customer_name" TEXT NULL, '
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
  ];

  /// Satu transaksi contoh untuk fixture.
  static const String _insertSale =
      'INSERT INTO sales (invoice_number, subtotal, discount, total, '
      'payment_method, paid_amount, change_amount, customer_name, status, '
      'note, created_at, voided_at, debt_paid_at) '
      'VALUES (?, ?, 0, ?, ?, ?, 0, ?, ?, NULL, ?, ?, NULL)';

  /// Membuat file database v1 di [path] dan mengisinya dengan **data
  /// campuran yang sengaja berantakan** seperti database warung sungguhan:
  ///
  /// - `"Bu Ani"`, `"bu ani"`, `"Bu Ani "` — satu orang, tiga ejaan
  ///   (AC-7.1); ejaan terbanyak adalah `"Bu Ani"` (2 transaksi).
  /// - `"  "` (spasi saja) dan `NULL` — tidak boleh melahirkan pelanggan.
  /// - transaksi hutang, transaksi lunas, dan satu transaksi `voided`.
  /// - `"Pak Joko"` yang hutangnya sudah lunas — tetap harus punya baris
  ///   `customers` (dia pelanggan, bukan penghutang).
  /// Nilai `settings.pin_hash`/`pin_salt` yang ditulis bila [create]
  /// dipanggil dengan `withGlobalPin: true` — meniru warung yang sudah
  /// memasang kunci PIN sejak v1.0 (M5). Rantai migrasi 1 → 2 → 3 wajib
  /// mengubahnya menjadi akun **Pemilik** tanpa pemilik pernah diminta
  /// membuat PIN baru (AC-8.2).
  static const String globalPinHash = 'hash-pin-lama-v1';
  static const String globalPinSalt = 'garam-pin-lama-v1';

  static void create(String path, {bool withGlobalPin = false}) {
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
        "VALUES ('Beras 5kg', 65000, 60000, 10.0, 'pcs', 1, 1000, 1000)",
      );

      var day = 1;
      void sale({
        required String invoice,
        required int total,
        required String method,
        required String? customer,
        required String status,
        int? voidedAt,
      }) {
        db.execute(_insertSale, [
          invoice,
          total,
          total,
          method,
          method == 'cash' ? total : 0,
          customer,
          status,
          1_700_000_000_000 + (day++ * 86_400_000),
          voidedAt,
        ]);
      }

      // "Bu Ani" — tiga ejaan, dua hutang belum lunas + satu tunai.
      sale(
        invoice: '20260801-0001',
        total: 25000,
        method: 'debt',
        customer: 'Bu Ani',
        status: 'debt_unpaid',
      );
      sale(
        invoice: '20260802-0001',
        total: 15000,
        method: 'debt',
        customer: 'bu ani',
        status: 'debt_unpaid',
      );
      sale(
        invoice: '20260803-0001',
        total: 30000,
        method: 'cash',
        customer: 'Bu Ani ',
        status: 'completed',
      );

      // "Pak Joko" — hutang yang SUDAH lunas.
      sale(
        invoice: '20260804-0001',
        total: 50000,
        method: 'debt',
        customer: 'Pak Joko',
        status: 'completed',
      );

      // "Mbak Sri" — hutang yang dibatalkan (voided): tidak boleh ikut
      // terhitung sebagai hutang berjalan, tapi orangnya tetap pelanggan.
      sale(
        invoice: '20260805-0001',
        total: 40000,
        method: 'debt',
        customer: 'Mbak Sri',
        status: 'voided',
        voidedAt: 1_700_600_000_000,
      );
      sale(
        invoice: '20260806-0001',
        total: 12000,
        method: 'debt',
        customer: 'MBAK SRI',
        status: 'debt_unpaid',
      );

      // Transaksi tanpa pelanggan — nama kosong & NULL.
      sale(
        invoice: '20260807-0001',
        total: 5000,
        method: 'cash',
        customer: null,
        status: 'completed',
      );
      sale(
        invoice: '20260808-0001',
        total: 7000,
        method: 'cash',
        customer: '   ',
        status: 'completed',
      );

      db.execute(
        "INSERT INTO settings (key, value) VALUES ('store_name', 'Warung Lama')",
      );

      if (withGlobalPin) {
        db.execute(
          'INSERT INTO settings (key, value) VALUES (?, ?)',
          ['pin_hash', globalPinHash],
        );
        db.execute(
          'INSERT INTO settings (key, value) VALUES (?, ?)',
          ['pin_salt', globalPinSalt],
        );
      }
    } finally {
      db.close();
    }
  }

  /// Total hutang belum lunas menurut database v1 (dihitung ulang dari
  /// file, bukan dihardcode) — dipakai membandingkan sebelum vs sesudah
  /// migrasi (AC-7.2).
  static int totalUnpaidDebt(String path) {
    final db = sqlite3lib.sqlite3.open(path, mode: sqlite3lib.OpenMode.readOnly);
    try {
      final rows = db.select(
        "SELECT COALESCE(SUM(total), 0) AS total FROM sales "
        "WHERE status = 'debt_unpaid'",
      );
      return rows.first['total'] as int;
    } finally {
      db.close();
    }
  }

  /// Jumlah baris seluruh tabel v1 — dipakai membuktikan migrasi tidak
  /// menghilangkan satu baris pun (AC-10.3, AC-10.4).
  static Map<String, int> rowCounts(String path) {
    const tables = [
      'categories',
      'products',
      'sales',
      'sale_items',
      'stock_movements',
      'held_carts',
      'settings',
    ];
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
