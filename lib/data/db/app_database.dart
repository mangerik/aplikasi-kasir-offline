import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/repositories/repository_exceptions.dart';
import 'tables/categories_table.dart';
import 'tables/customer_point_entries_table.dart';
import 'tables/customers_table.dart';
import 'tables/held_carts_table.dart';
import 'tables/products_table.dart';
import 'tables/sale_items_table.dart';
import 'tables/sales_table.dart';
import 'tables/settings_table.dart';
import 'tables/stock_movements_table.dart';
import 'tables/users_table.dart';

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
/// - **3** — v1.2 Tier 2 / M13 (PRD v1.1 §8.5): `users`, `sales.user_id`/
///   `user_name`/`voided_by_user_id`, `stock_movements.user_id`, 2 index
///   baru, plus backfill PIN global lama menjadi akun **Pemilik**.
///
/// **M14 (grafik penjualan) sengaja TIDAK menaikkan angka ini** (PRD v1.1
/// §10, tahap "Tier 2c"): tidak ada tabel/kolom baru, hanya satu index
/// (`idx_sales_status_created`) yang dibuat idempoten di `beforeOpen` —
/// lihat [AppDatabase._createSeriesIndexes] untuk alasan lengkapnya.
const int kAppSchemaVersion = 3;

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
    Users,
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
          await _createUserIndexes();
          await _createSeriesIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // AC-10.5: seluruh langkah migrasi berjalan dalam SATU transaksi —
          // gagal di tengah jalan mengembalikan database persis ke keadaan
          // semula. AC-10.4: tidak ada DROP/penulisan ulang tabel, hanya
          // CREATE TABLE, ADD COLUMN, CREATE INDEX, dan UPDATE backfill.
          //
          // Transaksinya membungkus SELURUH rantai (1 → 2 → 3), bukan tiap
          // langkah sendiri-sendiri: database v1.0 yang gagal di langkah
          // kedua harus kembali menjadi v1.0 utuh, bukan tertinggal sebagai
          // v2 setengah jadi yang tidak dikenali versi aplikasi mana pun.
          try {
            await transaction(() async {
              if (from < 2) {
                await _upgradeToV2(m);
              }
              if (from < 3) {
                await _upgradeToV3(m);
              }
            });
          } catch (e, s) {
            // Separuh kedua AC-10.5: pesan Bahasa Indonesia yang jelas.
            // Rollback-nya dikerjakan SQLite; yang dikerjakan di sini adalah
            // memastikan yang sampai ke layar bukan `SqliteException(1)`.
            Error.throwWithStackTrace(
              MigrasiDatabaseGagalException(dari: from, ke: to, penyebab: e),
              s,
            );
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // M14 (PRD v1.1 §9.5): index grafik dibuat di sini, BUKAN lewat
          // kenaikan `schemaVersion` — lihat [_createSeriesIndexes].
          await _createSeriesIndexes();
        },
      );

  /// Index penunjang **grafik penjualan** (PRD v1.1 §9.5, M14).
  ///
  /// ```sql
  /// CREATE INDEX IF NOT EXISTS idx_sales_status_created ON sales(status, created_at)
  /// ```
  ///
  /// Query grafik selalu memfilter `status` **dan** rentang `created_at`
  /// sekaligus; dua index terpisah (`idx_sales_status` + `idx_sales_created_at`)
  /// memaksa SQLite memilih salah satu lalu menyaring sisanya baris demi
  /// baris.
  ///
  /// **Keputusan K-9.6 — dibuat di `beforeOpen`, `schemaVersion` TETAP 3.**
  /// PRD §10 menetapkan tahap "Tier 2c §9 Grafik" tidak menaikkan versi
  /// skema, dan plan M14 memintanya lewat "migrasi idempoten". Konsekuensi
  /// teknisnya: `onUpgrade` hanya berjalan saat `from < to`, sehingga
  /// database yang sudah berada di versi 3 (setiap pengguna yang memasang
  /// M13) TIDAK akan pernah menjalankannya — index-nya tidak akan pernah
  /// lahir. `beforeOpen` adalah satu-satunya jalur yang menjangkau
  /// database lama maupun baru tanpa menyentuh `user_version`, dan
  /// `CREATE INDEX IF NOT EXISTS` sudah idempoten sehingga pemanggilan di
  /// setiap pembukaan koneksi adalah no-op setelah yang pertama.
  ///
  /// Menaikkan `schemaVersion` demi index ini justru berbahaya: ia akan
  /// membuat backup v1.2 ditolak oleh aplikasi v1.1 (AC-10.2) padahal
  /// isinya identik — index bukan bagian dari bentuk data.
  Future<void> _createSeriesIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sales_status_created '
      'ON sales(status, created_at)',
    );
  }

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

  /// Migrasi 2 → 3 (PRD v1.1 §8.5): akun pengguna menjadi entitas nyata,
  /// dan setiap penjualan/pergerakan stok bisa menyebut **siapa**.
  ///
  /// Seluruhnya `CREATE TABLE` + `ADD COLUMN` + `CREATE INDEX` — di SQLite
  /// `ALTER TABLE ADD COLUMN` bersifat O(1) (tidak menulis ulang tabel),
  /// sehingga migrasi ini tetap ringan di database besar (PRD §8.7).
  ///
  /// **Backfill (AC-8.2):** PIN global lama (`settings.pin_hash`/`pin_salt`)
  /// disalin apa adanya menjadi PIN akun **"Pemilik"** yang pertama. Yang
  /// disalin adalah hash-nya, bukan PIN-nya — PIN teks polos memang tidak
  /// pernah ada di database (AC-8.14). Key lama sengaja **dibiarkan utuh**
  /// supaya mode single-user (multi-user mati) tetap berperilaku persis
  /// seperti v1.0, dan mematikan multi-user nanti bisa mulus (§8.5).
  ///
  /// `settings.multi_user_enabled` sengaja TIDAK diisi di sini: multi-user
  /// mati secara default (K-8.5, AC-8.1). Migrasi hanya menyiapkan akunnya,
  /// pemilik yang memutuskan kapan menyalakannya.
  Future<void> _upgradeToV3(Migrator m) async {
    await m.createTable(users);
    await m.addColumn(sales, sales.userId);
    await m.addColumn(sales, sales.userName);
    await m.addColumn(sales, sales.voidedByUserId);
    await m.addColumn(stockMovements, stockMovements.userId);
    await _createUserIndexes();

    // Idempoten: kalau entah bagaimana sudah ada akun, jangan menambah
    // "Pemilik" kedua yang membingungkan.
    final existing = await customSelect(
      'SELECT COUNT(*) AS c FROM users',
    ).getSingle();
    if (existing.read<int>('c') > 0) return;

    final rows = await customSelect(
      "SELECT key, value FROM settings WHERE key IN ('pin_hash', 'pin_salt')",
    ).get();
    final stored = {
      for (final row in rows) row.read<String>('key'): row.read<String>('value'),
    };
    final pinHash = stored['pin_hash'];
    if (pinHash == null || pinHash.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await into(users).insert(
      UsersCompanion.insert(
        name: 'Pemilik',
        role: 'owner',
        pinHash: pinHash,
        pinSalt: stored['pin_salt'] ?? '',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Index pengguna & jejak kasir (PRD v1.1 §8.5). Dipanggil dari
  /// `onCreate` MAUPUN migrasi 2 → 3 — semuanya `IF NOT EXISTS` supaya
  /// idempoten.
  ///
  /// `idx_users_name_nocase` sengaja **parsial** (hanya pengguna aktif):
  /// kasir yang sudah dinonaktifkan tidak boleh menghalangi pemilik
  /// memakai nama yang sama lagi untuk karyawan baru.
  Future<void> _createUserIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_name_nocase '
      'ON users(name COLLATE NOCASE) WHERE is_active = 1',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sales_user ON sales(user_id, created_at)',
    );
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
