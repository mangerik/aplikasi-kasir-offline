import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/constants/app_theme.dart';
import 'package:kasir_warung/core/widgets/app_widgets.dart';

/// Regresi untuk temuan agent area Transaksi & Laporan: [AppPill] dipakai
/// untuk data dinamis (nama pelanggan, nomor struk) dan meluber keluar layar.
/// Label kini SELALU satu baris + elipsis, dan pill ikut menyusut selama
/// lebar yang diterimanya terbatas.
void main() {
  const longLabel = 'Bu Siti Nurhaliza Warung Sebelah Jalan Raya No. 123';

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('teks pendek: pill tetap menciut ke lebar isinya', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 300,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppPill(label: 'Lunas', tone: AppTone.success),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(AppPill));
    expect(size.width, lessThan(150), reason: 'pill tidak boleh melar');
    expect(tester.takeException(), isNull);
  });

  testWidgets('teks panjang di ruang sempit: menyusut, tanpa overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 100,
          child: AppPill(label: longLabel, tone: AppTone.accent),
        ),
      ),
    );

    expect(tester.getSize(find.byType(AppPill)).width, lessThanOrEqualTo(100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('teks panjang + ikon di dalam Row (dibungkus Flexible)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 160,
          child: Row(
            children: [
              Icon(Icons.person_outline),
              Flexible(
                child: AppPill(
                  label: longLabel,
                  icon: Icons.schedule,
                  tone: AppTone.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('teks panjang di dalam Wrap sempit', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 120,
          child: Wrap(
            children: [
              AppPill(label: 'Tunai', tone: AppTone.success),
              AppPill(label: longLabel, tone: AppTone.info),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('anak langsung Row (lebar tak terbatas) tidak melempar assertion', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              AppPill(label: longLabel, tone: AppTone.neutral),
              AppPill(label: 'Batal', tone: AppTone.danger, filled: true),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('maxWidth membatasi pill di tempat berlebar tak terbatas', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppPill(label: longLabel, tone: AppTone.accent, maxWidth: 120),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byType(AppPill)).width, lessThanOrEqualTo(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('label dense pun ikut dipotong, bukan meluber', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 90,
          child: AppPill(label: longLabel, dense: true),
        ),
      ),
    );

    expect(tester.getSize(find.byType(AppPill)).width, lessThanOrEqualTo(90));
    expect(tester.takeException(), isNull);
  });
}
