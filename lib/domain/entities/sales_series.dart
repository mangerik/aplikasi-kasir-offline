/// Entitas deret data untuk **grafik penjualan** (PRD v1.1 §9.5, M14).
///
/// Semua angka di sini SELALU lahir dari agregasi SQL di
/// `ReportRepository.getSalesSeries`/`getHourlyDistribution` (K-9.5) —
/// tidak pernah dari penjumlahan baris mentah di Dart. Yang dikerjakan di
/// Dart hanyalah **pengisian ember kosong** (lihat [SeriesBucket]), karena
/// SQLite tidak punya `generate_series` dan menambal itu dengan CTE
/// rekursif jauh lebih mahal dibaca daripada satu perulangan tanggal.
library;

/// Ukuran ember (bucket) satu batang pada grafik tren (PRD §9.3.A).
enum SeriesBucket {
  /// Satu batang = satu jam. Dipakai untuk rentang 1 hari (24 batang).
  hour,

  /// Satu batang = satu hari. Dipakai untuk rentang 2–62 hari.
  day,

  /// Satu batang = satu bulan. Dipakai untuk rentang > 62 hari.
  month;

  /// Aturan ember otomatis PRD §9.3.A — dipilih dari **panjang rentang**,
  /// bukan dari preset yang dipakai, supaya rentang kustom pun konsisten.
  ///
  /// | Panjang rentang | Ember | Jumlah batang |
  /// |---|---|---|
  /// | 1 hari | per jam | 24 |
  /// | 2–62 hari | per hari | 2–62 |
  /// | > 62 hari | per bulan | ≤ ~24 |
  ///
  /// Batas 62 hari (bukan 60) dipilih supaya "dua bulan penuh" — termasuk
  /// pasangan bulan 31 hari — tetap tampil per hari, dan K-9.4 (maksimum
  /// ~90 batang) tidak pernah terlanggar.
  static SeriesBucket forRange(DateTime start, DateTime end) {
    final days = dayCount(start, end);
    if (days <= 1) return SeriesBucket.hour;
    if (days <= 62) return SeriesBucket.day;
    return SeriesBucket.month;
  }

  /// Jumlah hari kalender **inklusif** yang disentuh rentang [start]..[end].
  ///
  /// Dihitung dari tanggalnya saja (jam dibuang) supaya rentang laporan
  /// yang berakhir pukul 23:59:59.999 tidak terbaca sebagai "kurang dari
  /// satu hari".
  static int dayCount(DateTime start, DateTime end) {
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(end.year, end.month, end.day);
    // `difference().inDays` di DateTime lokal aman untuk Indonesia (tidak
    // ada DST); pembulatan lewat jam dihindari dengan menormalkan dulu.
    return b.difference(a).inDays + 1;
  }

  /// Awal ember yang memuat [moment] (waktu LOKAL).
  DateTime floor(DateTime moment) => switch (this) {
        SeriesBucket.hour =>
          DateTime(moment.year, moment.month, moment.day, moment.hour),
        SeriesBucket.day => DateTime(moment.year, moment.month, moment.day),
        SeriesBucket.month => DateTime(moment.year, moment.month),
      };

  /// Ember berikutnya setelah [bucketStart].
  ///
  /// Sengaja lewat konstruktor `DateTime` (bukan `add(Duration)`) supaya
  /// normalisasi kalender — 31 Januari + 1 bulan, 31 Desember + 1 hari —
  /// diurus Dart, bukan aritmetika tangan.
  DateTime next(DateTime bucketStart) => switch (this) {
        SeriesBucket.hour => DateTime(
            bucketStart.year,
            bucketStart.month,
            bucketStart.day,
            bucketStart.hour + 1,
          ),
        SeriesBucket.day => DateTime(
            bucketStart.year,
            bucketStart.month,
            bucketStart.day + 1,
          ),
        SeriesBucket.month =>
          DateTime(bucketStart.year, bucketStart.month + 1),
      };

  /// Kunci ember dalam bentuk teks — **wajib identik** dengan keluaran
  /// `strftime` di `ReportRepositoryImpl` (`'%Y-%m-%d %H'` / `'%Y-%m-%d'` /
  /// `'%Y-%m'` dengan `'localtime'`), karena kunci inilah yang menjodohkan
  /// hasil SQL dengan ember hasil pengisian di Dart.
  String keyOf(DateTime bucketStart) {
    final y = bucketStart.year.toString().padLeft(4, '0');
    final m = bucketStart.month.toString().padLeft(2, '0');
    final d = bucketStart.day.toString().padLeft(2, '0');
    final h = bucketStart.hour.toString().padLeft(2, '0');
    return switch (this) {
      SeriesBucket.hour => '$y-$m-$d $h',
      SeriesBucket.day => '$y-$m-$d',
      SeriesBucket.month => '$y-$m',
    };
  }

  /// Pola `strftime` SQLite yang menghasilkan [keyOf].
  String get strftimeFormat => switch (this) {
        SeriesBucket.hour => '%Y-%m-%d %H',
        SeriesBucket.day => '%Y-%m-%d',
        SeriesBucket.month => '%Y-%m',
      };
}

/// Satu batang pada grafik tren penjualan (PRD §9.3.A).
///
/// Ember yang tidak punya transaksi TETAP hadir dengan nilai nol — grafik
/// yang bolong menyembunyikan hari sepi, padahal hari sepi itulah
/// informasinya (AC-9.11).
class SalesPoint {
  const SalesPoint({
    required this.bucket,
    required this.start,
    required this.omzet,
    required this.grossProfit,
    required this.transactionCount,
  });

  /// Ukuran ember batang ini.
  final SeriesBucket bucket;

  /// Awal ember dalam waktu **lokal perangkat** (AC-9.4).
  final DateTime start;

  /// Total `sales.total` pada ember ini, tanpa transaksi `voided` (AC-9.3).
  final int omzet;

  /// Laba kotor pada ember ini — aturan hitungnya sama persis dengan
  /// `DailySummary.grossProfit` (item tanpa harga modal tidak ikut).
  final int grossProfit;

  /// Jumlah transaksi selesai pada ember ini.
  final int transactionCount;

  /// Batas akhir ember (eksklusif) — dipakai membuka Riwayat terfilter
  /// saat batang disentuh (PRD §9.3.A).
  DateTime get endExclusive => bucket.next(start);

  /// Nilai yang digambar sesuai metrik terpilih.
  int valueOf({required bool profit}) => profit ? grossProfit : omzet;
}

/// Satu batang pada grafik "jam ramai" (PRD §9.3.B).
///
/// Selalu 24 baris (jam 0–23) untuk rentang apa pun: jam tanpa transaksi
/// ditampilkan sebagai batang nol supaya "bentuk hari" terbaca utuh.
class HourlyPoint {
  const HourlyPoint({
    required this.hour,
    required this.omzet,
    required this.transactionCount,
  });

  /// 0–23, dalam waktu **lokal perangkat**.
  final int hour;
  final int omzet;
  final int transactionCount;
}
