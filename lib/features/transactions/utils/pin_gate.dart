import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/pin_hasher.dart';
import '../../settings/providers/settings_providers.dart';

/// Hook gerbang PIN sebelum void transaksi (plan.md Milestone 3 poin 5:
/// "dan PIN bila fitur PIN aktif — PIN baru dibuat di M5, jadi cukup
/// siapkan hook/cek settingnya").
///
/// PIN LENGKAP (layar set/ubah/hapus PIN) adalah scope Milestone 5. Di
/// sini HANYA mengecek apakah `settings.pin_hash` sudah terisi:
/// - **Belum terisi** (kondisi normal di Milestone 3, karena layar
///   set-PIN M5 belum ada) -> lolos langsung TANPA dialog apa pun.
/// - **Sudah terisi** (setelah M5 selesai) -> minta PIN, verifikasi
///   dengan [PinHasher] (hasher yang sama WAJIB dipakai layar set-PIN M5
///   supaya hook ini tidak perlu diubah lagi).
///
/// Mengembalikan `true` bila boleh lanjut (PIN nonaktif ATAU PIN benar),
/// `false` bila dibatalkan/PIN salah.
Future<bool> checkPinGate(BuildContext context, WidgetRef ref) async {
  final pinHash = await ref.read(settingsRepoProvider).getValue('pin_hash');
  if (pinHash == null || pinHash.isEmpty) return true;
  if (!context.mounted) return false;

  final pinController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Verifikasi PIN'),
      content: TextField(
        controller: pinController,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(labelText: 'Masukkan PIN'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Lanjutkan'),
        ),
      ],
    ),
  );
  final enteredPin = pinController.text.trim();
  pinController.dispose();
  if (confirmed != true) return false;
  return PinHasher.hash(enteredPin) == pinHash;
}
