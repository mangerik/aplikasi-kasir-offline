import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/constants/app_palette.dart';
import 'package:kasir_warung/core/constants/app_sizes.dart';
import 'package:kasir_warung/core/constants/app_theme.dart';
import 'package:kasir_warung/core/widgets/app_bar_chart.dart';

/// Grafik batang buatan sendiri (PRD v1.1 §9.6, K-9.1).
///
/// Yang diuji di sini bukan "kelihatan bagus" (itu urusan mata di device),
/// melainkan hal-hal yang diam-diam bisa salah: tinggi batang proporsional
/// terhadap nilainya, area sentuh yang tidak punya lubang, penjarangan
/// label, kelakuan saat SEMUA nilai nol, dan bahwa warnanya benar-benar
/// mengikuti tema (AC-9.9).
void main() {
  /// Membungkus [child] dengan tema aplikasi yang sebenarnya (bukan
  /// `MaterialApp` polos) supaya `context.palette` terisi persis seperti
  /// di aplikasi.
  Widget wrap(Widget child, {required Brightness brightness}) {
    return MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 360, child: child),
        ),
      ),
    );
  }

  List<AppBarChartEntry> entries(List<int> values) => [
        for (var i = 0; i < values.length; i++)
          AppBarChartEntry(
            label: i.toString().padLeft(2, '0'),
            value: values[i],
            valueText: 'Rp${values[i]}',
          ),
      ];

  group('AppBarChartMetrics — geometri', () {
    test('slot batang membagi habis lebar area gambar (tanpa lubang sentuh)',
        () {
      const plotWidth = 312.0;
      const count = 7;
      final slot = AppBarChartMetrics.slotWidth(plotWidth, count);
      expect(slot * count, closeTo(plotWidth, 0.001));
    });

    test('area sentuh batang selebar SLOT, dan >= 48dp selama batangnya '
        'cukup sedikit untuk muat (AC-9.8, K-9.7)', () {
      // 360dp layar - 2*16 padding layar - 2*16 padding kartu - 48 sumbu Y.
      const plotWidth = 360.0 - 32 - 32 - AppBarChart.axisWidth;

      // Sampai 5 batang, slotnya melewati batas 48dp.
      expect(
        AppBarChartMetrics.slotWidth(plotWidth, 5),
        greaterThanOrEqualTo(AppSizes.minTouchTarget),
      );

      // Di atas itu, 48dp per batang MUSTAHIL secara aritmetika: 7 x 48 =
      // 336dp sedangkan seluruh lebar layar HP 5 inci cuma 360dp, dan PRD
      // §9.3.A sendiri meminta 24 batang untuk rentang satu hari. Yang
      // dijamin sebagai gantinya (K-9.7): slot bersambungan tanpa lubang
      // dan setinggi seluruh area gambar, sehingga tidak ada tap yang
      // gagal memilih batang.
      expect(AppBarChart.plotHeight, greaterThanOrEqualTo(AppSizes.minTouchTarget));
      expect(
        AppBarChartMetrics.slotWidth(plotWidth, 24) * 24,
        closeTo(plotWidth, 0.001),
      );
    });

    test('batang yang tergambar dijepit 3–28dp, area sentuhnya tidak', () {
      // Dua batang: slot sangat lebar, tapi batangnya tidak menjadi balok.
      expect(AppBarChartMetrics.barWidth(150), 28);
      // 24 batang di layar sempit: batang tipis, tapi tetap tergambar.
      expect(AppBarChartMetrics.barWidth(9), greaterThanOrEqualTo(3));
    });

    test('indexAt memetakan setiap titik ke satu batang — tidak ada zona mati',
        () {
      const plotWidth = 240.0;
      const count = 24;
      final seen = <int>{};
      for (var dx = 0.0; dx < plotWidth; dx += 1) {
        seen.add(AppBarChartMetrics.indexAt(dx, plotWidth, count));
      }
      expect(seen.length, count);
      expect(AppBarChartMetrics.indexAt(-5, plotWidth, count), 0);
      expect(AppBarChartMetrics.indexAt(9999, plotWidth, count), count - 1);
    });

    test('label dijarangkan saat slot menyempit, tidak saat lega (AC-9.12)',
        () {
      expect(AppBarChartMetrics.labelStep(50, 7, 32), 1);
      expect(AppBarChartMetrics.labelStep(10, 24, 32), 4);
      expect(AppBarChartMetrics.labelStep(32, 24, 32), 1);
    });
  });

  group('AppBarChart — render', () {
    testWidgets('tinggi batang proporsional terhadap nilainya', (tester) async {
      await tester.pumpWidget(
        wrap(
          AppBarChart(entries: entries([100, 50, 0]), animate: false),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();

      final boxes = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .toList();
      expect(boxes, hasLength(3));
      expect(boxes[0].heightFactor, closeTo(1.0, 0.001));
      expect(boxes[1].heightFactor, closeTo(0.5, 0.001));
      expect(boxes[2].heightFactor, closeTo(0.0, 0.001));
    });

    testWidgets('semua nilai nol tidak menghasilkan NaN maupun batang penuh '
        '(AC-9.11)', (tester) async {
      await tester.pumpWidget(
        wrap(
          AppBarChart(entries: entries([0, 0, 0, 0]), animate: false),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();

      final boxes =
          tester.widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox));
      for (final box in boxes) {
        expect(box.heightFactor, isNotNull);
        expect(box.heightFactor!.isNaN, isFalse);
        expect(box.heightFactor, 0);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('satu batang tetap tampil wajar (AC-9.11)', (tester) async {
      await tester.pumpWidget(
        wrap(
          AppBarChart(entries: entries([7500]), animate: false),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FractionallySizedBox), findsOneWidget);
      expect(find.text('00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sumbu Y hanya dua label: maksimum (ringkas) & nol',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          AppBarChart(
            entries: [
              const AppBarChartEntry(
                label: 'A',
                value: 1240000,
                valueText: 'Rp1.240.000',
              ),
              const AppBarChartEntry(
                label: 'B',
                value: 300000,
                valueText: 'Rp300.000',
              ),
            ],
            animate: false,
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1,2jt'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('tap memilih batang di bawah jari & tap ulang membatalkannya '
        '(AC-9.8)', (tester) async {
      int? selected;
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => AppBarChart(
              entries: entries([10, 20, 30, 40]),
              selectedIndex: selected,
              animate: false,
              onSelected: (index) => setState(() => selected = index),
            ),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();

      // Sisi paling kanan area gambar = batang terakhir.
      final chart = tester.getRect(find.byType(AppBarChart));
      await tester.tapAt(Offset(chart.right - 4, chart.center.dy));
      await tester.pumpAndSettle();
      expect(selected, 3);

      await tester.tapAt(Offset(chart.right - 4, chart.center.dy));
      await tester.pumpAndSettle();
      expect(selected, isNull, reason: 'tap ulang batang yang sama melepas pilihan');
    });

    testWidgets('label sumbu X dijarangkan pada 24 batang, semua tampil pada '
        '7 batang (AC-9.12)', (tester) async {
      await tester.pumpWidget(
        wrap(
          AppBarChart(
            entries: entries(List<int>.filled(24, 1000)),
            animate: false,
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      final dense = find.byType(Text).evaluate().length;

      await tester.pumpWidget(
        wrap(
          AppBarChart(entries: entries(List<int>.filled(7, 1000)), animate: false),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      final sparse = find.byType(Text).evaluate().length;

      // 24 batang tidak boleh menghasilkan 24 label (+2 label sumbu Y).
      expect(dense, lessThan(24));
      // 7 batang muat semuanya: 7 label + 2 label sumbu Y.
      expect(sparse, 9);
    });

    testWidgets('setiap batang punya semantics berisi angka persisnya '
        '(aksesibilitas)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          AppBarChart(entries: entries([1000, 2000]), animate: false),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('00: Rp1000'), findsOneWidget);
      expect(find.bySemanticsLabel('01: Rp2000'), findsOneWidget);
      handle.dispose();
    });
  });

  group('AppBarChart — tema (AC-9.9)', () {
    /// Warna batang diambil dari palet, bukan hex tetap: nilainya WAJIB
    /// berbeda antara terang & gelap.
    Future<Color> barColor(WidgetTester tester, Brightness brightness) async {
      await tester.pumpWidget(
        wrap(
          AppBarChart(entries: entries([100, 50]), animate: false),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      final decorated = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(FractionallySizedBox).first,
              matching: find.byType(DecoratedBox),
            ),
          )
          .first;
      return (decorated.decoration as BoxDecoration).color!;
    }

    testWidgets('warna batang mengikuti palet terang & gelap', (tester) async {
      final light = await barColor(tester, Brightness.light);
      final dark = await barColor(tester, Brightness.dark);

      expect(light, const AppPalette.light().primary200);
      expect(dark, const AppPalette.dark().primary200);
      expect(light, isNot(dark));
    });

    testWidgets('grafik ter-render tanpa exception di kedua tema',
        (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          wrap(
            AppBarChart(
              entries: entries(List<int>.generate(24, (i) => i * 1000)),
              highlightIndex: 23,
              animate: true,
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('AppStackedBar (AC-9.10)', () {
    testWidgets('setiap deret punya LABEL TEKS, nominal & persentase — tidak '
        'dibedakan hanya oleh warna', (tester) async {
      await tester.pumpWidget(
        wrap(
          AppStackedBar(
            animate: false,
            segments: [
              const AppStackedBarSegment(
                label: 'Tunai',
                value: 750000,
                valueText: 'Rp750.000',
                color: Color(0xFF1B7A43),
                caption: '15 transaksi',
              ),
              const AppStackedBarSegment(
                label: 'Non-tunai',
                value: 250000,
                valueText: 'Rp250.000',
                color: Color(0xFF2D6E9E),
              ),
            ],
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tunai'), findsOneWidget);
      expect(find.text('Non-tunai'), findsOneWidget);
      expect(find.text('Rp750.000'), findsOneWidget);
      expect(find.text('75% · 15 transaksi'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('deret kecil sekali tetap punya lebar & label, tidak "0%"',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          AppStackedBar(
            animate: false,
            segments: [
              const AppStackedBarSegment(
                label: 'Tunai',
                value: 1000000,
                valueText: 'Rp1.000.000',
                color: Color(0xFF1B7A43),
              ),
              const AppStackedBarSegment(
                label: 'Hutang',
                value: 1000,
                valueText: 'Rp1.000',
                color: Color(0xFFC98A2E),
              ),
            ],
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hutang'), findsOneWidget);
      expect(find.text('<1%'), findsOneWidget);
      final flexes = tester
          .widgetList<Expanded>(find.byType(Expanded))
          .map((e) => e.flex)
          .toList();
      expect(flexes.every((f) => f >= 1), isTrue);
    });
  });

  group('AppHorizontalBarChart', () {
    testWidgets('menampilkan nama, nominal, keterangan & bar proporsi',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const AppHorizontalBarChart(
            animate: false,
            entries: [
              AppBarChartEntry(
                label: 'Teh Botol Sosro Kotak 250ml',
                value: 40,
                valueText: 'Rp200.000',
                caption: '40 pcs terjual',
              ),
              AppBarChartEntry(
                label: 'Indomie Goreng',
                value: 10,
                valueText: 'Rp30.000',
                caption: '10 pcs terjual',
              ),
            ],
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Teh Botol Sosro Kotak 250ml'), findsOneWidget);
      expect(find.text('Rp30.000'), findsOneWidget);
      expect(find.text('10 pcs terjual'), findsOneWidget);

      final boxes = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .toList();
      expect(boxes[0].widthFactor, closeTo(1.0, 0.001));
      expect(boxes[1].widthFactor, closeTo(0.25, 0.001));
      expect(tester.takeException(), isNull);
    });
  });
}
