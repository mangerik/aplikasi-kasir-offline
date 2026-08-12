import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/pin_throttle.dart';
import 'package:kasir_warung/core/utils/recovery_code.dart';

/// Pembatas percobaan PIN & kode pemulihan (PRD v1.1 §8.3.B & §8.3.A).
void main() {
  group('PinThrottle (AC-8.10)', () {
    final now = DateTime(2026, 8, 12, 10);

    test('4 kali salah belum mengunci apa pun', () {
      var state = const PinThrottleState();
      for (var i = 0; i < 4; i++) {
        state = PinThrottle.registerFailure(state, now);
      }
      expect(state.failedAttempts, 4);
      expect(state.isLocked(now), isFalse);
    });

    test('kesalahan ke-5 mengunci keypad 30 detik', () {
      var state = const PinThrottleState();
      for (var i = 0; i < 5; i++) {
        state = PinThrottle.registerFailure(state, now);
      }
      expect(state.isLocked(now), isTrue);
      expect(state.remaining(now), const Duration(seconds: 30));
      // Lewat 30 detik → terbuka lagi, tanpa penghapusan data apa pun.
      expect(state.isLocked(now.add(const Duration(seconds: 31))), isFalse);
    });

    test('kuncian berlipat tiap ronde & berhenti di 5 menit', () {
      expect(PinThrottle.lockDurationFor(1), const Duration(seconds: 30));
      expect(PinThrottle.lockDurationFor(2), const Duration(minutes: 1));
      expect(PinThrottle.lockDurationFor(3), const Duration(minutes: 2));
      expect(PinThrottle.lockDurationFor(4), const Duration(minutes: 4));
      expect(PinThrottle.lockDurationFor(5), const Duration(minutes: 5));
      expect(PinThrottle.lockDurationFor(99), const Duration(minutes: 5));
    });

    test('ronde kedua (10 kali salah) mengunci 1 menit', () {
      var state = const PinThrottleState();
      for (var i = 0; i < 10; i++) {
        state = PinThrottle.registerFailure(state, now);
      }
      expect(state.remaining(now), const Duration(minutes: 1));
    });

    test(
      'keadaan bisa dipulihkan apa adanya dari penyimpanan — hitungan '
      'bertahan setelah aplikasi ditutup-buka',
      () {
        var state = const PinThrottleState();
        for (var i = 0; i < 5; i++) {
          state = PinThrottle.registerFailure(state, now);
        }
        // Simulasi "aplikasi ditutup lalu dibuka lagi": keadaan dibangun
        // ulang dari nilai tersimpan, bukan dari memori.
        final restored = PinThrottleState(
          failedAttempts: state.failedAttempts,
          lockedUntil: state.lockedUntil,
        );
        expect(restored.isLocked(now.add(const Duration(seconds: 5))), isTrue);
      },
    );

    test('PIN benar mereset hitungan sepenuhnya', () {
      expect(PinThrottle.cleared.failedAttempts, 0);
      expect(PinThrottle.cleared.isLocked(now), isFalse);
    });

    test('pesan tunggu memakai satuan yang wajar', () {
      expect(
        PinThrottle.waitMessage(const Duration(seconds: 30)),
        contains('30 detik'),
      );
      expect(
        PinThrottle.waitMessage(const Duration(minutes: 5)),
        contains('5 menit'),
      );
    });
  });

  group('RecoveryCode (AC-8.3)', () {
    test('kode 8 karakter, berpemisah, tanpa huruf ambigu', () {
      for (var i = 0; i < 50; i++) {
        final code = RecoveryCode.generate();
        expect(code, matches(r'^[0-9A-Z]{4}-[0-9A-Z]{4}$'));
        expect(code.contains('I'), isFalse);
        expect(code.contains('L'), isFalse);
        expect(code.contains('O'), isFalse);
        expect(code.contains('U'), isFalse);
      }
    });

    test('dua kode berturut-turut tidak sama', () {
      final codes = {for (var i = 0; i < 20; i++) RecoveryCode.generate()};
      expect(codes.length, greaterThan(1));
    });

    test('normalisasi memaafkan salah baca tulisan tangan', () {
      final code = RecoveryCode.normalize('7qk4-m2xb');
      expect(RecoveryCode.normalize('7QK4M2XB'), code);
      expect(RecoveryCode.normalize(' 7qk4 m2xb '), code);
      // O/0 dan I/1 yang tertukar tetap diterima.
      expect(RecoveryCode.normalize('O1I'), '011');
    });

    test('bentuk kode diperiksa sebelum dibandingkan', () {
      expect(RecoveryCode.isWellFormed('7QK4-M2XB'), isTrue);
      expect(RecoveryCode.isWellFormed('7QK4'), isFalse);
      expect(RecoveryCode.isWellFormed('7QK4-M2XB9'), isFalse);
    });
  });
}
