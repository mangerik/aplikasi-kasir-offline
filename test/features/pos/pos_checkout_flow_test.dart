import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/features/customers/widgets/customer_picker_sheet.dart';
import 'package:kasir_warung/features/transactions/widgets/history_tile.dart';

/// Widget test end-to-end Milestone 6 — Tugas B poin 5: regresi otomatis
/// alur PRD §4 (user stories) & §5 (alur utama kasir) lewat UI SUNGGUHAN
/// (bukan langsung panggil usecase), mulai dari tap produk sampai transaksi
/// tersimpan:
/// - **Happy path tunai**: pilih produk -> bayar tunai -> kembalian tampil
///   benar -> tersimpan (layar "Transaksi Berhasil" + baris di DB + stok
///   berkurang).
/// - **Hutang**: metode Hutang WAJIB nama pelanggan, tersimpan status
///   `debt_unpaid`.
/// - **Void**: dari Riwayat -> Detail -> Batalkan -> status jadi `voided`
///   DAN stok dikembalikan (plan.md Milestone 3 poin 5, PRD §3.1.C).
///
/// Alur hutang & void SUDAH punya cakupan test unit/DB terpisah sejak
/// Milestone 3 (`mark_debt_paid_usecase_test.dart`, `void_sale_usecase_
/// test.dart`, `sale_repository_impl_test.dart`) — test di sini BARU
/// (belum ada sebelumnya) karena menembus UI SUNGGUHAN (tap tombol nyata,
/// bukan panggil usecase langsung), sesuai instruksi tugas.
void main() {
  late AppDatabase db;

  setUpAll(() async {
    await DateFormatter.init();
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Paksa ukuran layar HP portrait (< `AppSizes.tabletBreakpoint` = 600dp)
  /// supaya `PosScreen` merender layout HP (grid produk + `CartSummaryBar`
  /// menempel di bawah), BUKAN layout tablet dua panel — ukuran default
  /// permukaan `flutter_test` (800x600 logis) lebih lebar dari breakpoint
  /// tablet dan akan salah memicu layout tablet tanpa ini.
  ///
  /// Tinggi dilebihkan (1600, bukan tinggi HP asli ~800) supaya seluruh isi
  /// layar "Transaksi Berhasil" (ikon, ringkasan, struk, tombol) muat tanpa
  /// scroll — cukup untuk membuktikan ALUR-nya benar; tinggi HP asli tidak
  /// relevan untuk test alur (bukan test visual/screenshot).
  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(392, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildApp() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const KasirApp(),
    );
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  Future<int> seedProduct({
    String name = 'Teh Botol',
    int sellPrice = 5000,
    double stock = 10,
  }) {
    final now = DateTime(2026, 8, 1).millisecondsSinceEpoch;
    return db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            name: name,
            sellPrice: sellPrice,
            stock: Value(stock),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  testWidgets(
    'happy path kasir: pilih produk -> bayar tunai -> kembalian benar -> tersimpan',
    (tester) async {
      await seedProduct(name: 'Teh Botol', sellPrice: 3000, stock: 10);

      setPhoneSize(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Tab Kasir adalah layar awal -> tap produk untuk masuk keranjang.
      await tester.tap(find.text('Teh Botol'));
      await tester.pump();

      // Bar keranjang ringkas (HP portrait) menunjukkan 1 item -> tap
      // "Bayar" untuk membuka sheet keranjang penuh.
      expect(find.text('1 item'), findsOneWidget);
      await tester.tap(find.text('Bayar').first);
      await tester.pumpAndSettle();

      // Di dalam sheet keranjang -> tap "Bayar" untuk buka sheet pembayaran.
      await tester.tap(find.text('Bayar').last);
      await tester.pumpAndSettle();

      // Sheet Pembayaran: metode default Tunai, total belanja Rp3.000. Tap
      // pecahan cepat Rp10.000 -> kembalian otomatis Rp7.000.
      expect(find.text('Pembayaran'), findsOneWidget);
      await tester.tap(find.text('Rp10.000'));
      await tester.pump();

      expect(find.text('Rp7.000'), findsOneWidget); // baris "Kembalian".

      await tester.tap(find.text('Selesaikan Pembayaran'));
      await tester.pumpAndSettle();

      // Layar sukses + kembalian yang sama tampil di ringkasan struk.
      expect(find.text('Transaksi Berhasil'), findsOneWidget);
      expect(find.text('Rp7.000'), findsWidgets);

      // Tersimpan di DB: 1 baris sales (tunai, lunas/completed, kembalian
      // benar) + stok produk berkurang sesuai qty terjual.
      final sales = await db.select(db.sales).get();
      expect(sales, hasLength(1));
      expect(sales.single.paymentMethod, 'cash');
      expect(sales.single.status, 'completed');
      expect(sales.single.total, 3000);
      expect(sales.single.paidAmount, 10000);
      expect(sales.single.changeAmount, 7000);

      final product = await (db.select(
        db.products,
      )..where((p) => p.name.equals('Teh Botol'))).getSingle();
      expect(product.stock, 9); // 10 - 1 terjual.

      // Kembali ke Kasir -> keranjang harus sudah kosong (dibersihkan
      // setelah simpan berhasil, plan.md Milestone 2 poin 7).
      await tester.tap(find.text('Transaksi Baru'));
      await tester.pumpAndSettle();
      expect(find.text('Keranjang kosong'), findsOneWidget);

      await disposeApp(tester);
    },
  );

  testWidgets(
    'transaksi hutang: nama pelanggan wajib, tersimpan status debt_unpaid',
    (tester) async {
      await seedProduct(name: 'Kopi Sachet', sellPrice: 2000, stock: 5);

      setPhoneSize(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kopi Sachet'));
      await tester.pump();
      await tester.tap(find.text('Bayar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bayar').last);
      await tester.pumpAndSettle();

      // Pilih metode Hutang.
      await tester.tap(find.text('Hutang'));
      await tester.pumpAndSettle();

      // Tombol tetap nonaktif tanpa nama pelanggan (validasi form).
      final buttonFinder = find.widgetWithText(FilledButton, 'Selesaikan Pembayaran');
      expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

      // M12 (PRD v1.1 §7.3.B): field teks bebas "Nama pelanggan" diganti
      // PEMILIH pelanggan. Aturan wajibnya tidak berubah (AC-7.4), hanya
      // cara mengisinya — di sini kasir mengetik nama baru lalu memakai
      // baris "Buat pelanggan baru".
      await tester.tap(find.text('Pilih Pelanggan *'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerPickerSheet), findsOneWidget);

      final pickerSearchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Ketik nama atau no. HP...',
      );
      await tester.enterText(pickerSearchField, 'Budi Santoso');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat pelanggan baru'));
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Transaksi Berhasil'), findsOneWidget);

      final sales = await db.select(db.sales).get();
      expect(sales, hasLength(1));
      expect(sales.single.paymentMethod, 'debt');
      expect(sales.single.status, 'debt_unpaid');
      // Snapshot nama tetap ditulis (K-7.1) DAN transaksi kini tertaut ke
      // baris `customers` yang sungguhan.
      expect(sales.single.customerName, 'Budi Santoso');
      expect(sales.single.customerId, isNotNull);
      expect(sales.single.paidAmount, 0);

      final customers = await db.select(db.customers).get();
      expect(customers, hasLength(1));
      expect(customers.single.name, 'Budi Santoso');

      await disposeApp(tester);
    },
  );

  testWidgets(
    'void transaksi dari Riwayat: status jadi voided DAN stok dikembalikan',
    (tester) async {
      await seedProduct(name: 'Gula Pasir', sellPrice: 15000, stock: 20);

      setPhoneSize(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Selesaikan satu transaksi tunai dulu lewat UI (uang pas).
      await tester.tap(find.text('Gula Pasir'));
      await tester.pump();
      await tester.tap(find.text('Bayar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bayar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uang Pas'));
      await tester.pump();
      await tester.tap(find.text('Selesaikan Pembayaran'));
      await tester.pumpAndSettle();
      expect(find.text('Transaksi Berhasil'), findsOneWidget);
      await tester.tap(find.text('Transaksi Baru'));
      await tester.pumpAndSettle();

      final stockAfterSale = await (db.select(
        db.products,
      )..where((p) => p.name.equals('Gula Pasir'))).getSingle();
      expect(stockAfterSale.stock, 19); // 20 - 1 terjual.

      // Pindah ke tab Riwayat -> buka transaksi -> Batalkan.
      await tester.tap(find.text('Riwayat').first);
      await tester.pumpAndSettle();

      // `HistoryTile` menampilkan no. struk/tanggal/metode/total (BUKAN
      // nama produk) — hanya ada 1 transaksi di DB pada titik ini, jadi
      // aman tap kartu riwayat pertama di daftar. Sejak redesign UI
      // (docs/ui-redesign-transactions-reports.md) baris riwayat berupa
      // `AppCard`, bukan `ListTile` lagi.
      await tester.tap(find.byType(HistoryTile).first);
      await tester.pumpAndSettle();

      // Tombol void ada di detail, teks "Batalkan Transaksi".
      await tester.tap(find.text('Batalkan Transaksi'));
      await tester.pumpAndSettle();

      // Dialog konfirmasi -> tap "Batalkan" (tombol merah di dialog). Pump
      // durasi eksplisit (BUKAN `pumpAndSettle`, yang akan menunggu sampai
      // SnackBar hasil void selesai tampil DAN hilang lagi -> teksnya
      // sudah tidak ada lagi saat baru dicek) untuk memberi waktu
      // `VoidSaleUsecase` (async, query Drift) selesai sebelum melanjutkan.
      await tester.tap(find.text('Batalkan'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Transaksi dibatalkan, stok dikembalikan.'), findsOneWidget);

      // Bukti otoritatif alur void berhasil adalah state DB (status + stok).
      final sales = await db.select(db.sales).get();
      expect(sales.single.status, 'voided');

      final stockAfterVoid = await (db.select(
        db.products,
      )..where((p) => p.name.equals('Gula Pasir'))).getSingle();
      expect(stockAfterVoid.stock, 20); // dikembalikan penuh.

      await disposeApp(tester);
    },
  );
}
