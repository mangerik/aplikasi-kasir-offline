import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
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
  static ThemeData light() {
    final textTheme = AppTypography.textTheme();

    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onDark,
      primaryContainer: AppColors.primary50,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.accent50,
      onSecondaryContainer: AppColors.accentText,
      tertiary: AppColors.info,
      onTertiary: AppColors.onDark,
      tertiaryContainer: AppColors.infoSoft,
      onTertiaryContainer: AppColors.infoText,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerSoft,
      onErrorContainer: AppColors.dangerText,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surfaceAlt,
      surfaceContainer: AppColors.background,
      surfaceContainerHigh: AppColors.surfaceAlt,
      surfaceContainerHighest: AppColors.surfaceAlt,
      onSurfaceVariant: AppColors.inkSecondary,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      shadow: AppColors.shadowBase,
      scrim: AppColors.scrim,
      inverseSurface: AppColors.surfaceDark,
      onInverseSurface: AppColors.onDark,
      inversePrimary: AppColors.primary200,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
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
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.shadowBase.withValues(alpha: 0.14),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSizes.spaceMd,
        toolbarHeight: 60,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(
          color: AppColors.ink,
          size: AppSizes.iconMd,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.primary,
          size: AppSizes.iconMd,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // ---------------------------------------------------------------
      // KARTU — datar + garis tipis. Kedalaman dari AppShadows kalau perlu.
      // ---------------------------------------------------------------
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.shadowBase.withValues(alpha: 0.10),
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      // ---------------------------------------------------------------
      // TOMBOL.
      // ---------------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _primaryButtonStyle(textTheme),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _primaryButtonStyle(textTheme),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.inkTertiary,
          minimumSize: const Size(64, AppSizes.buttonHeight),
          textStyle: textTheme.labelLarge,
          side: const BorderSide(color: AppColors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceMl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
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
          foregroundColor: AppColors.ink,
          minimumSize: const Size.square(AppSizes.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.inkSecondary,
          selectedBackgroundColor: AppColors.primary50,
          selectedForegroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          textStyle: textTheme.labelMedium,
          minimumSize: const Size(48, AppSizes.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onDark,
        splashColor: AppColors.primaryDark,
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
        fillColor: AppColors.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceMd,
          vertical: AppSizes.spaceMd,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.inkTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSecondary,
        ),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.primary,
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.dangerText),
        prefixIconColor: AppColors.inkSecondary,
        suffixIconColor: AppColors.inkSecondary,
        border: _inputBorder(AppColors.borderStrong),
        enabledBorder: _inputBorder(AppColors.borderStrong),
        disabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.primary, width: 2),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 2),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary100,
        selectionHandleColor: AppColors.primary,
      ),

      // ---------------------------------------------------------------
      // CHIP.
      // ---------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary50,
        secondarySelectedColor: AppColors.primary50,
        disabledColor: AppColors.surfaceAlt,
        checkmarkColor: AppColors.primary,
        labelStyle: textTheme.labelMedium!.copyWith(
          color: AppColors.inkSecondary,
        ),
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(
          color: AppColors.primary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceMs,
          vertical: AppSizes.spaceSm,
        ),
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),

      // ---------------------------------------------------------------
      // DIALOG, SHEET, MENU, TOOLTIP.
      // ---------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppColors.shadowBase.withValues(alpha: 0.2),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceLg,
          vertical: AppSizes.spaceLg,
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: AppColors.inkSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        dragHandleSize: const Size(40, 4),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radius2xl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: AppColors.shadowBase.withValues(alpha: 0.18),
        textStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: AppColors.onDark),
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
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary50,
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
            color: selected ? AppColors.primary : AppColors.inkSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppSizes.iconMd,
            color: selected ? AppColors.primary : AppColors.inkSecondary,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.inkSecondary,
        selectedLabelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.inkSecondary,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.border,
        dividerHeight: AppSizes.hairline,
        overlayColor: WidgetStatePropertyAll(
          AppColors.primary.withValues(alpha: 0.06),
        ),
        indicator: const UnderlineTabIndicator(
          borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
          borderSide: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),

      // ---------------------------------------------------------------
      // LIST & PEMISAH.
      // ---------------------------------------------------------------
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.inkSecondary,
        textColor: AppColors.ink,
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
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: AppSizes.hairline,
        space: AppSizes.hairline,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.inkSecondary,
        textColor: AppColors.ink,
        collapsedTextColor: AppColors.ink,
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
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.onDark,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.primary200,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSizes.spaceMs),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        circularTrackColor: AppColors.primary100,
        linearTrackColor: AppColors.primary100,
        linearMinHeight: 6,
        strokeWidth: 3,
        strokeCap: StrokeCap.round,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.danger,
        textColor: Colors.white,
        textStyle: textTheme.labelSmall?.copyWith(
          color: Colors.white,
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
            return AppColors.border;
          }
          return states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.surfaceAlt;
          }
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.border;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderStrong;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.onDark),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXs),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderStrong;
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.primary100,
        thumbColor: AppColors.primary,
      ),

      // ---------------------------------------------------------------
      // PICKER TANGGAL (dipakai filter laporan & riwayat).
      // ---------------------------------------------------------------
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: AppColors.onDark,
        elevation: 0,
        dayStyle: textTheme.bodyMedium,
        todayBorder: const BorderSide(color: AppColors.primary, width: 1.5),
        rangeSelectionBackgroundColor: AppColors.primary50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
      ),
    );
  }

  /// Gaya tombol utama (Elevated & Filled dibuat identik supaya layar tidak
  /// perlu memikirkan mana yang dipakai).
  static ButtonStyle _primaryButtonStyle(TextTheme textTheme) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onDark,
      disabledBackgroundColor: AppColors.border,
      disabledForegroundColor: AppColors.inkTertiary,
      shadowColor: AppColors.shadowBase,
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
abstract final class AppDecorations {
  /// Permukaan kartu standar: putih hangat + garis tipis, tanpa shadow.
  /// Pakai untuk kartu di dalam list.
  static BoxDecoration card({
    Color color = AppColors.surface,
    Color borderColor = AppColors.border,
    double radius = AppSizes.radiusLg,
    List<BoxShadow> shadow = AppShadows.level0,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: shadow,
    );
  }

  /// Permukaan yang mengambang (dock nav, bar keranjang, kartu hero).
  static BoxDecoration floating({
    Color color = AppColors.surface,
    double radius = AppSizes.radiusXl,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadows.level2,
    );
  }

  /// Latar lembut bernada semantik (chip, ikon tonal, banner).
  static BoxDecoration tonal(
    AppTone tone, {
    double radius = AppSizes.radiusMd,
    bool outlined = true,
  }) {
    final c = tone.colors;
    return BoxDecoration(
      color: c.bg,
      borderRadius: BorderRadius.circular(radius),
      border: outlined ? Border.all(color: c.border) : null,
    );
  }
}
