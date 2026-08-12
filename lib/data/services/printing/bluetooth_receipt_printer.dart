import 'dart:async';
import 'dart:io' show Platform;

import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../domain/entities/printer_settings.dart';
import 'receipt_printer.dart';

/// Implementasi [ReceiptPrinter] di atas **Bluetooth Klasik (SPP)** lewat
/// package `print_bluetooth_thermal` (PRD v1.1 §3.7.1).
///
/// Ini SATU-SATUNYA berkas di seluruh aplikasi yang boleh meng-import
/// package Bluetooth (K-3.1). Kalau package-nya kelak ditinggalkan atau
/// printer di lapangan ternyata BLE, berkas inilah — dan hanya berkas ini —
/// yang diganti; byte struknya tidak tersentuh.
///
/// Tiga hal yang dijaga ketat di sini:
/// 1. **Mutex satu job.** Dua job cetak yang tumpang tindih merusak stream
///    SPP dan mengeluarkan struk ganda (AC-3.7).
/// 2. **Timeout eksplisit** pada setiap operasi (koneksi 8 detik, tulis 10
///    detik). Tanpa itu, printer yang mati membuat kasir mengira aplikasi
///    hang — persis saat antrian sedang panjang (AC-3.6).
/// 3. **Tidak pernah melempar exception mentah.** Semua kegagalan
///    diterjemahkan jadi [PrinterException] berbahasa Indonesia.
class BluetoothReceiptPrinter implements ReceiptPrinter {
  BluetoothReceiptPrinter();

  /// Batas waktu membuka koneksi ke printer yang sudah dipasangkan.
  static const Duration connectTimeout = Duration(seconds: 8);

  /// Batas waktu mengirim satu salinan struk.
  static const Duration writeTimeout = Duration(seconds: 10);

  /// Jeda antar salinan supaya buffer printer sempat kosong — klon murah
  /// gampang kehilangan byte kalau salinan berikutnya menyusul terlalu
  /// rapat.
  static const Duration _betweenCopies = Duration(milliseconds: 400);

  bool _busy = false;

  @override
  bool get isBusy => _busy;

  bool get _supported => Platform.isAndroid;

  @override
  Future<bool> hasPermission() async {
    if (!_supported) return false;
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isBluetoothOn() async {
    if (!_supported) return false;
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<BondedPrinter>> bondedPrinters() async {
    if (!_supported) throw const PrinterException.unsupportedPlatform();
    // Urutan pemeriksaan bukan selera: izin dulu, baru radio. Kalau
    // dibalik, HP Android 12+ yang izinnya belum diberikan akan melaporkan
    // "Bluetooth mati" — pesan yang menyesatkan ke tindakan yang salah.
    if (!await hasPermission()) throw const PrinterException.permissionDenied();
    if (!await isBluetoothOn()) throw const PrinterException.bluetoothOff();
    try {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      return <BondedPrinter>[
        for (final device in devices)
          BondedPrinter(name: device.name, address: device.macAdress),
      ];
    } catch (_) {
      throw const PrinterException.unreachable();
    }
  }

  @override
  Future<void> printBytes(
    List<int> bytes, {
    required String address,
    int copies = 1,
  }) async {
    if (!_supported) throw const PrinterException.unsupportedPlatform();
    if (address.trim().isEmpty) throw const PrinterException.notConfigured();
    // Gerbang kedua AC-3.7 (yang pertama ada di UI): walau dua layar
    // berbeda memanggil bersamaan, hanya satu yang lolos ke soket.
    if (_busy) throw const PrinterException.busy();
    _busy = true;
    try {
      if (!await hasPermission()) throw const PrinterException.permissionDenied();
      if (!await isBluetoothOn()) throw const PrinterException.bluetoothOff();

      await _connect(address.trim());
      final total = copies.clamp(1, PrinterSettings.maxCopies);
      for (var copy = 0; copy < total; copy++) {
        if (copy > 0) await Future<void>.delayed(_betweenCopies);
        await _write(bytes);
      }
    } finally {
      // Koneksi selalu ditutup, termasuk saat gagal: soket SPP yang
      // menggantung membuat percobaan berikutnya gagal dengan alasan yang
      // salah, dan pengguna mengejar masalah yang tidak ada.
      await disconnect();
      _busy = false;
    }
  }

  Future<void> _connect(String address) async {
    bool connected;
    try {
      if (await PrintBluetoothThermal.connectionStatus) return;
      connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: address,
      ).timeout(connectTimeout);
    } on TimeoutException {
      throw const PrinterException.unreachable();
    } catch (_) {
      throw const PrinterException.unreachable();
    }
    if (!connected) throw const PrinterException.unreachable();
  }

  Future<void> _write(List<int> bytes) async {
    bool ok;
    try {
      ok = await PrintBluetoothThermal.writeBytes(bytes).timeout(writeTimeout);
    } on TimeoutException {
      throw const PrinterException.writeFailed();
    } catch (_) {
      throw const PrinterException.writeFailed();
    }
    if (!ok) throw const PrinterException.writeFailed();
  }

  @override
  Future<void> disconnect() async {
    if (!_supported) return;
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {
      // Memutus koneksi yang memang sudah putus bukan kegagalan yang perlu
      // diketahui siapa pun.
    }
  }
}
