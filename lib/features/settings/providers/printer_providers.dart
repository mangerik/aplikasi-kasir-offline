import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/printing/bluetooth_receipt_printer.dart';
import '../../../data/services/printing/printer_settings_store.dart';
import '../../../data/services/printing/receipt_print_service.dart';
import '../../../data/services/printing/receipt_printer.dart';
import '../../../domain/entities/printer_settings.dart';
import '../../../domain/entities/sale_result.dart';
import 'settings_providers.dart';

/// Transport printer (PRD v1.1 K-3.1).
///
/// Sengaja satu instance untuk seluruh aplikasi: mutex "satu job cetak"
/// hanya berarti kalau semua layar memakai objek yang sama (AC-3.7).
/// Provider ini juga titik sisip test — widget test meng-override-nya
/// dengan printer palsu, sehingga tidak ada satu pun test yang butuh
/// perangkat Bluetooth.
final Provider<ReceiptPrinter> receiptPrinterProvider = Provider<ReceiptPrinter>((ref) {
  return BluetoothReceiptPrinter();
});

final Provider<ReceiptPrintService> receiptPrintServiceProvider = Provider<ReceiptPrintService>((
  ref,
) {
  return ReceiptPrintService(ref.watch(receiptPrinterProvider));
});

final Provider<PrinterSettingsStore> printerSettingsStoreProvider = Provider<PrinterSettingsStore>((
  ref,
) {
  return PrinterSettingsStore(ref.watch(settingsRepoProvider));
});

/// Konfigurasi printer dari tabel `settings`. `FutureProvider` biasa (bukan
/// Stream) karena hanya berubah lewat aksi eksplisit di layar Pengaturan —
/// yang mengubahnya wajib memanggil `ref.invalidate(printerSettingsProvider)`.
final FutureProvider<PrinterSettings> printerSettingsProvider = FutureProvider<PrinterSettings>((
  ref,
) {
  return ref.watch(printerSettingsStoreProvider).load();
});

/// Tahapan satu job cetak, dipakai untuk status inline pada tombol
/// (PRD §3.3.B: `Menghubungkan… → Mencetak… → Tercetak ✓ / Gagal`).
enum PrintStage { idle, connecting, printing, done, failed }

/// Keadaan job cetak satu layar.
class PrintJobState {
  const PrintJobState({this.stage = PrintStage.idle, this.message, this.failure});

  final PrintStage stage;

  /// Pesan Bahasa Indonesia saat [stage] == [PrintStage.failed].
  final String? message;

  final PrinterFailure? failure;

  bool get isRunning => stage == PrintStage.connecting || stage == PrintStage.printing;

  static const PrintJobState idle = PrintJobState();
}

/// Pengendali satu job cetak.
///
/// Dibuat `.autoDispose.family` per layar (kunci = penanda pemanggil)
/// supaya status tombol di layar sukses dan di detail transaksi tidak saling
/// menimpa, sementara mutex sesungguhnya tetap ada satu di
/// [receiptPrinterProvider].
class PrintJobController extends StateNotifier<PrintJobState> {
  PrintJobController(this._ref) : super(PrintJobState.idle);

  final Ref _ref;

  /// Lama tanda "Tercetak ✓" bertahan sebelum tombol kembali bisa ditekan.
  ///
  /// Perayaan yang menetap selamanya berhenti jadi perayaan dan mulai jadi
  /// tombol rusak: kasir yang butuh lembar kedua menatap tombol bertulis
  /// "Tercetak ✓" dan tidak tahu ia masih boleh ditekan. Karena itu status
  /// sukses sengaja punya umur, lalu tombol kembali ke "Cetak Ulang".
  static const Duration successLinger = Duration(milliseconds: 1800);

  Timer? _lingerTimer;

