# Arsitektur — Aplikasi Kasir Warung (Offline-First)

**Versi:** 1.0
**Acuan:** [prd.md](prd.md)

---

## 1. Gambaran Umum

Aplikasi Flutter **single-user, offline-first, local-only**. Tidak ada backend/server. Seluruh state persisten hidup di database SQLite lokal. Portabilitas data dicapai lewat export Excel dan backup/restore file database.

```
┌─────────────────────────────────────────────┐
│                Flutter App                  │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │  Presentation (UI + Riverpod)         │  │
│  │  Screens · Widgets · Providers        │  │
│  └───────────────┬───────────────────────┘  │
│                  │                          │
│  ┌───────────────▼───────────────────────┐  │
│  │  Domain (logika bisnis murni)         │  │
│  │  Entities · Usecases · Repo contracts │  │
│  └───────────────┬───────────────────────┘  │
│                  │                          │
│  ┌───────────────▼───────────────────────┐  │
│  │  Data                                 │  │
│  │  Drift (SQLite) · Repositories impl   │  │
│  │  Excel exporter · Backup service      │  │
│  └───────────────┬───────────────────────┘  │
└──────────────────┼──────────────────────────┘
                   ▼
        Penyimpanan lokal perangkat
        (file .sqlite + folder export)
```

---

## 2. Pilihan Teknologi

| Kebutuhan | Pilihan | Alasan |
|-----------|---------|--------|
| Framework | Flutter (stable terbaru), Dart 3 | Satu codebase Android/iOS, UI cepat |
| Database | **Drift** (di atas SQLite) | Type-safe, reactive stream query (UI auto-update), migrasi terkelola, transaksi ACID — krusial untuk atomisitas kasir |
| State management | **Riverpod** | Sederhana, testable, cocok dengan stream Drift |
| Navigasi | go_router | Deklaratif, mendukung layout adaptif |
| Export Excel | package `excel` | Menulis .xlsx murni Dart, tanpa native dependency |
| Scan barcode | `mobile_scanner` | Berbasis kamera, on-device (offline) |
| File picker/share | `file_picker`, `share_plus` | Untuk restore backup & share export/struk |
| Path storage | `path_provider` | Lokasi database & file export |
| Format uang/tanggal | `intl` | Format Rupiah & tanggal Indonesia |
| PIN lock | `shared_preferences` + hash PIN | Kebutuhan ringan, tidak perlu DB |
| Struk sebagai gambar | `screenshot`/`RepaintBoundary` bawaan | Share struk tanpa printer |

> Catatan: versi package dikunci saat inisialisasi proyek (`flutter pub add`), bukan di dokumen ini, agar selalu mengambil versi stabil terbaru yang kompatibel.

---

## 3. Struktur Folder Proyek

```
lib/
├── main.dart
├── app.dart                      # MaterialApp, tema, router
├── core/
│   ├── constants/                # warna, ukuran, string umum
│   ├── utils/                    # formatter rupiah, tanggal, validators
│   └── widgets/                  # widget umum (tombol besar, empty state, dialog)
├── data/
│   ├── db/
│   │   ├── app_database.dart     # definisi Drift database + migrasi
│   │   └── tables/               # definisi tabel Drift
│   ├── repositories/             # implementasi repository (pakai Drift)
│   └── services/
│       ├── excel_export_service.dart
│       ├── backup_service.dart
│       └── receipt_service.dart  # render & share struk
├── domain/
│   ├── entities/                 # model murni (Product, Sale, dll)
│   └── repositories/             # abstract class / kontrak repo
└── features/
    ├── pos/                      # layar kasir + keranjang + pembayaran
    ├── products/                 # CRUD produk & kategori
    ├── inventory/                # stok, penyesuaian, riwayat stok
    ├── transactions/             # riwayat, detail, void, pelunasan hutang
    ├── reports/                  # dashboard & laporan
    └── settings/                 # profil toko, PIN, backup/restore, export
```

Setiap folder `features/<nama>/` berisi `screens/`, `widgets/`, `providers/` miliknya sendiri. Aturan dependensi: `features → domain ← data`; `features` tidak boleh meng-import Drift langsung — selalu lewat repository.

---

## 4. Skema Database (SQLite via Drift)

