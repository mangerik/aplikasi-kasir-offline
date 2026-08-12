/// Bitmap 1-bit siap dicetak sebagai raster ESC/POS.
///
/// Murni Dart (K-3.2): pemilik data cuma tahu piksel hitam/putih dan
/// ukurannya. Pembacaan file gambar — yang butuh platform — terjadi di luar
/// kelas ini (`logo_raster_loader.dart`), sehingga encoder byte di bawah
/// bisa diuji unit sampai byte terakhir tanpa perangkat.
class EscPosRaster {
  EscPosRaster({required this.width, required this.height, required this.black})
    : assert(width > 0 && height > 0, 'raster tidak boleh kosong'),
      assert(black.length == width * height, 'jumlah piksel tidak cocok');

  final int width;
  final int height;

  /// `true` = piksel dicetak (hitam). Baris demi baris, kiri ke kanan.
  final List<bool> black;

  /// Byte perintah **`GS v 0`** (`GS v 0 m xL xH yL yH d…`).
  ///
  /// Perintah ini sengaja dipilih dan bukan `GS ( L` (grafik modern) atau
  /// `ESC *`: `GS v 0` adalah perintah raster paling tua dan justru karena
  /// itu paling luas didukung klon printer murah yang jadi target aplikasi
  /// ini (PRD §3.7.1 "Logo"). Mode `m = 0` (normal, tanpa penggandaan).
  ///
  /// Setiap baris dikemas jadi byte 8 piksel, MSB di kiri; sisa piksel di
  /// ujung kanan diisi 0 (putih).
  List<int> toGSv0Bytes() {
    final bytesPerRow = (width + 7) ~/ 8;
    final bytes = <int>[
      0x1D, 0x76, 0x30, 0x00, // GS v 0, m = 0
      bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF, // xL xH
      height & 0xFF, (height >> 8) & 0xFF, // yL yH
    ];
    for (var y = 0; y < height; y++) {
      for (var xByte = 0; xByte < bytesPerRow; xByte++) {
        var packed = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = xByte * 8 + bit;
          if (x >= width) break;
          if (black[y * width + x]) packed |= 0x80 >> bit;
        }
        bytes.add(packed);
      }
    }
    return bytes;
  }

  /// Bangun raster dari piksel RGBA (4 byte per piksel, urutan baris).
  ///
  /// [threshold] adalah ambang luminansi 0–255: lebih gelap dari itu →
  /// dicetak hitam. Piksel transparan dianggap putih supaya logo PNG
  /// beralas transparan tidak keluar sebagai kotak hitam pekat — kesalahan
  /// klasik yang menghabiskan setengah gulungan kertas.
  factory EscPosRaster.fromRgba(
    List<int> rgba, {
    required int width,
    required int height,
    int threshold = 128,
  }) {
    final black = List<bool>.filled(width * height, false);
    for (var i = 0; i < width * height; i++) {
      final o = i * 4;
      if (o + 3 >= rgba.length) break;
      final alpha = rgba[o + 3];
      if (alpha < 128) continue; // transparan → putih
      final luminance = (0.299 * rgba[o] + 0.587 * rgba[o + 1] + 0.114 * rgba[o + 2]);
      black[i] = luminance < threshold;
    }
    return EscPosRaster(width: width, height: height, black: black);
  }
}
