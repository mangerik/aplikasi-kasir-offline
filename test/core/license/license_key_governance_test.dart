import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/license/license_keys.dart';

import '../../fixtures/license_test_keys.dart';

/// Gerbang tata kelola kunci penerbit (PRD v1.1 §6.7.2, AC-6.19, AC-6.20).
///
/// Ini penjaga aset, bukan uji perilaku. Kunci privat yang bocor berarti
/// siapa pun bisa membuat keygen untuk perangkat mana pun — dan kebocoran
/// semacam itu tidak pernah terlihat di test biasa, karena aplikasinya tetap
/// berjalan sempurna. Karena itu pemeriksaannya dibuat otomatis, bukan
/// diserahkan pada ingatan siapa pun.
void main() {
  List<File> repoDartAndConfigFiles() {
    final dirs = [Directory('lib'), Directory('tool'), Directory('test')];
    return dirs
        .where((d) => d.existsSync())
        .expand((d) => d.listSync(recursive: true))
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  test('aplikasi hanya memuat kunci PUBLIK yang sah (32 byte)', () {
    expect(kProductionPublicKeys, isNotEmpty);
    for (final key in kProductionPublicKeys) {
      expect(base64Decode(key).length, 32, reason: key);
    }
    expect(base64Decode(kTestPublicKey).length, 32);
  });

  test('daftar kunci tepercaya siap ROTASI: berupa List, bukan satu kunci '
      '(AC-6.20)', () {
    // Kunci uji sengaja ditambahkan sebagai "kunci kedua" untuk membuktikan
    // bahwa dua kunci bisa hidup berdampingan tanpa mengubah format token
    // maupun alur verifikasi.
    final debugKeys = trustedLicensePublicKeysFor(debugBuild: true);
    expect(debugKeys.length, greaterThanOrEqualTo(2));
    expect(debugKeys, containsAll(kProductionPublicKeys));
  });

  test('kunci UJI tidak pernah ikut daftar tepercaya build release '
      '(AC-6.19)', () {
    final releaseKeys = trustedLicensePublicKeysFor(debugBuild: false);
    expect(releaseKeys, kProductionPublicKeys);
    expect(releaseKeys.contains(kTestPublicKey), isFalse);
    expect(releaseKeys.contains(kTestPublicKeyBase64), isFalse);
  });

  test('kunci uji publik di lib dan di fixture adalah pasangan yang sama', () {
    expect(kTestPublicKey, kTestPublicKeyBase64);
  });

  test('penjaga kunci uji: cabangnya `const`, jadi compiler AOT membuangnya '
      'dari build release', () {
    final source = File(
      'lib/core/license/license_keys.dart',
    ).readAsStringSync();
    expect(
      source.contains('const bool kLicenseDebugBuild'),
      isTrue,
      reason:
          'kLicenseDebugBuild WAJIB const — kalau ia berubah jadi variabel '
          'runtime, kunci uji ikut terbawa ke APK release.',
    );
    expect(
      source.contains("bool.fromEnvironment('dart.vm.product')"),
      isTrue,
      reason:
          'deteksi mode build wajib murni Dart supaya berkas ini tetap bisa '
          'diimpor tool/license_generator.dart.',
    );
    // Kunci uji hanya boleh disebut di satu tempat: definisinya dan
    // fungsi berpagar debug.
    final mentions = 'kTestPublicKey'.allMatches(source).length;
    expect(
      mentions,
      lessThanOrEqualTo(3),
      reason: 'kunci uji disebut di terlalu banyak tempat di jalur produksi',
    );
  });

  test('TIDAK ADA kunci privat penerbit di dalam repo (AC-6.19)', () {
    // Bentuk yang dicari: benih 32-byte base64 (44 karakter berakhiran "=")
    // yang di-hardcode di luar berkas fixture kunci uji.
    final seedPattern = RegExp(r"'[A-Za-z0-9+/]{43}='");
    final offenders = <String>[];
    for (final file in repoDartAndConfigFiles()) {
      if (file.path.endsWith('test/fixtures/license_test_keys.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in seedPattern.allMatches(source)) {
        final value = match.group(0)!;
        // Kunci PUBLIK produksi memang harus ada — itu bukan pelanggaran.
        if (kProductionPublicKeys.any((k) => value.contains(k))) continue;
        if (value.contains(kTestPublicKey)) continue;
        offenders.add('${file.path}: $value');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Ada nilai 32 byte base64 yang tidak dikenal di dalam repo. Kalau '
          'itu kunci privat penerbit, SEGERA rotasi kuncinya (§6.7.2).\n'
          '${offenders.join('\n')}',
    );
  });

  test('TIDAK ADA berkas kunci/CSV penerbitan di dalam repo', () {
    final stray = Directory('.')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => !f.path.contains('/build/') && !f.path.contains('/.git/'))
        .where(
          (f) =>
              f.path.endsWith('.key') ||
              f.path.endsWith('.pem') ||
              f.path.endsWith('lisensi-terbit.csv'),
        )
        .map((f) => f.path)
        .toList();
    expect(stray, isEmpty, reason: 'berkas rahasia penerbit ada di dalam repo');
  });

  test('.gitignore menutup kunci & buku penerbitan (§6.7.2)', () {
    final ignore = File('.gitignore').readAsStringSync();
    for (final pattern in ['*.key', '*.pem', 'lisensi-terbit.csv']) {
      expect(
        ignore.contains(pattern),
        isTrue,
        reason: '.gitignore belum menutup "$pattern"',
      );
    }
  });

  test('kunci privat UJI hanya hidup di test/fixtures, tidak pernah di lib '
      'maupun tool', () {
    for (final file in repoDartAndConfigFiles()) {
      if (file.path.startsWith('test/')) continue;
      expect(
        file.readAsStringSync().contains(kTestPrivateSeedBase64),
        isFalse,
        reason: '${file.path} memuat benih kunci privat uji',
      );
    }
  });
}
