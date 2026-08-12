/// Grafik batang bawaan Kasir Warung — **tanpa satu pun dependency grafik**
/// (PRD v1.1 K-9.1, AC-9.13).
///
/// Tiga bentuk, satu keluarga visual:
/// - [AppBarChart] — batang vertikal (tren penjualan, jam ramai).
/// - [AppHorizontalBarChart] — batang horizontal berlabel (produk terlaris).
/// - [AppStackedBar] — satu batang bertumpuk + legenda (komposisi metode
///   bayar). **Bukan** pie/donut (K-9.2).
///
/// Kenapa digambar sendiri, bukan memakai `fl_chart` (K-9.1):
/// 1. Proyek ini sudah dua kali gagal build karena dependency pihak ketiga
///    (`win32` di M0, `flutter_native_splash` di M6).
/// 2. Anggaran APK < 40 MB dan cold start < 3 detik.
/// 3. Pustaka grafik membawa bahasa visualnya sendiri yang harus dilawan
///    agar cocok dengan "Kertas & Daun".
///
/// Seluruh warna diambil dari `context.palette` (AC-9.9) — grafik ini ikut
/// berganti tema tanpa satu pun cabang `if (isDark)`. Bentuk visualnya
/// sengaja meneruskan pola **bar proporsi** yang sudah dipakai di kartu
/// metode bayar & produk terlaris sejak M4: batang berujung membulat di
/// atas alur (*track*) lembut, bukan gaya grafik yang asing di aplikasi ini.
library;

import 'package:flutter/material.dart';

import '../constants/app_palette.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';

/// Satu batang pada [AppBarChart] / [AppHorizontalBarChart].
class AppBarChartEntry {
  const AppBarChartEntry({
    required this.label,
    required this.value,
    required this.valueText,
    this.caption,
    this.color,
  });

  /// Label sumbu — sependek mungkin (`'07'`, `'12 Agu'`, `'Agu'`).
  final String label;

  /// Nilai batang. Negatif diperlakukan sebagai nol (tinggi batang tidak
  /// pernah punya arti di bawah garis dasar pada grafik ini).
  final num value;

  /// Nilai **persis** dalam bentuk teks — tampil saat batang disentuh dan
  /// dibacakan pembaca layar. Angka tidak boleh hanya tersirat dari tinggi
  /// batang (AC-9.8).
  final String valueText;

  /// Baris kedua pada kartu detail (mis. `'12 transaksi'`).
  final String? caption;

  /// Warna khusus batang ini. `null` = warna tonal bawaan grafik.
  final Color? color;

  double get safeValue => value <= 0 ? 0 : value.toDouble();
}

/// Perhitungan geometri grafik — dipisah dari widget supaya bisa diuji
/// langsung tanpa merender apa pun (AC-9.8 & AC-9.12).
abstract final class AppBarChartMetrics {
  /// Lebar kolom (slot) satu batang: seluruh lebar area gambar dibagi rata.
  ///
  /// Slot inilah **area sentuh** batang — bukan lebar batang yang tergambar
  /// (AC-9.8: "bila batang lebih sempit, area sentuhnya diperlebar tanpa
  /// mengubah gambar"). Karena slot-slot ini bersambungan tanpa celah,
  /// tidak ada satu piksel pun di dalam grafik yang tidak memilih batang.
  static double slotWidth(double plotWidth, int count) {
    if (count <= 0) return 0;
    return plotWidth / count;
  }

  /// Lebar batang yang **digambar** di tengah slotnya.
  ///
  /// Dijepit 3–28dp: di bawah 3dp batang berhenti menyampaikan apa pun,
  /// di atas 28dp grafik 2–3 batang berubah menjadi balok raksasa.
  static double barWidth(double slotWidth) {
    final raw = slotWidth - AppSizes.spaceXs;
    return raw.clamp(3.0, 28.0);
  }

  /// Batang keberapa yang tersentuh pada posisi [dx].
  static int indexAt(double dx, double plotWidth, int count) {
    if (count <= 0) return 0;
    final slot = slotWidth(plotWidth, count);
    if (slot <= 0) return 0;
    return (dx / slot).floor().clamp(0, count - 1);
  }

  /// Penjarangan label sumbu X (AC-9.12): label ditampilkan tiap `step`
  /// batang supaya masing-masing punya ruang minimal [minLabelWidth].
  ///
  /// 24 batang di HP 5 inci berarti slot ~10dp — menuliskan 24 label di
  /// sana menghasilkan bubur tinta, bukan informasi.
  static int labelStep(double slotWidth, int count, double minLabelWidth) {
    if (count <= 0 || slotWidth <= 0) return 1;
    final step = (minLabelWidth / slotWidth).ceil();
    return step.clamp(1, count);
  }
}

