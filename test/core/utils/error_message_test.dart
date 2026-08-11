import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/error_message.dart';
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
}
