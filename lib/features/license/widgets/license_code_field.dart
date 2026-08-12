import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/license/crockford_base32.dart';
import '../../../core/license/license_token.dart';
import '../../../core/widgets/app_widgets.dart';

/// Masukan kode aktivasi 120 karakter (PRD v1.1 §6.6).
///
/// Kode sepanjang ini adalah harga yang disadari dari tanda tangan Ed25519
/// yang tidak dipotong (K-6.3). Yang bisa dilakukan desain bukan
/// memendekkannya, melainkan **membuat pengetikan jadi jalan terakhir** dan
/// membuat jalan terakhir itu tetap manusiawi:
///
/// - karakter dinormalkan **saat diketik** (huruf besar otomatis, `O`→`0`,
///   `I`/`L`→`1`, karakter di luar alfabet ditolak diam-diam) sehingga
///   pengguna tidak pernah "salah" karena hal yang sebetulnya bisa ditebak;
/// - tanda hubung pemisah kelompok lima muncul sendiri — mata punya
///   pegangan saat berpindah dari layar HP satunya;
/// - 24 segmen di bawah kolom menunjukkan kelompok mana yang sudah terisi,
///   meminjam gagasan indikator titik pada `pin_keypad.dart`. Progres yang
///   terlihat mengubah "kode ini panjang sekali" menjadi "tinggal sedikit".
///
/// Keyboard yang dipakai tetap keyboard sistem: keypad khusus 32 tombol akan
/// memaksa target sentuh di bawah 48dp, dan melanggar aturan itu demi kode
/// yang jarang diketik adalah pertukaran yang salah.
class LicenseCodeField extends StatelessWidget {
  const LicenseCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.enabled = true,
    this.hasError = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final VoidCallback? onSubmitted;

  /// 120 karakter / 5 = 24 kelompok.
  static const int groupCount = LicenseToken.textLength ~/ 5;

  /// Key stabil untuk widget test — layar Aktivasi punya beberapa kolom
  /// teks lain di masa depan, dan `find.byType(TextField)` akan menjadi
  /// rapuh begitu itu terjadi.
  static const Key fieldKey = Key('licenseCodeField');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          maxLines: 3,
          minLines: 3,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          inputFormatters: [LicenseCodeInputFormatter()],
          style: context.textStyles.numeric.copyWith(fontSize: 15, height: 1.6),
          onSubmitted: (_) => onSubmitted?.call(),
          decoration: InputDecoration(
            hintText: 'KW1-XXXXX-XXXXX-…',
            filled: true,
            fillColor: palette.surfaceAlt,
            errorText: null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: hasError ? palette.dangerBorder : palette.border,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spaceSm),
        _GroupProgress(controller: controller),
      ],
    );
  }
}

/// Deretan 24 segmen tipis: terisi = warna brand, kosong = garis tenang.
class _GroupProgress extends StatelessWidget {
  const _GroupProgress({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final chars = LicenseToken.normalize(value.text).length;
        final filled = chars ~/ 5;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < LicenseCodeField.groupCount; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: AnimatedContainer(
                        duration: AppDurations.instant,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < filled ? palette.primary : palette.border,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusPill,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceXs),
            Text(
              '$filled dari ${LicenseCodeField.groupCount} kelompok terisi',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkSecondary,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Normalisasi & pengelompokan saat diketik.
///
/// Sengaja bekerja pada teks yang sudah dinormalkan lalu menyusun ulang
/// tanda hubungnya dari nol: jauh lebih sederhana (dan lebih sulit salah)
/// daripada menambal posisi kursor tiap kali pengguna menghapus di tengah.
class LicenseCodeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = CrockfordBase32.normalize(newValue.text);
    // Awalan versi format boleh ikut diketik/ditempel; simpan apa adanya
    // supaya pengguna melihat kode yang sama dengan yang dikirim penjual.
    final hasPrefix = normalized.startsWith('KW1');
    final body = hasPrefix ? normalized.substring(3) : normalized;

    final buffer = StringBuffer();
    var dataChars = 0;
    for (var i = 0; i < body.length; i++) {
      if (CrockfordBase32.decodeChar(body[i]) == null) continue;
      if (dataChars > 0 && dataChars % 5 == 0) buffer.write('-');
      buffer.write(body[i]);
      dataChars++;
    }
    final text = '${hasPrefix ? LicenseToken.prefix : ''}$buffer';

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
