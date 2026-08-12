import 'dart:io';
import 'dart:ui' as ui;

import '../../../domain/entities/printer_settings.dart';
import '../../../domain/entities/sale_result.dart';
import '../../../domain/entities/store_profile.dart';
import 'esc_pos_raster.dart';
import 'esc_pos_receipt_builder.dart';
import 'receipt_printer.dart';

/// Perekat antara struk (byte) dan printer (transport).
///
/// Yang penting dari kelas ini bukan apa yang dilakukannya, melainkan
/// **kapan ia dipanggil**: SELALU setelah penjualan tersimpan dan SELALU di
/// luar `db.transaction()` (K-3.4, AC-3.6). Printer yang mati, kertas yang
/// habis, atau Bluetooth yang dimatikan pembeli iseng tidak boleh punya
/// satu pun jalur untuk membatalkan, mengubah, atau menunda transaksi yang
/// sudah masuk. Kegagalan cetak diselesaikan dengan "Cetak Ulang" manual
/// dari Riwayat — tanpa antrean cetak persisten yang bisa korup (K-3.5).
class ReceiptPrintService {
  const ReceiptPrintService(this._printer);

  final ReceiptPrinter _printer;

  ReceiptPrinter get printer => _printer;

  /// Cetak struk penjualan. Melempar [PrinterException] bila gagal.
  Future<void> printSale({
    required SaleResult sale,
    required StoreProfile profile,
    required PrinterSettings settings,
    bool reprint = false,
  }) async {
    if (!settings.isConfigured) throw const PrinterException.notConfigured();
    final builder = EscPosReceiptBuilder(paperWidth: settings.paperWidth);
    final bytes = builder.build(
      sale: sale,
      profile: profile,
      settings: settings,
      reprint: reprint,
      logoRaster: await _logoRaster(settings),
    );
    await _printer.printBytes(
      bytes,
      address: settings.address!,
      copies: settings.copies,
    );
  }

  /// Struk "Cetak Uji" dari Pengaturan — selalu satu salinan, karena
  /// tujuannya memastikan formatnya benar, bukan menghabiskan kertas.
  Future<void> printTest({
    required StoreProfile profile,
    required PrinterSettings settings,
  }) async {
    if (!settings.isConfigured) throw const PrinterException.notConfigured();
    final builder = EscPosReceiptBuilder(paperWidth: settings.paperWidth);
    final bytes = builder.buildTestReceipt(
      profile: profile,
      settings: settings,
      logoRaster: await _logoRaster(settings),
    );
    await _printer.printBytes(bytes, address: settings.address!);
  }

  /// Ubah file logo jadi byte raster `GS v 0`, atau `null` bila logo mati /
  /// filenya sudah tidak ada.
  ///
  /// Gagal memuat logo **tidak pernah** menggagalkan struk: struk tanpa
  /// logo masih struk yang sah, sedangkan struk yang tidak keluar sama
  /// sekali adalah pembeli yang menunggu di depan kasir.
  Future<List<int>?> _logoRaster(PrinterSettings settings) async {
    if (!settings.hasLogo) return null;
    try {
      final raster = await loadLogoRaster(
        settings.logoPath!,
        maxWidth: settings.paperWidth.dots,
      );
      return raster?.toGSv0Bytes();
    } catch (_) {
      return null;
    }
  }
}

/// Baca file gambar logo dan turunkan jadi bitmap 1-bit selebar maksimal
/// [maxWidth] dot.
///
/// Memakai codec bawaan Flutter (`dart:ui`) — **tanpa dependency gambar
/// tambahan**. Dua batas sengaja dipasang:
/// - lebar dipotong ke [maxWidth] (384 dot untuk 58mm) karena piksel di
///   luar area cetak tidak dibuang printer melainkan **menggulung ke baris
///   berikutnya** dan menghasilkan logo yang tercabik;
/// - tinggi dibatasi supaya logo salah pilih (mis. foto 4000px) tidak
///   memuntahkan setengah gulungan kertas.
Future<EscPosRaster?> loadLogoRaster(
  String path, {
  required int maxWidth,
  int maxHeight = 240,
}) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();

  var codec = await ui.instantiateImageCodec(bytes);
  var frame = await codec.getNextFrame();
  if (frame.image.width > maxWidth) {
    frame.image.dispose();
    codec.dispose();
    codec = await ui.instantiateImageCodec(bytes, targetWidth: maxWidth);
    frame = await codec.getNextFrame();
  }
  final image = frame.image;
  try {
    if (image.height > maxHeight) return null;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return EscPosRaster.fromRgba(
      data.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
  } finally {
    image.dispose();
    codec.dispose();
  }
}
