import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/error_message.dart';
import 'package:kasir_warung/domain/repositories/import_exceptions.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';

/// Test Milestone 6 — Tugas B poin 1: memastikan [AppErrorMessage] TIDAK
/// PERNAH membocorkan teks Inggris/exception mentah ke pengguna, sekaligus
/// tetap menampilkan pesan Indonesia siap-tampil milik exception domain apa
/// adanya (bukan diganti generik).
class _FakeUnknownError implements Exception {
  @override
  String toString() => 'FormatException: Unexpected character at offset 12';
}

void main() {
  group('AppErrorMessage.from', () {
    test('exception domain (pesan Indonesia siap tampil) dipakai apa adanya', () {
      expect(
        AppErrorMessage.from(const NamaPelangganWajibException()),
        'Nama pelanggan wajib diisi untuk transaksi hutang.',
      );
      expect(
        AppErrorMessage.from(const ProdukTidakDitemukanException()),
        'Produk tidak ditemukan.',
      );
      expect(
        AppErrorMessage.from(const BarcodeSudahDipakaiException('12345')),
        contains('Barcode "12345" sudah dipakai'),
      );
    });

    test('exception TAK DIKENAL (pihak ketiga, pesan Inggris) diganti pesan generik Indonesia', () {
      final message = AppErrorMessage.from(_FakeUnknownError());
      expect(message, AppErrorMessage.generic);
      expect(message, isNot(contains('FormatException')));
      expect(message, isNot(contains('Unexpected character')));
    });

    test('Exception/String polos juga diganti pesan generik (bukan toString mentah)', () {
      expect(AppErrorMessage.from(Exception('boom')), AppErrorMessage.generic);
      expect(AppErrorMessage.from(StateError('bad state')), AppErrorMessage.generic);
    });
  });

  /// Sapu M11: kegagalan impor Excel (M9) punya pesan Indonesia spesifik yang
  /// jauh lebih berguna daripada pesan generik ("Kolom wajib hilang:
  /// harga_jual" vs "Terjadi kesalahan tak terduga"). Sebelum M11 induk
  /// `ImporProdukException` belum terdaftar, sehingga pesan itu hilang begitu
  /// error lewat jalur error umum.
  group('AppErrorMessage.from — kegagalan impor Excel M9', () {
    test('seluruh turunan ImporProdukException dipakai apa adanya', () {
      final kegagalan = <ImporProdukException>[
        const FileImporTidakValidException('file rusak'),
        const KolomWajibHilangException(['harga_jual']),
        const FileImporTerlaluBesarException(6000, 5000),
        const FileImporKosongException(),
        const BarisImporTidakValidException(12, 'harga jual kosong'),
      ];

      for (final e in kegagalan) {
        final message = AppErrorMessage.from(e);
        expect(
          message,
          isNot(AppErrorMessage.generic),
          reason: '${e.runtimeType} kehilangan pesan spesifiknya',
        );
        expect(message, e.toString());
      }
    });

    test('pesannya berbahasa Indonesia, bukan nama kelas mentah', () {
      final message = AppErrorMessage.from(const KolomWajibHilangException(['harga_jual']));
      expect(message, isNot(contains('Exception:')));
      expect(message, contains('harga_jual'));
    });
  });
}
