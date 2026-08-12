/// Peran pengguna — **hanya dua, tetap, tidak bisa dikustomisasi** (K-8.1).
///
/// Matriks izinnya (PRD v1.1 §8.3.C) diwujudkan sebagai getter di
/// [UserRoleAccess] di bawah, bukan sebagai data yang bisa diedit: layar
/// konfigurasi izin bebas adalah kerumitan yang tidak dibutuhkan pemilik
/// warung, dan setiap izin yang bisa diubah adalah izin yang bisa salah
/// diatur.
enum UserRole {
  owner('owner', 'Pemilik'),
  cashier('cashier', 'Kasir');

  const UserRole(this.dbValue, this.label);

  /// Nilai yang tersimpan di kolom `users.role`.
  final String dbValue;

  /// Label Bahasa Indonesia siap tampil.
  final String label;

  /// Baca dari database. Nilai asing diperlakukan sebagai [cashier] —
  /// peran paling TERBATAS, supaya baris yang rusak/asing tidak pernah
  /// menjadi celah izin.
  static UserRole fromDb(String? raw) =>
      raw == owner.dbValue ? owner : cashier;
}

/// Izin per peran (PRD v1.1 §8.3.C).
///
/// Dipakai DUA lapis sekaligus: `redirect` go_router (supaya rute tidak
/// bisa ditembus lewat deep link, AC-8.4) dan UI (supaya elemennya memang
/// tidak dirender, AC-8.5). Satu sumber kebenaran untuk keduanya.
extension UserRoleAccess on UserRole {
  bool get isOwner => this == UserRole.owner;

  /// Laporan & grafik.
  bool get canViewReports => isOwner;

  /// Melihat laba kotor & harga modal. Elemennya **disembunyikan
  /// sepenuhnya** untuk Kasir, bukan diburamkan (AC-8.5).
  bool get canSeeProfit => isOwner;

  /// Membatalkan (void) transaksi (AC-8.6).
  bool get canVoidSale => isOwner;

  /// Menambah/mengubah produk, harga, dan kategori.
  bool get canManageProducts => isOwner;

  /// Export Excel, backup, restore.
  bool get canManageData => isOwner;

  /// Mengubah pengaturan toko/printer/poin & mengelola pengguna. Tema
  /// tetap boleh diubah siapa pun (§8.3.C "kecuali tema").
  bool get canManageSettings => isOwner;

  /// Riwayat transaksi: Pemilik semua, Kasir **hanya hari ini**.
  bool get canSeeAllHistory => isOwner;

  /// Penyesuaian stok boleh dilakukan keduanya — tercatat atas namanya
  /// (AC-8.8).
  bool get canAdjustStock => true;

  /// Menjual, menahan keranjang, hutang & pelunasan, cetak struk.
  bool get canSell => true;
}

/// Satu akun pengguna aplikasi (PRD v1.1 §8).
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  final int id;
  final String name;
  final UserRole role;

  /// Pengguna tidak pernah dihapus keras — hanya dinonaktifkan, supaya
  /// jejaknya di transaksi lama tetap utuh (AC-8.13).
  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  bool get isOwner => role.isOwner;

  /// Inisial untuk avatar kartu pengguna (maksimal dua huruf) —
  /// "Bu Ani" → "BA", "Pemilik" → "P".
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return _firstLetter(parts.first).toUpperCase();
    return '${_firstLetter(parts[0])}${_firstLetter(parts[1])}'.toUpperCase();
  }

  static String _firstLetter(String word) =>
      word.isEmpty ? '' : word.substring(0, 1);

  /// Nama pendek untuk chip di AppBar layar Kasir — kata pertama saja,
  /// supaya penanda pengguna tidak pernah menyaingi CTA "Bayar" (§8.6).
  String get shortName {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return name;
    if (parts.length == 1) return parts.first;
    return '${parts[0]} ${_firstLetter(parts[1]).toUpperCase()}.';
  }

  AppUser copyWith({String? name, UserRole? role, bool? isActive}) => AppUser(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastLoginAt: lastLoginAt,
      );
}
