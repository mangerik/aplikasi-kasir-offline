import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/printer_settings.dart';
import '../../../domain/entities/sale_result.dart';
import '../../../domain/entities/store_profile.dart';
import 'receipt_text_sanitizer.dart';

/// Perataan satu baris struk.
enum EscPosAlign { left, center, right }

/// Satu baris struk yang **sudah jadi teks final** (sudah disanitasi, sudah
/// dipotong/diratakan ke lebar kertas) beserta gayanya.
///
/// Dipisah dari byte supaya tata letak bisa diuji sebagai teks yang enak
/// dibaca manusia, sementara byte diuji terpisah sebagai vektor uji.
class EscPosLine {
  const EscPosLine(
    this.text, {
    this.align = EscPosAlign.left,
    this.bold = false,
    this.doubleHeight = false,
  });

  final String text;
  final EscPosAlign align;
  final bool bold;

  /// Tinggi ganda (`GS ! 0x01`). Sengaja **hanya tinggi**, bukan lebar:
  /// lebar ganda memotong jumlah kolom jadi separuh dan merusak perataan
  /// nominal yang sudah dihitung terhadap 32 karakter.
  final bool doubleHeight;

  @override
  String toString() => text;
}

/// Pembentuk byte ESC/POS untuk struk penjualan (PRD v1.1 §3.3.D, K-3.2).
///
/// **Murni Dart, tanpa satu pun dependency platform** — tidak menyentuh
/// `dart:ui`, `package:flutter`, maupun plugin Bluetooth. Konsekuensinya
/// disengaja: seluruh tata letak & seluruh byte bisa diuji unit tanpa
/// perangkat dan tanpa printer, yang penting karena satu-satunya cara lain
/// memverifikasinya adalah membuang gulungan kertas.
///
/// Urutan blok struk **sama persis** dengan
/// `ReceiptService.formatReceiptText`, sehingga struk yang dicetak dan
/// struk yang di-share lewat WhatsApp bercerita hal yang sama.
///
/// Perintah ESC/POS yang dipakai sengaja dibatasi pada subset yang
/// didukung hampir semua klon murah (PRD §3.7.2): init, pilih codepage,
/// perataan, tebal, tinggi ganda, feed, dan raster `GS v 0` untuk logo.
/// **Tanpa auto-cut, tanpa laci kas, tanpa QR native** (K-3.8).
class EscPosReceiptBuilder {
  const EscPosReceiptBuilder({this.paperWidth = PrinterPaperWidth.mm58});

  final PrinterPaperWidth paperWidth;

  /// Jumlah karakter per baris pada Font A: 32 untuk 58mm, 48 untuk 80mm
  /// (K-3.6 — 80mm disiapkan sebagai pengaturan, pengujian resmi v1.1
  /// tetap hanya 58mm).
  int get columns => paperWidth.columns;

  // --- Perintah ESC/POS -----------------------------------------------
  static const List<int> _init = <int>[0x1B, 0x40]; // ESC @
  static const List<int> _codepageCp437 = <int>[0x1B, 0x74, 0x00]; // ESC t 0
  static const List<int> _alignLeft = <int>[0x1B, 0x61, 0x00]; // ESC a 0
  static const List<int> _alignCenter = <int>[0x1B, 0x61, 0x01];
  static const List<int> _alignRight = <int>[0x1B, 0x61, 0x02];
  static const List<int> _boldOn = <int>[0x1B, 0x45, 0x01]; // ESC E 1
  static const List<int> _boldOff = <int>[0x1B, 0x45, 0x00];
  static const List<int> _sizeNormal = <int>[0x1D, 0x21, 0x00]; // GS ! 0
  static const List<int> _sizeDoubleHeight = <int>[0x1D, 0x21, 0x01];
  static const int _lf = 0x0A;

