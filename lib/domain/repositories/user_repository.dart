import '../entities/app_user.dart';

/// Pasangan hash+salt PIN yang tersimpan untuk satu akun.
///
/// Satu-satunya alasan ini boleh keluar dari repository: saat multi-user
/// DIMATIKAN, PIN akun Pemilik harus kembali menjadi PIN global v1.0
/// (`settings.pin_hash`/`pin_salt`) supaya perilaku v1.0 pulih persis
/// (§8.3.A). Yang berpindah tetap hash-nya, bukan PIN-nya.
class StoredPin {
  const StoredPin({required this.hash, required this.salt});

  final String hash;
  final String salt;
}

/// Kontrak repository Pengguna (PRD v1.1 §8).
///
/// Implementasi (Drift) ada di `data/repositories/user_repository_impl.dart`.
/// SELURUH penanganan PIN terjadi di sini: layar tidak pernah melihat hash
/// maupun salt, dan PIN teks polos tidak pernah keluar dari method ini
/// (AC-8.14).
abstract class UserRepository {
  /// Daftar pengguna. Default hanya yang **aktif** — itulah yang dipakai
  /// layar Masuk; manajemen pengguna memakai `includeInactive: true`.
  Future<List<AppUser>> listUsers({bool includeInactive = false});

  Future<AppUser?> findById(int id);

  /// Akun Pemilik aktif pertama (dipakai tombol "Masuk sebagai Pemilik"
  /// pada layar penolakan akses).
  Future<AppUser?> firstOwner();

  /// Membuat akun baru. Melempar `PinTidakValidException` bila [pin] bukan
  /// 6 digit angka, `NamaPenggunaWajibException` bila nama kosong, atau
  /// `NamaPenggunaSudahAdaException` bila nama itu sudah dipakai pengguna
  /// AKTIF lain (perbandingan case-insensitive, index parsial §8.5).
  Future<AppUser> createUser({
    required String name,
    required UserRole role,
    required String pin,
  });

  /// Membuat akun Pemilik dari hash PIN yang SUDAH ada (PIN global v1.0)
  /// — dipakai alur "aktifkan multi-user" bila kunci PIN lama masih
  /// terpasang, supaya pemilik tidak perlu membuat PIN baru (AC-8.2).
  Future<AppUser> createOwnerFromExistingHash({
    required String name,
    required String pinHash,
    required String pinSalt,
  });

  Future<void> rename({required int userId, required String name});

  /// Menonaktifkan/mengaktifkan kembali akun. Pemilik AKTIF terakhir tidak
  /// boleh dinonaktifkan (`PemilikTerakhirException`) — kalau boleh,
  /// aplikasinya terkunci selamanya tanpa siapa pun yang bisa membukanya.
  Future<void> setActive({required int userId, required bool isActive});

  /// Mengganti PIN pengguna (reset oleh Pemilik, atau pemulihan lewat kode).
  Future<void> setPin({required int userId, required String pin});

  /// Memverifikasi PIN [userId]. Mengembalikan akunnya bila cocok (dan
  /// memperbarui `last_login_at`), `null` bila salah. Akun nonaktif SELALU
  /// ditolak.
  Future<AppUser?> authenticate({required int userId, required String pin});

  /// Hash+salt PIN akun [userId] — lihat [StoredPin] untuk alasan
  /// keberadaannya. `null` bila akunnya tidak ada.
  Future<StoredPin?> storedPin(int userId);

  /// Jumlah akun aktif — dipakai memutuskan apakah alur aktivasi
  /// multi-user masih perlu membuat akun Pemilik.
  Future<int> countActive();

  /// Menonaktifkan seluruh akun Kasir (dipakai saat multi-user dimatikan,
  /// §8.3.A). Akun Pemilik dibiarkan, dan `sales.user_id` historis TIDAK
  /// pernah disentuh (AC-8.13).
  Future<void> deactivateAllCashiers();
}
