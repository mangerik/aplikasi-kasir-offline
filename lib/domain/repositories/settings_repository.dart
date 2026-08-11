/// Kontrak repository Pengaturan (key-value), lihat architecture.md §4
/// tabel `settings` (`store_name`, `store_address`, `pin_hash`, dll).
///
/// [getValue] sudah ada sejak Milestone 3 (hook PIN sebelum void). Method
/// tulis ([setValue]/[deleteValue]) ditambah di Milestone 5 untuk layar
/// Pengaturan penuh: profil toko, threshold stok menipis default, kunci
/// PIN, dan timestamp backup terakhir (plan.md Milestone 5).
abstract class SettingsRepository {
  /// Mengambil nilai pengaturan berdasarkan [key]. `null` bila belum
  /// pernah diisi.
  Future<String?> getValue(String key);

  /// Menyimpan/menimpa nilai pengaturan untuk [key] (upsert — insert bila
  /// belum ada, update bila sudah ada).
  Future<void> setValue(String key, String value);

  /// Menghapus pengaturan [key] (mis. saat PIN dihapus). Tidak error bila
  /// key belum pernah diisi.
  Future<void> deleteValue(String key);
}
