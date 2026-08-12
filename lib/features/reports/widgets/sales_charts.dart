import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/daily_summary.dart';
import '../../../domain/entities/sales_series.dart';
import '../../../domain/entities/top_product.dart';
import '../../../domain/repositories/report_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../transactions/providers/history_providers.dart';
import '../../transactions/widgets/status_badge.dart';
import '../providers/report_providers.dart';

/// Empat grafik dashboard Laporan (PRD v1.1 §9.3, M14).
///
/// Semuanya menempel pada **pemilih rentang tanggal & filter kasir yang
/// sudah ada** (K-9.3, AC-9.14) — tidak ada satu pun pemilih baru di layar
/// ini. Urutannya mengikuti pertanyaan yang paling sering ditanyakan
/// pemilik warung: "bagaimana perkembangannya?" → "kapan ramainya?" →
/// "orang bayar pakai apa?" → "apa yang paling laku?".
///
/// Bahasa visualnya satu keluarga dengan bar proporsi yang sudah ada sejak
/// M4: judul kartu kecil, **angka besar** di atas grafik, batang di atas
/// alur lembut, dan seluruh warna dari `context.palette` (AC-9.9).
class SalesChartsSection extends StatelessWidget {
  const SalesChartsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: AppSizes.spaceXl),
        _TrendChartCard(),
        SizedBox(height: AppSizes.spaceXl),
        _BusyHoursCard(),
        SizedBox(height: AppSizes.spaceXl),
        _PaymentMixCard(),
      ],
    );
  }
}

// =====================================================================
// Grafik 1 — Tren penjualan (PRD §9.3.A).
// =====================================================================

class _TrendChartCard extends ConsumerStatefulWidget {
  const _TrendChartCard();

  @override
  ConsumerState<_TrendChartCard> createState() => _TrendChartCardState();
}

