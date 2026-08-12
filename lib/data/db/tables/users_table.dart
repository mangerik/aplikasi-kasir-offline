import 'package:drift/drift.dart';

/// Akun pengguna aplikasi (PRD v1.1 §8.5, `schemaVersion` 3).
///
/// Dua peran TETAP saja: `'owner'` (Pemilik) dan `'cashier'` (Kasir) —
/// izinnya tidak bisa dikustomisasi (K-8.1). Peran ketiga atau matriks
/// izin bebas sengaja TIDAK ada: layar konfigurasi rumit adalah kegagalan
/// untuk pengguna yang "gaptek ringan" (prd.md §2).
///
/// [pinHash]/[pinSalt] memakai `PinHasher` yang sudah ada (SHA-256 + salt),
/// dengan salt **per pengguna** (K-8.3) — bukan satu salt global. Dua kasir
/// yang kebetulan memilih PIN sama menghasilkan hash berbeda, dan keduanya
/// tetap bisa masuk ke akunnya sendiri karena nama dipilih lebih dulu
/// (K-8.2, AC-8.15).
///
/// Pengguna tidak pernah dihapus keras — hanya dinonaktifkan ([isActive]
/// `false`), supaya jejak `sales.user_id` miliknya tetap bisa ditelusuri
/// (AC-8.13), persis pola `customers`.
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  /// `'owner'` | `'cashier'`.
  TextColumn get role => text()();

  /// SHA-256 dari `salt:pin` — tidak pernah PIN teks polos (AC-8.14).
  TextColumn get pinHash => text()();

  /// Salt acak PER PENGGUNA (K-8.3).
  TextColumn get pinSalt => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Epoch millis UTC.
  IntColumn get createdAt => integer()();

  /// Epoch millis UTC.
  IntColumn get updatedAt => integer()();

  /// Epoch millis UTC — `null` bila belum pernah masuk sama sekali.
  IntColumn get lastLoginAt => integer().nullable()();
}
