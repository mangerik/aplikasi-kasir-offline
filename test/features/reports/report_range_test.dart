import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/domain/entities/sales_series.dart';
import 'package:kasir_warung/features/reports/providers/report_providers.dart';

/// Rentang **periode sebelumnya** untuk kalimat perbandingan grafik tren
/// (PRD v1.1 §9.3.A, AC-9.7).
///
/// Bagian yang gampang salah dan mahal: periode pembanding harus sama
/// panjang dan menempel PERSIS di depan rentang berjalan. Meleset satu
/// hari saja membuat "+12%" berbohong tanpa satu pun error muncul.
void main() {
  group('ReportDateRange.previousPeriod (AC-9.7)', () {
    test('rentang 7 hari dibandingkan dengan 7 hari TEPAT sebelumnya', () {
      final range = ReportDateRange.custom(
        start: DateTime(2026, 8, 6),
        end: DateTime(2026, 8, 12),
      );
      final previous = range.previousPeriod;

      expect(range.dayCount, 7);
      expect(previous.dayCount, 7);
      expect(previous.start, DateTime(2026, 7, 30));
      expect(previous.end, DateTime(2026, 8, 5, 23, 59, 59, 999));
      // Menempel tanpa celah & tanpa tumpang tindih.
      expect(
        previous.end.add(const Duration(milliseconds: 1)),
        range.start,
      );
    });

    test('rentang "hari ini" dibandingkan dengan kemarin', () {
      final range = ReportDateRange.custom(
        start: DateTime(2026, 8, 12),
        end: DateTime(2026, 8, 12),
      );
      final previous = range.previousPeriod;

      expect(range.dayCount, 1);
      expect(previous.start, DateTime(2026, 8, 11));
      expect(previous.end, DateTime(2026, 8, 11, 23, 59, 59, 999));
    });

    test('mundur melewati pergantian bulan & tahun mengikuti kalender', () {
      final range = ReportDateRange.custom(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 5),
      );
      final previous = range.previousPeriod;

      expect(previous.start, DateTime(2025, 12, 27));
      expect(previous.end, DateTime(2025, 12, 31, 23, 59, 59, 999));
      expect(previous.dayCount, range.dayCount);
    });

    test('bulan berjalan dibandingkan dengan periode sama panjang, bukan '
        'dengan bulan penuh sebelumnya', () {
      // "Bulan Ini" pada tanggal 12 berarti 12 hari — pembandingnya 12 hari
      // sebelum tanggal 1, bukan seluruh Juli.
      final range = ReportDateRange.custom(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 12),
      );
      final previous = range.previousPeriod;

      expect(range.dayCount, 12);
      expect(previous.start, DateTime(2026, 7, 20));
      expect(previous.end, DateTime(2026, 7, 31, 23, 59, 59, 999));
    });
  });

  group('ReportDateRange.bucket', () {
    test('preset bawaan memilih ember sesuai aturan PRD §9.3.A', () {
      expect(ReportDateRange.today().bucket, SeriesBucket.hour);
      expect(ReportDateRange.yesterday().bucket, SeriesBucket.hour);
      expect(ReportDateRange.last7Days().bucket, SeriesBucket.day);
      expect(
        ReportDateRange.custom(
          start: DateTime(2024),
          end: DateTime(2025, 2, 4),
        ).bucket,
        SeriesBucket.month,
      );
    });
  });
}
