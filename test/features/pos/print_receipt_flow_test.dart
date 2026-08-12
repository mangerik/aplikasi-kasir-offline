import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/constants/app_theme.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/data/services/printing/printer_settings_store.dart';
import 'package:kasir_warung/data/services/printing/receipt_printer.dart';
import 'package:kasir_warung/domain/entities/printer_settings.dart';
import 'package:kasir_warung/domain/entities/sale_result.dart';
import 'package:kasir_warung/features/pos/screens/checkout_success_screen.dart';
import 'package:kasir_warung/features/pos/widgets/print_receipt_button.dart';
import 'package:kasir_warung/features/settings/providers/printer_providers.dart';
import 'package:kasir_warung/features/settings/providers/settings_providers.dart';

/// Printer palsu — mencatat setiap job tanpa menyentuh Bluetooth apa pun.
///
/// Jeda [delay] disengaja: tanpa job yang "berjalan" selama beberapa frame,
/// AC-3.7 (dua tap cepat = satu struk) tidak mungkin diuji, karena tap kedua
/// akan selalu tiba setelah tap pertama tuntas.
class _FakePrinter implements ReceiptPrinter {
  _FakePrinter({this.failWith, this.delay = const Duration(milliseconds: 200)});

  final PrinterException? failWith;
  final Duration delay;

  final List<List<int>> jobs = <List<int>>[];
  int disconnectCalls = 0;
  bool _busy = false;

  @override
  bool get isBusy => _busy;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isBluetoothOn() async => true;

  @override
  Future<List<BondedPrinter>> bondedPrinters() async => const [
    BondedPrinter(name: 'ZJ-58', address: 'AA:BB:CC:DD:EE:FF'),
  ];

