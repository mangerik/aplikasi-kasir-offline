/// Pelanggan langganan warung (PRD v1.1 §7) — entitas domain untuk tabel
/// `customers`.
///
/// [points] adalah saldo tercache; sumber kebenarannya buku besar
/// `customer_point_entries` (K-7.2). Lihat
/// `CustomerRepository.recalculatePointsFromLedger` untuk aksi
/// pemeliharaan yang menyelaraskan keduanya.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.note,
    required this.points,
    required this.isActive,
    this.mergedIntoId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String? phone;
  final String? note;

  /// Saldo poin (bilangan bulat, K-7.3).
  final int points;

  /// `false` bila dinonaktifkan ATAU sudah digabung ke pelanggan lain.
  final bool isActive;

  /// Terisi bila pelanggan ini sudah digabung ke pelanggan lain (K-7.7).
  final int? mergedIntoId;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isMerged => mergedIntoId != null;

  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;
}

/// Satu baris pada daftar/pemilih pelanggan — nama + tiga angka yang paling
/// dicari pemilik warung (PRD §7.3.A): sisa hutang, saldo poin, dan kapan
/// terakhir belanja. Dihitung lewat agregasi SQL, bukan dimuat per baris.
class CustomerListItem {
  const CustomerListItem({
    required this.id,
    required this.name,
    this.phone,
    required this.points,
    required this.totalDebt,
    required this.debtTransactionCount,
    this.lastTransactionAt,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? phone;
  final int points;

  /// Jumlah `sales.total` transaksi berstatus `debt_unpaid` pelanggan ini.
  final int totalDebt;

  final int debtTransactionCount;

  final DateTime? lastTransactionAt;

  final bool isActive;

  bool get hasDebt => totalDebt > 0;
}

/// Ringkasan satu pelanggan untuk kartu di layar detail (PRD §7.3.A).
class CustomerSummary {
  const CustomerSummary({
    required this.totalSpent,
    required this.transactionCount,
    required this.totalDebt,
    required this.debtTransactionCount,
    required this.points,
    this.lastTransactionAt,
  });

  /// Total belanja sepanjang waktu — transaksi `voided` DIKECUALIKAN,
  /// konsisten dengan laporan (`ReportRepository.getSummary`).
  final int totalSpent;

  final int transactionCount;
  final int totalDebt;
  final int debtTransactionCount;
  final int points;
  final DateTime? lastTransactionAt;
}

/// Pratinjau dampak penggabungan pelanggan (PRD §7.3.D) — ditampilkan
/// SEBELUM konfirmasi karena aksinya satu arah & tidak bisa dibatalkan
/// (K-7.7).
class CustomerMergePreview {
  const CustomerMergePreview({
    required this.customerCount,
    required this.transactionCount,
    required this.totalPoints,
    required this.totalDebt,
  });

  final int customerCount;
  final int transactionCount;
  final int totalPoints;
  final int totalDebt;
}
