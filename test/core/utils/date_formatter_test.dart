import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';

void main() {
  setUpAll(() async {
    await DateFormatter.init();
  });

  // 11 Agustus 2026 adalah hari Selasa.
  final sample = DateTime(2026, 8, 11, 14, 5);

  group('DateFormatter', () {
    test('formatDate menghasilkan format tanggal lengkap Indonesia', () {
      expect(DateFormatter.formatDate(sample), '11 Agustus 2026');
    });

    test('formatDateShort menghasilkan format tanggal singkat', () {
      expect(DateFormatter.formatDateShort(sample), '11 Agu 2026');
    });

    test('formatDateTime menyertakan jam:menit', () {
      expect(DateFormatter.formatDateTime(sample), '11 Agu 2026, 14:05');
    });

    test('formatTime hanya menampilkan jam:menit', () {
      expect(DateFormatter.formatTime(sample), '14:05');
    });

    test('formatDayDate menyertakan nama hari Indonesia', () {
      expect(DateFormatter.formatDayDate(sample), 'Selasa, 11 Agustus 2026');
    });

    test('formatInvoiceDay menghasilkan yyyyMMdd', () {
      expect(DateFormatter.formatInvoiceDay(sample), '20260811');
    });

    test('toEpochMillis dan fromEpochMillis konsisten pulang-pergi', () {
      final utcDate = DateTime.utc(2026, 8, 11, 7, 0, 0);
      final millis = DateFormatter.toEpochMillis(utcDate);
      final restored = DateFormatter.fromEpochMillis(millis);
      expect(restored.toUtc(), utcDate);
    });
  });
}
