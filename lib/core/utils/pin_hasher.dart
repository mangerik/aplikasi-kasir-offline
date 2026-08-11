import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hash PIN sederhana (SHA-256) — HOOK disiapkan di Milestone 3 untuk
/// gerbang PIN sebelum void transaksi (plan.md Milestone 3 poin 5: "dan
/// PIN bila fitur PIN aktif — PIN baru dibuat di M5, jadi cukup siapkan
/// hook/cek settingnya").
///
/// PENTING: mekanisme PIN LENGKAP (set/ubah/hapus PIN + SALT per
/// architecture.md §5.4 "PIN 6 digit di-hash SHA-256 + salt") adalah scope
/// Milestone 5 — layar Pengaturan M5 WAJIB memakai hasher yang SAMA ini
/// (atau menggantinya sekaligus migrasi nilai `settings.pin_hash` lama)
/// supaya verifikasi yang sudah dipasang di M3 (`features/transactions/
/// utils/pin_gate.dart`) tetap konsisten tanpa perlu diubah lagi.
abstract final class PinHasher {
  static String hash(String pin) => sha256.convert(utf8.encode(pin)).toString();
}