/// Grafik batang **vertikal** dengan sumbu Y dua label (maksimum & nol),
/// label sumbu X yang dijarangkan otomatis, dan pemilihan batang lewat tap.
///
/// Widget ini **terkendali** (*controlled*): [selectedIndex] datang dari
/// pemanggil dan [onSelected] mengembalikan pilihan baru (`null` saat
/// batang yang sama disentuh lagi). Kartu detail angka persisnya digambar
/// pemanggil, bukan di dalam grafik — supaya layar bebas menaruhnya di
/// tempat yang paling masuk akal.
class AppBarChart extends StatelessWidget {
  const AppBarChart({
    super.key,
    required this.entries,
    this.height = plotHeight,
    this.selectedIndex,
    this.onSelected,
    this.highlightIndex,
    this.minLabelWidth = 32,
    this.animate = true,
  });

  /// Tinggi area gambar. **Tetap** apa pun datanya (PRD §9.6) supaya tata
  /// letak layar tidak melompat saat rentang tanggal berganti.
  static const double plotHeight = 160;

  /// Lebar sumbu Y. Cukup untuk `Rp1,2jt` dari
  /// `CurrencyFormatter.formatCompact`.
  static const double axisWidth = AppSizes.space2xl;

  final List<AppBarChartEntry> entries;
  final double height;

  /// Batang yang sedang disentuh pengguna.
  final int? selectedIndex;
  final ValueChanged<int?>? onSelected;

  /// Batang yang diberi warna penuh tanpa disentuh — dipakai "jam ramai"
  /// untuk menandai jam tersibuk (PRD §9.3.B: satu titik fokus per grafik).
  final int? highlightIndex;

  /// Lebar minimum satu label sumbu X sebelum dijarangkan.
  final double minLabelWidth;

  /// Animasi masuk 200 ms (`AppDurations.fast`, PRD §9.6). Dimatikan pada
  /// uji yang perlu tinggi batang final tanpa menunggu.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final palette = context.palette;
    final count = entries.length;
    final maxValue = entries.fold<double>(
      0,
      (max, e) => e.safeValue > max ? e.safeValue : max,
    );
    // AC-9.11: nilai nol semua tidak boleh menghasilkan pembagian nol
    // (`NaN`) maupun batang setinggi layar — skalanya dipaksa 1 sehingga
    // semua batang jatuh rata di garis dasar dan grafik tetap terbaca.
    final scale = maxValue <= 0 ? 1.0 : maxValue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = (constraints.maxWidth - axisWidth).clamp(
          1.0,
          double.infinity,
        );
        final slot = AppBarChartMetrics.slotWidth(plotWidth, count);
        final bar = AppBarChartMetrics.barWidth(slot);
        final step = AppBarChartMetrics.labelStep(slot, count, minLabelWidth);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: axisWidth,
                    child: _YAxis(maxValue: maxValue),
                  ),
                  SizedBox(
                    width: plotWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: onSelected == null
                          ? null
                          : (details) {
                              final index = AppBarChartMetrics.indexAt(
                                details.localPosition.dx,
                                plotWidth,
                                count,
                              );
                              onSelected!(index == selectedIndex ? null : index);
                            },
                      child: _Bars(
                        entries: entries,
                        scale: scale,
                        slot: slot,
                        barWidth: bar,
                        selectedIndex: selectedIndex,
                        highlightIndex: highlightIndex,
                        animate: animate,
                        palette: palette,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Row(
              children: [
                const SizedBox(width: axisWidth),
                SizedBox(
                  width: plotWidth,
                  child: _XLabels(
                    entries: entries,
                    slot: slot,
                    step: step,
                    selectedIndex: selectedIndex,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Sumbu Y: hanya **maksimum & nol** (PRD §9.6) — nilai persis batang
/// diperoleh lewat tap, bukan dari membaca garis bantu.
class _YAxis extends StatelessWidget {
  const _YAxis({required this.maxValue});

  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.palette.inkTertiary,
        );

    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _AppChartFormat.compact(maxValue),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text('0', style: style),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.entries,
    required this.scale,
    required this.slot,
    required this.barWidth,
    required this.selectedIndex,
    required this.highlightIndex,
    required this.animate,
    required this.palette,
  });

  final List<AppBarChartEntry> entries;
  final double scale;
  final double slot;
  final double barWidth;
  final int? selectedIndex;
  final int? highlightIndex;
  final bool animate;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Kunci pada jumlah batang: berganti rentang tanggal = grafik baru,
      // dan grafik baru layak tumbuh lagi dari nol.
      key: ValueKey<int>(entries.length),
      tween: Tween<double>(begin: animate ? 0 : 1, end: 1),
      duration: animate ? AppDurations.fast : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < entries.length; i++)
              SizedBox(
                width: slot,
                child: _Bar(
                  entry: entries[i],
                  fraction: (entries[i].safeValue / scale).clamp(0.0, 1.0) * t,
                  width: barWidth,
                  emphasized: i == selectedIndex || i == highlightIndex,
                  palette: palette,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.entry,
    required this.fraction,
    required this.width,
    required this.emphasized,
    required this.palette,
  });

  final AppBarChartEntry entry;
  final double fraction;
  final double width;
  final bool emphasized;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final fill = entry.color ??
        (emphasized ? palette.primary : palette.primary200);
    // Ujung atas membulat, dasar tegak — batang "berdiri" di garis dasar,
    // bukan melayang (PRD §9.6: `radiusXs` di ujung atas).
    const radius = BorderRadius.only(
      topLeft: Radius.circular(AppSizes.radiusXs),
      topRight: Radius.circular(AppSizes.radiusXs),
    );

    return Semantics(
      label: '${entry.label}: ${entry.valueText}',
      child: Center(
        child: SizedBox(
          width: width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Alur (track): membuat ember NOL tetap terlihat sebagai
              // kolom kosong — hari sepi adalah informasi, bukan lubang.
              const _Track(),
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: fraction,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: radius,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.primary50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSizes.radiusXs),
          topRight: Radius.circular(AppSizes.radiusXs),
        ),
      ),
    );
  }
}