  /// Byte lengkap satu struk, siap dikirim ke transport.
  ///
  /// [logoRaster] adalah byte perintah raster `GS v 0` yang sudah jadi
  /// (dibentuk di luar builder karena membaca file gambar butuh platform);
  /// `null` = tanpa logo.
  List<int> build({
    required SaleResult sale,
    required StoreProfile profile,
    PrinterSettings settings = const PrinterSettings(),
    bool reprint = false,
    List<int>? logoRaster,
  }) {
    final bytes = <int>[..._init, ..._codepageCp437];
    if (logoRaster != null && logoRaster.isNotEmpty) {
      bytes
        ..addAll(_alignCenter)
        ..addAll(logoRaster)
        ..addAll(_alignLeft);
    }
    for (final line in buildLines(
      sale: sale,
      profile: profile,
      settings: settings,
      reprint: reprint,
    )) {
      bytes.addAll(encodeLine(line));
    }
    // Baris kosong setelah struk supaya kertas lewat dari kepala cetak &
    // gampang disobek. Nilainya bisa diatur pengguna (0–6) karena jarak
    // kepala-ke-sobekan berbeda antar merek printer.
    for (var i = 0; i < settings.feedLines; i++) {
      bytes.add(_lf);
    }
    // Kembalikan printer ke keadaan wajar supaya job berikutnya (dari
    // aplikasi mana pun) tidak mewarisi gaya struk ini.
    bytes.addAll(_init);
    return bytes;
  }

  /// Byte satu baris — dipisah supaya bisa diuji sebagai vektor uji kecil.
  List<int> encodeLine(EscPosLine line) {
    return <int>[
      ...switch (line.align) {
        EscPosAlign.left => _alignLeft,
        EscPosAlign.center => _alignCenter,
        EscPosAlign.right => _alignRight,
      },
      ...(line.doubleHeight ? _sizeDoubleHeight : _sizeNormal),
      ...(line.bold ? _boldOn : _boldOff),
      ...ReceiptTextSanitizer.toBytes(line.text),
      _lf,
      ..._boldOff,
      ..._sizeNormal,
    ];
  }

