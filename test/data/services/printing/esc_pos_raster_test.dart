import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/services/printing/esc_pos_raster.dart';

/// Logo dicetak lewat `GS v 0` (K-3.8) — perintah raster paling tua, dan
/// justru karena itu paling luas didukung klon printer murah.
void main() {
  group('EscPosRaster.toGSv0Bytes', () {
    test('header GS v 0 memuat lebar dalam BYTE dan tinggi dalam BARIS', () {
      final raster = EscPosRaster(
        width: 16,
        height: 2,
        black: List<bool>.filled(32, false),
      );
      final bytes = raster.toGSv0Bytes();
      expect(bytes.sublist(0, 8), <int>[
        0x1D, 0x76, 0x30, 0x00, // GS v 0, m = 0 (normal)
        0x02, 0x00, // xL xH — 16 piksel = 2 byte per baris
        0x02, 0x00, // yL yH — 2 baris
      ]);
      expect(bytes.length, 8 + 2 * 2);
    });

    test('lebar yang bukan kelipatan 8 dibulatkan ke atas & sisanya putih', () {
      final raster = EscPosRaster(
        width: 9,
        height: 1,
        black: List<bool>.generate(9, (i) => i == 8), // hanya piksel ke-9 hitam
      );
      final bytes = raster.toGSv0Bytes();
      expect(bytes[4], 2); // 9 piksel butuh 2 byte
      expect(bytes.sublist(8), <int>[0x00, 0x80]); // MSB byte kedua
    });

    test('piksel dikemas MSB di kiri', () {
      final raster = EscPosRaster(
        width: 8,
        height: 1,
        black: <bool>[true, false, true, false, false, false, false, true],
      );
      expect(raster.toGSv0Bytes().last, 0xA1); // 1010 0001
    });
  });

  group('EscPosRaster.fromRgba', () {
    test('piksel gelap jadi hitam, terang jadi putih', () {
      final rgba = <int>[
        0, 0, 0, 255, // hitam pekat
        255, 255, 255, 255, // putih
      ];
      final raster = EscPosRaster.fromRgba(rgba, width: 2, height: 1);
      expect(raster.black, <bool>[true, false]);
    });

    test('piksel TRANSPARAN dianggap putih, bukan hitam', () {
      // Jebakan klasik: logo PNG beralas transparan yang keluar sebagai
      // kotak hitam pekat dan menghabiskan setengah gulungan kertas.
      final rgba = <int>[0, 0, 0, 0, 0, 0, 0, 255];
      final raster = EscPosRaster.fromRgba(rgba, width: 2, height: 1);
      expect(raster.black, <bool>[false, true]);
    });

    test('ambang luminansi bisa digeser', () {
      final rgba = <int>[160, 160, 160, 255];
      expect(
        EscPosRaster.fromRgba(rgba, width: 1, height: 1, threshold: 128).black,
        <bool>[false],
      );
      expect(
        EscPosRaster.fromRgba(rgba, width: 1, height: 1, threshold: 200).black,
        <bool>[true],
      );
    });
  });
}
