/// Exception domain untuk pelanggaran aturan bisnis di layer repository.
///
/// `toString()` masing-masing sudah berbahasa Indonesia dan siap ditampilkan
/// langsung ke pengguna (mis. lewat SnackBar), sesuai PRD §6 dan tugas
/// Milestone 1 poin 6 (validasi barcode unik) & poin 5 (validasi kategori
/// masih dipakai), serta Milestone 2 poin 6 (validasi simpan penjualan).
library;

import '../../core/utils/currency_formatter.dart';

/// Dilempar saat barcode yang diisi sudah dipakai produk lain (partial
/// unique index `idx_products_barcode_unique`, lihat app_database.dart).
class BarcodeSudahDipakaiException implements Exception {
  const BarcodeSudahDipakaiException(this.barcode);

  final String barcode;

  @override
  String toString() =>
      'Barcode "$barcode" sudah dipakai produk lain. Gunakan barcode yang '
      'berbeda atau kosongkan.';
}

/// Dilempar saat nama kategori yang diisi (tambah/ubah) sudah dipakai
/// kategori lain (`categories.name` bersifat UNIQUE).
class NamaKategoriSudahAdaException implements Exception {
  const NamaKategoriSudahAdaException(this.name);

  final String name;

  @override
  String toString() => 'Kategori "$name" sudah ada. Gunakan nama lain.';
}

/// Dilempar saat kategori yang ingin dihapus masih dipakai oleh produk.
class KategoriMasihDipakaiException implements Exception {
  const KategoriMasihDipakaiException(this.productCount);

  final int productCount;

  @override
  String toString() =>
      'Kategori tidak bisa dihapus karena masih dipakai oleh $productCount '
      'produk. Pindahkan atau hapus produk tersebut terlebih dahulu.';
}

/// Dilempar saat `SaveSaleUsecase` dipanggil dengan keranjang kosong
/// (plan.md Milestone 2 poin 6).
class KeranjangKosongException implements Exception {
  const KeranjangKosongException();

  @override
  String toString() => 'Keranjang masih kosong. Tambahkan barang terlebih dahulu.';
}

/// Dilempar saat uang tunai yang diterima kurang dari total belanja
/// (sheet pembayaran tunai, plan.md Milestone 2 poin 5).
class UangTidakCukupException implements Exception {
  const UangTidakCukupException({required this.total, required this.dibayar});

  final int total;
  final int dibayar;

  @override
  String toString() {
    final kurang = CurrencyFormatter.format(total - dibayar);
    return 'Uang diterima kurang $kurang dari total belanja.';
  }
}

/// Dilempar saat transaksi hutang tidak menyertakan nama pelanggan (wajib
/// — lihat architecture.md §4, kolom `sales.customer_name`).
class NamaPelangganWajibException implements Exception {
  const NamaPelangganWajibException();

  @override
  String toString() => 'Nama pelanggan wajib diisi untuk transaksi hutang.';
}

/// Dilempar saat `customerId` yang diminta tidak ada di database (PRD
/// v1.1 §7).
class PelangganTidakDitemukanException implements Exception {
  const PelangganTidakDitemukanException();

  @override
  String toString() => 'Pelanggan tidak ditemukan.';
}

/// Dilempar saat nama pelanggan yang diisi sudah dipakai pelanggan AKTIF
/// lain (index unik parsial `idx_customers_name_nocase`, PRD §7.5).
class NamaPelangganSudahAdaException implements Exception {
  const NamaPelangganSudahAdaException(this.name);

  final String name;

  @override
  String toString() =>
      'Pelanggan "$name" sudah ada. Pilih pelanggan yang sudah terdaftar '
      'atau pakai nama yang berbeda.';
}

/// Dilempar saat pelanggan yang masih punya hutang belum lunas hendak
/// dinonaktifkan (AC-7.13).
class PelangganMasihBerhutangException implements Exception {
  const PelangganMasihBerhutangException(this.totalDebt);

  final int totalDebt;

  @override
  String toString() =>
      'Pelanggan ini masih punya hutang ${CurrencyFormatter.format(totalDebt)} '
      'yang belum lunas. Lunasi atau batalkan transaksinya dulu sebelum '
      'dinonaktifkan.';
}

/// Dilempar saat poin yang hendak ditukar melebihi saldo pelanggan, atau
/// belum memenuhi minimum penukaran (PRD §7.3.C).
class PoinTidakCukupException implements Exception {
  const PoinTidakCukupException({required this.diminta, required this.tersedia});

  final int diminta;
  final int tersedia;

  @override
  String toString() =>
      'Poin tidak cukup: ingin menukar $diminta poin, saldo tersedia '
      '$tersedia poin.';
}

/// Dilempar saat penggabungan pelanggan diminta tanpa pelanggan sumber
/// yang sah (mis. hanya satu pelanggan dipilih, atau target ikut menjadi
/// sumber) — PRD §7.3.D.
class GabungPelangganTidakValidException implements Exception {
  const GabungPelangganTidakValidException(this.alasan);

  final String alasan;

  @override
  String toString() => 'Penggabungan pelanggan tidak bisa dilakukan: $alasan';
}

/// Dilempar saat `saleId` yang diminta (detail/pelunasan/void) tidak ada
/// di database (plan.md Milestone 3 poin 2 & 3).
class TransaksiTidakDitemukanException implements Exception {
  const TransaksiTidakDitemukanException();

  @override
  String toString() => 'Transaksi tidak ditemukan.';
}

