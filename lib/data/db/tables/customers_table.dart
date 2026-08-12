import 'package:drift/drift.dart';

/// Pelanggan langganan warung (PRD v1.1 §7.5) — entitas nyata yang
/// menggantikan teks bebas `sales.customer_name` sebagai *identitas*.
///
/// Catatan penting (K-7.1): `sales.customer_name` TIDAK dihapus. Ia tetap
/// menjadi **snapshot historis** persis seperti `sale_items.product_name`,
/// sehingga mengganti nama pelanggan di sini tidak pernah mengubah struk
/// lama.
///
/// [points] adalah **cache saldo** — kebenarannya ada di buku besar
/// `customer_point_entries` (K-7.2). Keduanya WAJIB diperbarui dalam satu
/// `db.transaction()` yang sama, dan invariannya
/// (`points == SUM(entries.points)`) diuji otomatis (AC-7.11).
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get phone => text().nullable()();

  TextColumn get note => text().nullable()();

  /// Saldo poin tercache; sumber kebenarannya `customer_point_entries`.
  IntColumn get points => integer().withDefault(const Constant(0))();

  /// Pelanggan tidak pernah dihapus keras — hanya dinonaktifkan, supaya
  /// riwayat transaksinya tetap utuh.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Terisi bila pelanggan ini sudah DIGABUNG ke pelanggan lain (K-7.7):
  /// satu arah dan tidak bisa dibatalkan.
  IntColumn get mergedIntoId => integer().nullable()();

  /// Epoch millis UTC.
  IntColumn get createdAt => integer()();

  /// Epoch millis UTC.
  IntColumn get updatedAt => integer()();
}
