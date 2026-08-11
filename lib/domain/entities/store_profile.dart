/// Profil toko (plan.md Milestone 5 poin 1) — disimpan sebagai tiga baris
/// `settings` (`store_name`, `store_address`, `store_phone`) dan otomatis
/// tampil di struk digital (`ReceiptWidget`/`ReceiptService`).
class StoreProfile {
  const StoreProfile({this.name, this.address, this.phone});

  final String? name;
  final String? address;
  final String? phone;

  /// Nama toko untuk ditampilkan — fallback `'KASIR WARUNG'` bila belum
  /// diisi pengguna (nilai default sebelum Milestone 5).
  String get displayName {
    final trimmed = name?.trim();
    return (trimmed == null || trimmed.isEmpty) ? 'KASIR WARUNG' : trimmed;
  }

  bool get hasAddress => address != null && address!.trim().isNotEmpty;

  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;

  StoreProfile copyWith({String? name, String? address, String? phone}) {
    return StoreProfile(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
    );
  }
}