class _TrendChartCardState extends ConsumerState<_TrendChartCard> {
  /// Batang yang sedang disentuh. Sengaja state layar, bukan provider:
  /// pilihan ini mati saat rentang berganti dan tidak ada satu pun bagian
  /// aplikasi lain yang perlu tahu.
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(reportDateRangeProvider);
    final metric = ref.watch(trendMetricProvider);
    final seriesAsync = ref.watch(salesSeriesProvider);
    // Peralih "Laba" hanya untuk Pemilik (§8.3.C, AC-8.5). Saat multi-user
    // mati, `role` bernilai owner sehingga perilaku v1.0 tidak berubah.
    final canSeeProfit = ref.watch(currentRoleProvider) == UserRole.owner;
    final showProfit = canSeeProfit && metric == TrendMetric.profit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Tren Penjualan',
          subtitle: _bucketSubtitle(range.bucket),
          trailing: canSeeProfit
              ? SegmentedButton<TrendMetric>(
                  segments: const [
                    ButtonSegment(value: TrendMetric.omzet, label: Text('Omzet')),
                    ButtonSegment(value: TrendMetric.profit, label: Text('Laba')),
                  ],
                  selected: {metric},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      ref.read(trendMetricProvider.notifier).set(selection.first),
                )
              : null,
        ),
        seriesAsync.when(
          loading: () => const AppLoadingView(compact: true),
          error: (error, stack) => AppErrorView(
            compact: true,
            title: 'Gagal memuat grafik tren',
            message: AppErrorMessage.from(error),
            onRetry: () => ref.invalidate(salesSeriesProvider),
          ),
          data: (series) {
            final total = series.fold<int>(
              0,
              (sum, point) => sum + point.valueOf(profit: showProfit),
            );
            final hasTransaction =
                series.any((point) => point.transactionCount > 0);
            if (!hasTransaction) {
              // AC-9.11: rentang kosong TIDAK ditampilkan sebagai grafik
              // datar tanpa penjelasan.
              return const EmptyState(
                compact: true,
                icon: Icons.show_chart_rounded,
                title: 'Belum ada penjualan pada rentang ini',
                message: 'Pilih rentang lain di atas, atau mulai transaksi '
                    'pertama hari ini.',
              );
            }

            final selected = _selected != null && _selected! < series.length
                ? series[_selected!]
                : null;

            return AppCard(
              elevated: true,
              padding: const EdgeInsets.all(AppSizes.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    showProfit ? 'LABA KOTOR PERIODE' : 'OMZET PERIODE',
                    style: context.textStyles.eyebrow,
                  ),
                  const SizedBox(height: AppSizes.spaceXs),
                  AppMoneyText(
                    CurrencyFormatter.format(total),
                    size: AppMoneySize.lg,
                  ),
                  const SizedBox(height: AppSizes.spaceXs),
                  _PeriodComparison(total: total, showProfit: showProfit),
                  const SizedBox(height: AppSizes.spaceMd),
                  AppBarChart(
                    entries: [
                      for (final point in series)
                        AppBarChartEntry(
                          label: _axisLabel(point),
                          value: point.valueOf(profit: showProfit),
                          valueText: CurrencyFormatter.format(
                            point.valueOf(profit: showProfit),
                          ),
                        ),
                    ],
                    selectedIndex: _selected,
                    onSelected: (index) => setState(() => _selected = index),
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: AppSizes.spaceMd),
                    _SelectedBarDetail(
                      point: selected,
                      showProfit: showProfit,
                    ),
                  ] else ...[
                    const SizedBox(height: AppSizes.spaceSm),
                    Text(
                      'Sentuh batang untuk melihat angka persisnya.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static String _bucketSubtitle(SeriesBucket bucket) => switch (bucket) {
        SeriesBucket.hour => 'Satu batang = satu jam',
        SeriesBucket.day => 'Satu batang = satu hari',
        SeriesBucket.month => 'Satu batang = satu bulan',
      };

  static String _axisLabel(SalesPoint point) => switch (point.bucket) {
        SeriesBucket.hour => point.start.hour.toString().padLeft(2, '0'),
        SeriesBucket.day => DateFormatter.formatDayMonth(point.start),
        SeriesBucket.month => DateFormatter.formatMonthShort(point.start),
      };
}

/// "Rp4.320.000 · +12% dari 7 hari sebelumnya" (PRD §9.3.A, AC-9.7).
class _PeriodComparison extends ConsumerWidget {
  const _PeriodComparison({required this.total, required this.showProfit});

  final int total;
  final bool showProfit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportDateRangeProvider);
    final previousAsync = ref.watch(previousPeriodSummaryProvider);
    final theme = Theme.of(context);

    return previousAsync.maybeWhen(
      orElse: () => const SizedBox(height: AppSizes.spaceMd),
      data: (previous) {
        final before = showProfit ? previous.grossProfit : previous.totalOmzet;
        final label = _periodLabel(range.dayCount);

        if (before <= 0) {
          // Tanpa pembanding, persentase apa pun adalah karangan —
          // "+100%" dari nol bukan kabar baik, itu hanya pembagian nol
          // yang disamarkan.
          return Text(
            'Tidak ada penjualan pada $label untuk dibandingkan',
            style: theme.textTheme.bodySmall,
          );
        }

        final delta = ((total - before) / before) * 100;
        final rounded = delta.round();
        final isUp = rounded >= 0;
        final tone = isUp ? AppTone.success : AppTone.danger;

        return Row(
          children: [
            Icon(
              isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: AppSizes.iconSm,
              color: tone.colorsOf(context).fg,
            ),
            const SizedBox(width: AppSizes.spaceXs),
            Expanded(
              child: Text(
                '${isUp ? '+' : ''}$rounded% dari $label',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tone.colorsOf(context).fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _periodLabel(int days) =>
      days == 1 ? 'hari sebelumnya' : '$days hari sebelumnya';
}

/// Kartu kecil angka persis satu batang + pintasan ke Riwayat terfilter
/// (PRD §9.3.A, AC-9.8).
class _SelectedBarDetail extends ConsumerWidget {
  const _SelectedBarDetail({required this.point, required this.showProfit});

  final SalesPoint point;
  final bool showProfit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      decoration: BoxDecoration(
        color: palette.primary50,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title(point), style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSizes.spaceXs),
          Row(
            children: [
              Expanded(
                child: AppMoneyText(
                  CurrencyFormatter.format(point.valueOf(profit: showProfit)),
                ),
              ),
              Text(
                '${point.transactionCount} transaksi',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.receipt_long_outlined, size: AppSizes.iconSm),
              label: const Text('Lihat transaksi'),
              onPressed: () => _openHistory(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  /// Membuka tab Riwayat dengan filter tanggal PERSIS seukuran ember yang
  /// disentuh — batas akhirnya dikurangi 1 milidetik karena filter riwayat
  /// bersifat inklusif di kedua ujung.
  void _openHistory(BuildContext context, WidgetRef ref) {
    ref.read(historyFilterProvider.notifier).apply(
          startDate: point.start,
          endDate: point.endExclusive.subtract(const Duration(milliseconds: 1)),
          userId: ref.read(reportUserFilterProvider),
        );
    GoRouter.of(context).go(AppRoutes.transactions);
  }

  static String _title(SalesPoint point) => switch (point.bucket) {
        SeriesBucket.hour =>
          '${DateFormatter.formatDateShort(point.start)}, '
              '${DateFormatter.formatTime(point.start)}–'
              '${DateFormatter.formatTime(point.endExclusive)}',
        SeriesBucket.day => DateFormatter.formatDayDate(point.start),
        SeriesBucket.month => DateFormatter.formatMonthFull(point.start),
      };
}

// =====================================================================
// Grafik 2 — Jam ramai (PRD §9.3.B).
// =====================================================================

class _BusyHoursCard extends ConsumerStatefulWidget {
  const _BusyHoursCard();

  @override
  ConsumerState<_BusyHoursCard> createState() => _BusyHoursCardState();
}

class _BusyHoursCardState extends ConsumerState<_BusyHoursCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final hourlyAsync = ref.watch(hourlyDistributionProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Jam Ramai',
          subtitle: 'Sebaran omzet per jam sepanjang rentang',
        ),
        hourlyAsync.when(
          loading: () => const AppLoadingView(compact: true),
          error: (error, stack) => AppErrorView(
            compact: true,
            title: 'Gagal memuat grafik jam ramai',
            message: AppErrorMessage.from(error),
            onRetry: () => ref.invalidate(hourlyDistributionProvider),
          ),
          data: (hours) {
            final busiest = _busiest(hours);
            if (busiest == null) {
              return const EmptyState(
                compact: true,
                icon: Icons.schedule_outlined,
                title: 'Belum ada jam ramai',
                message: 'Setelah ada transaksi pada rentang ini, jam-jam '
                    'tersibuk warung akan muncul di sini.',
              );
            }

            final selected = _selected != null && _selected! < hours.length
                ? hours[_selected!]
                : null;

            return AppCard(
              elevated: true,
              padding: const EdgeInsets.all(AppSizes.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('PALING RAMAI', style: context.textStyles.eyebrow),
                  const SizedBox(height: AppSizes.spaceXs),
                  Text(
                    _hourRangeLabel(busiest.hour),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${CurrencyFormatter.format(busiest.omzet)} dari '
                    '${busiest.transactionCount} transaksi',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  AppBarChart(
                    // Jam kosong TETAP digambar sebagai batang nol supaya
                    // "bentuk hari" terbaca utuh (PRD §9.3.B).
                    entries: [
                      for (final point in hours)
                        AppBarChartEntry(
                          label: point.hour.toString().padLeft(2, '0'),
                          value: point.omzet,
                          valueText: CurrencyFormatter.format(point.omzet),
                        ),
                    ],
                    highlightIndex: busiest.hour,
                    selectedIndex: _selected,
                    onSelected: (index) => setState(() => _selected = index),
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: AppSizes.spaceMs),
                    Text(
                      '${_hourRangeLabel(selected.hour)} · '
                      '${CurrencyFormatter.format(selected.omzet)} · '
                      '${selected.transactionCount} transaksi',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Jam dengan omzet tertinggi; `null` bila rentang benar-benar kosong.
  static HourlyPoint? _busiest(List<HourlyPoint> hours) {
    HourlyPoint? best;
    for (final point in hours) {
      if (point.transactionCount == 0) continue;
      if (best == null || point.omzet > best.omzet) best = point;
    }
    return best;
  }

  static String _hourRangeLabel(int hour) {
    final start = hour.toString().padLeft(2, '0');
    final end = ((hour + 1) % 24).toString().padLeft(2, '0');
    return '$start.00–$end.00';
  }
}

// =====================================================================
// Grafik 3 — Komposisi metode bayar (PRD §9.3.C).
// =====================================================================

/// Satu batang horizontal bertumpuk + legenda **berlabel teks** (AC-9.10).
///
/// Memakai data `DailySummary` yang sudah dimuat kartu ringkasan — tidak
/// ada query baru, dan karena itu angkanya mustahil berbeda dari kartu di
/// atasnya.
class _PaymentMixCard extends ConsumerWidget {
  const _PaymentMixCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dailySummaryProvider);

    // Sapu M15: sebelumnya seluruh kartu ini — judul section sekalian —
    // menghilang diam-diam saat memuat, saat gagal, dan saat rentangnya
    // kosong (`SizedBox.shrink()`). Rentang tanpa transaksi jadi terasa
    // seperti bug render, dan kegagalan provider tidak pernah sampai ke
    // pengguna. Sekarang polanya sama persis dengan dua grafik di atasnya:
    // judul selalu ada, isinya memuat / error / kosong / data.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Komposisi Pembayaran',
          subtitle: 'Proporsi omzet per metode dalam satu batang',
        ),
        summaryAsync.when(
          loading: () => const AppLoadingView(compact: true),
          error: (error, stack) => AppErrorView(
            compact: true,
            title: 'Gagal memuat komposisi pembayaran',
            message: AppErrorMessage.from(error),
            onRetry: () => ref.invalidate(dailySummaryProvider),
          ),
          data: (summary) {
            final segments = _segments(context, summary);
            if (segments.isEmpty) {
              // AC-9.11: rentang kosong dijelaskan, bukan dihilangkan.
              return const EmptyState(
                compact: true,
                icon: Icons.pie_chart_outline_rounded,
                title: 'Belum ada pembayaran pada rentang ini',
                message: 'Setelah ada transaksi, perbandingan tunai, '
                    'non-tunai, dan hutang muncul di sini.',
              );
            }

            return AppCard(
              elevated: true,
              padding: const EdgeInsets.all(AppSizes.spaceMd),
              child: AppStackedBar(segments: segments),
            );
          },
        ),
      ],
    );
  }

  /// Warna memakai alias domain palet (`tunai` hijau, `nonTunai` biru,
  /// `hutang` gula aren) supaya metode bayar berwarna sama di layar mana
  /// pun.
  static List<AppStackedBarSegment> _segments(
    BuildContext context,
    DailySummary summary,
  ) {
    final palette = context.palette;
    Color colorOf(String method) => switch (method) {
          'cash' => palette.tunai,
          'noncash' => palette.nonTunai,
          'debt' => palette.hutang,
          _ => palette.inkTertiary,
        };

    final entries = [...summary.byPaymentMethod]
      ..sort((a, b) => b.total.compareTo(a.total));
    return [
      for (final entry in entries)
        if (entry.total > 0)
          AppStackedBarSegment(
            label: paymentMethodLabel(entry.method),
            value: entry.total,
            valueText: CurrencyFormatter.format(entry.total),
            caption: '${entry.count} transaksi',
            color: colorOf(entry.method),
          ),
    ];
  }
}

// =====================================================================
// Grafik 4 — Produk terlaris (PRD §9.3.D).
// =====================================================================

/// Batang horizontal 5 teratas dari `getTopProducts` yang sudah ada —
/// **tanpa query baru** (plan M14).
///
/// Menggantikan daftar teks peringkat: informasinya sama (nama, jumlah
/// terjual, nilai), tapi jarak antar peringkat langsung terlihat alih-alih
/// harus dibandingkan digit per digit.
class TopProductsChart extends StatelessWidget {
  const TopProductsChart({
    super.key,
    required this.products,
    required this.sortBy,
  });

  final List<TopProduct> products;
  final TopProductSort sortBy;

  /// K-9.4 dalam bentuk kecilnya: lebih dari 5 baris, kartu ini berhenti
  /// menjadi "sorotan" dan berubah menjadi daftar.
  static const int maxBars = 5;

  @override
  Widget build(BuildContext context) {
    final top = products.take(maxBars).toList();

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      child: AppHorizontalBarChart(
        entries: [
          for (final product in top)
            AppBarChartEntry(
              label: product.productName,
              value: sortBy == TopProductSort.qty
                  ? product.qtySold
                  : product.totalValue,
              valueText: CurrencyFormatter.format(product.totalValue),
              caption: '${_formatQty(product.qtySold)} ${product.unit} terjual',
            ),
        ],
      ),
    );
  }

  static String _formatQty(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
