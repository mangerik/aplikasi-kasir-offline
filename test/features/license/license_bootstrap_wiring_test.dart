import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/features/license/providers/license_providers.dart';

/// Penjaga pemasangan gerbang lisensi (PRD v1.1 §6.3.F, AC-6.1).
///
/// `licenseBootstrapProvider` sengaja punya default "aktif" supaya seluruh
/// widget test M0–M9 — yang tidak tahu-menahu soal lisensi — tetap bisa
/// membangun `KasirApp`. Kenyamanan itu punya harga: kalau `main()` suatu
/// hari berhenti meng-override provider tersebut, aplikasi rilis akan
/// terbuka lebar TANPA gerbang, dan tidak ada satu pun test perilaku yang
/// akan gagal karenanya.
///
/// Test ini menutup celah itu di tingkat sumber: bukan menguji perilaku,
/// melainkan memastikan pemasangannya tidak pernah hilang diam-diam.
void main() {
  late String mainSource;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
  });

  test('main() mengevaluasi lisensi SEBELUM runApp() (tidak ada kedipan '
      'layar Kasir sebelum layar Aktivasi)', () {
    final evaluateAt = mainSource.indexOf('await evaluateLicense(');
    // Cari pemanggilan `runApp(` yang SEBENARNYA (awal baris), bukan
    // penyebutannya di komentar.
    final runAppAt = mainSource.indexOf(
      RegExp(r'^\s*runApp\(', multiLine: true),
    );
    expect(
      evaluateAt,
      greaterThan(-1),
      reason: 'main() tidak memanggil evaluateLicense',
    );
    expect(runAppAt, greaterThan(-1));
    expect(
      evaluateAt,
      lessThan(runAppAt),
      reason: 'evaluasi lisensi wajib selesai sebelum runApp()',
    );
  });

  test('main() SELALU meng-override licenseBootstrapProvider, '
      'licenseStoreProvider, dan deviceCodeProvider', () {
    for (final override in [
      'licenseBootstrapProvider.overrideWithValue',
      'licenseStoreProvider.overrideWithValue',
      'deviceCodeProvider.overrideWithValue',
    ]) {
      expect(
        mainSource.contains(override),
        isTrue,
        reason:
            'Tanpa "$override", gerbang lisensi build rilis akan memakai '
            'default provider yang sengaja terbuka untuk keperluan test.',
      );
    }
  });

  test('override lisensi tidak dibungkus kondisi apa pun (tidak ada bypass '
      'kDebugMode di jalur gerbang)', () {
    final start = mainSource.indexOf('overrides: [');
    final end = mainSource.indexOf('child: const KasirApp()');
    expect(start, greaterThan(-1));
    expect(end, greaterThan(start));
    final overridesBlock = mainSource.substring(start, end);
    for (final forbidden in ['kDebugMode', 'if (', 'assert(']) {
      expect(
        overridesBlock.contains(forbidden),
        isFalse,
        reason: 'blok overrides memuat "$forbidden" — gerbang jadi bersyarat',
      );
    }
  });

  test('default provider MENANDAI dirinya sebagai gerbang yang dimatikan, '
      'sehingga kelalaian di main() bisa terdeteksi', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(licenseBootstrapProvider).gateDisabled, isTrue);
  });

  test('main() TIDAK pernah memakai keadaan "gerbang dimatikan"', () {
    expect(
      mainSource.contains('gerbangDimatikan'),
      isFalse,
      reason: 'main() rilis wajib memakai hasil evaluateLicense yang nyata',
    );
  });

  test('gerbang berada di lapisan router, bukan di UI (K-6.9)', () {
    final routerSource = File(
      'lib/core/router/app_router.dart',
    ).readAsStringSync();
    expect(routerSource.contains('redirect:'), isTrue);
    expect(routerSource.contains('licenseRedirect('), isTrue);
    expect(routerSource.contains('refreshListenable:'), isTrue);
  });

  test('tidak ada nilai lisensi yang ditulis ke database / tabel settings '
      '(K-6.1)', () {
    final licenseFiles = Directory('lib/features/license')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in licenseFiles) {
      final source = file.readAsStringSync();
      expect(
        source.contains("setValue('license"),
        isFalse,
        reason: '${file.path} menulis lisensi ke tabel settings',
      );
    }
  });
}
