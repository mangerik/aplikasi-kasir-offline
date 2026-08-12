# Laporan Milestone 12 — Pelanggan & Program Poin (`schemaVersion` 1 → 2)

**Tanggal:** 12 Agustus 2026
**Baseline:** commit `717edcd` (tag `v1.1.0`) — M7–M11 tuntas, analyze bersih, 608/608 test lulus
**Acuan:** [plan-v1.1.md](plan-v1.1.md) "Milestone 12" · [prd-v1.1.md §7](prd-v1.1.md) &
[§10](prd-v1.1.md) · [architecture.md](architecture.md) ·
[ui-redesign-foundation.md](ui-redesign-foundation.md)

---

## 1. Ringkasan

M12 mengubah pelanggan dari **teks bebas** menjadi **entitas**, dan
memperkenalkan program poin di atas **buku besar**, bukan kolom saldo.

Dua hal yang paling menentukan hasilnya, dan keduanya soal uang:

1. **Migrasi 1 → 2 dengan backfill.** Daftar hutang lama pemilik warung
   harus keluar dari migrasi ini **persis sama nilainya**, sekaligus
   otomatis rapi (`"Bu Ani"`, `"bu ani"`, `"Bu Ani "` menjadi satu orang).
   Satu angka meleset di sini dan pemilik berhenti percaya pada aplikasi
   yang memegang catatan bonnya.
2. **Invarian saldo poin.** `customers.points` hanyalah cache; kebenaran
   ada di `customer_point_entries`. Kalau keduanya berpisah, yang terjadi
   di dunia nyata adalah adu mulut di depan warung tanpa alat bukti.

Angka kunci:

- `flutter analyze` → **0 issue**.
- `flutter test` → **670/670 lulus**. Baseline 608 utuh; **62 test baru**.
  Empat berkas test lama diubah — seluruhnya karena perilakunya memang
  berubah menurut PRD, dirinci di §6.
- `flutter build apk --release` → **sukses**; per-ABI **27,1 / 31,0 /
  33,4 MB**, ketiganya di bawah batas 40 MB (§7).
- `schemaVersion` **1 → 2**, `kAppSchemaVersion = 2`. Guard backup AC-10.2
  ikut naik otomatis tanpa perubahan kode (efek K-M11 yang dirancang untuk
  ini) dan diuji ulang dua arah.
- Navigasi bawah **tetap 5 tab**.
- Program poin **mati secara default** — nol elemen poin di layar mana pun
  maupun di struk sampai pemilik menyalakannya.

---

## 2. Skema & migrasi

### 2.1 Yang ditambahkan

| Objek | Bentuk |
|---|---|
| `customers` | `id`, `name`, `phone`, `note`, `points`, `is_active`, `merged_into_id`, `created_at`, `updated_at` |
| `customer_point_entries` | `id`, `customer_id`, `sale_id`, `type`, `points`, `balance_after`, `note`, `created_at` |
| `sales.customer_id` | `INTEGER NULL REFERENCES customers(id)` — lewat `ALTER TABLE ADD COLUMN` |
| `idx_customers_name_nocase` | `UNIQUE ... (name COLLATE NOCASE) WHERE is_active = 1` (parsial) |
| `idx_sales_customer` | `(customer_id, created_at)` |
| `idx_point_entries_customer` | `(customer_id, created_at)` |
| `settings` | `points_enabled` (`0`), `points_rupiah_per_point` (`10000`), `points_value_per_point` (`500`), `points_min_redeem` (`10`) |

`sales.customer_name` **tidak dihapus dan tidak diubah** (K-7.1) — ia
snapshot historis, persis seperti `sale_items.product_name`.

### 2.2 Backfill (PRD §7.3.E)

Seluruh langkah dibungkus **satu `transaction()`** di dalam `onUpgrade`
(AC-10.5): gagal di tengah jalan mengembalikan database persis ke keadaan
semula. Tidak ada `DROP`, tidak ada penulisan ulang tabel, tidak ada
penghapusan data (AC-10.4).

Pengelompokannya:

```sql
GROUP BY LOWER(TRIM(customer_name)), TRIM(customer_name)
ORDER BY key_name, freq DESC, first_at ASC
```

Baris pertama tiap kelompok `LOWER(TRIM(...))` menjadi **ejaan pemenang**
— frekuensi terbanyak dulu, seri diputus transaksi paling awal. Nama
kosong / hanya spasi / `NULL` diabaikan. Seluruh pelanggan hasil backfill
lahir `points = 0` dengan buku besar kosong: **tidak ada poin surut**
(K-7.4).

### 2.3 Bukti

