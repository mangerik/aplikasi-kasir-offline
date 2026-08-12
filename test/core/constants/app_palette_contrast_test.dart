import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/constants/app_colors.dart';
import 'package:kasir_warung/core/constants/app_palette.dart';

/// Uji kontras otomatis palet (PRD v1.1 AC-5.8).
///
/// Alasan test ini ada: di aplikasi kasir yang salah baca adalah **angka
/// uang**. Menilai kontras "dengan mata" di layar laptop terang tidak sama
/// dengan membaca layar HP murah di warung yang lampunya redup. Jadi setiap
/// pasangan (teks, latar) yang benar-benar muncul di aplikasi dihitung
/// rasionya di sini — untuk palet terang MAUPUN gelap — dan angka usulan
/// PRD §5.4 hanya sah kalau lolos di sini.
///
/// Ambang WCAG AA: **4.5:1** teks normal, **3:1** teks >= 18px & ikon.
void main() {
  const light = AppPalette.light();
  const dark = AppPalette.dark();

  group('kontras palet terang', () {
    for (final pair in _pairs(light)) {
      test('${pair.label} >= ${pair.min}:1', () => pair.expectPass());
    }
  });

  group('kontras palet gelap', () {
    for (final pair in _pairs(dark)) {
      test('${pair.label} >= ${pair.min}:1', () => pair.expectPass());
    }
  });

  group('pengecualian yang disengaja', () {
    // inkTertiary SENGAJA di bawah 4.5:1 — ia hanya untuk hint/placeholder
    // dan teks >= 18px (lihat dokumentasi tokennya). Didaftarkan eksplisit
    // di sini supaya "lolos" bukan karena terlewat, tapi karena diputuskan.
    //
    // Ambangnya 2.8 dan bukan 3.0 karena nilai TERANG (#8A928B, 2.86:1 di
    // atas kartu) berasal dari v1.0 dan tidak boleh digeser (AC-5.12).
    // Versi gelapnya justru jauh lebih longgar (~4.1:1).
    test('inkTertiary tetap terbaca sebagai hint (>= 2.8:1) di kedua tema', () {
      for (final p in [light, dark]) {
        expect(
          _ratio(p.inkTertiary, p.surface),
          greaterThanOrEqualTo(2.8),
          reason: 'inkTertiary di atas surface',
        );
        expect(
          _ratio(p.inkTertiary, p.background),
          greaterThanOrEqualTo(2.8),
          reason: 'inkTertiary di atas background',
        );
      }
    });

    test('inkTertiary memang TIDAK memenuhi 4.5:1 (jadi jangan dipakai '
        'untuk teks kecil yang penting)', () {
      expect(_ratio(light.inkTertiary, light.surface), lessThan(4.5));
      expect(_ratio(dark.inkTertiary, dark.surface), lessThan(4.5));
    });

    // `accent` (gula aren #D97E27) sudah di bawah 3:1 di atas kertas sejak
    // v1.0 — dan nilainya TIDAK BOLEH diubah (AC-5.12 melarang pergeseran
    // palet terang). Yang menjaga keterbacaan bukan warna ini melainkan
    // aturan pemakaiannya: `accent` hanya jadi ISI (track progress, FAB,
    // latar chip), sedangkan teks/ikon aksen memakai `accentText`.
    test('accent hanya boleh jadi isi, bukan teks — pasangan teksnya '
        '(accentText) yang wajib lolos', () {
      expect(_ratio(light.accent, light.surface), lessThan(3.0));
      for (final p in [light, dark]) {
        expect(_ratio(p.accentText, p.surface), greaterThanOrEqualTo(4.5));
        // Isi aksen tetap harus terlihat dari track/latar tonalnya sendiri.
        expect(_ratio(p.accent, p.accent100), greaterThanOrEqualTo(2.0));
      }
    });
  });

  group('aturan palet gelap "Kertas & Daun Malam" (PRD §5.4)', () {
    test('tidak ada hitam murni sebagai permukaan', () {
      for (final c in [dark.background, dark.surface, dark.surfaceAlt]) {
        expect(
          c,
          isNot(const Color(0xFF000000)),
          reason: 'permukaan gelap wajib bernada hangat-hijau, bukan hitam',
        );
      }
    });

    test('tangga permukaan menaik: background < surface < surfaceAlt', () {
      expect(
        dark.background.computeLuminance(),
        lessThan(dark.surface.computeLuminance()),
      );
      expect(
        dark.surface.computeLuminance(),
        lessThan(dark.surfaceAlt.computeLuminance()),
      );
    });

    test('tangga permukaan mode terang tetap menurun (kartu > kanvas)', () {
      expect(
        light.surface.computeLuminance(),
        greaterThan(light.background.computeLuminance()),
      );
    });

    test('surfaceDark benar-benar inversi di tiap tema', () {
      expect(
        light.surfaceDark.computeLuminance(),
        lessThan(light.surface.computeLuminance()),
      );
      expect(
        dark.surfaceDark.computeLuminance(),
        greaterThan(dark.surface.computeLuminance()),
      );
    });

    test('peran warna brand dibalik: primary gelap terang, teks di atasnya '
        'justru gelap', () {
      expect(
        dark.primary.computeLuminance(),
        greaterThan(light.primary.computeLuminance()),
      );
      expect(
        dark.onPrimary.computeLuminance(),
        lessThan(dark.primary.computeLuminance()),
      );
      expect(
        light.onPrimary.computeLuminance(),
        greaterThan(light.primary.computeLuminance()),
      );
    });

    test('garis kartu terlihat dari permukaannya (>= 1.15:1)', () {
      for (final p in [light, dark]) {
        expect(_ratio(p.border, p.surface), greaterThanOrEqualTo(1.15));
        expect(_ratio(p.borderStrong, p.surface), greaterThanOrEqualTo(1.2));
      }
    });
  });

  group('palet terang identik dengan AppColors v1.0 (AC-5.12)', () {
    test('token netral & brand tidak bergeser sedikit pun', () {
      expect(light.background, AppColors.background);
      expect(light.surface, AppColors.surface);
      expect(light.surfaceAlt, AppColors.surfaceAlt);
      expect(light.surfaceDark, AppColors.surfaceDark);
      expect(light.ink, AppColors.ink);
      expect(light.inkSecondary, AppColors.inkSecondary);
      expect(light.inkTertiary, AppColors.inkTertiary);
      expect(light.border, AppColors.border);
      expect(light.borderStrong, AppColors.borderStrong);
      expect(light.primary, AppColors.primary);
      expect(light.primaryDark, AppColors.primaryDark);
      expect(light.primaryDeep, AppColors.primaryDeep);
      expect(light.primary50, AppColors.primary50);
      expect(light.primary100, AppColors.primary100);
      expect(light.primary200, AppColors.primary200);
      expect(light.accent, AppColors.accent);
      expect(light.accentText, AppColors.accentText);
      expect(light.accent50, AppColors.accent50);
      expect(light.accent100, AppColors.accent100);
      expect(light.success, AppColors.success);
      expect(light.successSoft, AppColors.successSoft);
      expect(light.successText, AppColors.successText);
      expect(light.warning, AppColors.warning);
      expect(light.warningSoft, AppColors.warningSoft);
      expect(light.warningText, AppColors.warningText);
      expect(light.danger, AppColors.danger);
      expect(light.dangerSoft, AppColors.dangerSoft);
      expect(light.dangerText, AppColors.dangerText);
      expect(light.info, AppColors.info);
      expect(light.infoSoft, AppColors.infoSoft);
      expect(light.infoText, AppColors.infoText);
    });

    test('alias domain tetap membawa makna yang sama', () {
      for (final p in [light, dark]) {
        expect(p.tunai, p.success);
        expect(p.nonTunai, p.info);
        expect(p.hutang, p.accentText);
      }
    });
  });
}

