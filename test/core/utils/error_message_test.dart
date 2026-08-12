import 'dart:io';

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

  /// Sapu M15 — cacat yang ditemukan saat regresi: sebelas exception M12
  /// (pelanggan & poin) dan M13 (multi-user) tidak pernah didaftarkan ke
  /// `AppErrorMessage`, padahal seluruh layarnya melaporkan kegagalan lewat
  /// `AppErrorMessage.from(e)`. Akibatnya "Pelanggan sudah ada", "Poin tidak
  /// cukup", dan "Pemilik terakhir tidak boleh dinonaktifkan" sampai ke
  /// pengguna sebagai "Terjadi kesalahan tak terduga. Coba lagi." — pesan
  /// yang tidak memberi tahu apa pun tentang apa yang harus dilakukan.
  group('AppErrorMessage.from — exception M12 (pelanggan & poin) & M13 (pengguna)', () {
    test('seluruhnya memakai pesan spesifiknya, bukan pesan generik', () {
      final kegagalan = <Object>[
        const PelangganTidakDitemukanException(),
        const NamaPelangganSudahAdaException('Bu Ani'),
        const PelangganMasihBerhutangException(25000),
        const PoinTidakCukupException(diminta: 20, tersedia: 5),
        const GabungPelangganTidakValidException('pelanggan sumber sama dengan tujuan'),
        const NamaPenggunaWajibException(),
        const NamaPenggunaSudahAdaException('Ani'),
        const PenggunaTidakDitemukanException(),
        const PemilikTerakhirException(),
        const KodePemulihanSalahException(),
        const AksesDitolakException(),
      ];

      for (final e in kegagalan) {
        final message = AppErrorMessage.from(e);
        expect(
          message,
          isNot(AppErrorMessage.generic),
          reason: '${e.runtimeType} kehilangan pesan spesifiknya',
        );
        expect(message, e.toString());
        expect(message, isNot(contains('Exception')));
      }
    });
  });

  /// Gerbang otomatis (pola AC-5.6): daftar manual tertinggal DUA kali —
  /// `ImporProdukException` di M9 dan sebelas exception M12/M13. Penanda
  /// [DomainException] menutup celahnya, tapi hanya kalau setiap exception
  /// domain baru benar-benar memakainya. Test ini memindai berkasnya
  /// sehingga exception ke-40 pun tidak bisa lahir tanpa pesan Indonesia.
  group('gerbang: setiap exception domain memakai penanda DomainException', () {
    final berkasDomain = <String>[
      'lib/domain/repositories/repository_exceptions.dart',
      'lib/domain/repositories/import_exceptions.dart',
    ];

    test('tidak ada lagi `implements Exception` telanjang di lib/domain/repositories', () {
      final pelanggar = <String>[];
      for (final path in berkasDomain) {
        final baris = File(path).readAsLinesSync();
        for (var i = 0; i < baris.length; i++) {
          final line = baris[i];
          if (!line.startsWith('class ') && !line.startsWith('abstract class ')) continue;
          if (!line.contains('implements Exception')) continue;
          pelanggar.add('$path:${i + 1} — $line');
        }
      }

      expect(
        pelanggar,
        isEmpty,
        reason:
            'Exception domain WAJIB `implements DomainException` (bukan '
            '`Exception` telanjang), kalau tidak pesan Indonesianya diganti '
            'pesan generik oleh AppErrorMessage:\n${pelanggar.join('\n')}',
      );
    });

    test('penanda memang mengenali seluruh exception di kedua berkas', () {
      // Sanity: penanda hanya berguna kalau `is DomainException` benar-benar
      // menyala untuk turunan yang jauh (mis. turunan ImporProdukException).
      expect(const FileImporKosongException(), isA<DomainException>());
      expect(const AksesDitolakException(), isA<DomainException>());
      expect(const BarcodeSudahDipakaiException('1'), isA<DomainException>());
    });
  });
}
