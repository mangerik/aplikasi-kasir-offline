import '../../domain/repositories/repository_exceptions.dart';

/// Menerjemahkan objek `error`/`exception` APA PUN menjadi pesan Bahasa
/// Indonesia yang aman ditampilkan langsung ke pengguna (SnackBar, dialog,
/// teks error layar) — plan.md Milestone 6 poin 1: "tidak ada teks Inggris/
/// exception mentah yang bocor ke UI".
///
/// Exception domain (`domain/repositories/repository_exceptions.dart`,
/// exception usecase PIN, dst.) SUDAH menulis `toString()` berbahasa
/// Indonesia yang siap tampil sejak dilempar -> dipakai apa adanya. Error
/// LAIN (exception dari package pihak ketiga seperti Drift/SQLite/file
/// system/platform channel — pesannya berbahasa Inggris & sering berisi
/// detail teknis mentah yang membingungkan pengguna awam) DIGANTI dengan
/// pesan generik Bahasa Indonesia.
abstract final class AppErrorMessage {
  /// Pesan generik dipakai untuk error TAK DIKENAL (bukan exception domain).
  static const String generic = 'Terjadi kesalahan tak terduga. Coba lagi.';

  static String from(Object error) => _isDomainException(error) ? error.toString() : generic;

  static bool _isDomainException(Object error) {
    return error is BarcodeSudahDipakaiException ||
        error is NamaKategoriSudahAdaException ||
        error is KategoriMasihDipakaiException ||
        error is KeranjangKosongException ||
        error is UangTidakCukupException ||
        error is NamaPelangganWajibException ||
        error is TransaksiTidakDitemukanException ||
        error is TransaksiBukanHutangException ||
        error is TransaksiSudahDibatalkanException ||
        error is PinTidakValidException ||
        error is PinSalahException ||
        error is PinBelumDiaturException ||
        error is FileBackupTidakValidException ||
        error is ProdukTidakDitemukanException ||
        error is JumlahPenyesuaianTidakValidException ||
        error is AlasanPenyesuaianWajibException;
  }
}
