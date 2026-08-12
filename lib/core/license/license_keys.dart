/// Daftar kunci publik penerbit yang dipercaya aplikasi (PRD v1.1 §6.7.2).
///
/// **Yang ada di berkas ini hanya kunci PUBLIK.** Kunci privat penerbit
/// hidup di `~/.kasir-warung/license_ed25519.key` di laptop penjual, tidak
/// pernah di dalam repositori, tidak pernah di dalam APK (AC-6.19).
///
/// ### Kenapa daftar, bukan satu kunci (AC-6.20)
/// Rotasi kunci harus mungkin tanpa mengubah format token maupun alur
/// verifikasi. Dengan daftar, kode yang ditandatangani kunci lama dan kunci
/// baru sama-sama lolos selama keduanya masih terdaftar — sehingga:
/// - **kunci hilang** → tambahkan kunci baru, pelanggan lama tidak terganggu;
/// - **kunci bocor**  → tambahkan kunci baru dan **buang** yang bocor, lalu
///   rilis pembaruan.
///
/// Menambah/menghapus baris di sini adalah keputusan rilis, bukan sekadar
/// perubahan kode: baca §6.7.2 sebelum menyentuhnya.
library;

/// Deteksi mode build **murni Dart** (tanpa `package:flutter/foundation.dart`)
/// supaya berkas ini tetap bisa diimpor `tool/license_generator.dart`.
///
/// Nilainya `const`, jadi cabang yang tidak terpakai dibuang compiler AOT —
/// kunci uji benar-benar tidak ikut ke dalam build release.
const bool kLicenseReleaseBuild = bool.fromEnvironment('dart.vm.product');
const bool _kProfileBuild = bool.fromEnvironment('dart.vm.profile');

/// `true` pada build debug (termasuk `flutter test` & `dart run`).
const bool kLicenseDebugBuild = !kLicenseReleaseBuild && !_kProfileBuild;

/// Kunci publik PRODUKSI. Ditambah lewat `--buat-kunci` pada tool penjual.
///
/// Urutan tidak berarti apa pun — verifier mencoba semuanya.
const List<String> kProductionPublicKeys = <String>[
  // Kunci penerbit v1 (dibuat 2026-08-12; privat: ~/.kasir-warung/license_ed25519.key)
  'rsBd/CBPjDklHlV7AKK0NTlGi/d4uZ6C9m2L2+6feS4=',
];

/// Kunci publik UJI — pasangannya ada di `test/fixtures/license_test_keys.dart`
/// dan sengaja di-commit (AC-6.8).
///
/// Ia **hanya** ikut daftar tepercaya pada build debug/test. Kalau kunci ini
/// pernah lolos ke build release, siapa pun yang membaca repo publik bisa
/// menerbitkan lisensi — karena itu ia dijaga `const` (dibuang compiler) dan
/// diuji ulang di `test/core/license/license_keys_test.dart`.
const String kTestPublicKey = 'BvM36lmeMEfo0mWp8tNTCJeq0ds02eyT18BcLyww0k0=';

/// Daftar kunci tepercaya untuk build ini.
List<String> trustedLicensePublicKeys() =>
    trustedLicensePublicKeysFor(debugBuild: kLicenseDebugBuild);

/// Varian yang bisa diuji tanpa membangun ulang aplikasi dalam mode release.
List<String> trustedLicensePublicKeysFor({required bool debugBuild}) =>
    debugBuild
    ? <String>[...kProductionPublicKeys, kTestPublicKey]
    : <String>[...kProductionPublicKeys];
