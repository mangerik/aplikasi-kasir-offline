import '../../../domain/entities/printer_settings.dart';
import '../../../domain/repositories/settings_repository.dart';

/// Baca/tulis [PrinterSettings] ke tabel `settings` (key-value) yang sudah
/// ada sejak v1.0 — **tanpa perubahan skema**, `schemaVersion` tetap 1
/// (PRD v1.1 §3.5).
///
/// Semua nilai disimpan sebagai teks dan dibaca dengan **fallback yang
/// selalu masuk akal**: file backup lama tidak punya key printer sama
/// sekali, dan pengguna yang me-restore backup dari HP lain harus tetap
/// mendapat aplikasi yang jalan, bukan aplikasi yang gagal memuat
/// Pengaturan (AC-3.13).
class PrinterSettingsStore {
  const PrinterSettingsStore(this._settings);

  final SettingsRepository _settings;

  Future<PrinterSettings> load() async {
    final values = await Future.wait(<Future<String?>>[
      _settings.getValue(PrinterSettings.keyAddress),
      _settings.getValue(PrinterSettings.keyName),
      _settings.getValue(PrinterSettings.keyType),
      _settings.getValue(PrinterSettings.keyPaperWidth),
      _settings.getValue(PrinterSettings.keyAutoPrint),
      _settings.getValue(PrinterSettings.keyCopies),
      _settings.getValue(PrinterSettings.keyLogoPath),
      _settings.getValue(PrinterSettings.keyPrintLogo),
      _settings.getValue(PrinterSettings.keyFooterText),
      _settings.getValue(PrinterSettings.keyFeedLines),
    ]);

    final footer = values[8];
    return PrinterSettings(
      address: _blankToNull(values[0]),
      name: _blankToNull(values[1]),
      type: _blankToNull(values[2]) ?? PrinterSettings.typeClassic,
      paperWidth: PrinterPaperWidth.fromMillimeters(int.tryParse(values[3] ?? '')),
      autoPrint: values[4] == '1',
      copies: (int.tryParse(values[5] ?? '') ?? 1).clamp(1, PrinterSettings.maxCopies),
      logoPath: _blankToNull(values[6]),
      printLogo: values[7] == '1',
      // Kalimat penutup boleh sengaja dikosongkan pengguna; hanya `null`
      // (belum pernah diisi) yang jatuh ke nilai bawaan.
      footerText: footer ?? PrinterSettings.defaultFooterText,
      feedLines: (int.tryParse(values[9] ?? '') ?? PrinterSettings.defaultFeedLines).clamp(
        0,
        PrinterSettings.maxFeedLines,
      ),
    );
  }

  Future<void> save(PrinterSettings value) async {
    await _settings.setValue(PrinterSettings.keyAddress, value.address ?? '');
    await _settings.setValue(PrinterSettings.keyName, value.name ?? '');
    await _settings.setValue(PrinterSettings.keyType, value.type);
    await _settings.setValue(
      PrinterSettings.keyPaperWidth,
      value.paperWidth.millimeters.toString(),
    );
    await _settings.setValue(PrinterSettings.keyAutoPrint, value.autoPrint ? '1' : '0');
    await _settings.setValue(PrinterSettings.keyCopies, value.copies.toString());
    await _settings.setValue(PrinterSettings.keyLogoPath, value.logoPath ?? '');
    await _settings.setValue(PrinterSettings.keyPrintLogo, value.printLogo ? '1' : '0');
    await _settings.setValue(PrinterSettings.keyFooterText, value.footerText);
    await _settings.setValue(PrinterSettings.keyFeedLines, value.feedLines.toString());
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
