import 'package:drift/drift.dart';

import '../../core/utils/date_formatter.dart';
import '../../core/utils/pin_hasher.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/repository_exceptions.dart';
import '../../domain/repositories/user_repository.dart';
import '../db/app_database.dart' as db;

/// Implementasi [UserRepository] di atas Drift/SQLite (PRD v1.1 §8.5).
///
/// PIN di-hash dengan [PinHasher] yang sudah ada (SHA-256 + salt), dengan
/// salt **dibangkitkan baru per pengguna** (K-8.3): dua kasir yang
/// kebetulan memilih PIN sama menghasilkan hash yang berbeda, sehingga
/// bocornya satu hash tidak memberi tahu apa pun tentang akun lain.
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._db);

  final db.AppDatabase _db;

  static final RegExp _pinPattern = RegExp(r'^\d{6}$');

  @override
  Future<List<AppUser>> listUsers({bool includeInactive = false}) async {
    final statement = _db.select(_db.users);
    if (!includeInactive) {
      statement.where((u) => u.isActive.equals(true));
    }
    // Pemilik lebih dulu (dia yang paling sering menyiapkan warung pagi
    // hari), lalu urut nama supaya posisi kartu di layar Masuk TETAP —
    // otot jari kasir mengingat posisi, bukan tulisan.
    statement.orderBy([
      (u) => OrderingTerm(expression: u.role, mode: OrderingMode.asc),
      (u) => OrderingTerm(expression: u.name),
    ]);
    final rows = await statement.get();
    return rows.map(_toUser).toList();
  }

  @override
  Future<AppUser?> findById(int id) async {
    final row = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toUser(row);
  }

  @override
  Future<AppUser?> firstOwner() async {
    final row = await (_db.select(_db.users)
          ..where((u) => u.isActive.equals(true) & u.role.equals(UserRole.owner.dbValue))
          ..orderBy([(u) => OrderingTerm(expression: u.id)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toUser(row);
  }

  @override
  Future<AppUser> createUser({
    required String name,
    required UserRole role,
    required String pin,
  }) async {
    final trimmed = _validateName(name);
    _validatePin(pin);
    await _ensureNameFree(trimmed, exceptUserId: null);

    final salt = PinHasher.generateSalt();
    return _insert(
      name: trimmed,
      role: role,
      pinHash: PinHasher.hash(pin, salt),
      pinSalt: salt,
    );
  }

  @override
  Future<AppUser> createOwnerFromExistingHash({
    required String name,
    required String pinHash,
    required String pinSalt,
  }) async {
    final trimmed = _validateName(name);
    await _ensureNameFree(trimmed, exceptUserId: null);
    return _insert(
      name: trimmed,
      role: UserRole.owner,
      pinHash: pinHash,
      pinSalt: pinSalt,
    );
  }

  Future<AppUser> _insert({
    required String name,
    required UserRole role,
    required String pinHash,
    required String pinSalt,
  }) async {
    final now = DateFormatter.toEpochMillis(DateTime.now());
    final id = await _db.into(_db.users).insert(
          db.UsersCompanion.insert(
            name: name,
            role: role.dbValue,
            pinHash: pinHash,
            pinSalt: pinSalt,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await findById(id))!;
  }

  @override
  Future<void> rename({required int userId, required String name}) async {
    final trimmed = _validateName(name);
    await _requireUser(userId);
    await _ensureNameFree(trimmed, exceptUserId: userId);
    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      db.UsersCompanion(
        name: Value(trimmed),
        updatedAt: Value(DateFormatter.toEpochMillis(DateTime.now())),
      ),
    );
    // Catatan sengaja: `sales.user_name` TIDAK ikut diubah — ia snapshot
    // historis (K-8.6, AC-8.7).
  }

  @override
  Future<void> setActive({required int userId, required bool isActive}) async {
    final user = await _requireUser(userId);
    if (!isActive && UserRole.fromDb(user.role).isOwner) {
      final owners = await _activeOwnerCount();
      if (owners <= 1) throw const PemilikTerakhirException();
    }
    if (isActive) {
      // Mengaktifkan kembali harus lolos uji nama unik yang sama: index
      // parsial hanya menjaga baris aktif, jadi bentroknya baru muncul di
      // sini.
      await _ensureNameFree(user.name, exceptUserId: userId);
    }
    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      db.UsersCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateFormatter.toEpochMillis(DateTime.now())),
      ),
    );
  }

  @override
  Future<void> setPin({required int userId, required String pin}) async {
    _validatePin(pin);
    await _requireUser(userId);
    final salt = PinHasher.generateSalt();
    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      db.UsersCompanion(
        pinHash: Value(PinHasher.hash(pin, salt)),
        pinSalt: Value(salt),
        updatedAt: Value(DateFormatter.toEpochMillis(DateTime.now())),
      ),
    );
  }

  @override
  Future<AppUser?> authenticate({required int userId, required String pin}) async {
    final row = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(userId))).getSingleOrNull();
    if (row == null || !row.isActive) return null;
    if (PinHasher.hash(pin, row.pinSalt) != row.pinHash) return null;

    final now = DateFormatter.toEpochMillis(DateTime.now());
    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      db.UsersCompanion(lastLoginAt: Value(now)),
    );
    return _toUser(row);
  }

  @override
  Future<StoredPin?> storedPin(int userId) async {
    final row = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(userId))).getSingleOrNull();
    return row == null ? null : StoredPin(hash: row.pinHash, salt: row.pinSalt);
  }

  @override
  Future<int> countActive() async {
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM users WHERE is_active = 1',
      readsFrom: {_db.users},
    ).getSingle();
    return row.read<int>('c');
  }

  @override
  Future<void> deactivateAllCashiers() async {
    await (_db.update(_db.users)
          ..where((u) => u.role.equals(UserRole.cashier.dbValue)))
        .write(
      db.UsersCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateFormatter.toEpochMillis(DateTime.now())),
      ),
    );
  }

  Future<int> _activeOwnerCount() async {
    final row = await _db.customSelect(
      "SELECT COUNT(*) AS c FROM users WHERE is_active = 1 AND role = 'owner'",
      readsFrom: {_db.users},
    ).getSingle();
    return row.read<int>('c');
  }

  Future<db.User> _requireUser(int userId) async {
    final row = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(userId))).getSingleOrNull();
    if (row == null) throw const PenggunaTidakDitemukanException();
    return row;
  }

  /// Nama harus unik di antara pengguna AKTIF, case-insensitive — sama
  /// dengan index parsial `idx_users_name_nocase` (§8.5). Diperiksa di
  /// sini juga supaya pengguna mendapat pesan Bahasa Indonesia, bukan
  /// "UNIQUE constraint failed".
  Future<void> _ensureNameFree(String name, {required int? exceptUserId}) async {
    final row = await _db.customSelect(
      'SELECT id FROM users WHERE is_active = 1 '
      'AND name = ?1 COLLATE NOCASE LIMIT 1',
      variables: [Variable.withString(name)],
      readsFrom: {_db.users},
    ).getSingleOrNull();
    if (row == null) return;
    if (exceptUserId != null && row.read<int>('id') == exceptUserId) return;
    throw NamaPenggunaSudahAdaException(name);
  }

  static String _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const NamaPenggunaWajibException();
    return trimmed;
  }

  static void _validatePin(String pin) {
    if (!_pinPattern.hasMatch(pin)) throw const PinTidakValidException();
  }

  AppUser _toUser(db.User row) => AppUser(
        id: row.id,
        name: row.name,
        role: UserRole.fromDb(row.role),
        isActive: row.isActive,
        createdAt: DateFormatter.fromEpochMillis(row.createdAt),
        updatedAt: DateFormatter.fromEpochMillis(row.updatedAt),
        lastLoginAt: row.lastLoginAt == null
            ? null
            : DateFormatter.fromEpochMillis(row.lastLoginAt!),
      );
}
