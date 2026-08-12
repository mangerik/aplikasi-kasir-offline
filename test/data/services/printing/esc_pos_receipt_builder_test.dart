import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/services/printing/esc_pos_receipt_builder.dart';
import 'package:kasir_warung/data/services/printing/receipt_text_sanitizer.dart';
import 'package:kasir_warung/domain/entities/printer_settings.dart';
import 'package:kasir_warung/domain/entities/sale_result.dart';
import 'package:kasir_warung/domain/entities/store_profile.dart';

/// Uji tata letak & byte struk cetak (PRD v1.1 §3.3.D, K-3.2).
///
/// Semuanya berjalan **tanpa perangkat dan tanpa printer** — itulah alasan
/// builder-nya sengaja dibuat murni Dart. Satu-satunya cara lain
/// memverifikasi hal-hal di bawah adalah membuang gulungan kertas satu per
/// satu sambil menebak.
void main() {
  setUpAll(() async {
    // `DateFormatter` memakai data locale id_ID.
    await DateFormatter.init();
  });

  const profile = StoreProfile(
    name: 'Warung Bu Erik',
    address: 'Jl. Melati No. 12, Sleman',
    phone: '081234567890',
  );

  SaleResult sale({
    String status = 'completed',
    String paymentMethod = 'cash',
    int discount = 1000,
    List<SaleResultItem>? items,
    String? customerName,
  }) {
    return SaleResult(
      saleId: 7,
      invoiceNumber: '20260812-0007',
      subtotal: 15000,
      discount: discount,
      total: 14000,
      paymentMethod: paymentMethod,
      paidAmount: 20000,
      changeAmount: 6000,
      customerName: customerName,
      createdAt: DateTime(2026, 8, 12, 19, 42),
      status: status,
      items:
          items ??
          const [
            SaleResultItem(
              name: 'Indomie Goreng',
              unit: 'pcs',
              qty: 2,
              sellPrice: 3500,
              discount: 0,
              lineTotal: 7000,
            ),
            SaleResultItem(
              name: 'Gula Pasir',
              unit: 'kg',
              qty: 0.5,
              sellPrice: 16000,
              discount: 1000,
              lineTotal: 8000,
            ),
          ],
    );
  }

  const builder58 = EscPosReceiptBuilder();
  const builder80 = EscPosReceiptBuilder(paperWidth: PrinterPaperWidth.mm80);

  List<String> textOf(List<EscPosLine> lines) => [for (final l in lines) l.text];

  group('lebar kertas (K-3.6)', () {
    test('58mm = 32 karakter, 80mm = 48 karakter', () {
      expect(builder58.columns, 32);
      expect(builder80.columns, 48);
    });

    test('TIDAK ADA baris yang melebihi lebar kertas', () {
      for (final b in <EscPosReceiptBuilder>[builder58, builder80]) {
        final lines = b.buildLines(sale: sale(), profile: profile);
        for (final line in lines) {
          expect(
            line.text.length,
            lessThanOrEqualTo(b.columns),
            reason: 'baris "${line.text}" melebihi ${b.columns} karakter',
          );
        }
      }
    });

    test('garis pemisah tepat selebar kertas', () {
      final lines = textOf(builder58.buildLines(sale: sale(), profile: profile));
      final separators = lines.where((l) => l.startsWith('---'));
      expect(separators, isNotEmpty);
      for (final s in separators) {
        expect(s, '-' * 32);
      }
    });
  });

  group('perataan nominal', () {
    test('nominal rata kanan memakai SPASI, bukan tab', () {
      final lines = textOf(builder58.buildLines(sale: sale(), profile: profile));
      final total = lines.firstWhere((l) => l.startsWith('TOTAL'));
      expect(total.length, 32);
      expect(total.endsWith('14.000'), isTrue);
      expect(total.contains('\t'), isFalse);
      expect(total, 'TOTAL                     14.000');
    });

    test('baris item memuat qty, satuan, harga satuan, dan total baris', () {
      final lines = textOf(builder58.buildLines(sale: sale(), profile: profile));
      expect(lines, contains('Indomie Goreng'));
      final itemLine = lines.firstWhere((l) => l.trimLeft().startsWith('2 pcs x'));
      expect(itemLine.length, 32);
      expect(itemLine.endsWith('7.000'), isTrue);
    });

    test('qty pecahan memakai koma gaya Indonesia', () {
      final lines = textOf(builder58.buildLines(sale: sale(), profile: profile));
      expect(lines.any((l) => l.contains('0,5 kg x 16.000')), isTrue);
    });

    test('nominal TIDAK PERNAH terpotong walau labelnya kepanjangan', () {
      final lines = textOf(
        builder58.buildLines(
          sale: sale(
            items: const [
              SaleResultItem(
                name: 'X',
                unit: 'karung-super-panjang-sekali',
                qty: 12345,
                sellPrice: 1234567,
                discount: 0,
                lineTotal: 1234567,
              ),
            ],
          ),
          profile: profile,
        ),
      );
      final itemLine = lines.firstWhere((l) => l.endsWith('1.234.567'));
      expect(itemLine.length, lessThanOrEqualTo(32));
      expect(itemLine.endsWith('1.234.567'), isTrue);
    });

    test('rupiah dicetak TANPA prefiks "Rp" (hemat lebar)', () {
      final lines = textOf(builder58.buildLines(sale: sale(), profile: profile));
      expect(lines.any((l) => l.contains('Rp')), isFalse);
    });
  });

  group('pemotongan nama panjang', () {
    test('nama > lebar kertas pindah baris di BATAS KATA', () {
      final lines = textOf(
        builder58.buildLines(
          sale: sale(
            items: const [
              SaleResultItem(
                name: 'Minyak Goreng Sawit Kemasan Botol Dua Liter Merek Bagus',
                unit: 'btl',
                qty: 1,
                sellPrice: 38000,
                discount: 0,
                lineTotal: 38000,
              ),
            ],
          ),
          profile: profile,
        ),
      );
      final nameLines = lines.where((l) => l.contains('Minyak') || l.contains('Merek')).toList();
      expect(nameLines.length, greaterThanOrEqualTo(2));
      for (final l in nameLines) {
        expect(l.length, lessThanOrEqualTo(32));
      }
      // Tidak ada kata yang terbelah di tengah.
      expect(nameLines.join(' ').replaceAll(RegExp(r'\s+'), ' '),
          'Minyak Goreng Sawit Kemasan Botol Dua Liter Merek Bagus');
    });

    test('satu kata yang memang lebih panjang dari kertas dipenggal keras', () {
      final lines = textOf(
        builder58.buildLines(
          sale: sale(
            items: [
              SaleResultItem(
                name: 'A' * 70,
                unit: 'pcs',
                qty: 1,
                sellPrice: 1000,
                discount: 0,
                lineTotal: 1000,
              ),
            ],
          ),
          profile: profile,
        ),
      );
      final aLines = lines.where((l) => l.startsWith('AAAA')).toList();
      expect(aLines.length, 3); // 32 + 32 + 6
      expect(aLines.map((l) => l.length).reduce((a, b) => a + b), 70);
    });
  });

  group('penanda cetak ulang & void', () {
    test('cetak ulang menambah ** CETAK ULANG ** di bawah nomor struk', () {
      final lines = textOf(
        builder58.buildLines(sale: sale(), profile: profile, reprint: true),
      );
      final invoiceIndex = lines.indexWhere((l) => l.startsWith('No. Struk:'));
      expect(lines[invoiceIndex + 1], '** CETAK ULANG **');
    });

    test('struk normal TIDAK memuat penanda apa pun', () {
      final lines = textOf(builder58.buildLines(sale: sale(), profile: profile));
      expect(lines.any((l) => l.contains('CETAK ULANG')), isFalse);
      expect(lines.any((l) => l.contains('DIBATALKAN')), isFalse);
    });

    test('transaksi void memuat ** DIBATALKAN ** dan TIDAK memuat kembalian '
        '(AC-3.9)', () {
      final lines = textOf(
        builder58.buildLines(sale: sale(status: 'voided'), profile: profile, reprint: true),
      );
      expect(lines, contains('** DIBATALKAN **'));
      expect(lines, contains('** CETAK ULANG **'));
      expect(lines.any((l) => l.startsWith('Kembali')), isFalse);
      // Baris "Tunai" tetap ada — nominal yang pernah diterima bukan
      // informasi yang perlu disembunyikan.
      expect(lines.any((l) => l.startsWith('Tunai')), isTrue);
    });

    test('cetak ulang struk normal TETAP memuat kembalian', () {
      final lines = textOf(
        builder58.buildLines(sale: sale(), profile: profile, reprint: true),
      );
      expect(lines.any((l) => l.startsWith('Kembali')), isTrue);
    });
  });

  group('isi struk', () {
    test('kepala toko memakai nama/alamat/telp dari profil', () {
      final lines = builder58.buildLines(sale: sale(), profile: profile);
      expect(lines.first.text, 'WARUNG BU ERIK');
      expect(lines.first.bold, isTrue);
      expect(lines.first.doubleHeight, isTrue);
      expect(lines.first.align, EscPosAlign.center);
      expect(textOf(lines).any((l) => l.contains('Jl. Melati')), isTrue);
      expect(textOf(lines).any((l) => l.contains('Telp: 081234567890')), isTrue);
    });

    test('profil kosong jatuh ke KASIR WARUNG tanpa alamat/telp', () {
      final lines = textOf(
        builder58.buildLines(sale: sale(), profile: const StoreProfile()),
      );
      expect(lines.first, 'KASIR WARUNG');
      expect(lines.any((l) => l.startsWith('Telp:')), isFalse);
    });

    test('diskon per item & diskon transaksi tampil sebagai nominal negatif', () {
      final lines = textOf(builder58.buildLines(sale: sale(), profile: profile));
      expect(lines.any((l) => l.trimLeft().startsWith('Diskon') && l.endsWith('-1.000')), isTrue);
      expect(lines.any((l) => l.startsWith('Diskon transaksi')), isTrue);
    });

    test('hutang & non-tunai tidak memunculkan baris kembalian', () {
      for (final method in <String>['debt', 'noncash']) {
        final lines = textOf(
          builder58.buildLines(
            sale: sale(paymentMethod: method, customerName: 'Bu Ani'),
            profile: profile,
          ),
        );
        expect(lines.any((l) => l.startsWith('Kembali')), isFalse);
      }
    });

    test('nama pelanggan tampil bila ada', () {
      final lines = textOf(
        builder58.buildLines(
          sale: sale(paymentMethod: 'debt', customerName: 'Bu Ani'),
          profile: profile,
        ),
      );
      expect(lines, contains('Pelanggan: Bu Ani'));
    });

    test('kalimat penutup dari pengaturan, maksimal 2 baris', () {
      final lines = textOf(
        builder58.buildLines(
          sale: sale(),
          profile: profile,
          settings: const PrinterSettings(
            address: 'AA:BB',
            footerText: 'Terima kasih sudah belanja di warung kami semoga sehat '
                'selalu dan rezekinya lancar terus sampai akhir tahun nanti ya',
          ),
        ),
      );
      final footerLines = lines.where((l) => l.contains('Terima kasih') || l.contains('warung kami'));
      expect(footerLines.length, lessThanOrEqualTo(2));
    });

    test('SELURUH baris ASCII murni, apa pun isinya (AC-3.4)', () {
      final lines = textOf(
        builder58.buildLines(
          sale: sale(
            customerName: 'Bu Añi 中 ✅',
            items: const [
              SaleResultItem(
                name: 'Kopi “Spesial” — 2× Gula',
                unit: 'sachet',
                qty: 3,
                sellPrice: 2500,
                discount: 0,
                lineTotal: 7500,
              ),
            ],
          ),
          profile: const StoreProfile(name: 'Café Élysée', address: 'Jl. Anggrek №5'),
        ),
      );
      for (final l in lines) {
        expect(ReceiptTextSanitizer.isPureAscii(l), isTrue, reason: 'baris tidak ASCII: "$l"');
      }
    });
  });

  group('byte ESC/POS (vektor uji)', () {
    test('encodeLine baris biasa: align kiri, ukuran normal, bold mati', () {
      const line = EscPosLine('OK');
      expect(builder58.encodeLine(line), <int>[
        0x1B, 0x61, 0x00, // ESC a 0  — rata kiri
        0x1D, 0x21, 0x00, // GS ! 0   — ukuran normal
        0x1B, 0x45, 0x00, // ESC E 0  — bold mati
        0x4F, 0x4B, // "OK"
        0x0A, // LF
        0x1B, 0x45, 0x00, // reset bold
        0x1D, 0x21, 0x00, // reset ukuran
      ]);
    });

    test('encodeLine baris tengah + tebal + tinggi ganda', () {
      const line = EscPosLine('Hi', align: EscPosAlign.center, bold: true, doubleHeight: true);
      expect(builder58.encodeLine(line), <int>[
        0x1B, 0x61, 0x01, // rata tengah
        0x1D, 0x21, 0x01, // tinggi ganda (LEBAR tetap — kolom tidak bergeser)
        0x1B, 0x45, 0x01, // bold nyala
        0x48, 0x69, // "Hi"
        0x0A,
        0x1B, 0x45, 0x00,
        0x1D, 0x21, 0x00,
      ]);
    });

    test('encodeLine menyanitasi teks sebelum jadi byte', () {
      const line = EscPosLine('2×3');
      expect(builder58.encodeLine(line).sublist(9, 12), <int>[0x32, 0x78, 0x33]); // "2x3"
    });

    test('struk diawali ESC @ + pilih codepage CP437', () {
      final bytes = builder58.build(sale: sale(), profile: profile);
      expect(bytes.sublist(0, 5), <int>[0x1B, 0x40, 0x1B, 0x74, 0x00]);
    });

    test('struk diakhiri baris feed sesuai pengaturan lalu ESC @', () {
      final bytes = builder58.build(
        sale: sale(),
        profile: profile,
        settings: const PrinterSettings(address: 'AA:BB', feedLines: 3),
      );
      expect(bytes.sublist(bytes.length - 2), <int>[0x1B, 0x40]);
      expect(bytes.sublist(bytes.length - 5, bytes.length - 2), <int>[0x0A, 0x0A, 0x0A]);
    });

    test('feedLines = 0 berarti benar-benar tanpa baris kosong tambahan', () {
      final bytes = builder58.build(
        sale: sale(),
        profile: profile,
        settings: const PrinterSettings(address: 'AA:BB', feedLines: 0),
      );
      // Byte tepat sebelum ESC @ penutup adalah LF akhir baris terakhir,
      // bukan tumpukan LF tambahan.
      expect(bytes.sublist(bytes.length - 2), <int>[0x1B, 0x40]);
      expect(bytes[bytes.length - 3], isNot(0x0A));
    });

    test('seluruh byte muat dalam satu byte (0–255)', () {
      final bytes = builder58.build(sale: sale(), profile: profile);
      expect(bytes.every((b) => b >= 0 && b <= 0xFF), isTrue);
    });

    test('TIDAK ADA perintah terlarang: auto-cut, QR native, laci kas '
        '(K-3.8)', () {
      final bytes = builder58.build(sale: sale(), profile: profile);
      // GS V (auto-cut) = 0x1D 0x56 ; GS ( k (QR) = 0x1D 0x28 0x6B ;
      // ESC p (laci kas) = 0x1B 0x70
      for (var i = 0; i < bytes.length - 2; i++) {
        expect(bytes[i] == 0x1D && bytes[i + 1] == 0x56, isFalse, reason: 'ada auto-cut');
        expect(
          bytes[i] == 0x1D && bytes[i + 1] == 0x28 && bytes[i + 2] == 0x6B,
          isFalse,
          reason: 'ada QR native',
        );
        expect(bytes[i] == 0x1B && bytes[i + 1] == 0x70, isFalse, reason: 'ada laci kas');
      }
    });

    test('logo raster disisipkan sebelum kepala struk, diapit perintah rata '
        'tengah', () {
      const raster = <int>[0x1D, 0x76, 0x30, 0x00, 0x01, 0x00, 0x01, 0x00, 0xFF];
      final bytes = builder58.build(sale: sale(), profile: profile, logoRaster: raster);
      // ESC @ (2) + ESC t 0 (3) = 5, lalu ESC a 1 (3), lalu raster.
      expect(bytes.sublist(5, 8), <int>[0x1B, 0x61, 0x01]);
      expect(bytes.sublist(8, 8 + raster.length), raster);
    });
  });

  group('struk uji', () {
    test('memuat penanda CETAK UJI dan penggaris selebar kertas', () {
      final bytes = builder58.buildTestReceipt(profile: profile);
      final text = String.fromCharCodes(bytes.where((b) => b >= 0x20 && b <= 0x7E));
      expect(text.contains('CETAK UJI'), isTrue);
      expect(text.contains('1234567890'), isTrue);
      expect(text.contains('58mm (32 karakter)'), isTrue);
    });
  });
}
