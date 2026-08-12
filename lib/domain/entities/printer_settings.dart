/// Lebar kertas printer thermal.
///
/// 58mm adalah standar de-facto warung Indonesia dan **satu-satunya yang
/// diuji resmi di v1.1**; 80mm disiapkan sebagai pengaturan karena biayanya
/// cuma satu konstanta (PRD v1.1 K-3.6).
enum PrinterPaperWidth {
  /// 58mm @ 203dpi = 384 dot area cetak, Font A = 32 karakter/baris.
  mm58(58, 32, 384),

  /// 80mm = 576 dot, Font A = 48 karakter/baris.
  mm80(80, 48, 576);

  const PrinterPaperWidth(this.millimeters, this.columns, this.dots);

  final int millimeters;

  /// Jumlah karakter Font A per baris.
  final int columns;

  /// Lebar area cetak dalam dot — batas atas lebar raster logo.
  final int dots;

  static PrinterPaperWidth fromMillimeters(int? value) =>
      value == 80 ? PrinterPaperWidth.mm80 : PrinterPaperWidth.mm58;
}

/// Seluruh konfigurasi printer struk (PRD v1.1 §3.5).
///
/// **Tidak ada perubahan skema database**: semuanya disimpan sebagai baris
/// di tabel `settings` (key-value) yang sudah ada sejak v1.0, sehingga
/// `schemaVersion` tetap **1** dan backup v1.0 ↔ v1.1 tetap kompatibel
/// penuh. Konsekuensi menyenangkan: pengaturan printer ikut terbawa
/// backup/restore tanpa kode tambahan apa pun (AC-3.13).
class PrinterSettings {
  const PrinterSettings({
    this.address,
    this.name,
    this.type = PrinterSettings.typeClassic,
    this.paperWidth = PrinterPaperWidth.mm58,
    this.autoPrint = false,
    this.copies = 1,
    this.logoPath,
    this.printLogo = false,
    this.footerText = defaultFooterText,
    this.feedLines = defaultFeedLines,
  });

  // --- Key tabel `settings` (PRD §3.5) ---
  static const String keyAddress = 'printer_address';
  static const String keyName = 'printer_name';
  static const String keyType = 'printer_type';
  static const String keyPaperWidth = 'printer_paper_width';
  static const String keyAutoPrint = 'printer_auto_print';
  static const String keyCopies = 'printer_copies';
  static const String keyLogoPath = 'printer_logo_path';
  static const String keyPrintLogo = 'printer_print_logo';
  static const String keyFooterText = 'receipt_footer_text';
  static const String keyFeedLines = 'receipt_feed_lines';

  /// Transport Bluetooth Klasik (SPP) — satu-satunya yang dipakai v1.1.
  static const String typeClassic = 'classic';

  /// Disiapkan untuk jalur cadangan BLE (PRD §3.7.2). Belum diimplementasi.
  static const String typeBle = 'ble';

  static const String defaultFooterText = 'Terima kasih';
  static const int defaultFeedLines = 3;
  static const int maxFeedLines = 6;
  static const int maxCopies = 3;

  /// Alamat MAC / device id printer default. Kosong = belum terpasang.
  final String? address;

  /// Nama perangkat untuk ditampilkan di UI.
  final String? name;

  /// [typeClassic] | [typeBle].
  final String type;

  final PrinterPaperWidth paperWidth;

  /// Cetak otomatis begitu layar sukses transaksi tampil. **Default mati**
  /// — kertas yang keluar sendiri tanpa diminta itu mahal.
  final bool autoPrint;

  /// 1–3 salinan.
  final int copies;

  final String? logoPath;
  final bool printLogo;

  /// Kalimat penutup struk, maksimal 2 baris selebar kertas.
  final String footerText;

  /// Baris kosong setelah struk (0–6) — jarak kepala cetak ke gerigi
  /// penyobek berbeda antar merek printer.
  final int feedLines;

  /// `true` bila sudah ada printer default tersimpan.
  bool get isConfigured => address != null && address!.trim().isNotEmpty;

  /// Nama untuk ditampilkan; jatuh ke alamat MAC bila nama perangkat kosong.
  String get displayName {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return address?.trim() ?? '';
  }

  /// `true` bila logo benar-benar akan dicetak (opsi nyala DAN file dipilih).
  bool get hasLogo => printLogo && (logoPath?.trim().isNotEmpty ?? false);

  PrinterSettings copyWith({
    String? address,
    String? name,
    String? type,
    PrinterPaperWidth? paperWidth,
    bool? autoPrint,
    int? copies,
    String? logoPath,
    bool? printLogo,
    String? footerText,
    int? feedLines,
    bool clearDevice = false,
    bool clearLogoPath = false,
  }) {
    return PrinterSettings(
      address: clearDevice ? null : (address ?? this.address),
      name: clearDevice ? null : (name ?? this.name),
      type: type ?? this.type,
      paperWidth: paperWidth ?? this.paperWidth,
      autoPrint: autoPrint ?? this.autoPrint,
      copies: copies ?? this.copies,
      logoPath: clearLogoPath ? null : (logoPath ?? this.logoPath),
      printLogo: clearLogoPath ? false : (printLogo ?? this.printLogo),
      footerText: footerText ?? this.footerText,
      feedLines: feedLines ?? this.feedLines,
    );
  }
}

/// Satu printer yang **sudah dipasangkan** (bonded) di Pengaturan Bluetooth
/// Android.
///
/// Aplikasi tidak pernah memindai perangkat sendiri (K-3.9) — daftar ini
/// datang dari sistem, itu sebabnya fitur ini tidak butuh izin memindai
/// maupun izin lokasi.
class BondedPrinter {
  const BondedPrinter({required this.name, required this.address});

  final String name;
  final String address;

  String get displayName => name.trim().isEmpty ? address : name.trim();
}
