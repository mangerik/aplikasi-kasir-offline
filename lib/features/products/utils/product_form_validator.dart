/// Logika validasi form Produk & Kategori — Dart murni, tanpa dependency
/// Flutter/Drift, agar mudah di-unit-test (lihat
/// `test/features/products/product_form_validator_test.dart`).
///
/// Setiap method cocok dipakai langsung sebagai `validator` pada
/// `TextFormField` (signature `String? Function(String?)`) dan mengembalikan
/// pesan error Bahasa Indonesia, atau `null` bila valid.
abstract final class ProductFormValidator {
  /// Nama produk: wajib diisi.
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama produk wajib diisi';
    }
    return null;
  }

  /// Harga jual: wajib diisi, berupa angka bulat > 0.
  static String? sellPrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Harga jual wajib diisi';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Harga jual harus berupa angka';
    }
    if (parsed <= 0) {
      return 'Harga jual harus lebih dari 0';
    }
    return null;
  }

  /// Harga modal: opsional, tapi bila diisi harus angka bulat >= 0.
  static String? costPrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Harga modal harus berupa angka';
    }
    if (parsed < 0) {
      return 'Harga modal tidak boleh negatif';
    }
    return null;
  }

  /// Stok (awal atau saat ini): opsional (kosong = 0), boleh desimal
  /// (mendukung satuan kg/liter), tidak boleh negatif.
  static String? stock(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) {
      return 'Stok harus berupa angka';
    }
    if (parsed < 0) {
      return 'Stok tidak boleh negatif';
    }
    return null;
  }

  /// Satuan: wajib diisi (mis. pcs, kg, liter).
  static String? unit(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Satuan wajib diisi';
    }
    return null;
  }

  /// Threshold stok menipis: opsional (kosong = pakai default global),
  /// boleh desimal, tidak boleh negatif.
  static String? lowStockThreshold(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) {
      return 'Threshold harus berupa angka';
    }
    if (parsed < 0) {
      return 'Threshold tidak boleh negatif';
    }
    return null;
  }

  /// Nama kategori: wajib diisi (dipakai dialog CRUD kategori).
  static String? categoryName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama kategori wajib diisi';
    }
    return null;
  }
}
