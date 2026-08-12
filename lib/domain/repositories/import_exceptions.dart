/// Exception domain khusus impor produk dari Excel (PRD v1.1 §4).
///
/// Sengaja TERPISAH dari `repository_exceptions.dart` supaya fitur impor
/// tidak menyentuh berkas milik bersama. `toString()` masing-masing sudah
/// berbahasa Indonesia dan siap ditampilkan apa adanya ke pengguna
/// (AC-4.14: "pesan Bahasa Indonesia yang jelas, aplikasi tidak crash").
library;

/// Induk seluruh kegagalan impor. `AppErrorMessage.from` cukup mengenali
/// tipe ini saja, bukan satu per satu turunannya.
abstract class ImporProdukException implements Exception {
  const ImporProdukException();
}

/// File tidak bisa dibaca sebagai `.xlsx`: rusak, sebenarnya bukan xlsx
/// (mis. `.xls` lama atau CSV yang diganti namanya), atau terkunci
/// password.
class FileImporTidakValidException extends ImporProdukException {
  const FileImporTidakValidException(this.alasan);

  final String alasan;

  @override
  String toString() => 'File impor tidak bisa dibaca: $alasan';
}

/// Kolom wajib (`Nama Produk` / `Harga Jual`) tidak ditemukan di baris
/// pertama. Impor ditolak SEBELUM satu baris pun diproses (AC-4.4).
class KolomWajibHilangException extends ImporProdukException {
  const KolomWajibHilangException(this.kolom);

  /// Nama kolom yang hilang, apa adanya seperti di template.
  final List<String> kolom;

  @override
  String toString() =>
      'Kolom wajib tidak ditemukan: ${kolom.join(', ')}. Perbaiki judul kolom '
      'di baris pertama file (huruf besar-kecil bebas, urutan bebas), lalu '
      'coba lagi.';
}

/// File melebihi batas 5.000 baris produk sekali impor (K-4.4, AC-4.13).
class FileImporTerlaluBesarException extends ImporProdukException {
  const FileImporTerlaluBesarException(this.jumlahBaris, this.batas);

  final int jumlahBaris;
  final int batas;

  @override
  String toString() =>
      'File berisi $jumlahBaris baris produk, melebihi batas $batas baris '
      'sekali impor. Pecah file menjadi beberapa bagian, lalu impor satu per '
      'satu.';
}

/// File terbaca tapi tidak berisi satu pun baris produk di bawah header.
class FileImporKosongException extends ImporProdukException {
  const FileImporKosongException();

  @override
  String toString() =>
      'File tidak berisi satu pun baris produk di bawah baris judul kolom. '
      'Isi dulu datanya di laptop, lalu simpan ulang sebagai .xlsx.';
}

/// Penjaga terakhir: baris bermasalah TIDAK BOLEH sampai ke transaksi
/// database. Dilempar dari dalam `db.transaction()` sehingga seluruh impor
/// dibatalkan utuh (K-4.5, AC-4.15).
class BarisImporTidakValidException extends ImporProdukException {
  const BarisImporTidakValidException(this.excelRow, this.alasan);

  final int excelRow;
  final String alasan;

  @override
  String toString() =>
      'Impor dibatalkan: baris $excelRow masih bermasalah ($alasan). Tidak ada '
      'satu pun produk yang tersimpan.';
}