class _XLabels extends StatelessWidget {
  const _XLabels({
    required this.entries,
    required this.slot,
    required this.step,
    required this.selectedIndex,
  });

  final List<AppBarChartEntry> entries;
  final double slot;
  final int step;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final base = Theme.of(context).textTheme.bodySmall;

    return SizedBox(
      height: AppSizes.spaceMl,
      child: Row(
        children: [
          for (var i = 0; i < entries.length; i++)
            SizedBox(
              width: slot,
              child: i % step == 0 || i == selectedIndex
                  // OverflowBox: label boleh melebar melewati slotnya
                  // sendiri (yang bisa saja cuma 10dp) tanpa menggeser
                  // batang mana pun — teksnya tetap terpusat di batangnya.
                  ? OverflowBox(
                      maxWidth: slot * step,
                      child: Text(
                        entries[i].label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: i == selectedIndex
                            ? base?.copyWith(
                                color: palette.ink,
                                fontWeight: FontWeight.w600,
                              )
                            : base?.copyWith(color: palette.inkSecondary),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

/// Grafik batang **horizontal** berlabel: satu baris per entri dengan nama
/// di kiri, nominal di kanan, dan bar proporsi di bawahnya.
///
/// Bentuknya sengaja sama persis dengan bar proporsi metode bayar & produk
/// terlaris yang sudah ada sejak M4 — di layar yang sama, dua gaya bar
/// berbeda akan terbaca sebagai dua sistem.
class AppHorizontalBarChart extends StatelessWidget {
  const AppHorizontalBarChart({
    super.key,
    required this.entries,
    this.animate = true,
  });

  final List<AppBarChartEntry> entries;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = context.palette;
    final maxValue = entries.fold<double>(
      0,
      (max, e) => e.safeValue > max ? e.safeValue : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSizes.spaceMd),
          Semantics(
            label: '${entries[i].label}: ${entries[i].valueText}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entries[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Text(
                      entries[i].valueText,
                      style: context.textStyles.money,
                    ),
                  ],
                ),
                if (entries[i].caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entries[i].caption!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSizes.spaceSm),
                _HorizontalTrack(
                  fraction: maxValue <= 0
                      ? 0
                      : (entries[i].safeValue / maxValue).clamp(0.0, 1.0),
                  color: entries[i].color ??
                      (i == 0 ? palette.primary : palette.primary200),
                  animate: animate,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HorizontalTrack extends StatelessWidget {
  const _HorizontalTrack({
    required this.fraction,
    required this.color,
    required this.animate,
  });

  final double fraction;
  final Color color;
  final bool animate;

  static const double barHeight = 8;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: SizedBox(
        height: barHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: context.palette.primary50),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: animate ? 0 : fraction, end: fraction),
              duration: animate ? AppDurations.fast : Duration.zero,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value,
                  child: ColoredBox(color: color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu deret pada [AppStackedBar].
class AppStackedBarSegment {
  const AppStackedBarSegment({
    required this.label,
    required this.value,
    required this.valueText,
    required this.color,
    this.caption,
  });

  /// **Wajib** — AC-9.10: deret tidak boleh dibedakan hanya oleh warna.
  final String label;
  final num value;
  final String valueText;
  final Color color;

  /// Keterangan tambahan pada legenda (mis. `'12 transaksi'`).
  final String? caption;

  double get safeValue => value <= 0 ? 0 : value.toDouble();
}

/// Satu batang **horizontal bertumpuk** dengan legenda berlabel teks —
/// pengganti pie/donut chart (K-9.2, AC-9.10).
///
/// Mata manusia buruk membandingkan sudut, dan potongan 4% pada donut di
/// layar 5 inci tidak terbaca beserta labelnya. Panjang di satu garis lurus
/// jauh lebih mudah dibandingkan.
class AppStackedBar extends StatelessWidget {
  const AppStackedBar({
    super.key,
    required this.segments,
    this.animate = true,
  });

  final List<AppStackedBarSegment> segments;
  final bool animate;

  static const double barHeight = AppSizes.spaceMd;

  @override
  Widget build(BuildContext context) {
    final visible = segments.where((s) => s.safeValue > 0).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = context.palette;
    final total = visible.fold<double>(0, (sum, s) => sum + s.safeValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          child: SizedBox(
            height: barHeight,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: animate ? 0 : 1, end: 1),
              duration: animate ? AppDurations.fast : Duration.zero,
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Row(
                children: [
                  for (final segment in visible)
                    Expanded(
                      // Bobot dikali 1000 supaya deret 0,4% tetap punya
                      // bilangan bulat yang berarti (Expanded hanya
                      // menerima flex integer).
                      flex: _flexOf(segment.safeValue, total),
                      child: ColoredBox(color: segment.color),
                    ),
                  // Sisa lebar saat animasi masuk belum penuh — diisi
                  // permukaan alur, bukan celah transparan.
                  if (t < 1)
                    Expanded(
                      flex: ((1 - t) * 4000).round().clamp(1, 4000),
                      child: ColoredBox(color: palette.primary50),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSizes.spaceSm),
          Row(
            children: [
              Container(
                width: AppSizes.spaceMs,
                height: AppSizes.spaceMs,
                decoration: BoxDecoration(
                  color: visible[i].color,
                  borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Expanded(
                child: Text(
                  visible[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(visible[i].valueText, style: context.textStyles.money),
                  Text(
                    _percentLabel(visible[i].safeValue, total) +
                        (visible[i].caption == null
                            ? ''
                            : ' · ${visible[i].caption}'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  static int _flexOf(double value, double total) {
    if (total <= 0) return 1;
    return ((value / total) * 4000).round().clamp(1, 4000);
  }

  /// Persentase bulat, tapi tidak pernah `0%` untuk deret yang benar-benar
  /// ada — "0%" di sebelah nominal Rp50.000 terbaca sebagai bug.
  static String _percentLabel(double value, double total) {
    if (total <= 0) return '0%';
    final percent = (value / total) * 100;
    if (percent > 0 && percent < 1) return '<1%';
    return '${percent.round()}%';
  }
}

/// Format ringkas khusus sumbu grafik.
///
/// Sengaja tidak memanggil `CurrencyFormatter` langsung dari `core/widgets`
/// supaya grafik ini tetap bisa dipakai untuk deret non-uang (mis. jumlah
/// transaksi) — pemanggil menentukan satuannya lewat `valueText`, dan
/// sumbu Y hanya butuh besaran kasar.
abstract final class _AppChartFormat {
  static String compact(double value) {
    if (value < 1000) return value.round().toString();
    const units = ['', 'rb', 'jt', 'm', 't'];
    var magnitude = value;
    var unit = 0;
    while (unit < units.length - 1 && (magnitude * 10).round() / 10 >= 1000) {
      magnitude /= 1000;
      unit++;
    }
    final rounded = (magnitude * 10).round() / 10;
    final digits = rounded >= 100
        ? rounded.round().toString()
        : (rounded == rounded.roundToDouble()
            ? rounded.toInt().toString()
            : rounded.toStringAsFixed(1).replaceAll('.', ','));
    return '$digits${units[unit]}';
  }
}
