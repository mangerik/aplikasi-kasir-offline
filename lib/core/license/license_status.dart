import 'license_payload.dart';

/// Enam keadaan lisensi (PRD v1.1 §6.3.E).
///
/// Semuanya **diturunkan** dari token + waktu acuan, tidak ada satu pun
/// yang disimpan sebagai "keadaan" tersendiri — supaya tidak pernah ada dua
/// sumber kebenaran yang bisa melenceng (K-6.1).
enum LicenseState {
  /// Belum pernah ada token sah → layar Aktivasi mengunci seluruh aplikasi.
  belumAktif,

  /// Lifetime, atau `hariIni < hariKedaluwarsa`.
  aktif,

  /// Sisa ≤ 7 hari (trial: ≤ 1 hari) → normal + banner peringatan.
  akanBerakhir,

  /// Lewat kedaluwarsa, masih dalam tenggang → normal + banner merah.
  masaTenggang,

  /// Tenggang habis → layar Kasir dikunci, sisanya tetap terbuka.
  kedaluwarsaTahunan,

  /// Masa coba habis (tanpa tenggang) → layar ajakan beli.
  kedaluwarsaTrial;

  /// Boleh membuat/menyimpan transaksi baru?
  ///
  /// Perhatikan: `masaTenggang` **boleh** — masa tenggang berfungsi penuh,
  /// yang berubah hanya bannernya.
  bool get canSell =>
      this == LicenseState.aktif ||
      this == LicenseState.akanBerakhir ||
      this == LicenseState.masaTenggang;

  /// Seluruh aplikasi terkunci (layar di luar shell)?
  bool get locksWholeApp =>
      this == LicenseState.belumAktif || this == LicenseState.kedaluwarsaTrial;
}

/// Potret lisensi pada satu titik waktu.
class LicenseStatus {
  const LicenseStatus({
    required this.state,
    required this.referenceTime,
    this.payload,
    this.activatedAt,
    this.remainingDays,
    this.graceRemainingDays,
    this.clockRolledBack = false,
    this.gateDisabled = false,
  });

  /// Keadaan khusus **test & pengembangan**: gerbang lisensi dimatikan.
  ///
  /// Dipakai sebagai nilai default `licenseBootstrapProvider` supaya seluruh
  /// widget test M0–M9 — yang tidak tahu-menahu soal lisensi — tetap bisa
  /// membangun `KasirApp`. `main()` **selalu** menggantinya dengan hasil
  /// [evaluateLicense] yang sebenarnya; penjaganya ada di
  /// `test/features/license/license_bootstrap_wiring_test.dart`.
  ///
  /// Sengaja bukan `kDebugMode`: sebuah bendera yang terbaca jelas di
  /// keadaan itu sendiri jauh lebih sulit tertinggal diam-diam daripada
  /// cabang `if (kDebugMode)` yang tersebar di jalur gerbang.
  factory LicenseStatus.gerbangDimatikan() => LicenseStatus(
    state: LicenseState.aktif,
    referenceTime: DateTime.now(),
    gateDisabled: true,
  );

  /// Keadaan "belum aktif" — dipakai saat token kosong atau tidak lolos
  /// verifikasi lagi (mis. kunci penerbitnya sudah dicabut).
  factory LicenseStatus.belumAktif({
    required DateTime referenceTime,
    bool clockRolledBack = false,
  }) => LicenseStatus(
    state: LicenseState.belumAktif,
    referenceTime: referenceTime,
    clockRolledBack: clockRolledBack,
  );

  final LicenseState state;
  final DateTime referenceTime;
  final LicensePayload? payload;
  final DateTime? activatedAt;

  /// Sisa hari sampai kedaluwarsa (hanya saat masih berlaku).
  final int? remainingDays;

  /// Sisa hari masa tenggang (hanya saat [LicenseState.masaTenggang]).
  final int? graceRemainingDays;

  /// Jam perangkat tertinggal jauh di belakang waktu acuan (§6.3.G).
  final bool clockRolledBack;

  /// `true` hanya pada keadaan default test/pengembangan
  /// ([LicenseStatus.gerbangDimatikan]).
  final bool gateDisabled;

  LicenseType? get type => payload?.type;

  bool get isLifetime => payload?.isLifetime ?? false;

  DateTime? get expiresAt => payload?.expiresAt;

  /// Label jenis lisensi untuk UI ("Selamanya", "Tahunan", "Coba").
  String get typeLabel => payload?.type.label ?? '—';

