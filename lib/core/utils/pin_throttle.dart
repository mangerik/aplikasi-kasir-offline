/// Pembatas percobaan PIN (PRD v1.1 §8.3.B, AC-8.10).
///
/// Aturannya sengaja **menahan, bukan menghukum**: 5 kali salah → keypad
/// terkunci 30 detik, dan tiap ronde berikutnya berlipat sampai maksimal 5
/// menit. Tidak ada penghapusan data setelah sekian kali gagal — di
/// aplikasi warung, yang salah ketik berulang kali jauh lebih mungkin
/// pemiliknya sendiri daripada pencuri.
///
/// Keadaannya disimpan di `shared_preferences`, bukan di memori, supaya
/// hitungan **bertahan setelah aplikasi ditutup-buka** (AC-8.10) — kalau
/// tidak, gerbangnya bisa dilewati hanya dengan menutup aplikasi.
class PinThrottleState {
  const PinThrottleState({this.failedAttempts = 0, this.lockedUntil});

  final int failedAttempts;
  final DateTime? lockedUntil;

  /// Sisa waktu tunggu, atau `null` bila keypad sedang terbuka.
  Duration? remaining(DateTime now) {
    final until = lockedUntil;
    if (until == null) return null;
    final left = until.difference(now);
    return left.isNegative || left == Duration.zero ? null : left;
  }

  bool isLocked(DateTime now) => remaining(now) != null;
}

abstract final class PinThrottle {
  /// Jumlah kesalahan sebelum keypad terkunci.
  static const int maxAttempts = 5;

  /// Kuncian pertama.
  static const Duration baseLock = Duration(seconds: 30);

  /// Batas atas kuncian (PRD: "naik berlipat sampai maksimal 5 menit").
  static const Duration maxLock = Duration(minutes: 5);

  /// Durasi kuncian untuk ronde ke-[round] (1 = kuncian pertama).
  static Duration lockDurationFor(int round) {
    if (round <= 1) return baseLock;
    var seconds = baseLock.inSeconds;
    for (var i = 1; i < round; i++) {
      seconds *= 2;
      if (seconds >= maxLock.inSeconds) return maxLock;
    }
    return Duration(seconds: seconds);
  }

  /// Keadaan baru setelah satu PIN salah.
  static PinThrottleState registerFailure(PinThrottleState current, DateTime now) {
    final attempts = current.failedAttempts + 1;
    if (attempts % maxAttempts != 0) {
      return PinThrottleState(
        failedAttempts: attempts,
        lockedUntil: current.lockedUntil,
      );
    }
    final round = attempts ~/ maxAttempts;
    return PinThrottleState(
      failedAttempts: attempts,
      lockedUntil: now.add(lockDurationFor(round)),
    );
  }

  /// Keadaan setelah PIN benar — hitungan direset penuh.
  static const PinThrottleState cleared = PinThrottleState();

  /// Kalimat siap tampil untuk sisa waktu tunggu.
  static String waitMessage(Duration remaining) {
    final seconds = remaining.inSeconds + (remaining.inMilliseconds % 1000 > 0 ? 1 : 0);
    if (seconds < 60) return 'Terlalu banyak percobaan. Tunggu $seconds detik.';
    final minutes = (seconds / 60).ceil();
    return 'Terlalu banyak percobaan. Tunggu $minutes menit.';
  }
}
