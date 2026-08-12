/// Pasangan kunci **UJI** untuk vektor uji lisensi (PRD v1.1 AC-6.8).
///
/// ### Kenapa kunci privat boleh ada di sini
/// Karena ini bukan kunci penerbit. Ia dibuat khusus untuk test, tidak
/// pernah menandatangani satu pun lisensi yang beredar, dan **tidak pernah**
/// masuk daftar tepercaya build release (`kLicenseDebugBuild` di
/// `lib/core/license/license_keys.dart`, diuji di `license_keys_test.dart`).
/// Keberadaannya di repo justru yang membuat seluruh vektor uji bisa
/// berjalan **tanpa perangkat, tanpa jaringan, dan tanpa berkas apa pun di
/// luar repo** — syarat yang diminta AC-6.8.
///
/// Kunci PRODUKSI tidak pernah, dalam keadaan apa pun, boleh ditulis di
/// berkas seperti ini. Lihat §6.7.2.
library;

/// Benih (seed) 32 byte kunci privat uji, base64.
const String kTestPrivateSeedBase64 =
    'SCPmXsV6ng1lZNMIaY9FyYLJKj/XnEN+80+1UteKeks=';

/// Kunci publik pasangannya — nilai yang sama dengan `kTestPublicKey`
/// di `lib/core/license/license_keys.dart`.
const String kTestPublicKeyBase64 =
    'BvM36lmeMEfo0mWp8tNTCJeq0ds02eyT18BcLyww0k0=';

/// Kunci penerbit "asing" — dipakai menguji bahwa kode yang ditandatangani
/// kunci di luar daftar tepercaya SELALU ditolak.
const String kForeignPrivateSeedBase64 =
    'ZmFrZS1pc3N1ZXItc2VlZC1mb3ItdGVzdHMtMzJieXQ=';