Semua uang disimpan sebagai **INTEGER rupiah penuh** (tanpa desimal). Semua waktu sebagai **UTC epoch millis** (ditampilkan dalam zona perangkat). Soft-delete memakai kolom `deleted_at` bila perlu; transaksi tidak pernah dihapus, hanya `status = voided`.

### Tabel

```sql
-- kategori produk
categories(
  id INTEGER PK AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
)

-- produk
products(
  id INTEGER PK AUTOINCREMENT,
  name TEXT NOT NULL,
  barcode TEXT NULL,                -- UNIQUE jika terisi (partial index)
  category_id INTEGER NULL REFERENCES categories(id),
  sell_price INTEGER NOT NULL,      -- harga jual (Rp)
  cost_price INTEGER NULL,          -- harga modal (Rp, opsional)
  stock REAL NOT NULL DEFAULT 0,    -- REAL: dukung satuan kg/liter
  unit TEXT NOT NULL DEFAULT 'pcs',
  low_stock_threshold REAL NULL,    -- null = pakai default global
  image_path TEXT NULL,             -- path file lokal
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)

-- transaksi penjualan (header)
sales(
  id INTEGER PK AUTOINCREMENT,
  invoice_number TEXT NOT NULL UNIQUE,  -- format: YYYYMMDD-XXXX
  subtotal INTEGER NOT NULL,
  discount INTEGER NOT NULL DEFAULT 0,  -- diskon level transaksi
  total INTEGER NOT NULL,
  payment_method TEXT NOT NULL,         -- 'cash' | 'noncash' | 'debt'
  paid_amount INTEGER NOT NULL DEFAULT 0,
  change_amount INTEGER NOT NULL DEFAULT 0,
  customer_name TEXT NULL,              -- wajib jika hutang
  status TEXT NOT NULL,                 -- 'completed' | 'debt_unpaid' | 'voided'
  note TEXT NULL,
  created_at INTEGER NOT NULL,
  voided_at INTEGER NULL,
  debt_paid_at INTEGER NULL
)

-- item transaksi (detail) — snapshot, tidak ikut berubah jika produk diedit
sale_items(
  id INTEGER PK AUTOINCREMENT,
  sale_id INTEGER NOT NULL REFERENCES sales(id),
  product_id INTEGER NULL REFERENCES products(id), -- NULL = item bebas
  product_name TEXT NOT NULL,      -- snapshot nama
  unit TEXT NOT NULL,
  qty REAL NOT NULL,
  sell_price INTEGER NOT NULL,     -- snapshot harga jual saat transaksi
  cost_price INTEGER NULL,         -- snapshot modal (untuk hitung laba)
  discount INTEGER NOT NULL DEFAULT 0,  -- diskon per item (nominal)
  line_total INTEGER NOT NULL
)

-- pergerakan stok (audit trail)
stock_movements(
  id INTEGER PK AUTOINCREMENT,
  product_id INTEGER NOT NULL REFERENCES products(id),
  type TEXT NOT NULL,              -- 'sale' | 'void_return' | 'adjust_in' | 'adjust_out' | 'opname'
  qty_change REAL NOT NULL,        -- +masuk / −keluar
  stock_after REAL NOT NULL,
  reference_sale_id INTEGER NULL REFERENCES sales(id),
  note TEXT NULL,
  created_at INTEGER NOT NULL
)

-- transaksi yang ditahan/parkir (hold)
held_carts(
  id INTEGER PK AUTOINCREMENT,
  label TEXT NULL,
  cart_json TEXT NOT NULL,         -- serialisasi isi keranjang
  created_at INTEGER NOT NULL
)

-- pengaturan key-value
settings(
  key TEXT PK,
  value TEXT NOT NULL
)  -- store_name, store_address, store_phone, low_stock_default, pin_hash, dll.
```

### Index Penting
- `products(name)`, `products(barcode)` — pencarian & scan cepat
- `sales(created_at)`, `sales(status)` — filter riwayat & laporan
- `sale_items(sale_id)`, `stock_movements(product_id, created_at)`