  /// Tata letak struk sebagai daftar baris teks final.
  ///
  /// Ini yang diuji paling ketat: jumlah karakter per baris, perataan
  /// nominal, pemotongan nama panjang, dan penanda cetak ulang/void.
  List<EscPosLine> buildLines({
    required SaleResult sale,
    required StoreProfile profile,
    PrinterSettings settings = const PrinterSettings(),
    bool reprint = false,
  }) {
    final lines = <EscPosLine>[];
    final isVoided = sale.status == 'voided';

    // --- Kepala toko ---
    lines.add(
      EscPosLine(
        _clean(profile.displayName).toUpperCase(),
        align: EscPosAlign.center,
        bold: true,
        doubleHeight: true,
      ),
    );
    if (profile.hasAddress) {
      for (final part in _wrap(_clean(profile.address!.trim()))) {
        lines.add(EscPosLine(part, align: EscPosAlign.center));
      }
    }
    if (profile.hasPhone) {
      lines.add(
        EscPosLine('Telp: ${_clean(profile.phone!.trim())}', align: EscPosAlign.center),
      );
    }

    // --- Identitas transaksi ---
    lines.add(_separator());
    lines.add(EscPosLine('No. Struk: ${_clean(sale.invoiceNumber)}'));
    // Penanda ditaruh TEPAT di bawah nomor struk (PRD §3.3.C) supaya
    // pemilik warung yang memegang dua lembar kertas langsung tahu mana
    // yang cetakan ulang — tanpa membaca seluruh struk.
    if (isVoided) {
      lines.add(const EscPosLine('** DIBATALKAN **', align: EscPosAlign.center, bold: true));
    }
    if (reprint) {
      lines.add(const EscPosLine('** CETAK ULANG **', align: EscPosAlign.center, bold: true));
    }
    lines.add(EscPosLine(DateFormatter.formatDateTime(sale.createdAt)));
    final customer = sale.customerName?.trim();
    if (customer != null && customer.isNotEmpty) {
      lines.add(EscPosLine('Pelanggan: ${_clean(customer)}'));
    }
    // Baris "Kasir" hanya ada saat multi-user aktif (PRD v1.1 §8.3.D);
    // struk mode single-user tetap identik dengan v1.0 (AC-8.1).
    final cashier = sale.userName?.trim();
    if (cashier != null && cashier.isNotEmpty) {
      lines.add(EscPosLine('Kasir: ${_clean(cashier)}'));
    }

    // --- Item ---
    lines.add(_separator());
    for (final item in sale.items) {
      for (final part in _wrap(_clean(item.name))) {
        lines.add(EscPosLine(part));
      }
      lines.add(
        EscPosLine(
          _row(
            '  ${_formatQty(item.qty)} ${_clean(item.unit)} x '
            '${CurrencyFormatter.formatNumber(item.sellPrice)}',
            CurrencyFormatter.formatNumber(item.lineTotal),
          ),
        ),
      );
      if (item.discount > 0) {
        lines.add(
          EscPosLine(
            _row('  Diskon', '-${CurrencyFormatter.formatNumber(item.discount)}'),
          ),
        );
      }
    }

    // --- Ringkasan uang ---
    lines.add(_separator());
    lines.add(EscPosLine(_row('Subtotal', CurrencyFormatter.formatNumber(sale.subtotal))));
    // Penukaran poin adalah diskon transaksi (K-7.6), tapi di struk ia
    // dipisah supaya pembeli melihat poinnya benar-benar terpakai
    // (AC-7.9). Bila nilai rupiahnya tidak bisa dipisah dari diskon
    // manual, barisnya tetap muncul sebagai keterangan tanpa nominal —
    // angka totalnya tetap konsisten.
    final redeemValue = sale.pointsRedeemedValue;
    final manualDiscount = sale.discount - redeemValue;
    if (manualDiscount > 0) {
      lines.add(
        EscPosLine(
          _row('Diskon transaksi', '-${CurrencyFormatter.formatNumber(manualDiscount)}'),
        ),
      );
    }
    if (sale.pointsRedeemed > 0) {
      lines.add(
        EscPosLine(
          _row(
            'Tukar poin (${sale.pointsRedeemed})',
            redeemValue > 0 ? '-${CurrencyFormatter.formatNumber(redeemValue)}' : '-',
          ),
        ),
      );
    }
    lines.add(
      EscPosLine(
        _row('TOTAL', CurrencyFormatter.formatNumber(sale.total)),
        bold: true,
        doubleHeight: true,
      ),
    );

    switch (sale.paymentMethod) {
      case 'cash':
        lines.add(EscPosLine(_row('Tunai', CurrencyFormatter.formatNumber(sale.paidAmount))));
        // AC-3.9: struk transaksi yang dibatalkan TIDAK memuat baris
        // kembalian — uangnya sudah tidak berpindah seperti yang tertulis.
        if (!isVoided) {
          lines.add(
            EscPosLine(_row('Kembali', CurrencyFormatter.formatNumber(sale.changeAmount))),
          );
        }
      case 'debt':
        lines.add(EscPosLine(_row('Pembayaran', 'HUTANG')));
      default:
        lines.add(EscPosLine(_row('Pembayaran', 'NON-TUNAI')));
    }

    // Program poin mati → `pointsEarned`/`pointsBalanceAfter` selalu 0,
    // sehingga tidak ada satu pun baris poin yang tercetak (AC-7.6).
    if (sale.pointsEarned > 0) {
      lines.add(EscPosLine(_row('Poin didapat', '+${sale.pointsEarned}')));
    }
    if (sale.pointsBalanceAfter > 0) {
      lines.add(EscPosLine(_row('Saldo poin', '${sale.pointsBalanceAfter}')));
    }

    // --- Penutup ---
    lines.add(_separator());
    final footer = _clean(settings.footerText.trim());
    if (footer.isNotEmpty) {
      // Maksimal 2 baris (PRD §3.3.E) — kalimat penutup bukan tempat
      // menulis brosur.
      for (final part in _wrap(footer).take(2)) {
        lines.add(EscPosLine(part, align: EscPosAlign.center));
      }
    }
    return lines;
  }