`test/data/db/migration_v1_to_v2_test.dart` (14 test) berjalan di atas
**snapshot database v1 nyata** yang dibangun `test/fixtures/v1_database_fixture.dart`
— DDL-nya disalin apa adanya dari `sqlite_master` build v1, dan datanya
sengaja berantakan seperti database warung sungguhan: tiga ejaan satu
nama, nama kosong, `NULL`, transaksi voided, hutang yang sudah lunas.

| AC | Yang dibuktikan |
|---|---|
| AC-10.1 | Fixture memang ber-`user_version` 1, tanpa tabel `customers`, tanpa kolom `customer_id` (test prasyarat sendiri) |
| AC-7.1 | Tiga ejaan → satu pelanggan bernama `"Bu Ani"` dengan tiga transaksi; daftar hutang satu baris, total Rp40.000 |
| AC-7.2 | `SUM(total)` hutang sebelum vs sesudah migrasi **identik**, dan jumlah per-pelanggan juga identik |
| AC-7.3 | `customer_name` ketiga transaksi tetap `Bu Ani` / `bu ani` / `Bu Ani ` |
| AC-10.3 / AC-10.4 | Jumlah baris seluruh 7 tabel sama persis; kolom lama & isi `settings` utuh |
| AC-10.2 | Guard backup diuji **dua arah** dengan skema baru: `user_version` 1 → diterima & termigrasi; 2 → diterima; 3 → ditolak dengan pesan versi lebih baru |
| — | Migrasi idempoten (buka ulang tidak menggandakan pelanggan); ketiga index M12 terbentuk lewat jalur migrasi, bukan hanya `onCreate` |

---

## 3. Program poin

### 3.1 Aturan yang diterapkan

| Aturan | Penerapan |
|---|---|
| Dasar perolehan | `sales.total` **akhir** — sudah bersih dari diskon manual DAN dari potongan penukaran poin, sehingga poin tidak pernah lahir dari poin (AC-7.10) |
| Pembulatan | `total ~/ rupiahPerPoint`, ke bawah (AC-7.7: Rp37.000 → 3, Rp9.999 → 0) |
| Metode bayar | Semua, termasuk hutang (K-7.5) |
| Penukaran | Diskon level transaksi pada `sales.discount` + entri `redeem` (K-7.6) |
| Void | Poin ditukar dikembalikan **lebih dulu**, lalu poin earn ditarik — dua entri `void_return` terpisah dengan `sale_id` yang sama (AC-7.8) |
| Saldo negatif | Tidak mungkin: dipatok 0, entri mencatat poin yang benar-benar terpakai, sisanya dijelaskan di `note` (K-7.9) |
| Program mati | Tidak ada entri poin sama sekali; permintaan tukar diabaikan; struk tidak memuat kata "poin" (AC-7.6) |

### 3.2 Satu penulis saldo

`lib/data/db/point_ledger.dart` adalah **satu-satunya** tempat yang boleh
mengubah `customers.points` (K-7.8). Ia sengaja tidak membuka transaksi
sendiri: pemanggilnya (`SaleRepositoryImpl.saveSale`/`voidSale`,
`CustomerRepositoryImpl.merge`/`recalculate`) sudah berada di dalam
transaksi, dan penulisan poin harus atomik bersama peristiwa yang
memicunya.

### 3.3 Bukti invarian (AC-7.11)

`test/features/customers/points_ledger_test.dart` (19 test) memeriksa
`points == SUM(entries.points)` untuk **seluruh** pelanggan setelah setiap
langkah, termasuk pada rangkaian **acak berbenih tetap** 60 langkah
jual/tukar/void/gabung. Di akhir rangkaian, aksi "hitung ulang saldo dari
buku besar" menemukan **0 selisih**.

Penggabungan 3 pelanggan (AC-7.12) diuji terpisah: seluruh transaksi
menunjuk target, saldo = jumlah ketiganya, **tidak satu entri pun hilang**
(entri dialihkan, bukan disalin; +1 entri penanda `merge` bernilai 0 poin).

---

## 4. UI

Seluruh layar baru mengikuti "Kertas & Daun": token dari `context.palette`,
gaya teks dari `context.textStyles`, spasi dari `AppSizes`, komponen
bersama (`AppCard`, `AppPill`, `AppIconBadge`, `SectionHeader`,
`AppKeyValueRow`, `EmptyState`). Gerbang `no_hardcoded_colors_test.dart`
tetap hijau tanpa penambahan allowlist.