### Aturan Integritas (di level usecase + transaksi DB)
1. **Simpan penjualan** = satu transaksi DB atomik: insert `sales` + semua `sale_items` + update `products.stock` + insert `stock_movements`. Gagal salah satu → rollback semua.
2. **Void** = set status `voided`, kembalikan stok, catat `stock_movements(type='void_return')` — dalam satu transaksi DB.
3. Stok boleh minus (warung sering jual dulu catat belakangan) tapi UI menampilkan peringatan.
4. `invoice_number` dibangkitkan berurutan per hari di dalam transaksi DB yang sama (hindari duplikat).

---

## 5. Desain Fitur Kunci

### 5.1 Layar Kasir (POS) — Adaptif HP/Tablet
- **HP (portrait):** daftar/grid produk di atas, bar keranjang ringkas menempel di bawah; tap bar → sheet keranjang penuh → bayar.
- **Tablet (≥ 600dp lebar):** dua panel berdampingan — grid produk kiri, keranjang + tombol bayar kanan (layout `LayoutBuilder`/`Breakpoint`).
- Keranjang adalah state in-memory (Riverpod `Notifier`); hanya menyentuh DB saat "hold" atau "bayar".
- Pencarian produk memakai stream Drift dengan `LIKE`, debounce 150 ms.

### 5.2 Export Excel
- Service tersendiri, berjalan di `Isolate` (via `compute`) agar UI tidak macet pada data besar.
- Tiga jenis file: `produk_stok.xlsx`, `transaksi_<rentang>.xlsx` (sheet header + sheet detail item), `laporan_<rentang>.xlsx`.
- Simpan ke folder Documents app lalu tawarkan `share_plus`.

### 5.3 Backup & Restore (Pindah Perangkat)
- **Backup:** checkpoint WAL → salin file `.sqlite` menjadi `kasir_backup_YYYYMMDD_HHmm.db` → share/simpan. Satu file = seluruh data. (Foto produk: MVP menyalin DB saja; path foto invalid di device baru ditangani dengan placeholder — foto masuk backup zip di fase berikutnya.)
- **Restore:** pilih file → validasi (buka sebagai SQLite, cek tabel & versi skema) → tutup koneksi DB → timpa file DB → buka ulang & jalankan migrasi bila versi lama. Konfirmasi ganda sebelum menimpa.
- Versi skema disimpan di DB; migrasi Drift menjamin backup lama tetap bisa direstore di app versi baru.

### 5.4 Kunci PIN
- PIN 6 digit di-hash (SHA-256 + salt) di `shared_preferences`.
- Mengunci akses ke: Laporan, Pengaturan, void transaksi, ubah harga/produk (dapat dikonfigurasi). Layar kasir tetap terbuka.

---

## 6. State Management (Riverpod)

| Provider | Jenis | Tanggung jawab |
|----------|-------|----------------|
| `databaseProvider` | Provider | Instance tunggal AppDatabase |
| `productRepoProvider`, `saleRepoProvider`, dst | Provider | Repository |
| `cartProvider` | NotifierProvider | Keranjang aktif (in-memory) |
| `productListProvider(query)` | StreamProvider | Daftar produk reaktif dari Drift |
| `dailySummaryProvider(date)` | StreamProvider | Ringkasan laporan realtime |
| `settingsProvider` | NotifierProvider | Pengaturan toko |

Query laporan (SUM, GROUP BY) dikerjakan di SQL — bukan di Dart — agar tetap cepat di 100k transaksi.

---

## 7. Penanganan Error & Ketahanan
- SQLite mode WAL untuk ketahanan crash + concurrent read.
- Semua operasi tulis multi-tabel wajib dibungkus `db.transaction()`.
- Kegagalan export/backup/restore menampilkan pesan Bahasa Indonesia yang jelas + tidak mengubah data.
- Pengingat backup lokal: jika > 7 hari tidak backup, tampilkan banner lembut di Pengaturan/Dashboard.

## 8. Testing
- **Unit:** usecase (hitung total/diskon/kembalian, generate invoice, mutasi stok).
- **DB test:** Drift in-memory — simpan penjualan atomik, void, restore skema lama → migrasi.
- **Widget:** alur kasir happy path, keranjang, pembayaran tunai.
- **Manual device matrix:** HP kecil (5"), HP normal, tablet 10" (portrait & landscape).