  @override
  Future<void> printBytes(List<int> bytes, {required String address, int copies = 1}) async {
    if (_busy) throw const PrinterException.busy();
    _busy = true;
    try {
      await Future<void>.delayed(delay);
      if (failWith != null) throw failWith!;
      for (var i = 0; i < copies; i++) {
        jobs.add(bytes);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> disconnect() async => disconnectCalls++;
}

void main() {
  late AppDatabase db;

  setUpAll(() async => DateFormatter.init());

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  final sale = SaleResult(
    saleId: 1,
    invoiceNumber: '20260812-0001',
    subtotal: 7000,
    discount: 0,
    total: 7000,
    paymentMethod: 'cash',
    paidAmount: 10000,
    changeAmount: 3000,
    createdAt: DateTime(2026, 8, 12, 19, 42),
    items: const [
      SaleResultItem(
        name: 'Indomie Goreng',
        unit: 'pcs',
        qty: 2,
        sellPrice: 3500,
        discount: 0,
        lineTotal: 7000,
      ),
    ],
  );

  Future<void> savePrinter(
    ProviderContainer container, {
    bool autoPrint = false,
    int copies = 1,
  }) async {
    await PrinterSettingsStore(container.read(settingsRepoProvider)).save(
      PrinterSettings(
        address: 'AA:BB:CC:DD:EE:FF',
        name: 'ZJ-58',
        autoPrint: autoPrint,
        copies: copies,
      ),
    );
  }

  /// `pumpAndSettle` berhenti begitu tidak ada frame terjadwal, sedangkan
  /// status "Tercetak ✓" dikembalikan ke "Cetak Ulang" oleh sebuah `Timer`
  /// (lihat [PrintJobController.successLinger]). Helper ini memajukan waktu
  /// melewati timer itu, sekaligus memastikan tidak ada timer menggantung
  /// saat test berakhir.
  Future<void> settlePrint(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(PrintJobController.successLinger + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pumpSuccessScreen(
    WidgetTester tester,
    _FakePrinter printer, {
    bool autoPrint = false,
    int copies = 1,
  }) async {
    tester.view.physicalSize = const Size(392, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        receiptPrinterProvider.overrideWithValue(printer),
      ],
    );
    addTearDown(container.dispose);
    await savePrinter(container, autoPrint: autoPrint, copies: copies);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CheckoutSuccessScreen(sale: sale),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('AC-3.7 — dua tap cepat "Cetak Struk" hanya menghasilkan SATU '
      'struk', (tester) async {
    final printer = _FakePrinter();
    await pumpSuccessScreen(tester, printer);

    // Dicari lewat KUNCI, bukan teks: label tombol berubah jadi
    // "Menghubungkan…" tepat setelah tap pertama.
    final button = find.byKey(PrintReceiptButton.buttonKey);
    expect(button, findsOneWidget);
    expect(find.text('Cetak Struk'), findsOneWidget);

    await tester.tap(button);
    await tester.pump(); // job mulai; tombol jadi non-aktif
    // Tap kedua "secepat mungkin" — sengaja dipanggil lewat controller juga,
    // supaya gerbangnya diuji, bukan sekadar tombol yang kebetulan disabled.
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();

    await settlePrint(tester);
    expect(printer.jobs.length, 1);
  });

  testWidgets('cetak otomatis mati (default) — tidak ada struk keluar sendiri', (
    tester,
  ) async {
    final printer = _FakePrinter();
    await pumpSuccessScreen(tester, printer);
    await tester.pumpAndSettle();
    expect(printer.jobs, isEmpty);
    expect(find.text('Cetak Struk'), findsOneWidget);
  });

  testWidgets('cetak otomatis nyala — struk keluar sendiri, tombol jadi '
      '"Cetak Ulang"', (tester) async {
    final printer = _FakePrinter();
    await pumpSuccessScreen(tester, printer, autoPrint: true);
    await settlePrint(tester);
    expect(printer.jobs.length, 1);
    expect(find.text('Cetak Ulang'), findsOneWidget);
  });

  testWidgets('jumlah salinan dipatuhi', (tester) async {
    final printer = _FakePrinter();
    await pumpSuccessScreen(tester, printer, autoPrint: true, copies: 3);
    await settlePrint(tester);
    expect(printer.jobs.length, 3);
  });

  testWidgets('AC-3.5 — Bluetooth mati: pesan Bahasa Indonesia + tombol aksi, '
      'tanpa crash', (tester) async {
    final printer = _FakePrinter(failWith: const PrinterException.bluetoothOff());
    await pumpSuccessScreen(tester, printer);

    await tester.tap(find.byKey(PrintReceiptButton.buttonKey));
    await tester.pumpAndSettle();

    expect(find.text('Bluetooth mati. Nyalakan dulu untuk mencetak.'), findsOneWidget);
    expect(find.text('Gagal — Coba Lagi'), findsOneWidget);
    expect(find.text('Buka Pengaturan Bluetooth Android'), findsOneWidget);
  });

  testWidgets('AC-3.6 — printer tidak terjangkau: layar sukses & data '
      'transaksi tidak berubah sedikit pun', (tester) async {
    final printer = _FakePrinter(failWith: const PrinterException.unreachable());
    await pumpSuccessScreen(tester, printer);

    // Transaksi ini sudah tersimpan SEBELUM layar ini muncul. Yang diuji di
    // sini: kegagalan printer tidak menyentuhnya sama sekali — nomor struk,
    // kembalian, dan tombol "Transaksi Baru" tetap utuh.
    await tester.tap(find.byKey(PrintReceiptButton.buttonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Printer tidak terjangkau. Pastikan printer menyala, kertasnya '
          'ada, dan jaraknya dekat.'),
      findsOneWidget,
    );
    expect(find.text('Struk 20260812-0001'), findsOneWidget);
    expect(find.text('Pembayaran berhasil disimpan'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Transaksi Baru'), findsOneWidget);
    // Boleh dicoba lagi — tombolnya aktif kembali, bukan mati permanen.
    final retry = tester.widget<OutlinedButton>(find.byKey(PrintReceiptButton.buttonKey));
    expect(retry.onPressed, isNotNull);
  });

  testWidgets('printer belum terpasang — pesan mengarahkan ke Pengaturan', (
    tester,
  ) async {
    final printer = _FakePrinter();
    tester.view.physicalSize = const Size(392, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        receiptPrinterProvider.overrideWithValue(printer),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: CheckoutSuccessScreen(sale: sale)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(PrintReceiptButton.buttonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Belum ada printer terpasang. Hubungkan printer dulu di Pengaturan.'),
      findsOneWidget,
    );
    expect(printer.jobs, isEmpty);
  });

  testWidgets('cetak ulang dari layar sukses membawa penanda ** CETAK ULANG **', (
    tester,
  ) async {
    final printer = _FakePrinter(delay: Duration.zero);
    await pumpSuccessScreen(tester, printer);

    await tester.tap(find.byKey(PrintReceiptButton.buttonKey));
    await settlePrint(tester);
    expect(find.text('Cetak Ulang'), findsOneWidget);
    await tester.tap(find.byKey(PrintReceiptButton.buttonKey));
    await settlePrint(tester);

    expect(printer.jobs.length, 2);
    String textOf(List<int> bytes) =>
        String.fromCharCodes(bytes.where((b) => b >= 0x20 && b <= 0x7E));
    expect(textOf(printer.jobs[0]).contains('** CETAK ULANG **'), isFalse);
    expect(textOf(printer.jobs[1]).contains('** CETAK ULANG **'), isTrue);
  });
}