| Layar / komponen | Berkas | Catatan desain |
|---|---|---|
| Pemilih pelanggan | `features/customers/widgets/customer_picker_sheet.dart` | Sheet 75% tinggi, field pencarian **autofocus**, baris jauh di atas 56dp, baris pertama "Buat pelanggan baru: `<ketikan>`" saat tidak ada yang cocok persis |
| Form pelanggan | `.../widgets/customer_form_sheet.dart` | Tiga field saja (nama wajib, HP, catatan). Saat ubah, banner mengingatkan bahwa struk lama tidak ikut berubah |
| Daftar Pelanggan | `.../screens/customers_screen.dart` | Pencarian + chip filter **Semua / Punya hutang / Termasuk nonaktif**; kartu total hutang muncul saat filter hutang menyala; long-press → mode pilih → **Gabungkan** |
| Detail pelanggan | `.../screens/customer_detail_screen.dart` | Kartu identitas → 4 kartu ringkasan (nilai besar di atas label kecil) → riwayat belanja berpaginasi 20 → buku besar poin dengan tanda ±, `successText`/`dangerText`, dan "sisa N" di bawahnya |
| Gabung pelanggan | `.../widgets/merge_customers_sheet.dart` | Pilih nama yang dipertahankan → pratinjau dampak → banner "tidak bisa dibatalkan" → konfirmasi |
| Sheet pembayaran | `features/pos/widgets/payment_sheet.dart` | Field teks bebas diganti tombol/chip pemilih; kartu "TUKAR POIN" beraksen muncul hanya bila program menyala DAN pelanggan terpilih; pilihan penukaran berupa **chip**, bukan field angka |
| Kartu Pelanggan di Laporan | `features/reports/screens/reports_screen.dart` | Bekas kartu "Hutang Pelanggan"; dua ringkasan (total hutang, jumlah pelanggan) menuju layar yang sama dengan filter awal berbeda |
| Detail transaksi | `features/transactions/screens/sale_detail_screen.dart` | Nama pelanggan menjadi **tautan** ke profil bila `customer_id` ada; transaksi lama tanpa tautan tetap teks biasa |
| Pengaturan → Program Poin | `features/settings/widgets/points_section.dart` | Default mati; saat mati seluruh pengaturan turunannya **disembunyikan**, bukan sekadar dinonaktifkan. Ada aksi "Hitung Ulang Saldo dari Buku Besar" |
| Export Excel | `features/settings/widgets/export_section.dart` | Tile keempat "Pelanggan & Poin" (AC-7.16) — tanpa pemilih rentang tanggal, karena hutang & poin adalah keadaan sekarang |

**AC-7.5 (nol tap tambahan) dijaga bentuknya:** pemilih pelanggan adalah
tombol opsional di sheet pembayaran; alur "pilih barang → Bayar → Uang Pas
→ Selesaikan" tidak bertambah satu tap pun. Smoke test alur kasir tunai
M2 lulus tanpa perubahan satu baris pun.

---

## 5. Layar yang dihapus

`debt_list_screen.dart` dan `customer_debt_transactions_screen.dart`
**dihapus** sesuai PRD §7.6. Alasannya bukan kerapian: menyisakan layar
lama berarti dua daftar hutang dengan aturan pengelompokan berbeda — yang
lama per teks `customer_name` (jadi "Bu Ani" & "bu ani" tetap dua baris),
yang baru per `customer_id`. Itu persis masalah yang PRD §7.1 minta
diselesaikan.

`ReportRepository.getUnpaidDebts` / `getDebtTransactions` **tetap ada** di
layer data (agregasi per snapshot nama historis; test M4-nya tidak
disentuh), tapi kini tanpa konsumen UI. Providernya
(`unpaidDebtsProvider`, `customerDebtTransactionsProvider`) dihapus dan
alasannya ditinggalkan sebagai komentar di `report_providers.dart`.

---

## 6. Perubahan pada test lama — dan alasannya

Empat berkas test baseline diubah. **Tidak satu pun** karena test-nya
"rewel"; semuanya karena perilaku yang diuji memang berubah menurut PRD.

| Berkas | Perubahan | Dasar |
|---|---|---|
| `test/data/db/app_database_test.dart` | `expect(db.schemaVersion, 1)` → `2` (+ ditambah assert bahwa nilainya sama dengan `kAppSchemaVersion`) | PRD §10: Tier 2a menaikkan skema 1 → 2. Inti milestone ini |
| `test/features/pos/pos_checkout_flow_test.dart` | Alur hutang: mengetik ke field "Nama pelanggan *" → membuka **pemilih pelanggan**, mengetik nama, menekan "Buat pelanggan baru". Assert ditambah: `sales.customer_id` terisi & satu baris `customers` terbentuk | PRD §7.3.B mengganti field teks bebas dengan pemilih. **Aturan wajibnya tidak dilonggarkan** — assert bahwa tombol tetap nonaktif tanpa pelanggan dipertahankan apa adanya (AC-7.4) |
| `test/features/transactions/transactions_reports_ui_test.dart` | "PERLU DITAGIH" kini membuka `CustomersScreen` (filter hutang) lalu `CustomerDetailScreen`, bukan `DebtListScreen` → `CustomerDebtTransactionsScreen`. Seed transaksi hutang kini membuat pelanggan sungguhan | PRD §7.6: daftar hutang menjadi filter di dalam daftar pelanggan. Assert "TOTAL HUTANG BERJALAN" & "SISA HUTANG" tetap dipertahankan |
| `test/domain/usecases/{save_sale,void_sale,mark_debt_paid}_usecase_test.dart` | Tanda tangan `_FakeSaleRepository.saveSale` disesuaikan dengan parameter baru | Perubahan **mekanis** mengikuti kontrak repository. Tidak ada satu pun ekspektasi yang diubah |