  /// Struk uji untuk tombol "Cetak Uji" di Pengaturan. Sengaja memuat
  /// contoh baris nominal & karakter yang paling sering bermasalah, supaya
  /// kegagalan format ketahuan di sini — bukan di depan pembeli.
  List<int> buildTestReceipt({
    required StoreProfile profile,
    PrinterSettings settings = const PrinterSettings(),
    List<int>? logoRaster,
  }) {
    final bytes = <int>[..._init, ..._codepageCp437];
    if (logoRaster != null && logoRaster.isNotEmpty) {
      bytes
        ..addAll(_alignCenter)
        ..addAll(logoRaster)
        ..addAll(_alignLeft);
    }
    final lines = <EscPosLine>[
      EscPosLine(
        _clean(profile.displayName).toUpperCase(),
        align: EscPosAlign.center,
        bold: true,
        doubleHeight: true,
      ),
      const EscPosLine('CETAK UJI', align: EscPosAlign.center, bold: true),
      _separator(),
      EscPosLine(DateFormatter.formatDateTime(DateTime.now())),
      EscPosLine('Lebar kertas: ${paperWidth.millimeters}mm ($columns karakter)'),
      _separator(),
      EscPosLine(_ruler()),
      EscPosLine(_row('Contoh Barang Panjang', '150.000')),
      EscPosLine(_row('TOTAL', '150.000'), bold: true, doubleHeight: true),
      _separator(),
      const EscPosLine(
        'Kalau garis di atas lurus dan angka rata kanan, printer siap dipakai.',
        align: EscPosAlign.center,
      ),
    ];
    for (final line in lines) {
      if (line.text.length > columns && line.align == EscPosAlign.center) {
        for (final part in _wrap(line.text)) {
          bytes.addAll(encodeLine(EscPosLine(part, align: EscPosAlign.center)));
        }
        continue;
      }
      bytes.addAll(encodeLine(line));
    }
    for (var i = 0; i < settings.feedLines; i++) {
      bytes.add(_lf);
    }
    bytes.addAll(_init);
    return bytes;
  }

  // --- Helper tata letak ----------------------------------------------

  EscPosLine _separator() => EscPosLine('-' * columns);

  /// Penggaris kolom untuk cetak uji: `1234567890...` sepanjang [columns].
  String _ruler() => List<int>.generate(columns, (i) => (i + 1) % 10).join();

  String _clean(String value) => ReceiptTextSanitizer.sanitize(value);

  /// Satu baris label-kiri + nominal-kanan yang diratakan dengan **spasi**,
  /// bukan tab: tab diterjemahkan berbeda-beda oleh firmware printer murah
  /// dan hasilnya bergeser tak terduga (PRD §3.3.D).
  ///
  /// Bila kiri+kanan tidak muat, yang dipotong adalah **teks kiri** —
  /// nominal tidak pernah boleh terpotong, itu angka uang.
  String _row(String left, String right) {
    final l = _clean(left);
    final r = _clean(right);
    final pad = columns - l.length - r.length;
    if (pad >= 1) return '$l${' ' * pad}$r';
    final maxLeft = columns - r.length - 1;
    if (maxLeft <= 0) {
      // Nominal saja sudah selebar kertas (kasus ekstrem) — cetak rata kanan.
      return r.padLeft(columns);
    }
    return '${l.substring(0, maxLeft)} $r';
  }

  /// Pembungkus kata: nama produk lebih panjang dari lebar kertas pindah ke
  /// baris berikutnya **di batas kata**, bukan dipotong paksa di tengah
  /// kata (PRD §3.3.D). Kata tunggal yang memang lebih panjang dari satu
  /// baris (mis. kode barang) terpaksa dipenggal keras.
  List<String> _wrap(String text) {
    final source = text.trim();
    if (source.isEmpty) return const <String>[];
    if (source.length <= columns) return <String>[source];

    final result = <String>[];
    var current = StringBuffer();
    for (final word in source.split(' ')) {
      if (word.isEmpty) continue;
      if (word.length > columns) {
        if (current.isNotEmpty) {
          result.add(current.toString());
          current = StringBuffer();
        }
        var rest = word;
        while (rest.length > columns) {
          result.add(rest.substring(0, columns));
          rest = rest.substring(columns);
        }
        if (rest.isNotEmpty) current.write(rest);
        continue;
      }
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length > columns) {
        result.add(current.toString());
        current = StringBuffer(word);
      } else {
        current
          ..clear()
          ..write(candidate);
      }
    }
    if (current.isNotEmpty) result.add(current.toString());
    return result;
  }

  /// Qty gaya Indonesia: bilangan bulat tanpa desimal (`2`), pecahan dengan
  /// **koma** (`0,5`) — konsisten dengan cara angka ditulis di seluruh
  /// aplikasi.
  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    final raw = qty.toString();
    final trimmed = raw.contains('.')
        ? raw.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : raw;
    return trimmed.replaceAll('.', ',');
  }
}
