import 'dart:typed_data';

/// Jenis lisensi yang dijual (PRD v1.1 §6.1).
enum LicenseType {
  /// Masa coba 3 hari, kedaluwarsanya **absolut** (tertanam di kode) —
  /// itulah yang membuat trial tidak bisa direset dengan memasang ulang.
  coba(0x01, 'Coba', 3, 0),

  /// Sekali beli, dipakai selamanya di perangkat itu.
  selamanya(0x02, 'Selamanya', null, 0),

  /// 365 hari + masa tenggang 7 hari.
  tahunan(0x03, 'Tahunan', 365, 7);

  const LicenseType(
    this.code,
    this.label,
    this.defaultDurationDays,
    this.defaultGraceDays,
  );

  /// Nilai byte 1 di muatan.
  final int code;

  /// Label Bahasa Indonesia untuk UI & keluaran tool.
  final String label;

  /// Lama berlaku default saat diterbitkan; `null` = tanpa kedaluwarsa.
  final int? defaultDurationDays;

  /// Masa tenggang default (ikut ditandatangani, K-6.13).
  final int defaultGraceDays;

  static LicenseType? fromCode(int code) {
    for (final type in LicenseType.values) {
      if (type.code == code) return type;
    }
    return null;
  }

  static LicenseType? fromName(String raw) {
    final lower = raw.trim().toLowerCase();
    for (final type in LicenseType.values) {
      if (type.name == lower || type.label.toLowerCase() == lower) return type;
    }
    // Sinonim yang wajar diketik penjual.
    return switch (lower) {
      'trial' => LicenseType.coba,
      'lifetime' => LicenseType.selamanya,
      'yearly' || 'tahun' => LicenseType.tahunan,
      _ => null,
    };
  }
}

/// Muatan 9 byte yang ditandatangani (PRD v1.1 §6.3.D).
///
/// | Byte | Isi |
/// |---|---|
/// | 0 | versi format (`0x01`) |
/// | 1 | jenis lisensi |
/// | 2–3 | tanggal terbit, uint16 BE, hari sejak 2020-01-01 UTC |
/// | 4–5 | tanggal kedaluwarsa; `0xFFFF` = tanpa kedaluwarsa |
/// | 6 | masa tenggang (hari) |
/// | 7–8 | petunjuk perangkat (16 bit pertama SHA-256 kode perangkat) |
///
/// Jenis, tanggal, dan masa tenggang **tidak pernah** disimpan terpisah di
/// aplikasi (K-6.1): semuanya diturunkan ulang dari token setiap *cold
/// start*, sehingga tidak ada nilai turunan yang bisa melenceng dari
/// tanda tangannya.
class LicensePayload {
  const LicensePayload({
    required this.version,
    required this.type,
    required this.issuedDay,
    required this.expiryDay,
    required this.graceDays,
    required this.deviceHint,
  });

  /// Versi format yang dikenal aplikasi ini. Muatan dengan versi LEBIH BESAR
  /// menghasilkan pesan "perbarui aplikasi", bukan "kode tidak sah"
  /// (AC-6.21) — kait yang membuat format v2 kelak tidak menyakiti siapa pun.
  static const int currentVersion = 0x01;

  /// Panjang muatan dalam byte.
  static const int lengthInBytes = 9;

  /// Nilai byte 4–5 untuk "tanpa kedaluwarsa" (lisensi selamanya).
  static const int noExpiry = 0xFFFF;

  /// Titik nol penanggalan muatan.
  static final DateTime epoch = DateTime.utc(2020, 1, 1);

  final int version;
  final LicenseType type;
  final int issuedDay;
  final int expiryDay;
  final int graceDays;
  final int deviceHint;

  bool get isLifetime => expiryDay == noExpiry;

  DateTime get issuedAt => dayToDate(issuedDay);

  /// Hari pertama saat lisensi sudah TIDAK berlaku (`hariIni < expiry` =
  /// aktif, PRD §6.3.E). `null` untuk lisensi selamanya.
  DateTime? get expiresAt => isLifetime ? null : dayToDate(expiryDay);

  /// Hari pertama setelah masa tenggang habis. `null` untuk selamanya.
  int? get graceEndDay => isLifetime ? null : expiryDay + graceDays;

  /// Tanggal (UTC) → nomor hari sejak [epoch].
  static int dateToDay(DateTime date) {
    final utc = DateTime.utc(
      date.toUtc().year,
      date.toUtc().month,
      date.toUtc().day,
    );
    return utc.difference(epoch).inDays;
  }

  static DateTime dayToDate(int day) => epoch.add(Duration(days: day));

  Uint8List toBytes() {
    final bytes = Uint8List(lengthInBytes);
    bytes[0] = version & 0xFF;
    bytes[1] = type.code;
    bytes[2] = (issuedDay >> 8) & 0xFF;
    bytes[3] = issuedDay & 0xFF;
    bytes[4] = (expiryDay >> 8) & 0xFF;
    bytes[5] = expiryDay & 0xFF;
    bytes[6] = graceDays & 0xFF;
    bytes[7] = (deviceHint >> 8) & 0xFF;
    bytes[8] = deviceHint & 0xFF;
    return bytes;
  }

  /// Baca muatan mentah. [type] boleh `null` bila kodenya tidak dikenal —
  /// pemanggil (verifier) yang memutuskan pesannya.
  static ({int version, LicenseType? type, LicensePayload? payload}) parse(
    List<int> bytes,
  ) {
    if (bytes.length < lengthInBytes) {
      return (version: 0, type: null, payload: null);
    }
    final version = bytes[0];
    final type = LicenseType.fromCode(bytes[1]);
    if (type == null) {
      return (version: version, type: null, payload: null);
    }
    return (
      version: version,
      type: type,
      payload: LicensePayload(
        version: version,
        type: type,
        issuedDay: (bytes[2] << 8) | bytes[3],
        expiryDay: (bytes[4] << 8) | bytes[5],
        graceDays: bytes[6],
        deviceHint: (bytes[7] << 8) | bytes[8],
      ),
    );
  }

  @override
  String toString() =>
      'LicensePayload(v$version, ${type.name}, terbit=$issuedDay, '
      'kedaluwarsa=${isLifetime ? "-" : expiryDay}, tenggang=$graceDays, '
      'petunjuk=0x${deviceHint.toRadixString(16).padLeft(4, "0")})';
}