---

## 7. Verifikasi

```
flutter analyze                 → No issues found!
flutter test                    → 670/670 lulus (baseline 608 + 62 baru)
flutter build apk --release     → sukses, app-release.apk 84,9 MB (fat, 3 ABI)
flutter build apk --release --split-per-abi
                                → sukses: 27,1 / 31,0 / 33,4 MB (armeabi-v7a /
                                  arm64-v8a / x86_64)
```

Ukuran fat APK (84,9 MB) **bukan** bentuk distribusi: ia memuat tiga ABI
sekaligus. Distribusi wajib per-ABI atau App Bundle (keputusan M10).
Ketiga APK per-ABI tetap di bawah batas 40 MB (AC-3.14, PRD §11.1), naik
tipis dari M11 (26,9 / 30,8 / 33,3 MB) — sekitar **0,2 MB**, seluruhnya
kode Dart: M12 tidak menambah satu pun dependency native.

Test baru (62):

| Berkas | Jumlah | Cakupan |
|---|---|---|
| `test/data/db/migration_v1_to_v2_test.dart` | 14 | AC-10.1 s.d. AC-10.4, AC-7.1 s.d. AC-7.3, gerbang backup dua arah |
| `test/features/customers/points_ledger_test.dart` | 19 | AC-7.6 s.d. AC-7.12 + invarian acak |
| `test/data/repositories/customer_repository_impl_test.dart` | 21 | CRUD, nama duplikat, AC-7.13, pencarian/paginasi/escape LIKE, ringkasan, export |
| `test/data/repositories/customer_repository_impl_performance_test.dart` | 4 | AC-7.14, AC-7.15, + `EXPLAIN QUERY PLAN` yang mengunci pemakaian index |
| `test/features/customers/customers_ui_test.dart` | 4 | Smoke HP 392dp, AC-7.6 di tingkat layar, palet gelap |

---

## 8. Yang TIDAK selesai (butuh perangkat fisik)

Satu item checklist sengaja dibiarkan tidak tercentang:

- **Uji manual device fisik** — alur kasir tunai tanpa memilih pelanggan
  tidak bertambah satu tap pun, dan **restore backup v1.0 di perangkat
  lain → migrasi jalan otomatis & total hutang sama persis**.

Padanan otomatisnya sudah hijau (uji migrasi atas snapshot v1 nyata untuk
yang kedua; smoke test alur kasir tunai untuk yang pertama), tapi keduanya
menyangkut hal yang hanya bisa dinilai di tangan: jumlah ketukan jempol,
dan file backup yang benar-benar berpindah antar HP.

Ambang performa AC-7.14 (< 100 ms) juga **diukur dengan ambang longgar**
(< 500 ms) di mesin pengembang. Yang dijaga uji itu adalah kelas
kompleksitasnya — dan itu dikunci lebih tegas oleh uji `EXPLAIN QUERY
PLAN` yang gagal begitu ada yang mengganti query berindeks dengan
pemuatan seluruh tabel ke Dart. Angka 100 ms sesungguhnya butuh HP
sungguhan.

---

## 9. Catatan untuk M13

- Migrasi berikutnya **2 → 3**; uji migrasinya wajib memakai snapshot
  skema 2. Pola `test/fixtures/v1_database_fixture.dart` bisa disalin —
  DDL-nya diambil dari `sqlite_master` build ini.
- `sales.customer_name` sekarang terisi untuk semua metode bayar, bukan
  hanya hutang. Laporan mana pun yang kelak mengelompokkan per nama harus
  sadar itu (dan sebaiknya memakai `customer_id`).
- Struk kini punya baris "Tukar poin", "Poin didapat", dan "Saldo poin".
  M13 menambah "Kasir: `<nama>`" pada builder yang sama
  (`EscPosReceiptBuilder`, `ReceiptService`, `ReceiptWidget` — tiga tempat,
  semuanya harus ikut).
- `PointLedger` menetapkan pola untuk milestone berikutnya: bila ada
  besaran tercache lain, penulisnya satu dan invariannya diuji.