/// Semua pasangan (teks/ikon, latar) yang benar-benar dipakai aplikasi.
List<_Pair> _pairs(AppPalette p) {
  final theme = p.isDark ? 'gelap' : 'terang';
  final surfaces = <String, Color>{
    'background': p.background,
    'surface': p.surface,
    'surfaceAlt': p.surfaceAlt,
  };

  final pairs = <_Pair>[];

  void add(String fgName, Color fg, String bgName, Color bg, double min) {
    pairs.add(_Pair('$theme · $fgName di atas $bgName', fg, bg, min));
  }

  // --- Teks netral di seluruh permukaan.
  for (final entry in surfaces.entries) {
    add('ink', p.ink, entry.key, entry.value, 4.5);
    add('inkSecondary', p.inkSecondary, entry.key, entry.value, 4.5);
    // Warna brand & aksen ikut dipakai sebagai TEKS (nominal uang penting,
    // label tab aktif, angka hutang), jadi diuji di ambang teks normal.
    add('primary', p.primary, entry.key, entry.value, 4.5);
    add('accentText', p.accentText, entry.key, entry.value, 4.5);
    add('successText', p.successText, entry.key, entry.value, 4.5);
    add('warningText', p.warningText, entry.key, entry.value, 4.5);
    add('dangerText', p.dangerText, entry.key, entry.value, 4.5);
    add('infoText', p.infoText, entry.key, entry.value, 4.5);
  }

  // --- Ikon berisi pekat (indikator progress, ikon status) — ambang 3:1.
  // `accent` sengaja TIDAK ikut: lihat grup "pengecualian yang disengaja".
  for (final entry in surfaces.entries) {
    add('success (isi)', p.success, entry.key, entry.value, 3.0);
    add('warning (isi)', p.warning, entry.key, entry.value, 3.0);
    add('danger (isi)', p.danger, entry.key, entry.value, 3.0);
    add('info (isi)', p.info, entry.key, entry.value, 3.0);
  }

  // --- Trio semantik: teks di atas latar lembutnya sendiri (pill, banner).
  add('successText', p.successText, 'successSoft', p.successSoft, 4.5);
  add('warningText', p.warningText, 'warningSoft', p.warningSoft, 4.5);
  add('dangerText', p.dangerText, 'dangerSoft', p.dangerSoft, 4.5);
  add('infoText', p.infoText, 'infoSoft', p.infoSoft, 4.5);
  add('accentText', p.accentText, 'accent50', p.accent50, 4.5);
  add('primary', p.primary, 'primary50', p.primary50, 4.5);
  add('inkSecondary', p.inkSecondary, 'surfaceAlt', p.surfaceAlt, 4.5);

  // --- Permukaan berisi warna: teks di atasnya.
  add('onPrimary', p.onPrimary, 'primary', p.primary, 4.5);
  add('onPrimary', p.onPrimary, 'primaryDark', p.primaryDark, 4.5);
  add('onDark', p.onDark, 'primaryDeep', p.primaryDeep, 4.5);
  add('onAccent', p.onAccent, 'accent', p.accent, 4.5);
  add('onSurfaceDark', p.onSurfaceDark, 'surfaceDark', p.surfaceDark, 4.5);

  // --- Pill/badge berisi penuh (AppPill filled): teks memakai warna
  //     "on filled" yang sama dengan aturan di AppPill._onFilled.
  final onFilled = p.isDark ? p.background : p.onDark;
  for (final tone in AppTone.values) {
    if (tone == AppTone.neutral) continue;
    final c = tone.resolve(p);
    pairs.add(
      _Pair('$theme · pill berisi ${tone.name}', onFilled, c.fg, 4.5),
    );
  }
  final neutralFilledFg = p.isDark ? p.background : p.surface;
  pairs.add(
    _Pair(
      '$theme · pill berisi neutral',
      neutralFilledFg,
      AppTone.neutral.resolve(p).fg,
      4.5,
    ),
  );

  // --- Pill/badge tonal (tidak berisi): teks di atas latar lembutnya.
  for (final tone in AppTone.values) {
    final c = tone.resolve(p);
    pairs.add(_Pair('$theme · pill tonal ${tone.name}', c.fg, c.bg, 4.5));
  }

  return pairs;
}

@immutable
class _Pair {
  const _Pair(this.label, this.fg, this.bg, this.min);

  final String label;
  final Color fg;
  final Color bg;
  final double min;

  void expectPass() {
    final ratio = _ratio(fg, bg);
    expect(
      ratio,
      greaterThanOrEqualTo(min),
      reason:
          '$label hanya ${ratio.toStringAsFixed(2)}:1 '
          '(fg ${_hex(fg)} / bg ${_hex(bg)}), minimal $min:1',
    );
  }
}

/// Rasio kontras WCAG 2.1.
double _ratio(Color fg, Color bg) {
  final a = fg.computeLuminance();
  final b = bg.computeLuminance();
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
