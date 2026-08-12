/// CRC-16/CCITT-FALSE (poly `0x1021`, init `0xFFFF`, tanpa refleksi).
///
/// **Kenapa masih ada CRC padahal sudah ada tanda tangan Ed25519?**
/// (K-6.7) Tanda tangan hanya bisa menjawab "sah / tidak sah". Ia tidak bisa
/// membedakan pengguna yang salah mengetik satu karakter dari pengguna yang
/// memakai kode palsu — dan menuduh yang pertama sebagai yang kedua adalah
/// cara tercepat kehilangan pembeli yang sudah membayar. CRC menutup celah
/// itu: kode yang rusak karena salah ketik hampir pasti gagal di CRC lebih
/// dulu, sehingga aplikasi bisa berkata *"Kode belum lengkap atau ada yang
/// salah ketik"* alih-alih *"kode tidak sah"*.
abstract final class Crc16 {
  /// Hitung CRC-16 atas [bytes].
  static int compute(List<int> bytes) {
    var crc = 0xFFFF;
    for (final byte in bytes) {
      crc ^= (byte & 0xFF) << 8;
      for (var bit = 0; bit < 8; bit++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc & 0xFFFF;
  }
}
