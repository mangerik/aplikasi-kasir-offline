import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_shadows.dart';
import 'app_sizes.dart';
import 'app_typography.dart';

/// Tema Material 3 aplikasi Kasir Warung — design language
/// **"Kertas & Daun"**.
///
/// Filosofi (lihat `docs/ui-redesign-foundation.md` untuk versi lengkap):
/// 1. **Kanvas kertas hangat**, bukan putih rumah sakit. Kartu putih hangat
///    "mengambang" di atas kanvas krem dengan garis tipis, bukan shadow tebal.
/// 2. **Hijau daun tua = aksi**, gula aren = penanda. Warna kuat hanya muncul
///    di tempat yang butuh keputusan; sisanya tenang.
/// 3. **Angka lebih besar dari labelnya.** Di aplikasi kasir, yang dibaca
///    adalah nominal — label cuma pendamping.
/// 4. **Target sentuh besar** (>= 48dp, CTA 52-60dp) karena dipakai sambil
///    berdiri, terburu-buru, kadang dengan tangan basah.
///
/// Seluruh komponen Material sudah ditema di sini. Layar TIDAK BOLEH
/// meng-override warna/bentuk komponen secara lokal kecuali diinstruksikan
/// dokumen fondasi.
abstract final class AppTheme {
  /// Tema terang — "Kertas & Daun" siang.
  static ThemeData light() => _build(const AppPalette.light());

  /// Tema gelap — "Kertas & Daun Malam" (PRD v1.1 §5.4).
  static ThemeData dark() => _build(const AppPalette.dark());