  /// Tandai job selesai, lalu kembalikan tombol ke keadaan siap-tekan.
  ///
  /// Timernya disimpan & dibatalkan di [dispose] — tanpa itu, layar yang
  /// ditutup tepat setelah struk keluar meninggalkan timer hidup yang
  /// menyentuh notifier mati.
  void _finishSuccessfully() {
    state = const PrintJobState(stage: PrintStage.done);
    _lingerTimer?.cancel();
    _lingerTimer = Timer(successLinger, () {
      if (!mounted) return;
      if (state.stage == PrintStage.done) state = PrintJobState.idle;
    });
  }

  @override
  void dispose() {
    _lingerTimer?.cancel();
    super.dispose();
  }

  /// Cetak struk penjualan. **Tidak pernah melempar** — kegagalan menjadi
  /// state, karena pemanggilnya selalu berada setelah transaksi tersimpan
  /// dan tidak boleh punya jalur untuk menggagalkan apa pun (K-3.4).
  ///
  /// Mengembalikan `true` bila struk berhasil keluar.
  Future<bool> printSale(SaleResult sale, {bool reprint = false}) async {
    // Gerbang pertama AC-3.7: tap kedua saat job pertama masih jalan
    // dibuang di sini, sebelum menyentuh transport sama sekali.
    if (state.isRunning) return false;
    state = const PrintJobState(stage: PrintStage.connecting);
    try {
      final settings = await _ref.read(printerSettingsProvider.future);
      final profile = await _ref.read(storeProfileProvider.future);
      state = const PrintJobState(stage: PrintStage.printing);
      await _ref.read(receiptPrintServiceProvider).printSale(
        sale: sale,
        profile: profile,
        settings: settings,
        reprint: reprint,
      );
      _finishSuccessfully();
      return true;
    } on PrinterException catch (e) {
      state = PrintJobState(stage: PrintStage.failed, message: e.message, failure: e.failure);
      return false;
    } catch (e) {
      state = const PrintJobState(
        stage: PrintStage.failed,
        message: 'Struk gagal dicetak. Coba lagi.',
        failure: PrinterFailure.writeFailed,
      );
      return false;
    }
  }

  /// Cetak struk uji dari Pengaturan.
  Future<bool> printTest() async {
    if (state.isRunning) return false;
    state = const PrintJobState(stage: PrintStage.connecting);
    try {
      final settings = await _ref.read(printerSettingsProvider.future);
      final profile = await _ref.read(storeProfileProvider.future);
      state = const PrintJobState(stage: PrintStage.printing);
      await _ref.read(receiptPrintServiceProvider).printTest(
        profile: profile,
        settings: settings,
      );
      _finishSuccessfully();
      return true;
    } on PrinterException catch (e) {
      state = PrintJobState(stage: PrintStage.failed, message: e.message, failure: e.failure);
      return false;
    } catch (_) {
      state = const PrintJobState(
        stage: PrintStage.failed,
        message: 'Struk uji gagal dicetak. Coba lagi.',
        failure: PrinterFailure.writeFailed,
      );
      return false;
    }
  }

  void reset() {
    _lingerTimer?.cancel();
    state = PrintJobState.idle;
  }
}

/// [PrintJobController] per pemanggil. Kunci `family` adalah penanda layar
/// (mis. `'checkout'`, `'sale-42'`, `'settings'`).
final AutoDisposeStateNotifierProviderFamily<PrintJobController, PrintJobState, String>
    printJobProvider =
    StateNotifierProvider.autoDispose.family<PrintJobController, PrintJobState, String>((ref, _) {
      return PrintJobController(ref);
    });

/// Daftar printer bonded untuk sheet "Pilih Printer".
///
/// Dibuat `autoDispose` supaya setiap kali sheet dibuka daftarnya segar —
/// pengguna sering baru saja memasangkan printer di Pengaturan Android lalu
/// kembali ke sini.
final AutoDisposeFutureProvider<List<BondedPrinter>> bondedPrintersProvider =
    FutureProvider.autoDispose<List<BondedPrinter>>((ref) {
      return ref.watch(receiptPrinterProvider).bondedPrinters();
    });
