import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../../settings/screens/pin_entry_screen.dart';

/// Hook gerbang PIN sebelum void transaksi, dan (sejak Milestone 5) juga
/// dipakai untuk menjaga akses tab Laporan & Pengaturan (`MainShell`) —
/// lihat architecture.md §5.4.
///
/// - **PIN belum diaktifkan** (`settings.pin_hash` kosong) -> lolos
///   langsung TANPA layar apa pun.
/// - **PIN aktif** -> tampilkan [PinEntryScreen] (keypad besar, plan.md
///   Milestone 5 poin 6) dengan verifikasi lewat [VerifyPinUsecase] —
///   layar itu sendiri yang menangani retry saat PIN salah.
///
/// Mengembalikan `true` bila boleh lanjut (PIN nonaktif ATAU PIN benar),
/// `false` bila dibatalkan (tombol kembali).
Future<bool> checkPinGate(BuildContext context, WidgetRef ref) async {
  // Multi-user aktif → PIN global v1.0 sudah digantikan oleh peran &
  // gerbang masuk (PRD v1.1 §8). Menanyakan dua PIN berbeda untuk satu
  // aksi hanya akan membuat kasir menghafal PIN pemilik.
  if (ref.read(sessionProvider).multiUserEnabled) return true;

  final active = await ref.read(verifyPinUsecaseProvider).isPinActive();
  if (!active) return true;
  if (!context.mounted) return false;

  final verifyPin = ref.read(verifyPinUsecaseProvider);
  final entered = await PinEntryScreen.show(
    context,
    title: 'Verifikasi PIN',
    subtitle: 'Masukkan PIN untuk melanjutkan.',
    validator: verifyPin.call,
  );
  return entered != null;
}