  LicenseStatus copyWith({bool? clockRolledBack}) => LicenseStatus(
    state: state,
    referenceTime: referenceTime,
    payload: payload,
    activatedAt: activatedAt,
    remainingDays: remainingDays,
    graceRemainingDays: graceRemainingDays,
    clockRolledBack: clockRolledBack ?? this.clockRolledBack,
    gateDisabled: gateDisabled,
  );

  /// Turunkan keadaan dari muatan + waktu acuan.
  ///
  /// [referenceTime] WAJIB berupa waktu acuan monoton
  /// ([monotonicReferenceTime]), bukan jam perangkat mentah (K-6.8).
  static LicenseStatus evaluate({
    required LicensePayload? payload,
    required DateTime referenceTime,
    DateTime? activatedAt,
    bool clockRolledBack = false,
  }) {
    if (payload == null) {
      return LicenseStatus.belumAktif(
        referenceTime: referenceTime,
        clockRolledBack: clockRolledBack,
      );
    }
    if (payload.isLifetime) {
      return LicenseStatus(
        state: LicenseState.aktif,
        referenceTime: referenceTime,
        payload: payload,
        activatedAt: activatedAt,
        clockRolledBack: clockRolledBack,
      );
    }

    final today = LicensePayload.dateToDay(referenceTime);
    final remaining = payload.expiryDay - today;

    if (remaining > 0) {
      // Trial hanya diperingatkan pada hari terakhirnya: memasang banner
      // "berakhir 3 hari lagi" pada hari pertama masa coba akan terasa
      // seperti tagihan, bukan sambutan.
      final threshold = payload.type == LicenseType.coba ? 1 : 7;
      return LicenseStatus(
        state: remaining <= threshold
            ? LicenseState.akanBerakhir
            : LicenseState.aktif,
        referenceTime: referenceTime,
        payload: payload,
        activatedAt: activatedAt,
        remainingDays: remaining,
        clockRolledBack: clockRolledBack,
      );
    }

    final graceRemaining = payload.expiryDay + payload.graceDays - today;
    if (graceRemaining > 0) {
      return LicenseStatus(
        state: LicenseState.masaTenggang,
        referenceTime: referenceTime,
        payload: payload,
        activatedAt: activatedAt,
        remainingDays: 0,
        graceRemainingDays: graceRemaining,
        clockRolledBack: clockRolledBack,
      );
    }

    return LicenseStatus(
      state: payload.type == LicenseType.coba
          ? LicenseState.kedaluwarsaTrial
          : LicenseState.kedaluwarsaTahunan,
      referenceTime: referenceTime,
      payload: payload,
      activatedAt: activatedAt,
      remainingDays: 0,
      graceRemainingDays: 0,
      clockRolledBack: clockRolledBack,
    );
  }
}

/// Toleransi sebelum aplikasi menegur jam yang mundur (§6.3.G).
///
/// Sepuluh menit cukup untuk menyerap koreksi NTP biasa tanpa memicu
/// peringatan palsu — dan peringatan palsu adalah cara tercepat membuat
/// pengguna berhenti membaca peringatan.
const Duration kClockRollbackTolerance = Duration(minutes: 10);

/// Jam yang tidak bisa mundur (K-6.8).
///
/// ```
/// waktuAcuan = max(jam perangkat, license_last_seen_at,
///                  MAX(sales.created_at), license_activated_at)
/// ```
///
/// `MAX(sales.created_at)` adalah saksi yang **ikut terbawa restore backup**
/// — kasus yang paling mungkin terjadi dalam praktik (pengguna memulihkan
/// data di HP yang jamnya sudah dimundurkan).
DateTime monotonicReferenceTime({
  required DateTime deviceNow,
  DateTime? lastSeenAt,
  DateTime? lastSaleAt,
  DateTime? activatedAt,
}) {
  var result = deviceNow;
  for (final witness in [lastSeenAt, lastSaleAt, activatedAt]) {
    if (witness != null && witness.isAfter(result)) result = witness;
  }
  return result;
}

/// `true` bila jam perangkat tertinggal lebih dari [kClockRollbackTolerance]
/// di belakang waktu acuan.
///
/// Ini HANYA memicu banner. Jam kacau tidak pernah dijadikan alasan
/// mengunci aplikasi selama masa berlaku belum lewat — pengguna yang
/// baterainya habis dan jamnya ter-reset adalah pengguna jujur.
bool isClockRolledBack({
  required DateTime deviceNow,
  required DateTime referenceTime,
}) => referenceTime.difference(deviceNow) > kClockRollbackTolerance;