  /// Satu builder untuk kedua tema: bentuk, ukuran, dan aturan komponen
  /// identik: yang berbeda hanya nilai token di [p]. Ini yang menjamin mode
  /// gelap bukan "tema kedua" melainkan aplikasi yang sama di ruangan gelap.
  static ThemeData _build(AppPalette p) {
    final textTheme = AppTypography.textTheme(p);
    // Teks di atas warna `danger` pekat.
    final onDanger = p.isDark ? const Color(0xFF2B0D0A) : const Color(0xFFFFFFFF);

    final colorScheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primary50,
      onPrimaryContainer: p.primaryDark,
      secondary: p.accent,
      onSecondary: p.onAccent,
      secondaryContainer: p.accent50,
      onSecondaryContainer: p.accentText,
      tertiary: p.info,
      onTertiary: p.isDark ? const Color(0xFF06222F) : p.onDark,
      tertiaryContainer: p.infoSoft,
      onTertiaryContainer: p.infoText,
      error: p.danger,
      onError: onDanger,
      errorContainer: p.dangerSoft,
      onErrorContainer: p.dangerText,
      surface: p.surface,
      onSurface: p.ink,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surfaceAlt,
      surfaceContainer: p.background,
      surfaceContainerHigh: p.surfaceAlt,
      surfaceContainerHighest: p.surfaceAlt,
      onSurfaceVariant: p.inkSecondary,
      outline: p.borderStrong,
      outlineVariant: p.border,
      shadow: p.shadowBase,
      scrim: p.scrim,
      inverseSurface: p.surfaceDark,
      onInverseSurface: p.onSurfaceDark,
      inversePrimary: p.primary200,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      // Tint permukaan otomatis M3 dimatikan: nuansa kertas kita atur
      // manual lewat AppColors, bukan lewat elevation overlay.
      applyElevationOverlayColor: false,

      // ---------------------------------------------------------------
      // APP BAR — menyatu dengan kanvas (tanpa "pita" warna). Identitas
      // dibawa oleh tipografi tebal + ikon hijau, bukan blok warna.
      // ---------------------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        shadowColor: p.shadowBase.withValues(alpha: 0.14),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSizes.spaceMd,
        toolbarHeight: 60,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(
          color: p.ink,
          size: AppSizes.iconMd,
        ),
        actionsIconTheme: IconThemeData(
          color: p.primary,
          size: AppSizes.iconMd,
        ),
        // AC-5.9 — ikon status bar dibalik mengikuti tema supaya tetap
        // terbaca: ikon gelap di atas kanvas terang, ikon terang di atas
        // kanvas gelap.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: p.isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: p.background,
          systemNavigationBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
        ),
      ),

      // ---------------------------------------------------------------
      // KARTU — datar + garis tipis. Kedalaman dari AppShadows kalau perlu.
      // ---------------------------------------------------------------
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: p.shadowBase.withValues(alpha: 0.10),
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          side: BorderSide(color: p.border),
        ),
      ),

      // ---------------------------------------------------------------
      // TOMBOL.
      // ---------------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _primaryButtonStyle(p, textTheme),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _primaryButtonStyle(p, textTheme),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          backgroundColor: p.surface,
          disabledForegroundColor: p.inkTertiary,
          minimumSize: const Size(64, AppSizes.buttonHeight),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: p.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceMl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(48, AppSizes.minTouchTarget),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceMs),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.ink,
          minimumSize: const Size.square(AppSizes.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.surface,
          foregroundColor: p.inkSecondary,
          selectedBackgroundColor: p.primary50,
          selectedForegroundColor: p.primary,
          side: BorderSide(color: p.border),
          textStyle: textTheme.labelMedium,
          minimumSize: const Size(48, AppSizes.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        splashColor: p.primaryDark,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 2,
        extendedTextStyle: textTheme.labelLarge,
        // Squircle, bukan lingkaran — konsisten dengan bahasa bentuk kartu.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        extendedPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceMl,
        ),
      ),

      // ---------------------------------------------------------------
      // INPUT.
      // ---------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceMd,
          vertical: AppSizes.spaceMd,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: p.inkTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: p.inkSecondary,
        ),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: p.primary,
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: p.dangerText),
        prefixIconColor: p.inkSecondary,
        suffixIconColor: p.inkSecondary,
        border: _inputBorder(p.borderStrong),
        enabledBorder: _inputBorder(p.borderStrong),
        disabledBorder: _inputBorder(p.border),
        focusedBorder: _inputBorder(p.primary, width: 2),
        errorBorder: _inputBorder(p.danger),
        focusedErrorBorder: _inputBorder(p.danger, width: 2),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary100,
        selectionHandleColor: p.primary,
      ),

      // ---------------------------------------------------------------
      // CHIP.
      // ---------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primary50,
        secondarySelectedColor: p.primary50,
        disabledColor: p.surfaceAlt,
        checkmarkColor: p.primary,
        labelStyle: textTheme.labelMedium!.copyWith(
          color: p.inkSecondary,
        ),
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(
          color: p.primary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceMs,
          vertical: AppSizes.spaceSm,
        ),
        side: BorderSide(color: p.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),

      // ---------------------------------------------------------------
      // DIALOG, SHEET, MENU, TOOLTIP.
      // ---------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: p.shadowBase.withValues(alpha: 0.2),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceLg,
          vertical: AppSizes.spaceLg,
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: p.inkSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: p.borderStrong,
        dragHandleSize: const Size(40, 4),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radius2xl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: p.shadowBase.withValues(alpha: 0.18),
        textStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          side: BorderSide(color: p.border),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              side: BorderSide(color: p.border),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: p.onSurfaceDark),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceMs,
          vertical: AppSizes.spaceSm,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),

      // ---------------------------------------------------------------
      // NAVIGASI (fallback — shell utama memakai dock kustom di
      // `lib/core/widgets/main_shell.dart`).
      // ---------------------------------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primary50,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            letterSpacing: 0,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? p.primary : p.inkSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppSizes.iconMd,
            color: selected ? p.primary : p.inkSecondary,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.inkSecondary,
        selectedLabelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.inkSecondary,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: p.border,
        dividerHeight: AppSizes.hairline,
        overlayColor: WidgetStatePropertyAll(
          p.primary.withValues(alpha: 0.06),
        ),
        indicator: UnderlineTabIndicator(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          borderSide: BorderSide(color: p.primary, width: 3),
        ),
      ),

      // ---------------------------------------------------------------
      // LIST & PEMISAH.
      // ---------------------------------------------------------------
      listTileTheme: ListTileThemeData(
        iconColor: p.inkSecondary,
        textColor: p.ink,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        leadingAndTrailingTextStyle: textTheme.labelMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceMd,
          vertical: AppSizes.spaceXs,
        ),
        minVerticalPadding: AppSizes.spaceMs,
        horizontalTitleGap: AppSizes.spaceMs,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: AppSizes.hairline,
        space: AppSizes.hairline,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: p.primary,
        collapsedIconColor: p.inkSecondary,
        textColor: p.ink,
        collapsedTextColor: p.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      ),

      // ---------------------------------------------------------------
      // FEEDBACK.
      // ---------------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceDark,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: p.onSurfaceDark,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: p.isDark ? p.primaryDark : p.primary200,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSizes.spaceMs),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        circularTrackColor: p.primary100,
        linearTrackColor: p.primary100,
        linearMinHeight: 6,
        strokeWidth: 3,
        strokeCap: StrokeCap.round,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: p.danger,
        textColor: onDanger,
        textStyle: textTheme.labelSmall?.copyWith(
          color: onDanger,
          fontSize: 10,
          letterSpacing: 0,
        ),
        smallSize: 8,
        largeSize: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
      ),

      // ---------------------------------------------------------------
      // KONTROL FORM.
      // ---------------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return p.border;
          }
          return states.contains(WidgetState.selected)
              ? p.onPrimary
              : p.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return p.surfaceAlt;
          }
          return states.contains(WidgetState.selected)
              ? p.primary
              : p.border;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? p.primary
              : p.borderStrong;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? p.primary
              : Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(p.onPrimary),
        side: BorderSide(color: p.borderStrong, width: 1.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXs),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? p.primary
              : p.borderStrong;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.primary100,
        thumbColor: p.primary,
      ),

      // ---------------------------------------------------------------
      // PICKER TANGGAL (dipakai filter laporan & riwayat).
      // ---------------------------------------------------------------
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.primary,
        headerForegroundColor: p.onPrimary,
        elevation: 0,
        dayStyle: textTheme.bodyMedium,
        todayBorder: BorderSide(color: p.primary, width: 1.5),
        rangeSelectionBackgroundColor: p.primary50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
      ),

      // ---------------------------------------------------------------
      // PALET SADAR-KONTEKS (PRD v1.1 K-5.1) — sumber kebenaran seluruh
      // warna kustom di luar `colorScheme`. Dibaca lewat `context.palette`.
      // ---------------------------------------------------------------
      extensions: <ThemeExtension<dynamic>>[p],
    );
  }

  /// Gaya tombol utama (Elevated & Filled dibuat identik supaya layar tidak
  /// perlu memikirkan mana yang dipakai).
  static ButtonStyle _primaryButtonStyle(AppPalette p, TextTheme textTheme) {
    return ElevatedButton.styleFrom(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      disabledBackgroundColor: p.border,
      disabledForegroundColor: p.inkTertiary,
      shadowColor: p.shadowBase,
      elevation: 0,
      minimumSize: const Size(64, AppSizes.buttonHeight),
      textStyle: textTheme.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceMl),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Dekorasi permukaan siap pakai — supaya layar tidak menyusun
/// [BoxDecoration] sendiri-sendiri dan bentuknya jadi beda-beda.
///
/// Sejak mode gelap (PRD v1.1 §5.5) setiap builder menerima [BuildContext]
/// dan mengambil warna dari `context.palette`, bukan dari konstanta terang.
abstract final class AppDecorations {
  /// Permukaan kartu standar: kertas + garis tipis, tanpa shadow.
  /// Pakai untuk kartu di dalam list.
  static BoxDecoration card(
    BuildContext context, {
    Color? color,
    Color? borderColor,
    double radius = AppSizes.radiusLg,
    List<BoxShadow>? shadow,
  }) {
    final p = context.palette;
    return BoxDecoration(
      color: color ?? p.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? p.border),
      boxShadow: shadow ?? AppShadows.level0,
    );
  }

  /// Permukaan yang mengambang (dock nav, bar keranjang, kartu hero).
  static BoxDecoration floating(
    BuildContext context, {
    Color? color,
    double radius = AppSizes.radiusXl,
  }) {
    final p = context.palette;
    return BoxDecoration(
      color: color ?? p.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: p.border),
      boxShadow: AppShadows.of(context).level2,
    );
  }

  /// Latar lembut bernada semantik (chip, ikon tonal, banner).
  static BoxDecoration tonal(
    BuildContext context,
    AppTone tone, {
    double radius = AppSizes.radiusMd,
    bool outlined = true,
  }) {
    final c = tone.colorsOf(context);
    return BoxDecoration(
      color: c.bg,
      borderRadius: BorderRadius.circular(radius),
      border: outlined ? Border.all(color: c.border) : null,
    );
  }
}
