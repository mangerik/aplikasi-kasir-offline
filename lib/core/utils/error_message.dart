import '../../domain/repositories/repository_exceptions.dart';

/// Menerjemahkan objek `error`/`exception` APA PUN menjadi pesan Bahasa
/// Indonesia yang aman ditampilkan langsung ke pengguna (SnackBar, dialog,
/// teks error layar) — plan.md Milestone 6 poin 1: "tidak ada teks Inggris/
/// exception mentah yang bocor ke UI".
///
/// Exception domain SUDAH menulis `toString()` berbahasa Indonesia yang siap
/// tampil sejak dilempar -> dipakai apa adanya. Error LAIN (exception dari
/// package pihak ketiga seperti Drift/SQLite/file system/platform channel —
/// pesannya berbahasa Inggris & sering berisi detail teknis mentah yang
/// membingungkan pengguna awam) DIGANTI dengan pesan generik Bahasa
/// Indonesia.
///
/// Yang menentukan "domain" adalah **penanda** `DomainException`
/// (`domain/repositories/repository_exceptions.dart`), bukan daftar tipe di
/// sini. Sejarahnya ditulis di doc penanda itu: daftar manual tertinggal dua
/// kali (M9 & M12/M13) dan diam-diam menurunkan pesan spesifik menjadi
/// generik.
abstract final class AppErrorMessage {
  /// Pesan generik dipakai untuk error TAK DIKENAL (bukan exception domain).
  static const String generic = 'Terjadi kesalahan tak terduga. Coba lagi.';

  static String from(Object error) => error is DomainException ? error.toString() : generic;
}

// Catatan sengaja: `PrinterException` (M8) TIDAK memakai penanda di atas. Ia hidup
// di `data/services/printing/`, dan `core/` dilarang mengimpor `data/`
// (architecture.md §3). Konsekuensinya sudah ditanggung di tempatnya: setiap
// pemanggil printer menangkap `PrinterException` secara eksplisit dan membaca
// `.message` — lihat `printer_providers.dart` & `printer_device_sheet.dart`.
