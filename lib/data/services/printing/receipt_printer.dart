import '../../../domain/entities/printer_settings.dart';

/// Jenis kegagalan pencetakan yang **berbeda tindak lanjutnya** bagi
/// pengguna.
///
/// Sengaja bukan sekadar string pesan: layar perlu tahu tombol aksi apa
/// yang harus ditawarkan. "Bluetooth mati" butuh tombol menuju Pengaturan
/// Bluetooth, "izin ditolak" butuh tombol menuju Pengaturan aplikasi, dan
/// "printer tidak terjangkau" cuma butuh "Coba Lagi". Menyamakan ketiganya
/// jadi satu SnackBar merah adalah cara paling cepat membuat kasir menyerah
/// (PRD v1.1 AC-3.5, AC-3.6, AC-3.10).
enum PrinterFailure {
  /// Belum ada printer default tersimpan.
  notConfigured,

  /// Izin `BLUETOOTH_CONNECT` belum/ditolak diberikan (Android 12+).
  permissionDenied,

  /// Bluetooth perangkat sedang mati.
  bluetoothOff,

  /// Printer mati, di luar jangkauan, atau menolak koneksi.
  unreachable,

  /// Koneksi terbentuk tapi pengiriman byte gagal/terputus di tengah.
  writeFailed,

  /// Masih ada job cetak yang berjalan (mutex, AC-3.7).
  busy,

  /// Platform belum didukung (iOS/desktop) — printer baru untuk Android.
  unsupportedPlatform,
}

/// Kegagalan cetak yang **sudah berbahasa Indonesia dan siap ditampilkan**.
///
/// Pesannya dibaca lewat [message], bukan lewat `AppErrorMessage.from`:
/// helper itu memakai daftar putih exception domain (`core/utils/
/// error_message.dart`) dan `PrinterException` sengaja TIDAK didaftarkan di
/// sana, karena mendaftarkannya berarti `core/` harus mengimpor `data/` —
/// arah dependensi yang dilarang architecture.md §3. Konsekuensinya
/// mengikat: **setiap** pemanggil wajib menangkap `PrinterException` secara
/// eksplisit (lihat `PrintJobController` dan `PrinterDeviceSheet`); yang
/// lupa akan mendapat pesan generik, bukan pesan yang berguna.
///
/// `toString()` tetap mengembalikan [message] sebagai jaring pengaman
/// terakhir bila pesan ini toh bocor ke jalur error umum.
class PrinterException implements Exception {
  const PrinterException(this.failure, this.message);

  const PrinterException.notConfigured()
    : failure = PrinterFailure.notConfigured,
      message = 'Belum ada printer terpasang. Hubungkan printer dulu di Pengaturan.';

  const PrinterException.permissionDenied()
    : failure = PrinterFailure.permissionDenied,
      message =
          'Aplikasi belum diizinkan memakai Bluetooth. Beri izin Bluetooth '
          'lewat Pengaturan aplikasi, lalu coba cetak lagi.';

  const PrinterException.bluetoothOff()
    : failure = PrinterFailure.bluetoothOff,
      message = 'Bluetooth mati. Nyalakan dulu untuk mencetak.';

  const PrinterException.unreachable()
    : failure = PrinterFailure.unreachable,
      message =
          'Printer tidak terjangkau. Pastikan printer menyala, kertasnya '
          'ada, dan jaraknya dekat.';

  const PrinterException.writeFailed()
    : failure = PrinterFailure.writeFailed,
      message = 'Struk gagal terkirim ke printer. Coba cetak lagi.';

  const PrinterException.busy()
    : failure = PrinterFailure.busy,
      message = 'Masih ada struk yang sedang dicetak. Tunggu sebentar.';

  const PrinterException.unsupportedPlatform()
    : failure = PrinterFailure.unsupportedPlatform,
      message = 'Cetak struk baru tersedia di Android.';

  final PrinterFailure failure;
  final String message;

  @override
  String toString() => message;
}

/// Kontrak transport printer struk (K-3.1).
///
/// **Alasan abstraksi ini ada.** Package Bluetooth adalah bagian paling
/// rapuh dari fitur ini: ia bisa ditinggalkan pemeliharanya, dan printer di
/// lapangan bisa ternyata BLE-only sehingga transportnya harus diganti
/// (PRD §3.7.2). Byte ESC/POS-nya sendiri tidak akan berubah sama sekali.
/// Karena itu `features/` **tidak pernah** mengimpor package Bluetooth
/// langsung — ia hanya kenal antarmuka ini, dan mengganti transport berarti
/// mengganti satu file implementasi.
abstract class ReceiptPrinter {
  /// `true` bila izin Bluetooth sudah diberikan.
  Future<bool> hasPermission();

  /// `true` bila radio Bluetooth perangkat sedang menyala.
  Future<bool> isBluetoothOn();

  /// Daftar printer yang **sudah dipasangkan** di Pengaturan Bluetooth
  /// Android. Aplikasi tidak pernah memindai sendiri (K-3.9).
  Future<List<BondedPrinter>> bondedPrinters();

  /// Kirim [bytes] ke printer di [address], sebanyak [copies] salinan.
  ///
  /// Melempar [PrinterException] untuk SEMUA mode kegagalan — pemanggil
  /// tidak pernah menerima exception mentah dari package.
  ///
  /// Wajib dijalankan **di luar** transaksi database (K-3.4): kegagalan
  /// printer tidak boleh pernah membatalkan atau menunda penyimpanan
  /// penjualan.
  Future<void> printBytes(List<int> bytes, {required String address, int copies = 1});

  /// Putuskan koneksi bila masih terbuka. Aman dipanggil kapan saja.
  Future<void> disconnect();

  /// `true` bila ada job cetak sedang berjalan — dipakai UI untuk
  /// menonaktifkan tombol (AC-3.7).
  bool get isBusy;
}
