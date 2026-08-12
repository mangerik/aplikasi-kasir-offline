/// Aturan program poin (PRD v1.1 §7.3.C) — disimpan sebagai empat baris
/// `settings` dan **mati secara default** (prinsip PRD §1.3 poin 6).
///
/// Saat [enabled] `false`, seluruh elemen poin WAJIB tersembunyi di layar
/// mana pun, termasuk struk (AC-7.6).
class PointsSettings {
  const PointsSettings({
    this.enabled = false,
    this.rupiahPerPoint = defaultRupiahPerPoint,
    this.valuePerPoint = defaultValuePerPoint,
    this.minRedeem = defaultMinRedeem,
  });

  /// Key tabel `settings`.
  static const String keyEnabled = 'points_enabled';
  static const String keyRupiahPerPoint = 'points_rupiah_per_point';
  static const String keyValuePerPoint = 'points_value_per_point';
  static const String keyMinRedeem = 'points_min_redeem';

  static const int defaultRupiahPerPoint = 10000;
  static const int defaultValuePerPoint = 500;
  static const int defaultMinRedeem = 10;

  /// Program poin aktif — **default mati** (AC-7.6).
  final bool enabled;

  /// Berapa rupiah belanja untuk mendapat 1 poin.
  final int rupiahPerPoint;

  /// Nilai tukar 1 poin dalam rupiah.
  final int valuePerPoint;

  /// Minimum poin yang boleh ditukar sekaligus.
  final int minRedeem;

  /// Poin yang didapat dari [total] belanja (SUDAH bersih dari seluruh
  /// diskon termasuk potongan penukaran poin, AC-7.10). Pembulatan ke
  /// bawah, tidak pernah negatif (AC-7.7).
  int pointsFor(int total) {
    if (!enabled || rupiahPerPoint <= 0 || total <= 0) return 0;
    return total ~/ rupiahPerPoint;
  }

  /// Nilai rupiah dari [points] poin yang ditukar.
  int rupiahFor(int points) {
    if (!enabled || points <= 0) return 0;
    return points * valuePerPoint;
  }

  /// Poin maksimum yang masuk akal ditukar pada transaksi bernilai
  /// [total]: dibatasi saldo [balance] DAN tidak boleh melebihi nilai
  /// transaksi (menukar lebih dari itu hanya membuang poin pelanggan).
  int maxRedeemable({required int balance, required int total}) {
    if (!enabled || valuePerPoint <= 0) return 0;
    final byTotal = total ~/ valuePerPoint;
    final capped = balance < byTotal ? balance : byTotal;
    return capped < 0 ? 0 : capped;
  }

  /// `true` bila [balance] sudah memenuhi syarat minimum penukaran.
  bool canRedeem({required int balance, required int total}) =>
      enabled &&
      balance >= minRedeem &&
      maxRedeemable(balance: balance, total: total) >= minRedeem;

  PointsSettings copyWith({
    bool? enabled,
    int? rupiahPerPoint,
    int? valuePerPoint,
    int? minRedeem,
  }) {
    return PointsSettings(
      enabled: enabled ?? this.enabled,
      rupiahPerPoint: rupiahPerPoint ?? this.rupiahPerPoint,
      valuePerPoint: valuePerPoint ?? this.valuePerPoint,
      minRedeem: minRedeem ?? this.minRedeem,
    );
  }
}
