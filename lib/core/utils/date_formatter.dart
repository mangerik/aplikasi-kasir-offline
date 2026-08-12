import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Formatter tanggal & waktu berbahasa Indonesia.
///
/// Semua waktu disimpan di database sebagai UTC epoch millis
/// (lihat architecture.md §4) dan ditampilkan dalam zona waktu perangkat.
///
/// PENTING: [DateFormatter.init] wajib dipanggil sekali (mis. di `main()`)
/// sebelum method format di kelas ini dipakai, agar data locale `id_ID`
/// sudah dimuat oleh package `intl`.
abstract final class DateFormatter {
  static const String _locale = 'id_ID';

  /// Memuat data locale `id_ID` untuk package `intl`. Panggil sekali saja,
  /// idealnya di awal `main()` sebelum `runApp`.
  static Future<void> init() => initializeDateFormatting(_locale);

  static final DateFormat _fullDate = DateFormat('d MMMM yyyy', _locale);
  static final DateFormat _shortDate = DateFormat('d MMM yyyy', _locale);
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm', _locale);
  static final DateFormat _time = DateFormat('HH:mm', _locale);
  static final DateFormat _dayDate = DateFormat('EEEE, d MMMM yyyy', _locale);
  static final DateFormat _invoiceDay = DateFormat('yyyyMMdd');

  // --- Label sumbu grafik (M14, PRD v1.1 §9.6). Sengaja SANGAT pendek:
  // label sumbu X berbagi ruang dengan 24–62 label lain di layar 5 inci.
  static final DateFormat _dayMonth = DateFormat('d/M', _locale);
  static final DateFormat _monthShort = DateFormat('MMM yy', _locale);
  static final DateFormat _monthFull = DateFormat('MMMM yyyy', _locale);

  /// Contoh: `11 Agustus 2026`.
  static String formatDate(DateTime date) => _fullDate.format(date.toLocal());

  /// Contoh: `11 Agu 2026`.
  static String formatDateShort(DateTime date) => _shortDate.format(date.toLocal());

  /// Contoh: `11 Agu 2026, 14:05`.
  static String formatDateTime(DateTime date) => _dateTime.format(date.toLocal());

  /// Contoh: `14:05`.
  static String formatTime(DateTime date) => _time.format(date.toLocal());

  /// Contoh: `Selasa, 11 Agustus 2026`.
  static String formatDayDate(DateTime date) => _dayDate.format(date.toLocal());

  /// Label sumbu X grafik harian, mis. `11/8`.
  static String formatDayMonth(DateTime date) => _dayMonth.format(date.toLocal());

  /// Label sumbu X grafik bulanan, mis. `Agu 26`. Tahunnya ikut karena
  /// rentang > 62 hari bisa melompati pergantian tahun.
  static String formatMonthShort(DateTime date) => _monthShort.format(date.toLocal());

  /// Judul ember bulanan pada kartu detail, mis. `Agustus 2026`.
  static String formatMonthFull(DateTime date) => _monthFull.format(date.toLocal());

  /// Bagian tanggal (`yyyyMMdd`) untuk penomoran invoice harian, mis. `20260811`.
  static String formatInvoiceDay(DateTime date) => _invoiceDay.format(date.toLocal());

  /// Konversi epoch millis (UTC, seperti disimpan di kolom `created_at`)
  /// menjadi [DateTime] lokal perangkat.
  static DateTime fromEpochMillis(int epochMillis) =>
      DateTime.fromMillisecondsSinceEpoch(epochMillis, isUtc: true).toLocal();

  /// Konversi [DateTime] menjadi epoch millis UTC untuk disimpan di database.
  static int toEpochMillis(DateTime date) => date.toUtc().millisecondsSinceEpoch;
}
