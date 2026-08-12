import '../entities/customer.dart';
import '../entities/customer_point_entry.dart';
import '../entities/sale.dart';

/// Kontrak repository Pelanggan & Program Poin (PRD v1.1 §7, plan-v1.1.md
/// Milestone 12).
///
/// Implementasi (Drift) ada di
/// `data/repositories/customer_repository_impl.dart`. Aturan yang mengikat
/// implementasi:
///
/// 1. **Buku besar adalah sumber kebenaran** (K-7.2). Setiap perubahan
///    saldo WAJIB menulis satu baris `customer_point_entries` dan
///    memperbarui cache `customers.points` DI DALAM `db.transaction()`
///    yang sama (AC-7.11).
/// 2. **Agregasi lewat SQL**, bukan memuat baris ke Dart (AC-7.14,
///    AC-7.15) — pola sama dengan `ReportRepository`.
/// 3. `sales.customer_name` **tidak pernah** disentuh oleh method mana pun
///    di sini; ia snapshot historis (K-7.1, AC-7.3).
abstract class CustomerRepository {
  /// Daftar/pencarian pelanggan, terpaginasi.
  ///
  /// [query] cocokkan nama & no. HP secara case-insensitive (kosong =
  /// semua). [onlyWithDebt] menyaring hanya yang masih punya hutang
  /// (menggantikan layar daftar hutang terpisah, PRD §7.6).
  /// [includeInactive] memasukkan pelanggan nonaktif/hasil gabung.
  Future<List<CustomerListItem>> search({
    String query = '',
    bool onlyWithDebt = false,
    bool includeInactive = false,
    int limit = 50,
    int offset = 0,
  });

  /// Satu pelanggan menurut [id]. Melempar
  /// `PelangganTidakDitemukanException` bila tidak ada.
  Future<Customer> getById(int id);

  /// Membuat pelanggan baru. Melempar `NamaPelangganSudahAdaException`
  /// bila nama itu sudah dipakai pelanggan AKTIF lain (index unik parsial
  /// `idx_customers_name_nocase`).
  Future<Customer> create({required String name, String? phone, String? note});

  /// Mengubah data pelanggan. Nama boleh diganti — `sales.customer_name`
  /// transaksi lama TIDAK ikut berubah (AC-7.3).
  Future<Customer> update(
    int id, {
    required String name,
    String? phone,
    String? note,
  });

  /// Menonaktifkan pelanggan. Melempar
  /// `PelangganMasihBerhutangException` bila masih ada transaksi
  /// `debt_unpaid` (AC-7.13).
  Future<void> deactivate(int id);

  /// Mengaktifkan kembali pelanggan yang dinonaktifkan.
  Future<void> reactivate(int id);

  /// Ringkasan pelanggan (total belanja, jumlah transaksi, sisa hutang,
  /// saldo poin) — seluruhnya agregasi SQL.
  Future<CustomerSummary> getSummary(int customerId);

  /// Riwayat belanja pelanggan, terbaru dulu, TERPAGINASI (AC-7.15).
  Future<List<Sale>> getSales(
    int customerId, {
    required int limit,
    required int offset,
  });

  /// Riwayat poin pelanggan, terbaru dulu, terpaginasi.
  Future<List<CustomerPointEntry>> getPointEntries(
    int customerId, {
    required int limit,
    required int offset,
  });

  /// Pratinjau dampak penggabungan [ids] (PRD §7.3.D).
  Future<CustomerMergePreview> previewMerge(List<int> ids);

  /// Menggabungkan [sourceIds] ke dalam [targetId] dalam SATU transaksi
  /// DB: `sales.customer_id` dialihkan, entri buku besar dialihkan, saldo
  /// dijumlahkan, sumber ditandai nonaktif + `merged_into_id` (K-7.7,
  /// AC-7.12). Satu arah, tidak bisa dibatalkan.
  Future<void> merge({required int targetId, required List<int> sourceIds});

  /// Aksi pemeliharaan: menghitung ulang `customers.points` dari buku
  /// besar dan menuliskan entri `adjust` untuk setiap selisih yang
  /// ditemukan. Mengembalikan jumlah pelanggan yang saldonya dikoreksi.
  Future<int> recalculatePointsFromLedger();

  /// Baris "Pelanggan & Poin" untuk export Excel (AC-7.16) — seluruh
  /// pelanggan (aktif & nonaktif), diurut nama.
  Future<List<CustomerListItem>> getAllForExport();

  /// Total belanja sepanjang waktu per pelanggan (`customerId` -> rupiah),
  /// transaksi `voided` dikecualikan. Satu query `GROUP BY` untuk seluruh
  /// pelanggan sekaligus — dipakai export Excel (AC-7.16) supaya tidak
  /// perlu satu query per baris.
  Future<Map<int, int>> getTotalSpentByCustomer();
}
