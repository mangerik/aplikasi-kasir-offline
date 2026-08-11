/// Kontrak repository Pengaturan (key-value), lihat architecture.md §4
/// tabel `settings` (`store_name`, `store_address`, `pin_hash`, dll).
///
/// Implementasi PENUH (profil toko, PIN set/ubah/hapus, backup/restore)
/// adalah scope Milestone 5 (plan.md). Milestone 3 HANYA memakai
/// [getValue] sebagai HOOK pengecekan status PIN sebelum void transaksi
/// (plan.md Milestone 3 poin 5: "dan PIN bila fitur PIN aktif — PIN baru
/// dibuat di M5, jadi cukup siapkan hook/cek settingnya").
abstract class SettingsRepository {
  /// Mengambil nilai pengaturan berdasarkan [key]. `null` bila belum
  /// pernah diisi.
  Future<String?> getValue(String key);
}