/// Dilempar saat `MarkDebtPaidUsecase` dipanggil untuk transaksi yang
/// bukan hutang belum lunas (mis. sudah lunas, atau bukan transaksi
/// hutang sama sekali) — plan.md Milestone 3 poin 4.
class TransaksiBukanHutangException implements Exception {
  const TransaksiBukanHutangException();

  @override
  String toString() => 'Transaksi ini bukan hutang yang belum lunas.';
}

/// Dilempar saat `VoidSaleUsecase` dipanggil untuk transaksi yang sudah
/// pernah di-void sebelumnya (plan.md Milestone 3 poin 5).
class TransaksiSudahDibatalkanException implements Exception {
  const TransaksiSudahDibatalkanException();

  @override
  String toString() => 'Transaksi ini sudah dibatalkan sebelumnya.';
}

/// Dilempar saat PIN yang diisi (set/ubah) BUKAN 6 digit angka (plan.md
/// Milestone 5 poin 6).
class PinTidakValidException implements Exception {
  const PinTidakValidException();

  @override
  String toString() => 'PIN harus terdiri dari 6 digit angka.';
}

/// Dilempar saat PIN yang diketik (verifikasi/ubah/hapus) tidak cocok
/// dengan PIN yang tersimpan.
class PinSalahException implements Exception {
  const PinSalahException();

  @override
  String toString() => 'PIN yang dimasukkan salah.';
}

/// Dilempar saat `RemovePinUsecase`/`ChangePinUsecase` dipanggil padahal
/// belum ada PIN yang aktif tersimpan.
class PinBelumDiaturException implements Exception {
  const PinBelumDiaturException();

  @override
  String toString() => 'Kunci PIN belum diaktifkan.';
}

/// Dilempar saat file yang dipilih untuk restore BUKAN backup database
/// aplikasi yang valid (bukan file SQLite, atau tabel wajib tidak lengkap)
/// — plan.md Milestone 5 poin 5.
class FileBackupTidakValidException implements Exception {
  const FileBackupTidakValidException(this.alasan);

  final String alasan;

  @override
  String toString() => 'File backup tidak valid: $alasan';
}

/// Dilempar saat `AdjustStockUsecase`/`StockRepository.adjustStock`
/// dipanggil untuk `productId` yang tidak ada di database (plan.md
/// Milestone 4 poin 1).
class ProdukTidakDitemukanException implements Exception {
  const ProdukTidakDitemukanException();

  @override
  String toString() => 'Produk tidak ditemukan.';
}

/// Dilempar saat jumlah penyesuaian stok tidak valid: nol/negatif untuk
/// stok masuk & keluar, atau negatif untuk hasil opname (plan.md
/// Milestone 4 poin 1).
class JumlahPenyesuaianTidakValidException implements Exception {
  const JumlahPenyesuaianTidakValidException();

  @override
  String toString() => 'Jumlah penyesuaian stok tidak valid.';
}

/// Dilempar saat penyesuaian stok manual tidak menyertakan alasan/catatan
/// (wajib — lihat architecture.md §4 `stock_movements.note`, PRD §3.1.B
/// "dengan catatan alasan").
class AlasanPenyesuaianWajibException implements Exception {
  const AlasanPenyesuaianWajibException();

  @override
  String toString() => 'Alasan penyesuaian stok wajib diisi.';
}

/// Dilempar saat nama pengguna yang diisi kosong (PRD v1.1 §8).
class NamaPenggunaWajibException implements Exception {
  const NamaPenggunaWajibException();

  @override
  String toString() => 'Nama pengguna wajib diisi.';
}

/// Dilempar saat nama pengguna sudah dipakai akun AKTIF lain
/// (perbandingan case-insensitive, index `idx_users_name_nocase` §8.5).
/// Nama harus unik justru karena layar Masuk memilih NAMA lebih dulu
/// (K-8.2) — dua "Ani" di daftar adalah pilihan yang mustahil dibedakan.
class NamaPenggunaSudahAdaException implements Exception {
  const NamaPenggunaSudahAdaException(this.name);

  final String name;

  @override
  String toString() => 'Sudah ada pengguna bernama "$name".';
}

/// Dilempar saat akun yang dirujuk tidak ada di database (PRD v1.1 §8).
class PenggunaTidakDitemukanException implements Exception {
  const PenggunaTidakDitemukanException();

  @override
  String toString() => 'Pengguna tidak ditemukan.';
}

/// Dilempar saat akun **Pemilik aktif terakhir** hendak dinonaktifkan atau
/// diturunkan perannya. Kalau ini diizinkan, tidak ada satu orang pun yang
/// bisa membuka Pengaturan lagi — aplikasi terkunci dari pemiliknya sendiri
/// (risiko utama §8.7).
class PemilikTerakhirException implements Exception {
  const PemilikTerakhirException();

  @override
  String toString() =>
      'Harus ada minimal satu Pemilik aktif. Jadikan pengguna lain '
      'Pemilik dulu sebelum menonaktifkan yang ini.';
}

/// Dilempar saat kode pemulihan yang dimasukkan tidak cocok (PRD v1.1
/// §8.3.E).
class KodePemulihanSalahException implements Exception {
  const KodePemulihanSalahException();

  @override
  String toString() => 'Kode pemulihan tidak cocok.';
}

/// Dilempar saat aksi yang hanya boleh dilakukan Pemilik dicoba oleh Kasir
/// (PRD v1.1 §8.3.C). Penjagaan sesungguhnya ada di `redirect` router &
/// repository; exception ini adalah jaring terakhir di lapisan domain.
class AksesDitolakException implements Exception {
  const AksesDitolakException();

  @override
  String toString() =>
      'Fitur ini hanya untuk Pemilik. Minta Pemilik untuk masuk.';
}
