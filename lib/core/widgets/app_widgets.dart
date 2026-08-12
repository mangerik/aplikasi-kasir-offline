/// Barrel export komponen bersama Kasir Warung.
///
/// Cukup satu import di layar manapun:
/// ```dart
/// import '../../../core/widgets/app_widgets.dart';
/// ```
///
/// Daftar komponen & aturan pemakaiannya ada di
/// `docs/ui-redesign-foundation.md` (sumber kebenaran desain).
library;

// `AppToneColorsX` (getter `tone.colors`) SENGAJA tidak diekspor lagi: ia
// tidak sadar tema. Layar memakai `tone.colorsOf(context)` dari
// `app_palette.dart` yang ikut ekspor di bawah.
export '../constants/app_colors.dart' show AppColors, AppTone, AppToneColors;
export '../constants/app_palette.dart';
export '../constants/app_shadows.dart';
export '../constants/app_sizes.dart';
export '../constants/app_theme.dart' show AppDecorations;
export '../constants/app_typography.dart'
    show AppTextStyles, AppTextStyleSet, AppTextStylesContextX, AppTypography;
export 'app_card.dart';
export 'app_data_row.dart';
export 'app_pill.dart';
export 'app_state_views.dart';
export 'empty_state.dart';
export 'section_header.dart';
