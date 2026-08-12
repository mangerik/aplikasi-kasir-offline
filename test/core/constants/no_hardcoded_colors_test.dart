import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gerbang "sapu bersih" mode gelap (PRD v1.1 AC-5.6).
///
/// Ini penjaga utang teknis, bukan uji perilaku: satu layar yang lolos
/// dengan warna statis akan tampil sebagai **pulau putih** di tengah
/// aplikasi gelap, dan itu jenis cacat yang tidak pernah terlihat di test
/// biasa — layarnya tetap ter-render, tetap bisa ditekan, cuma salah warna.
/// Karena M8–M14 masih akan menambah banyak layar baru, gerbang ini dibuat
/// otomatis supaya tidak bergantung pada ingatan siapa pun.
void main() {
  final scanned = <Directory>[
    Directory('lib/features'),
    Directory('lib/core/widgets'),
  ];

  /// Berkas yang boleh memakai warna mentah, beserta alasannya. Daftar ini
  /// SENGAJA pendek — menambahnya butuh alasan yang bisa dibaca orang lain.
  const allowlist = <String, String>{
    'lib/features/pos/widgets/receipt_widget.dart':
        'Struk keluar dari aplikasi (di-share sebagai gambar, dicetak di '
        'kertas termal). Kertas tidak punya mode gelap — warnanya sengaja '
        'konstanta `paper`/`inkOnPaper`, bukan token palet (K-5.3).',
  };

  List<File> dartFiles() => scanned
      .where((d) => d.existsSync())
      .expand((d) => d.listSync(recursive: true))
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Baris kode saja — komentar & dokumentasi tidak dihitung, karena
  /// menyebut nama token di dokumentasi justru dianjurkan.
  Iterable<({int number, String text})> codeLines(File f) {
    final lines = f.readAsLinesSync();
    return [
      for (var i = 0; i < lines.length; i++)
        if (!lines[i].trimLeft().startsWith('//'))
          (number: i + 1, text: lines[i]),
    ];
  }

  test('tidak ada `AppColors.*` di lib/features & lib/core/widgets — '
      'warna WAJIB lewat context.palette (AC-5.6)', () {
    final offenders = <String>[];
    for (final f in dartFiles()) {
      for (final line in codeLines(f)) {
        if (line.text.contains('AppColors.')) {
          offenders.add('${f.path}:${line.number}: ${line.text.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'AppColors adalah palet TERANG statis; pemakaiannya di layar '
          'membuat "pulau putih" saat mode gelap. Ganti dengan '
          'context.palette.<token>.\n${offenders.join('\n')}',
    );
  });

  test('tidak ada `Colors.white` / `Colors.black` telanjang '
      '(AC-5.6)', () {
    final offenders = <String>[];
    for (final f in dartFiles()) {
      final rel = f.path;
      if (allowlist.keys.any(rel.endsWith)) continue;
      for (final line in codeLines(f)) {
        final text = line.text;
        if (RegExp(r'\bColors\.(white|black)\b').hasMatch(text)) {
          offenders.add('$rel:${line.number}: ${text.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Putih & hitam telanjang tidak ikut tema. Pakai token palet '
          '(surface / ink / onPrimary / onSurfaceDark), atau daftarkan '
          'berkasnya di allowlist test ini beserta alasannya.\n'
          '${offenders.join('\n')}',
    );
  });

  /// Sapu M11. Dua celah yang tersisa dari gerbang M7:
  ///
  /// 1. `Color(0x…)` / `Color.fromARGB(…)` mentah tidak pernah diperiksa —
  ///    padahal itulah bentuk warna statis yang paling mudah ditulis. Efek
  ///    sampingnya: entri allowlist `receipt_widget.dart` selama ini **mati**
  ///    (berkas itu memakai `Color(0xFFFFFFFF)`, bukan `Colors.white`),
  ///    sehingga ia memakan satu slot allowlist tanpa menjaga apa pun.
  /// 2. `AppTextStyles.*` statis memanggang `AppColors.ink` (palet TERANG) ke
  ///    dalam gaya teks — pulau putih yang tidak pernah tertangkap pencarian
  ///    string `AppColors.`.
  test('tidak ada `Color(0x…)` / `Color.fromARGB` telanjang (AC-5.6)', () {
    final offenders = <String>[];
    final pattern = RegExp(r'\bColor(\.fromARGB)?\s*\(\s*0x|\bColor\.fromARGB\s*\(');
    for (final f in dartFiles()) {
      final rel = f.path;
      if (allowlist.keys.any(rel.endsWith)) continue;
      for (final line in codeLines(f)) {
        if (pattern.hasMatch(line.text)) {
          offenders.add('$rel:${line.number}: ${line.text.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Warna heksadesimal mentah tidak ikut tema. Pakai token '
          'context.palette.<token>, atau daftarkan berkasnya di allowlist '
          'beserta alasannya.\n${offenders.join('\n')}',
    );
  });

  test('tidak ada `AppTextStyles.*` statis di layar — gaya teks WAJIB lewat '
      'context.textStyles (AC-5.6)', () {
    final offenders = <String>[];
    for (final f in dartFiles()) {
      for (final line in codeLines(f)) {
        if (RegExp(r'\bAppTextStyles\.').hasMatch(line.text)) {
          offenders.add('${f.path}:${line.number}: ${line.text.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'AppTextStyles.* memanggang warna palet TERANG (AppColors.ink) ke '
          'dalam gaya. Pakai context.textStyles.<gaya> yang sadar tema.\n'
          '${offenders.join('\n')}',
    );
  });

  test('daftar allowlist tidak menumpuk diam-diam', () {
    // Kalau daftar ini mulai panjang, artinya aturannya yang salah — bukan
    // kodenya. Batas ini memaksa diskusi, bukan penambahan baris.
    expect(allowlist.length, lessThanOrEqualTo(3));
    for (final entry in allowlist.entries) {
      expect(
        File(entry.key).existsSync(),
        isTrue,
        reason: 'allowlist menunjuk berkas yang sudah tidak ada: ${entry.key}',
      );
      expect(entry.value.length, greaterThan(40), reason: 'alasan terlalu tipis');
    }
  });

  test('tidak ada pemakaian shadow statis yang tidak sadar tema', () {
    final offenders = <String>[];
    final pattern = RegExp(r'AppShadows\.(level[123]|primaryGlow)\b');
    for (final f in dartFiles()) {
      for (final line in codeLines(f)) {
        if (pattern.hasMatch(line.text)) {
          offenders.add('${f.path}:${line.number}: ${line.text.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Pakai AppShadows.of(context).<level> supaya alpha-nya turun di '
          'mode gelap (PRD §5.4 aturan 2).\n${offenders.join('\n')}',
    );
  });
}
