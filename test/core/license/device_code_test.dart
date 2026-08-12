import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/license/crockford_base32.dart';
import 'package:kasir_warung/core/license/device_code.dart';

/// Kode perangkat & alfabet Crockford (PRD v1.1 §6.3.C/D, K-6.5).
void main() {
  group('Crockford Base32', () {
    test('alfabetnya 32 karakter tanpa I, L, O, U', () {
      expect(CrockfordBase32.alphabet.length, 32);
      for (final ch in ['I', 'L', 'O', 'U']) {
        expect(CrockfordBase32.alphabet.contains(ch), isFalse, reason: ch);
      }
    });

    test('encode → decode bolak-balik utuh untuk 75 byte', () {
      final bytes = Uint8List.fromList([
        for (var i = 0; i < 75; i++) (i * 37) % 256,
      ]);
      final text = CrockfordBase32.encode(bytes);
      expect(text.length, 120);
      expect(CrockfordBase32.decode(text), bytes);
    });

    test('normalisasi menyatukan karakter kembar & membuang pemisah', () {
      expect(CrockfordBase32.normalize('ilo-IL O'), '110110');
      expect(CrockfordBase32.normalize('kw1 4t7qp\t9m2xk'), 'KW14T7QP9M2XK');
    });

    test('karakter di luar alfabet melempar FormatException', () {
      expect(() => CrockfordBase32.decode('UUUUUUUU'), throwsFormatException);
    });

    test('pengelompokan lima memberi mata pegangan', () {
      expect(CrockfordBase32.group('ABCDEFGHIJ'), 'ABCDE-FGHIJ');
    });
  });

  group('kode perangkat', () {
    test('bentuknya KW-XXXXX-XXXXX, 10 karakter data', () {
      final raw = DeviceCode.fromSeed('ssaid-contoh');
      expect(raw.length, DeviceCode.rawLength);
      expect(
        DeviceCode.format(raw),
        matches(RegExp(r'^KW-[0-9A-Z]{5}-[0-9A-Z]{5}$')),
      );
    });

    test('deterministik: SSAID sama → kode sama', () {
      expect(DeviceCode.fromSeed('abc'), DeviceCode.fromSeed('abc'));
      expect(DeviceCode.fromSeed('abc'), isNot(DeviceCode.fromSeed('abd')));
    });

    test('karakter cek menangkap SETIAP salah ketik satu karakter', () {
      final raw = DeviceCode.fromSeed('ssaid-contoh');
      for (var i = 0; i < raw.length; i++) {
        for (final replacement in CrockfordBase32.alphabet.split('')) {
          if (replacement == raw[i]) continue;
          final mutated = raw.replaceRange(i, i + 1, replacement);
          expect(
            DeviceCode.isValidRaw(mutated),
            isFalse,
            reason: 'posisi $i: ${raw[i]}→$replacement lolos',
          );
        }
      }
    });

    test('karakter cek menangkap tertukarnya dua karakter bersebelahan '
        '(kecuali batas matematis skema modulo 32)', () {
      // Batas yang diakui terus terang: skema linier modulo 32 tidak bisa
      // membedakan tertukarnya dua karakter yang nilainya berselisih tepat
      // 16. Sisa risikonya ditutup verifikasi tanda tangan di sisi penjual
      // (`--verifikasi`), bukan disembunyikan.
      var missed = 0;
      var checked = 0;
      for (final seed in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
        final raw = DeviceCode.fromSeed(seed);
        for (var i = 0; i < raw.length - 1; i++) {
          if (raw[i] == raw[i + 1]) continue;
          final swapped = raw.replaceRange(i, i + 2, '${raw[i + 1]}${raw[i]}');
          checked++;
          if (DeviceCode.isValidRaw(swapped)) {
            final a = CrockfordBase32.decodeChar(raw[i])!;
            final b = CrockfordBase32.decodeChar(raw[i + 1])!;
            expect(
              (a - b).abs() % 32,
              16,
              reason: 'tertukar yang lolos HARUS berselisih 16, bukan lainnya',
            );
            missed++;
          }
        }
      }
      expect(checked, greaterThan(50));
      expect(missed / checked, lessThan(0.12));
    });

    test('tryParse menerima bentuk apa pun yang wajar diketik penjual', () {
      final raw = DeviceCode.fromSeed('ssaid-contoh');
      final display = DeviceCode.format(raw);
      for (final input in [
        display,
        display.toLowerCase(),
        raw,
        ' $display ',
        display.replaceAll('-', ' '),
      ]) {
        expect(DeviceCode.tryParse(input), raw, reason: input);
      }
    });

    test('tryParse menolak kode yang salah ketik → penjual tidak pernah '
        'menerbitkan kode untuk perangkat yang tidak ada', () {
      final raw = DeviceCode.fromSeed('ssaid-contoh');
      final broken = raw.replaceRange(0, 1, raw[0] == '0' ? '1' : '0');
      expect(DeviceCode.tryParse(broken), isNull);
      expect(DeviceCode.tryParse('KW-123'), isNull);
    });

    test('SSAID cacat/tak terbaca dikenali (§6.3.C)', () {
      expect(DeviceCode.isUnusableSsaid(null), isTrue);
      expect(DeviceCode.isUnusableSsaid(''), isTrue);
      expect(DeviceCode.isUnusableSsaid('   '), isTrue);
      expect(DeviceCode.isUnusableSsaid('0000000000000000'), isTrue);
      expect(DeviceCode.isUnusableSsaid('9774d56d682e549c'), isTrue);
      expect(DeviceCode.isUnusableSsaid('9774D56D682E549C'), isTrue);
      expect(DeviceCode.isUnusableSsaid('a1b2c3d4e5f60718'), isFalse);
    });

    test('petunjuk perangkat 16 bit — beda perangkat, hampir selalu beda '
        'petunjuk', () {
      final hints = {
        for (var i = 0; i < 200; i++)
          DeviceCode.hint(DeviceCode.fromSeed('s$i')),
      };
      // Ulang tahun 16 bit atas 200 sampel: tabrakan sesekali wajar, dan
      // tidak berbahaya — petunjuk BUKAN pengaman, cuma pemilih pesan.
      expect(hints.length, greaterThan(180));
    });
  });
}
