# PRD v1.1 — Aplikasi Kasir Warung (Post-MVP)

**Versi:** 1.1
**Tanggal:** 12 Agustus 2026
**Platform:** Flutter (Android prioritas utama; iOS menyusul)
**Status:** Draft
**Acuan:** [prd.md](prd.md) (v1.0 MVP) · [plan.md](plan.md) · [architecture.md](architecture.md) · [ui-redesign-foundation.md](ui-redesign-foundation.md)

---

## 1. Ringkasan

### 1.1 Konteks

MVP v1.0 sudah **rilis dan tuntas**: seluruh milestone M0–M6 tercentang di [plan.md](plan.md), APK release terbangun dengan R8, dan alur inti (kasir tunai/non-tunai/hutang, void, stok, laporan, export Excel, backup/restore lintas perangkat) sudah diuji di perangkat nyata pada 2026-08-12.

Dokumen ini menurunkan **enam fitur "Fase Berikutnya"** yang sudah disebut di [prd.md §3.3](prd.md) menjadi spesifikasi yang bisa langsung direncanakan dan dikerjakan. Tidak ada fitur produk baru di luar keenam itu.

Ditambah **satu fitur yang tidak berasal dari daftar tersebut**: **Sistem Lisensi Offline** (§6). Ini bukan permintaan pengguna melainkan **keputusan komersial pemilik produk** — aplikasi akan dijual ke UMKM, sehingga dibutuhkan gerbang aktivasi sebelum aplikasi bisa dipakai. Karena lisensi menggerbangi mulainya penjualan, ia masuk **Tier 1** dan wajib selesai **sebelum** rilis v1.1.0. Konsekuensinya terhadap prinsip "100% offline" dibahas terbuka di §1.4.

### 1.2 Cakupan dokumen

| # | Fitur | Tier | Bab |
|---|---|---|---|
| 1 | Cetak struk ke printer thermal Bluetooth 58mm | **Tier 1** | §3 |
| 2 | Import produk dari Excel | **Tier 1** | §4 |
| 3 | Mode gelap | **Tier 1** | §5 |
| 4 | **Sistem lisensi offline (aktivasi wajib: trial 3 hari / lifetime / tahunan)** | **Tier 1** | **§6** |
| 5 | Manajemen pelanggan lengkap (poin, riwayat belanja) | Tier 2 | §7 |
| 6 | Multi-user dengan PIN per kasir | Tier 2 | §8 |
| 7 | Grafik penjualan di dashboard | Tier 2 | §9 |

### 1.3 Prinsip yang TIDAK boleh dilanggar

Seluruh prinsip v1.0 tetap mengikat penuh — fitur di dokumen ini tidak boleh melonggarkannya sedikit pun:

1. **100% offline, selamanya.** Tidak ada satupun fitur baru yang butuh internet. Bluetooth ke printer adalah komunikasi lokal perangkat-ke-perangkat, bukan koneksi jaringan — tetap sah. Dependency yang mengunduh aset saat runtime (`google_fonts` dan sejenisnya) tetap **dilarang**. Sistem lisensi (§6) tidak melanggar ini — perangkat kasir tetap tidak pernah menyentuh jaringan — tapi ia **mengubah janji produk** dengan cara lain; lihat §1.4.
2. **Bahasa Indonesia** sebagai satu-satunya bahasa UI, termasuk seluruh pesan error, label template Excel, dan isi struk.
3. **Target sentuh ≥ 48dp**, CTA 52–60dp, teks & angka besar (lihat [ui-redesign-foundation.md §4.4](ui-redesign-foundation.md)).
4. **Data tidak keluar perangkat** kecuali pengguna sendiri yang share/export/cetak.
5. **Atomisitas data.** Setiap operasi tulis multi-tabel wajib dibungkus satu `db.transaction()` — berlaku juga untuk import Excel dan mutasi poin pelanggan.
6. **Sederhana.** Fitur baru tidak boleh menambah langkah pada alur kasir inti (pilih barang → bayar → selesai). Semua fitur di dokumen ini bersifat opsional dan **mati secara default**, dengan dua pengecualian: mode gelap yang default-nya "Terang" (lihat §5.7), dan sistem lisensi (§6) yang justru **wajib dan aktif sejak pemasangan pertama** — itulah hakikatnya sebagai gerbang penjualan.
7. **Anggaran teknis tetap:** APK < 40 MB, cold start < 3 detik, Android 8.0 (API 26) ke atas.

### 1.4 Pengecualian yang disengaja terhadap prinsip offline

Sistem lisensi (§6) adalah **pengecualian pertama yang disengaja** terhadap janji "100% offline" [prd.md §1](prd.md), dan dokumen ini menuliskannya terus terang alih-alih menyamarkannya.

**Yang TIDAK berubah:**
- Perangkat kasir **tidak pernah** membutuhkan internet — tidak saat aktivasi, tidak saat verifikasi, tidak saat berjualan. Verifikasi kode terjadi sepenuhnya di dalam perangkat, memakai tanda tangan kriptografis dan kunci publik yang ditanam di aplikasi.
- Tidak ada server, tidak ada akun, tidak ada login, tidak ada telemetri, tidak ada satu byte pun data toko yang keluar dari perangkat.
- Pertukaran kode aktivasi terjadi lewat **manusia** (mis. WhatsApp), dan boleh dilakukan dari **HP mana pun** — bukan dari perangkat kasir.

**Yang berubah:** ada **gerbang aktivasi** sebelum aplikasi bisa dipakai, dan aplikasi menjadi produk berbayar dengan masa berlaku (kecuali lisensi selamanya). Aplikasi tidak lagi "pasang lalu jalan".

Ini bukan pelonggaran diam-diam melainkan pertukaran yang disadari: gerbang penjualan adalah syarat agar pengembangan v1.2 dan seterusnya punya sumber daya. Batasnya dijaga ketat oleh §6.8 — begitu ada kebutuhan yang menuntut server, jawabannya tetap "tidak" untuk v1.1.

---

## 2. Prioritas & Alasan

### 2.1 Kriteria penentuan tier

Sejak v1.1 ada satu kriteria yang berdiri **di atas** ketiganya:

0. **Apakah fitur itu menggerbangi penjualan produk?** Hanya satu fitur yang memenuhinya — sistem lisensi (§6). Tanpa gerbang aktivasi, tidak ada penjualan; tanpa penjualan, tidak ada v1.2. Karena itu ia masuk Tier 1 dan menjadi syarat rilis v1.1.0, terlepas dari nilainya bagi pengguna akhir.

Sisanya ditentukan oleh tiga hal, berurutan:

1. **Seberapa sering keluhan itu muncul dalam pemakaian harian** (frekuensi > kedalaman).
2. **Rasio nilai terhadap risiko teknis** — terutama risiko terhadap integritas data.
3. **Kebutuhan migrasi skema database.** Migrasi adalah risiko tertinggi di aplikasi yang datanya hanya ada di satu perangkat tanpa cadangan cloud.

### 2.2 Tier 1 — dikerjakan duluan

| Fitur | Alasan masuk Tier 1 |
|---|---|
| **Cetak struk thermal 58mm** | Permintaan paling nyata: pembeli minta struk fisik, dan share WhatsApp tidak menggantikan itu. Ini juga satu-satunya fitur di daftar yang membuat aplikasi terasa "seperti kasir betulan" di mata pembeli. |
| **Import produk dari Excel** | Hambatan terbesar pengguna baru: mengetik 300–1.000 produk satu per satu lewat HP praktis mustahil. Fitur ini menentukan apakah warung yang sudah punya daftar barang mau pindah ke aplikasi ini sama sekali. Export Excel sudah ada, jadi arah baliknya wajar dilengkapi. |
| **Mode gelap** | Warung banyak yang buka sampai malam; kanvas kertas `#F5F2EA` di ruangan gelap menyilaukan. Biaya implementasinya sedang, risikonya nyaris nol terhadap data, dan makin lama ditunda makin mahal karena setiap layar baru menambah utang token warna. |
| **Sistem lisensi offline** | **Gerbang penjualan.** Aplikasi ini akan dijual; selama gerbang aktivasi belum ada, setiap APK yang beredar adalah pemakai gratis dan pendanaan v1.2 tidak pernah datang. Ia juga **tidak boleh menyusul belakangan**: memasang gerbang pada pengguna yang sudah terbiasa memakai aplikasi secara bebas jauh lebih menyakitkan daripada memasangnya sejak rilis berbayar pertama. Karena itu lisensi wajib selesai **sebelum** v1.1.0 keluar, bukan sesudahnya. |

**Alasan kolektif Tier 1: keempatnya TIDAK menyentuh skema database sama sekali.** Cukup kunci baru di tabel `settings`/`shared_preferences` dan penulisan lewat repository yang sudah ada (lisensi bahkan **hanya** memakai `shared_preferences` dan tidak menulis ke database sama sekali — §6.5). `schemaVersion` tetap **1**, sehingga backup v1.0 dan v1.1 saling kompatibel penuh selama Tier 1 — properti yang sangat berharga untuk fase pertama pasca-rilis.

### 2.3 Tier 2 — berikutnya

| Fitur | Alasan ditunda |
|---|---|
| **Manajemen pelanggan (poin, riwayat)** | Butuh tabel baru + **backfill data lama** (`sales.customer_name` teks bebas → entitas pelanggan). Migrasi paling berisiko dari seluruh fitur v1.1, dan hanya dibutuhkan warung yang sudah rutin melayani pelanggan langganan. |
| **Multi-user PIN per kasir** | Butuh tabel `users` + kolom baru di `sales`, dan menyentuh model izin di seluruh aplikasi. Hanya relevan untuk toko dengan karyawan — sebagian besar target pengguna (pemilik warung yang menjaga sendiri) tidak terpengaruh. |
| **Grafik penjualan** | Bernilai tinggi tapi murni tambahan visual di atas data yang sudah ada; menunggu tidak merugikan siapa pun. Ditempatkan setelah multi-user agar bisa langsung mendukung filter "per kasir" tanpa dikerjakan dua kali. |

### 2.4 Ketergantungan antar fitur

```
Tier 1 (paralel, tanpa migrasi DB, schemaVersion tetap 1)
  ├── §3 Printer thermal      ── independen
  ├── §4 Import Excel         ── independen
  ├── §5 Mode gelap           ── sebaiknya SELESAI sebelum Tier 2,
  │                              supaya layar baru Tier 2 langsung
  │                              ditulis dengan token sadar-tema
  └── §6 Lisensi offline      ── independen dari §3/§4, tapi WAJIB
                                 selesai sebelum rilis v1.1.0
                                 (gerbang penjualan). Layar barunya
                                 dibuat setelah §5 agar langsung
                                 sadar-tema.

Tier 2 (berurutan, ada migrasi DB)
  §7 Pelanggan   → schemaVersion 1 → 2
  §8 Multi-user  → schemaVersion 2 → 3
  §9 Grafik      → tanpa tabel baru; hanya menambah index & query.
                   Filter "per kasir" pada grafik BERGANTUNG pada §8.
```

Catatan lintas fitur:
- §3 (printer) dan §7 (pelanggan) bertemu di struk: nama pelanggan & saldo poin dicetak bila keduanya aktif.
- §3 dan §8 bertemu di struk: baris "Kasir: <nama>".
- §5 (mode gelap) memengaruhi §9 (grafik): warna grafik wajib diambil dari token tema, bukan hex tetap.
- §6 (lisensi) dan §8 (multi-user) bertemu di gerbang router: urutannya **lisensi → masuk (login) → shell**, tidak boleh terbalik (§6.3.F).
- §6 memakai `mobile_scanner` yang sudah dipakai untuk barcode produk, dan `share_plus` yang sudah dipakai untuk struk — tanpa dependency baru untuk keduanya.

---

## 3. Fitur Tier 1 — Cetak Struk ke Printer Thermal Bluetooth 58mm

### 3.1 Latar & masalah pengguna

Struk digital yang bisa di-share (v1.0) menyelesaikan kebutuhan arsip, tapi tidak menyelesaikan kebutuhan **saat itu juga di depan pembeli**: pembeli tidak selalu punya WhatsApp terbuka, tidak mau memberi nomor, atau sekadar ingin secarik kertas untuk mencocokkan belanjaan. Pemilik warung juga memakai struk cetak sebagai bukti sederhana kalau ada komplain "kembalian saya kurang".

Printer thermal Bluetooth 58mm adalah standar de-facto di pasar Indonesia: harganya murah (kisaran ratusan ribu), kertasnya mudah dicari di mana saja, dan tidak butuh tinta. Ini juga satu-satunya perangkat keras yang realistis diminta dari pengguna target.

Masalah yang diselesaikan:
- Pembeli minta struk fisik, kasir tidak bisa memberi.
- Share WhatsApp memakan waktu 10–20 detik dan menghentikan antrian.
- Struk cetak dipakai sebagai penanda barang sudah dibayar.

### 3.2 User stories

1. Sebagai pemilik, saya bisa menghubungkan aplikasi ke printer thermal Bluetooth saya **satu kali**, lalu printer itu langsung siap dipakai setiap hari tanpa setting ulang.
2. Sebagai kasir, setelah transaksi selesai saya bisa menekan satu tombol "Cetak" dan struk keluar dalam hitungan detik.
3. Sebagai kasir, saya bisa menyalakan "cetak otomatis" supaya struk langsung keluar begitu transaksi tersimpan, tanpa tap tambahan.
4. Sebagai kasir, saya bisa mencetak ulang struk transaksi lama dari Riwayat kalau struk pertama hilang atau kertasnya macet.
5. Sebagai kasir, kalau printer mati atau tidak terjangkau, saya mendapat pesan yang jelas — **dan transaksi saya tetap tersimpan aman**.
6. Sebagai pemilik, saya bisa mengatur isi struk (nama toko, alamat, telepon, kalimat penutup) dan melihat pratinjaunya sebelum mencetak percobaan.

### 3.3 Perilaku & alur detail

#### A. Pemasangan printer (sekali saja)

```
Pengaturan → kartu "Printer Struk"
→ status awal: "Belum ada printer terpasang"
→ tap "Hubungkan Printer"
→ (Android 12+) minta izin BLUETOOTH_CONNECT: dialog penjelasan Bahasa
  Indonesia dulu ("Aplikasi perlu izin Bluetooth untuk mengirim struk ke
  printer Anda"), baru izin sistem
→ (jika Bluetooth mati) tawarkan "Nyalakan Bluetooth"
→ Daftar "Printer yang sudah dipasangkan" (bonded devices) — tampil instan
     └── kosong? → panduan 3 langkah + tombol
         [Buka Pengaturan Bluetooth Android]
         "1. Nyalakan printer  2. Pasangkan (PIN biasanya 1234 atau 0000)
          3. Kembali ke sini"
→ tap satu perangkat → "Menghubungkan…" → "Cetak Uji"
→ struk uji keluar → "Struknya keluar dengan benar?" [Ya, simpan] [Tidak, coba lagi]
→ tersimpan sebagai printer default
```

**Pemasangan (pairing) dilakukan di Pengaturan Bluetooth Android, bukan di dalam aplikasi** — konsekuensi langsung dari pilihan package (§3.7.1). Imbalannya besar: aplikasi tidak pernah meminta izin memindai maupun izin lokasi, sehingga tidak ada kelas kegagalan izin Android 12+ dan tidak ada pertanyaan Play Store. Aplikasi menyediakan pintasan langsung ke layar Bluetooth Android agar perpindahannya tetap satu tap.

Kalau pengguna menjawab "Tidak", tampilkan panduan singkat: cek kertas (dan arah gulungannya), cek daya, pasangkan ulang lewat Pengaturan Bluetooth Android, coba lebar kertas 58mm/80mm.

#### B. Cetak setelah transaksi

- Layar sukses transaksi mendapat tombol **"Cetak"** berdampingan dengan "Bagikan" yang sudah ada. Aksi utama layar tetap "Transaksi Baru" (lihat prinsip "momen puncak" di [ui-redesign-foundation.md §1](ui-redesign-foundation.md)).
- Bila **cetak otomatis** aktif: pencetakan dimulai sendiri begitu layar sukses tampil; tombol berubah jadi "Cetak Ulang".
- Status cetak ditampilkan inline pada tombol: `Menghubungkan… → Mencetak… → Tercetak ✓` atau `Gagal — Coba Lagi`.
- **Wajib:** pencetakan terjadi SETELAH transaksi tersimpan dan berada di luar transaksi DB. Kegagalan printer tidak pernah membatalkan, mengubah, atau menunda penyimpanan penjualan.

#### C. Cetak ulang dari Riwayat

Detail transaksi mendapat aksi "Cetak Ulang". Struk hasil cetak ulang menambahkan baris penanda `** CETAK ULANG **` di bawah nomor struk. Transaksi berstatus `voided` boleh dicetak ulang dengan penanda `** DIBATALKAN **` dan tanpa baris kembalian.

#### D. Tata letak struk 58mm

Kertas 58mm efektif = **32 karakter** pada font A (lihat catatan lebar cetak di §3.7). Struk memakai urutan yang sama dengan `ReceiptService.formatReceiptText` yang sudah ada, sehingga struk cetak dan struk share konsisten:

```
        NAMA TOKO              (center, bold, tinggi ganda)
     Alamat toko (opsional)    (center, kecil)
      Telp: 08xxxxxxxxxx       (center, kecil)
--------------------------------
No. Struk: 20260812-0007
12 Agustus 2026 19:42
Kasir: Ratna                   (hanya bila §8 aktif)
Pelanggan: Bu Ani              (hanya bila ada)
--------------------------------
Indomie Goreng
  2 pcs x 3.500        7.000
Gula Pasir
  0,5 kg x 16.000      8.000
  Diskon              -1.000
--------------------------------
Subtotal              15.000
Diskon transaksi      -1.000
TOTAL                 14.000   (bold, tinggi ganda)
Tunai                 20.000
Kembali                6.000
--------------------------------
   Terima kasih :)             (center, dari Pengaturan)
   Poin Anda: 12               (hanya bila §7 aktif)
[feed 3 baris]
```

Aturan format:
- Nama produk lebih dari 32 karakter dipotong ke baris kedua (word-wrap), bukan dipotong paksa di tengah kata.
- Nominal rata kanan memakai padding spasi, bukan tab (tab tidak konsisten antar firmware printer).
- Rupiah dicetak **tanpa prefiks "Rp"** untuk menghemat lebar; simbol cukup di header kolom/label.
- Angka memakai pemisah ribuan titik sesuai format Indonesia yang sudah dipakai `CurrencyFormatter`.
- Logo toko (opsional, §3.6) dicetak sebagai raster monokrom lebar maksimal 384 dot di atas nama toko.

#### E. Pengaturan printer

Kartu "Printer Struk" di Pengaturan berisi:

| Pengaturan | Nilai | Default |
|---|---|---|
| Printer terpasang | nama + alamat MAC | kosong |
| Cetak otomatis setelah transaksi | ya/tidak | **tidak** |
| Jumlah salinan | 1–3 | 1 |
| Lebar kertas | 58mm / 80mm | 58mm |
| Cetak logo toko | ya/tidak (butuh gambar dipilih) | tidak |
| Kalimat penutup struk | teks bebas maks. 2 baris × 32 karakter | "Terima kasih" |
| Baris kosong setelah struk | 0–6 | 3 |
| Aksi | "Cetak Uji", "Lepas Printer" | — |

Semua tersimpan di tabel `settings` yang sudah ada (key-value) — lihat §3.5.

### 3.4 Acceptance criteria

| # | Kriteria (bisa diuji) |
|---|---|
| AC-3.1 | Dari kondisi belum pernah pasang printer, pengguna bisa menyelesaikan pemasangan + cetak uji dalam ≤ 6 tap (di luar dialog izin sistem). |
| AC-3.2 | Struk transaksi 5 item tercetak lengkap dan terbaca di printer 58mm; tidak ada karakter terpotong di kanan dan tidak ada baris yang melipat tak terduga. |
| AC-3.3 | Waktu dari tap "Cetak" sampai kertas mulai keluar ≤ 5 detik pada printer yang sudah pernah dipasangkan (bonded). |
| AC-3.4 | Huruf Indonesia dan simbol yang dipakai aplikasi (`-`, `.`, `,`, `:`, `(`, `)`, `%`) tercetak benar; tidak ada mojibake. Karakter di luar dukungan codepage diganti aman (mis. `→` menjadi `-`), tidak membuat printer macet. |
| AC-3.5 | Bluetooth dimatikan → tap "Cetak" menghasilkan pesan Bahasa Indonesia "Bluetooth mati. Nyalakan dulu untuk mencetak." beserta tombol aksi; aplikasi tidak crash. |
| AC-3.6 | Printer mati/di luar jangkauan → operasi gagal dengan timeout ≤ 10 detik dan pesan "Printer tidak terjangkau…"; **transaksi tetap tersimpan dan tetap muncul di Riwayat**. |
| AC-3.7 | Menekan "Cetak" dua kali cepat hanya menghasilkan satu struk (job cetak di-debounce/dikunci selama proses berjalan). |
| AC-3.8 | Cetak ulang dari Riwayat menghasilkan struk identik + penanda `** CETAK ULANG **`. |
| AC-3.9 | Transaksi void yang dicetak ulang menampilkan penanda `** DIBATALKAN **` dan tidak menampilkan baris kembalian. |
| AC-3.10 | Di Android 12+ (API 31+), penolakan izin `BLUETOOTH_CONNECT` menampilkan penjelasan + pintasan ke Pengaturan aplikasi, bukan crash atau layar kosong. |
| AC-3.11 | Aplikasi **tidak pernah** meminta izin lokasi maupun `BLUETOOTH_SCAN` — diverifikasi dengan memeriksa `AndroidManifest.xml` hasil merge (`app/build/outputs/logs/manifest-merger-*.txt`) pada build release. |
| AC-3.16 | Daftar perangkat kosong (belum ada printer dipasangkan di Android) menampilkan panduan 3 langkah + tombol pintasan ke Pengaturan Bluetooth Android, bukan layar kosong. |
| AC-3.12 | Pemasangan printer bertahan setelah aplikasi ditutup paksa dan dibuka lagi (tidak perlu pasang ulang). |
| AC-3.13 | Backup → restore di perangkat lain: pengaturan printer ikut terbawa, tapi koneksi otomatis gagal dengan pesan wajar bila printer tidak ada — tidak memblokir aplikasi. |
| AC-3.14 | Ukuran APK release tetap < 40 MB setelah dependency printer ditambahkan. |
| AC-3.15 | `flutter build apk --release` sukses (uji regresi wajib — proyek ini pernah gagal build karena modul Android pihak ketiga tanpa `namespace`, lihat plan.md catatan M6). |

### 3.5 Dampak skema database

**Tidak ada perubahan skema. `schemaVersion` tetap 1.** Seluruh konfigurasi memakai tabel `settings` (key-value) yang sudah ada:

| Key | Nilai | Keterangan |
|---|---|---|
| `printer_address` | `String` (MAC / device id) | kosong = belum terpasang |
| `printer_name` | `String` | untuk ditampilkan di UI |
| `printer_type` | `classic` \| `ble` | default `classic`; disiapkan untuk jalur cadangan BLE (§3.7.2) |
| `printer_paper_width` | `58` \| `80` | default `58` |
| `printer_auto_print` | `0` \| `1` | default `0` |
| `printer_copies` | `1`–`3` | default `1` |
| `printer_logo_path` | path file lokal | opsional |
| `receipt_footer_text` | `String` | default `Terima kasih` |
| `receipt_feed_lines` | `0`–`6` | default `3` |

Konsekuensi: fitur ini **tidak memengaruhi kompatibilitas backup/restore sama sekali**.

### 3.6 Dampak UI

Semua mengikuti [ui-redesign-foundation.md](ui-redesign-foundation.md); tidak boleh ada komponen atau warna baru di luar sistem.

- **Pengaturan → kartu "Printer Struk"**: pakai `SettingsCard` yang sudah ada (pola sama dengan `store_profile_section.dart` / `pin_section.dart`). Status memakai `AppPill`: `AppTone.success` ("Terhubung"), `AppTone.neutral` ("Belum terpasang"), `AppTone.danger` ("Gagal terhubung").
- **Sheet pilih perangkat**: bottom sheet radius `radius2xl`, tiap baris perangkat tinggi ≥ 56dp (di atas `minTouchTarget` 48), nama perangkat `titleMedium`, alamat MAC `bodySmall`/`inkSecondary`. Daftar berisi perangkat yang **sudah dipasangkan** di Android; saat kosong tampilkan `EmptyState` berisi panduan 3 langkah + tombol "Buka Pengaturan Bluetooth Android" (AC-3.16).
- **Tombol Cetak di layar sukses**: tombol sekunder `OutlinedButton` tinggi `buttonHeight` 52 di samping "Bagikan"; **jangan** mencuri penekanan dari CTA "Transaksi Baru" (prinsip 3: satu titik fokus per layar).
- **Pratinjau struk**: reuse `ReceiptWidget` yang sudah ada, dibungkus kartu dengan latar `AppColors.surface` dan lebar tetap gaya kertas struk. Pratinjau **selalu bertema terang** meski aplikasi sedang mode gelap (lihat §5.3.D).
- **Empty state & error**: ikuti aturan "layar kosong tetap mengarahkan" — ikon + judul + kalimat pengarah + tombol aksi (mis. "Belum ada printer terpasang / Hubungkan printer thermal Bluetooth agar struk bisa langsung dicetak / [Hubungkan Printer]").
- Ikon: `Icons.print_outlined` untuk aksi cetak, `Icons.bluetooth` untuk daftar perangkat.

### 3.7 Riset package, keputusan & risiko teknis

> Bagian ini diisi dari riset pub.dev pada 12 Agustus 2026 — lihat tabel di §3.7.1. Versi yang disebut adalah versi yang direkomendasikan untuk dikunci di `pubspec.yaml` saat implementasi; verifikasi ulang dengan `flutter pub outdated` sebelum mulai.

#### 3.7.1 Kandidat package

Riset dilakukan atas toolchain **persis milik proyek ini** (Flutter 3.44.8 stable, Dart `^3.12.2`, AGP 9.0.1, Gradle 9.1.0, KGP 2.3.20, `minSdk 26`), dan kandidat teratas **diuji `flutter build apk` sungguhan**, bukan dinilai dari deskripsi pub.dev saja. Ini penting karena proyek ini sudah dua kali tersandung kegagalan build akibat modul Android pihak ketiga (lihat plan.md catatan M0 & M6).

| Package | Versi | Rilis terakhir | Transport | Hasil |
|---|---|---|---|---|
| **`print_bluetooth_thermal`** | **1.2.2** | 2026-05-23 | **Bluetooth Klasik (SPP)** | ✅ **build APK sukses** (diuji). 160/160 pub points, unduhan 30 hari tertinggi di antara package printer Bluetooth. Constraint `flutter >=3.44.0` — dirilis untuk Flutter yang persis dipakai proyek ini. |
| **`esc_pos_utils_plus`** | **2.0.4** | 2024-09-01 | — (generator byte murni) | ✅ **build APK sukses** (diuji). Tidak ada kode platform, jadi "tanggal rilis lama" bukan risiko build. |
| `flutter_esc_pos_utils` | 1.0.1 | 2024-05-03 | — (generator) | ⚠️ Cadangan generator bila `esc_pos_utils_plus` bermasalah. |
| `blue_thermal_printer` | 1.2.3 | 2022-07-19 | SPP | ❌ **build GAGAL** (diuji): `Namespace not specified` — persis mode kegagalan `flutter_native_splash` di M6. |
| `bluetooth_print_plus` | 2.4.6 | 2025-03-22 | BLE (+ jar tertutup) | ❌ **build GAGAL** (diuji): dikompilasi terhadap `compileSdk 31`, ditolak `androidx.window`. |
| `flutter_thermal_printer` | 2.2.1 | 2026-05-19 | BLE saja | ❌ **resolusi dependency GAGAL**: menarik `image ^4.8.0` → `xml ^7`, bentrok langsung dengan `excel ^4.0.6` (`xml >=5 <7`). Hanya bisa dipakai jika `excel` dibuang — tidak mungkin, itu tulang punggung fitur export. |
| `flutter_blue_plus` | 2.3.12 | 2026-08-10 | BLE saja | ❌ **Lisensi berbayar untuk penggunaan komersial** (README-nya menyatakan komersial wajib lisensi). Aplikasi kasir jelas komersial. Ini juga mendiskualifikasi package lain yang menariknya. |
| `thermal_printer` | 1.0.5 | 2024-02-02 | SPP + BLE | ❌ modul Android tanpa `namespace`. |
| `esc_pos_bluetooth`, `esc_pos_printer`, `esc_pos_utils`, `pos_printer_manager` | — | 2021 | — | ❌ tidak dipelihara sejak 2021. `esc_pos_printer` juga WiFi/TCP, bukan Bluetooth. |
| `unified_esc_pos_printer` | 3.4.0 | 2026-07-16 | SPP+BLE+USB | ❌ resolusi gagal: `win32` 6 vs 5, bentrok `file_picker ^12` (masalah keluarga yang sama dengan catatan M0). |
| `printly`, `esc_pos_dart`, dkk. | — | 2026 | campur | ➖ adopsi mendekati nol; tidak layak produksi. |

**Rekomendasi — versi yang dikunci di `pubspec.yaml`:**

```yaml
print_bluetooth_thermal: ^1.2.2   # transport: Bluetooth Klasik (SPP)
esc_pos_utils_plus: ^2.0.4        # generator byte ESC/POS (murni Dart)
```

Alasan:

1. **Satu-satunya kombinasi yang terbukti bisa dibangun** pada toolchain proyek ini — dibuktikan dengan APK jadi, bukan asumsi. Dua kandidat populer lainnya gagal build dengan cara yang sama persis seperti kegagalan yang pernah menghantam proyek ini.
2. **Bluetooth Klasik/SPP cocok dengan mayoritas printer 58mm yang beredar di Indonesia.** Printer kelas Zjiang ZJ-58xx, Goojprt PT-210, POS-5890, Panda, Eppos, Xprinter umumnya memakai SPP (`UUID 00001101-…`) — ditandai oleh alur pemasangan khas "masukkan PIN 1234/0000" yang hanya ada pada Bluetooth Klasik, bukan BLE. Seluruh alternatif yang aktif dipelihara justru **BLE-only**, yang berisiko tidak menemukan printer sama sekali di lapangan.
3. **Izin Android paling minimal.** Package ini sengaja dirancang tanpa izin lokasi: ia hanya membaca daftar perangkat yang **sudah dipasangkan** (bonded). Cukup `BLUETOOTH_CONNECT`; **tidak butuh `BLUETOOTH_SCAN` maupun `ACCESS_FINE_LOCATION`.** Ini menghilangkan seluruh kelas masalah izin Android 12+ sekaligus pertanyaan Play Store soal izin lokasi.
4. **100% offline.** `esc_pos_utils_plus` memuat profil kapabilitas printer dari **asset yang di-bundle**, bukan dari jaringan — sesuai [prd.md §1](prd.md).
5. **Tidak ada konflik dependency** dengan `excel ^4.0.6`, `file_picker ^12.0.0-beta.7`, dan `mobile_scanner ^7.4.0` (diverifikasi lewat resolusi terhadap `pubspec.yaml` proyek ini; `image` ter-resolve ke 4.3.0).
6. **Lisensi bebas** (BSD-3-Clause).

**Konsekuensi desain yang harus diterima (penting):** karena package hanya membaca perangkat bonded, **pemasangan awal printer dilakukan di Pengaturan Bluetooth Android**, bukan di dalam aplikasi. Alur di §3.3.A mengikuti kenyataan ini. Ini justru alur yang lebih tahan masalah untuk pengguna target: pemasangan Bluetooth adalah hal yang sudah pernah mereka lakukan (headset, speaker), dan aplikasi tidak perlu meminta izin memindai apa pun.

**Fakta teknis yang menentukan format struk (terverifikasi):**
- 58mm @ 203 dpi = **384 dot** area cetak; **Font A = 32 karakter/baris**, Font B = 42. Ini yang dipakai §3.3.D.
- Codepage **CP437** sudah cukup: Bahasa Indonesia murni ASCII.
- **Jebakan nyata:** karakter non-ASCII yang menyelinap dari UI/data — `×`, `–` (en dash), `’`, dan terutama **spasi tak-putus (U+00A0)** yang bisa dihasilkan `NumberFormat` locale `id_ID` milik `intl`. Semuanya tercetak sebagai sampah. Sanitasi ke ASCII **wajib** sebelum byte dibentuk (dikunci oleh AC-3.4 dan K-3.7).
- **Logo:** kirim sebagai raster 1-bit monokrom, lebar ≤ 384 px (idealnya ≤ 360 px agar ada margin), memakai perintah raster `GS v 0` yang paling luas didukung klon murah. Foto/grayscale tidak cocok untuk kertas thermal — hanya logo hitam-putih rata.
- **QR:** perintah QR native (`GS ( k`) **sering tidak diimplementasikan** printer murah dan menghasilkan kertas kosong. Bila QR dibutuhkan, render sendiri jadi bitmap lalu cetak sebagai raster (lihat K-3.8).

#### 3.7.2 Risiko teknis

| Risiko | Dampak | Mitigasi |
|---|---|---|
| `print_bluetooth_thermal` masih memakai `apply plugin: 'kotlin-android'` + `kotlinOptions` (DSL lama) | Saat ini hanya **warning**; Flutter/KGP mendatang berpotensi menjadikannya error dan build gagal | **Jangan hapus `android.builtInKotlin=false` dari `android/gradle.properties`** — baris inilah yang membuatnya lolos hari ini. Bila kelak pecah: patch lewat `subprojects { afterEvaluate { … } }` di `android/build.gradle.kts`, atau *vendor* plugin ke folder lokal sebagai `path:` dependency (lisensi BSD-3 mengizinkan; kode Kotlin-nya satu file). Presedennya sudah ada di M6. |
| Package printer ditinggalkan pemeliharanya | Tidak bisa build di Flutter berikutnya | Pisahkan transport di balik antarmuka `ReceiptPrinter` sendiri (`data/services/printing/`); byte ESC/POS dibangkitkan generator terpisah yang tidak bergantung transport. Ganti transport = ganti satu file, format struk tidak tersentuh. |
| Modul Android package tidak punya `namespace` | **`flutter build apk --release` gagal total** (persis kejadian `flutter_native_splash` di M6) | Sudah dihindari lewat pemilihan package yang diuji build (§3.7.1). Aturan tetap: setiap penambahan dependency native masuk **commit terpisah** yang divalidasi `flutter build apk --release` sebelum kode fitur ditulis. Kalau gagal — coret kandidatnya, jangan tambal Gradle. |
| Konflik dependency transitif | Tidak bisa `pub get` sama sekali | Sudah terverifikasi bersih terhadap `excel ^4.0.6` / `file_picker ^12` / `mobile_scanner ^7.4.0`. Kandidat yang bentrok (`flutter_thermal_printer`, `unified_esc_pos_printer`) sudah dicoret di §3.7.1 — jangan dihidupkan lagi tanpa uji resolusi ulang. |
| Printer di lapangan ternyata BLE-only | Printer tidak muncul di daftar bonded | Panduan di layar kosong (AC-3.16) menutup sebagian besar kasus (printer belum dipasangkan). Untuk BLE sejati: jalur cadangan memakai `universal_ble` (lisensi bebas) di balik antarmuka `ReceiptPrinter` yang sama — byte-nya identik, hanya transportnya berbeda. **`flutter_blue_plus` dihindari karena butuh lisensi komersial berbayar.** |
| Izin Bluetooth Android 12+ | Fitur mati diam-diam di HP baru | Deklarasikan **hanya** `BLUETOOTH_CONNECT` (+ `BLUETOOTH`/`BLUETOOTH_ADMIN` dengan `maxSdkVersion="30"`). **Jangan** menambahkan `BLUETOOTH_SCAN` atau izin lokasi — tidak dibutuhkan dan memicu pertanyaan Play Store (AC-3.11). |
| Fragmentasi firmware printer murah | Struk berantakan di merek tertentu | Uji minimal 3 merek berbeda; sediakan pengaturan lebar kertas & jumlah baris feed; hindari perintah ESC/POS eksotis — tanpa auto-cut, tanpa QR native, tanpa raster `GS ( L`. |
| Karakter non-ASCII menyelinap ke struk | Cetakan sampah / printer macet | Sanitasi ASCII wajib (K-3.7), dengan unit test khusus untuk keluaran `intl` locale `id_ID` yang bisa memuat spasi tak-putus (U+00A0). |
| Cetak memblokir UI | Kasir mengira app hang | Seluruh operasi printer `async` dengan timeout eksplisit (koneksi 8 detik, tulis 10 detik) dan status inline pada tombol. |
| Dua job cetak bersamaan | Struk ganda / stream rusak | Kunci mutex satu job pada service printer; tombol non-aktif selama proses. |
| Bluetooth dianggap "online" | Melanggar prinsip offline | Ditegaskan di §1.3: Bluetooth adalah tautan lokal perangkat-ke-perangkat, tidak ada lalu lintas internet. Package yang dipilih tidak boleh melakukan panggilan jaringan apa pun. |

#### 3.7.3 Keputusan

- **K-3.1** Transport printer diabstraksi di balik `abstract class ReceiptPrinter` di `data/services/printing/`; layer `features/` tidak pernah menyentuh package Bluetooth langsung (konsisten dengan aturan dependensi di [architecture.md §3](architecture.md)).
- **K-3.2** Byte ESC/POS dibentuk oleh builder milik aplikasi sendiri (`EscPosReceiptBuilder`) yang menerima `SaleResult` + `StoreProfile` dan menghasilkan `List<int>`. Builder ini **murni Dart, tanpa dependency platform**, sehingga bisa diuji unit penuh tanpa perangkat (uji: jumlah karakter per baris, perataan nominal, pemotongan nama panjang, penggantian karakter tak didukung).
- **K-3.3** Hanya **satu printer default** yang disimpan. Multi-printer (mis. printer dapur) di luar cakupan.
- **K-3.4** Pencetakan **tidak pernah** masuk ke dalam `db.transaction()` penyimpanan penjualan.
- **K-3.5** Tidak ada antrean cetak persisten. Kegagalan cetak diselesaikan dengan "Cetak Ulang" manual dari Riwayat — lebih sederhana dan tidak menambah state yang bisa korup.
- **K-3.6** Lebar 80mm disiapkan sebagai *pengaturan* (48 karakter) karena biayanya hanya satu konstanta, tapi **pengujian resmi v1.1 hanya untuk 58mm**.
- **K-3.7** Seluruh teks disanitasi ke **ASCII** sebelum dikirim ke printer (codepage CP437). Karakter di luar ASCII dipetakan ke padanan aman (`×`→`x`, `–`/`—`→`-`, `’`→`'`, U+00A0→spasi biasa) dan sisanya diganti spasi. Diuji unit, termasuk atas keluaran `CurrencyFormatter` yang memakai `intl` locale `id_ID`.
- **K-3.8** **Tidak ada QR native ESC/POS** (`GS ( k`) di v1.1 — banyak klon printer murah mengabaikannya dan mengeluarkan kertas kosong tanpa pesan error. Bila QR dibutuhkan kelak, dirender sendiri menjadi bitmap lalu dicetak sebagai raster. Logo dicetak sebagai raster 1-bit lewat perintah yang paling luas didukung (`GS v 0`), lebar ≤ 384 px.
- **K-3.9** Pemasangan (pairing) printer memakai Pengaturan Bluetooth Android, bukan pemindaian di dalam aplikasi (§3.3.A) — konsekuensi yang **diterima secara sadar** demi menghapus seluruh kebutuhan izin pindai & lokasi.

### 3.8 TIDAK termasuk

- Printer WiFi/LAN/Ethernet, printer USB/OTG, printer dot-matrix.
- Auto-cutter, laci kas (cash drawer), buzzer.
- Printer label/barcode (mencetak label harga produk).
- Antrean cetak yang bertahan setelah aplikasi ditutup.
- Lebih dari satu printer tersimpan, atau printer khusus per jenis dokumen.
- Cetak laporan/laporan harian ke printer thermal (hanya struk transaksi).
- Cetak QRIS dinamis (dilarang [prd.md §3.2](prd.md)) — QR statis milik toko sebagai gambar logo tetap boleh karena murni raster.
- Dukungan iOS untuk printer (menyusul bersama rilis iOS).

---

## 4. Fitur Tier 1 — Import Produk dari Excel

### 4.1 Latar & masalah pengguna

Aplikasi sudah bisa **meng-export** produk ke `produk_stok.xlsx` (M5). Arah baliknya belum ada, dan itulah tembok pertama pengguna baru: warung dengan 300–1.000 barang harus mengetik semuanya lewat form di HP. Realistis, ini butuh berjam-jam dan membuat sebagian besar calon pengguna berhenti sebelum memakai aplikasi sama sekali.

Kasus pemakaian nyata:
1. **Pengisian awal** — pemilik sudah punya daftar barang di Excel/WPS (dari aplikasi lama, dari toko grosir, atau ketikan sendiri di laptop).
2. **Pembaruan harga massal** — harga rokok/minyak naik; mengubah 40 harga lewat form satu-satu menyakitkan. Export → edit di laptop → import kembali jauh lebih cepat.
3. **Pemulihan sebagian** — pengguna ingin memindahkan katalog produk saja ke perangkat baru tanpa membawa riwayat transaksi (backup penuh membawa semuanya).

### 4.2 User stories

1. Sebagai pemilik baru, saya bisa mengunduh template Excel dari aplikasi, mengisinya di laptop, lalu mengimpornya sehingga ratusan produk masuk sekaligus.
2. Sebagai pemilik, saya bisa meng-export produk saya, mengubah harganya di Excel, lalu **mengimpor file yang sama** untuk memperbarui harga secara massal.
3. Sebagai pemilik, sebelum data benar-benar masuk saya bisa melihat **pratinjau**: berapa produk baru, berapa diperbarui, dan baris mana yang bermasalah beserta alasannya.
4. Sebagai pemilik, saya ingin baris yang salah tidak membatalkan seluruh impor secara diam-diam — saya ingin tahu persis baris nomor berapa dan kenapa.
5. Sebagai pemilik, saya ingin impor **tidak menimpa stok saya** kecuali saya memang memintanya, karena file Excel saya biasanya sudah basi soal stok.

### 4.3 Format template & aturan validasi

#### A. Template

Aplikasi menyediakan tombol **"Unduh Template"** yang menghasilkan `template_produk.xlsx` berisi dua sheet:

**Sheet 1: `Produk`** — baris 1 adalah header, baris 2–3 berisi contoh yang jelas-jelas ditandai contoh.

| Kolom | Header (harus persis) | Wajib | Aturan |
|---|---|---|---|
| A | `Nama Produk` | ✅ | 1–100 karakter setelah di-*trim*. |
| B | `Barcode` | — | Angka/teks. Kosong berarti produk tanpa barcode. |
| C | `Kategori` | — | Nama kategori; dibuat otomatis bila belum ada (opsi bisa dimatikan). |
| D | `Harga Jual` | ✅ | Bilangan bulat rupiah ≥ 0. |
| E | `Harga Modal` | — | Bilangan bulat rupiah ≥ 0. |
| F | `Stok` | — | Angka ≥ 0, boleh desimal (kg/liter). Kosong = 0. |
| G | `Satuan` | — | Teks bebas maks. 10 karakter. Kosong = `pcs`. |
| H | `Batas Stok Menipis` | — | Angka ≥ 0. Kosong = pakai default global. |
| I | `Aktif` | — | `Ya`/`Tidak` (juga menerima `1`/`0`, `Y`/`T`). Kosong = `Ya`. |

**Sheet 2: `Petunjuk`** — aturan pengisian dalam Bahasa Indonesia, contoh format harga & stok, dan peringatan tentang barcode ganda.

#### B. Kompatibilitas dengan file hasil export

File `produk_stok.xlsx` hasil export v1.0 **wajib bisa diimpor langsung tanpa diedit strukturnya**. Kolom `No` dan `Status Stok` yang ada di file export **diabaikan** saat impor. Ini menjadikan siklus **export → edit → import** sebagai alur resmi yang didukung (AC-4.2).

Aturan pencocokan header:
- Header dicocokkan **case-insensitive**, spasi di awal/akhir diabaikan.
- Urutan kolom **bebas** — pencocokan berdasarkan nama header, bukan posisi.
- Kolom tak dikenal diabaikan diam-diam.
- Bila kolom wajib (`Nama Produk`, `Harga Jual`) tidak ditemukan → impor ditolak sebelum apa pun diproses, dengan pesan menyebut kolom yang hilang.
- Sheet yang dibaca: sheet bernama `Produk` bila ada; kalau tidak, sheet pertama.

#### C. Normalisasi nilai (toleran terhadap kebiasaan pengguna Indonesia)

| Masukan | Diterima sebagai |
|---|---|
| `Rp 12.000`, `12.000`, `12000`, `12 000` | `12000` |
| `12.500,5` (stok) | `12500.5` |
| `1,5` (stok) | `1.5` |
| `1.5` (stok) | `1.5` |
| Sel bertipe angka Excel | dipakai apa adanya |
| `Ya`, `ya`, `YA`, `1`, `Y`, `true` | aktif |

Aturan turunan yang harus eksplisit di kode:
- **Harga** selalu dibulatkan ke rupiah penuh; nilai desimal pada harga → **peringatan** dan dibulatkan (bukan error), sesuai [prd.md §8](prd.md).
- Titik pada kolom harga selalu dianggap **pemisah ribuan**; koma dianggap desimal. Pada kolom stok, jika hanya ada satu tanda dan diikuti ≤ 2 digit, tanda itu dianggap desimal.

#### D. Tingkat masalah per baris

| Tingkat | Perilaku |
|---|---|
| **Error** | Baris dilewati, tidak diimpor. Contoh: nama kosong, harga jual kosong/negatif/tidak terbaca, barcode ganda di dalam file. |
| **Peringatan** | Baris tetap diimpor, ditandai kuning di pratinjau. Contoh: harga modal > harga jual, harga desimal dibulatkan, nama sama dengan produk yang sudah ada (tanpa barcode), satuan lebih dari 10 karakter (dipotong). |

#### E. Perilaku duplikat barcode

| Situasi | Perilaku |
|---|---|
| Barcode ganda **di dalam file** | **Semua** baris dengan barcode itu ditandai error dan dilewati; pesan menyebut semua nomor barisnya (mis. "Barcode 899123 muncul di baris 12 dan 47"). Tidak ada penebakan mana yang benar. |
| Barcode sudah ada **di database** | Ditentukan mode duplikat yang dipilih pengguna sebelum commit:<br>• **Perbarui produk yang ada** (default) — produk dicocokkan lewat barcode, lalu nama/kategori/harga jual/harga modal/satuan/threshold/status aktif diperbarui.<br>• **Lewati** — baris tidak diimpor, dihitung sebagai "dilewati". |
| Baris **tanpa barcode** | Tidak pernah dicocokkan ke produk lama (tidak ada pencocokan berdasarkan nama). Selalu masuk sebagai produk baru. Bila ada produk aktif bernama sama persis → **peringatan** duplikat, tapi tetap diimpor. |

#### F. Perlakuan stok saat memperbarui

Stok **tidak diubah secara default** saat memperbarui produk yang sudah ada. Alasan: file Excel pengguna hampir selalu lebih tua daripada stok berjalan di aplikasi, dan menimpanya diam-diam berarti menghapus penjualan/penyesuaian yang terjadi sejak file dibuat.

Pengguna dapat menyalakan opsi **"Timpa stok dari file"**. Bila aktif:
- Perubahan stok **wajib** dicatat ke `stock_movements` dengan `type = 'opname'`, `qty_change` = selisih, `stock_after` = nilai baru, dan `note` = `"Impor Excel: <nama_file>"`.
- Produk baru yang dibuat dengan stok awal > 0 juga mencatat `stock_movements` `type = 'adjust_in'` dengan catatan yang sama.

Dengan begitu jejak audit stok yang sudah dibangun di M4 tetap utuh dan bisa ditelusuri.

### 4.4 Alur wizard impor

```
Produk (menu ⋮) atau Pengaturan → "Impor Produk dari Excel"

Langkah 1 — Pilih file
  [Unduh Template]  [Pilih File .xlsx]
  → file_picker (ekstensi dibatasi xlsx)

Langkah 2 — Membaca file
  parsing + validasi di ISOLATE (compute), progress indeterminate
  → gagal baca → error jelas, kembali ke langkah 1

Langkah 3 — Pratinjau (inti fitur)
  Ringkasan:  120 baris dibaca · 84 baru · 30 diperbarui · 6 bermasalah
  Tab:        [Semua] [Baru] [Diperbarui] [Bermasalah]
  Tiap baris: nomor baris Excel · nama · harga · pill status
  Opsi:       ( ) Perbarui produk yang sudah ada   (default)
              ( ) Lewati produk yang sudah ada
              [ ] Timpa stok dari file             (default mati)
              [x] Buat kategori baru otomatis      (default nyala)

Langkah 4 — Konfirmasi
  "Impor 114 produk? 30 produk yang sudah ada akan diperbarui.
   Tindakan ini tidak bisa dibatalkan — disarankan backup dulu."
  [Backup Dulu]  [Batal]  [Impor Sekarang]

Langkah 5 — Hasil
  ✓ 114 produk berhasil diimpor (84 baru, 30 diperbarui, 6 dilewati)
  [Lihat Produk]  [Unduh Laporan Baris Bermasalah (.xlsx)]
```

Penulisan ke database terjadi dalam **satu `db.transaction()`**: seluruh impor berhasil, atau tidak ada satupun baris masuk. Baris "bermasalah" sudah tersaring di langkah 3 sehingga tidak ikut masuk transaksi.

### 4.5 Acceptance criteria

| # | Kriteria (bisa diuji) |
|---|---|
| AC-4.1 | Template yang diunduh, diisi 3 baris valid, lalu diimpor → 3 produk muncul di daftar Produk dengan seluruh field benar. |
| AC-4.2 | File `produk_stok.xlsx` hasil export v1.0 bisa diimpor tanpa diedit; hasilnya 0 produk baru dan N produk "diperbarui" tanpa perubahan nilai (idempoten). |
| AC-4.3 | Header dengan urutan kolom diacak dan huruf besar-kecil berbeda tetap terbaca benar. |
| AC-4.4 | File tanpa kolom `Harga Jual` ditolak di langkah 2 dengan pesan menyebut nama kolom yang hilang; database tidak tersentuh. |
| AC-4.5 | Barcode yang muncul dua kali dalam satu file membuat **kedua** baris masuk daftar bermasalah dengan pesan menyebut kedua nomor baris. |
| AC-4.6 | Mode "Perbarui": produk dengan barcode yang sudah ada diperbarui harganya, dan **stoknya tidak berubah** selama opsi timpa stok mati. |
| AC-4.7 | Mode "Lewati": produk dengan barcode yang sudah ada tidak berubah sama sekali. |
| AC-4.8 | Opsi "Timpa stok" aktif → setiap perubahan stok menghasilkan tepat satu baris `stock_movements` dengan catatan berisi nama file. |
| AC-4.9 | Kategori baru pada file otomatis terbuat sekali saja (tidak duplikat) ketika opsi aktif; ketika mati, produk masuk tanpa kategori dan diberi peringatan. |
| AC-4.10 | Nilai `Rp 12.000`, `12.000`, dan `12000` semuanya menghasilkan `sellPrice = 12000`. |
| AC-4.11 | Stok `1,5` dan `1.5` sama-sama menghasilkan `1.5`. |
| AC-4.12 | File 1.000 baris terbaca dan tampil di pratinjau ≤ 15 detik pada HP kelas menengah, tanpa frame drop yang terasa (parsing di isolate). |
| AC-4.13 | File > 5.000 baris ditolak dengan pesan menyarankan memecah file. |
| AC-4.14 | File rusak/bukan xlsx/terenkripsi password → pesan Bahasa Indonesia yang jelas, aplikasi tidak crash. |
| AC-4.15 | Impor dibatalkan di tengah (tekan kembali / proses gagal) → **tidak ada** produk yang masuk sebagian (uji dengan menyuntikkan error di baris ke-50 dari 100). |
| AC-4.16 | Setelah impor sukses, daftar Produk & badge stok menipis langsung ter-refresh tanpa perlu menutup aplikasi (stream Drift). |
| AC-4.17 | Laporan baris bermasalah yang diunduh berisi nomor baris, isi baris asli, dan alasan dalam Bahasa Indonesia. |

### 4.6 Dampak skema database

**Tidak ada perubahan skema. `schemaVersion` tetap 1.**

- Menulis ke tabel `products`, `categories`, `stock_movements` yang sudah ada, lewat repository yang sudah ada.
- Diperlukan penambahan method repository (bukan tabel): `ProductRepository.importProducts(...)` yang menerima daftar baris tervalidasi dan melakukan seluruh penulisan dalam satu transaksi, mengembalikan ringkasan hasil.
- Riwayat impor **tidak disimpan** ke database (lihat §4.9). Bila di masa depan dibutuhkan, tambahkan tabel `import_logs` — bukan di v1.1.

### 4.7 Dampak UI

- **Titik masuk ganda**: (a) menu ⋮ pada layar Produk → "Impor dari Excel"; (b) Pengaturan → kartu Data, berdampingan dengan `export_section.dart` yang sudah ada. Keduanya membuka layar wizard yang sama.
- **Wizard sebagai layar penuh**, bukan bottom sheet — kontennya panjang (daftar pratinjau) dan pengguna butuh menggulir sambil membaca.
- **Indikator langkah** sederhana di bawah AppBar: `1 Pilih file · 2 Pratinjau · 3 Selesai` memakai `AppPill`/`SectionHeader`.
- **Ringkasan pratinjau** memakai `AppCard(elevated: true)` dengan angka besar (`AppTextStyles.numeric`) dan label kecil di bawahnya — sesuai prinsip "angka lebih penting dari labelnya".
- **Baris pratinjau**: `AppCard` datar dalam list; status memakai `AppPill` — `AppTone.success` "Baru", `AppTone.info` "Diperbarui", `AppTone.warning` "Perlu dicek", `AppTone.danger` "Bermasalah".
- **CTA bawah** tinggi `buttonHeightLarge` 60 menempel di bawah ("Impor Sekarang"), dengan padding bawah scroll `bottomSafePadding`.
- **Dialog konfirmasi** memakai pola konfirmasi ganda yang sama dengan restore backup, termasuk tombol pintas "Backup Dulu".
- **Empty/error state** mengikuti aturan §1: ikon + judul + kalimat pengarah + tombol.

### 4.8 Keputusan & risiko teknis

- **K-4.1** Hanya format **`.xlsx`** yang didukung. CSV tidak didukung — package `excel` (sudah ada di proyek) tidak menanganinya, dan CSV membawa masalah encoding & pemisah desimal koma-vs-titik khas Indonesia yang justru menambah kelas bug baru. Tidak ada dependency baru untuk fitur ini.
- **K-4.2** Parsing & validasi dijalankan di **isolate** lewat `compute`, dengan pola yang persis sama seperti `ExcelExportService`: hanya tipe "sendable" yang menyeberang isolate (tanpa closure/koneksi native). Penulisan DB tetap di isolate utama.
- **K-4.3** Pencocokan produk lama **hanya lewat barcode**, tidak pernah lewat nama. Pencocokan nama terlalu rawan (typo, huruf besar-kecil, satuan menempel di nama) dan bisa merusak katalog secara diam-diam.
- **K-4.4** Batas **5.000 baris per file**. Angka ini di bawah target skala 10.000 produk ([prd.md §6](prd.md)) tapi cukup untuk sekali impor; pengguna dengan katalog lebih besar memecah file. Batas ini melindungi memori isolate dan durasi transaksi.
- **K-4.5** Impor bersifat **atomik penuh** (satu transaksi). Alternatif "impor sebagian, lanjutkan yang bisa" ditolak karena melanggar prinsip keandalan v1.0 dan menyulitkan pengguna memahami keadaan akhir.
- **K-4.6** Impor **tidak pernah menghapus** produk. File yang lebih pendek dari katalog tidak menghilangkan apa pun — sinkronisasi dua arah bukan tujuan fitur ini.
- **K-4.7** Produk nonaktif juga ikut dicocokkan lewat barcode (partial unique index `idx_products_barcode_unique` berlaku tanpa memandang `is_active`), sehingga impor tidak bisa "menabrak" barcode milik produk yang dinonaktifkan.

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Pengguna mengimpor file basi lalu stok kacau | Kepercayaan hilang, sulit dipulihkan | Timpa stok **default mati** + konfirmasi ganda + saran backup + jejak `stock_movements` yang bisa ditelusuri. |
| File besar bikin memori habis di HP low-end | Aplikasi ditutup paksa OS | Batas 5.000 baris, parsing di isolate, tidak menyimpan objek Excel setelah parsing selesai. |
| Angka Indonesia salah tafsir (`1.500` dibaca 1,5) | Harga salah masuk | Aturan normalisasi eksplisit (§4.3.C) + **unit test tabel-kasus** untuk setiap bentuk masukan + pratinjau menampilkan nilai hasil parsing, bukan teks asli. |
| Pengguna tidak membaca daftar bermasalah | Mengira semua masuk | Ringkasan hasil menyebut angka "dilewati" dengan nada peringatan (`AppTone.warning`) dan menawarkan unduh laporan. |

### 4.9 TIDAK termasuk

- Impor CSV, ODS, Google Sheets, atau tautan online apa pun.
- Impor riwayat transaksi, kategori terpisah, pelanggan, atau pengaturan.
- Impor/penautan foto produk.
- Pemetaan kolom bebas oleh pengguna (drag kolom → field). Template tetap.
- Penghapusan produk lewat impor (kolom "Hapus").
- Penjadwalan impor otomatis / memantau folder.
- Riwayat impor yang tersimpan permanen & fitur "batalkan impor terakhir" (undo). Pemulihan tetap lewat backup/restore yang sudah ada.
- Pencocokan produk lama berdasarkan nama atau kemiripan nama.

---

## 5. Fitur Tier 1 — Mode Gelap

### 5.1 Latar & masalah pengguna

Design language "Kertas & Daun" dibangun di atas kanvas kertas hangat `#F5F2EA` dengan kartu `#FFFDFA`. Di ruangan terang itu tepat sasaran. Di warung yang buka sampai malam — lampu redup, HP dipegang dekat wajah — layar sebesar itu dengan latar hampir putih menyilaukan dan melelahkan mata kasir yang harus menatapnya ratusan kali semalam.

Selain kenyamanan, ada tiga alasan pendukung:
- **Baterai** — banyak HP Android target memakai OLED; latar gelap hemat daya nyata pada layar yang menyala terus di meja kasir.
- **Kebiasaan** — pengguna Android 2026 mengharapkan aplikasi mengikuti pengaturan tema sistem; aplikasi yang memaksa terang terasa tertinggal.
- **Utang teknis** — setiap layar baru yang ditulis dengan warna langsung (`AppColors.primary`) menambah biaya konversi. Saat ini terdapat **351 pemakaian `AppColors.*` yang tersebar di 44 file**. Angka itu hanya akan bertambah bila mode gelap terus ditunda — inilah alasan utama fitur ini masuk Tier 1 meski nilai bisnisnya di bawah dua fitur lainnya.

### 5.2 User stories

1. Sebagai kasir yang bekerja malam, saya bisa menyalakan mode gelap supaya layar tidak menyilaukan.
2. Sebagai pengguna, saya bisa memilih **Terang / Gelap / Ikuti Sistem**, dan pilihan itu diingat setelah aplikasi ditutup.
3. Sebagai pengguna yang memakai mode gelap, saya tetap bisa membaca semua angka, status, dan peringatan dengan jelas — tidak ada teks abu-abu di atas hitam.
4. Sebagai pengguna, ketika saya membagikan struk sebagai gambar, struk itu tetap **berlatar putih seperti kertas** meski aplikasi saya sedang gelap.
5. Sebagai pengguna, saat aplikasi dibuka dalam mode gelap saya tidak melihat "kedipan putih" sepersekian detik sebelum tema gelap muncul.

### 5.3 Perilaku & alur detail

#### A. Letak pengaturan

```
Pengaturan → kartu baru "Tampilan" (ditempatkan di ATAS kartu "Profil Toko")
  Tema aplikasi
  ┌──────────┬──────────┬──────────────┐
  │  Terang  │  Gelap   │ Ikuti Sistem │   ← SegmentedButton, tinggi ≥48dp
  └──────────┴──────────┴──────────────┘
  Keterangan: "Ikuti Sistem mengikuti pengaturan tema HP Anda."
```

Tidak ada tombol pintas di AppBar layar lain — mengubah tema bukan aksi harian, dan ikon tambahan di AppBar kasir melanggar prinsip "satu titik fokus".

#### B. Default

Default = **Terang**.

Alasan: pengguna v1.0 yang sudah terbiasa tidak boleh mendapat kejutan visual saat memperbarui aplikasi, dan tampilan terang adalah identitas produk. "Ikuti Sistem" tersedia sebagai satu tap dan akan dipertimbangkan menjadi default pada v1.2 setelah mode gelap terbukti stabil di lapangan.

#### C. Penerapan

- `MaterialApp.router` menerima `theme: AppTheme.light()`, `darkTheme: AppTheme.dark()`, `themeMode: ref.watch(themeModeProvider)`.
- Perpindahan tema berlaku **seketika** ke seluruh layar tanpa restart, termasuk warna status bar (`SystemUiOverlayStyle` ikut dibalik).
- Nilai tersimpan dibaca **sebelum `runApp()`** sehingga frame pertama sudah bertema benar (tidak ada kedip putih).

#### D. Permukaan yang WAJIB tetap terang

Tiga hal tidak boleh ikut gelap, karena hasilnya keluar dari aplikasi:

1. **`ReceiptWidget`** (struk yang di-capture jadi gambar untuk di-share) — harus tetap kertas putih dengan tinta gelap. Diterapkan dengan membungkusnya dalam `Theme(data: AppTheme.light(), child: ...)` saat di-render.
2. **Pratinjau struk printer** (§3.6) — sama, karena mewakili kertas sungguhan.
3. **File export Excel** — tidak terpengaruh tema sama sekali (tidak ada styling warna dari tema).

Splash screen native tetap hijau brand `#1B7A43` di kedua tema (lihat K-5.5).

### 5.4 Strategi palet gelap "Kertas & Daun Malam"

Prinsipnya bukan "membalik warna", tapi **memindahkan metafora**: dari kertas siang yang hangat ke **kertas di bawah lampu malam** — permukaan gelap yang tetap bernada hangat-kehijauan, bukan abu-abu netral atau hitam murni.

Empat aturan turunan:

1. **Tidak ada hitam murni (`#000000`).** Permukaan paling gelap tetap punya nada hangat-hijau, konsisten dengan `surfaceDark` `#1F2723` yang sudah dipakai SnackBar di v1.0.
2. **Kedalaman datang dari terang permukaan, bukan dari shadow.** Di mode terang, kartu "mengambang" lewat shadow cokelat hangat; di mode gelap shadow praktis tak terlihat, jadi hierarki dibawa oleh tangga permukaan `background < surface < surfaceAlt` plus garis `border`. Token `AppShadows` di mode gelap memakai alpha jauh lebih rendah (dekoratif saja).
3. **Warna brand dibalik perannya.** `#0D5D42` (hijau tua) tidak terbaca di atas latar gelap. Di mode gelap, tombol utama memakai hijau **terang** dengan teks gelap di atasnya — pola standar Material 3 yang juga menjaga kontras ≥ 4.5:1.
4. **Warna "soft" semantik menjadi gelap-bertint.** `successSoft` `#E6F3EC` diganti latar hijau gelap; teksnya (`successText`) menjadi versi terang. Trio setiap status tetap: isi / latar lembut / teks.

#### Usulan nilai token

Nilai berikut adalah titik awal yang harus **diverifikasi kontrasnya oleh uji otomatis** (AC-5.8), bukan angka final yang sakral.

**Netral**

| Token | Terang | Gelap (usulan) | Catatan |
|---|---|---|---|
| `background` | `#F5F2EA` | `#141613` | Kanvas Scaffold. |
| `surface` | `#FFFDFA` | `#1C1F1B` | Kartu, sheet, dialog, dock nav. |
| `surfaceAlt` | `#FAF7F0` | `#232722` | Sub-panel, baris zebra. |
| `surfaceDark` | `#1F2723` | `#EDEAE1` | Permukaan **inversi** (SnackBar/tooltip) — di mode gelap justru terang. |
| `ink` | `#191D1A` | `#EDEAE0` | Teks utama. ~13:1 di atas `surface`. |
| `inkSecondary` | `#5A625C` | `#A7ADA4` | Label; harus tetap ≥ 4.5:1. |
| `inkTertiary` | `#8A928B` | `#7A8078` | Hanya hint/placeholder & teks ≥18px. |
| `onDark` | `#F6F8F5` | `#F6F8F5` | Tetap — teks di atas permukaan hijau tua. |
| `border` | `#E6E0D4` | `#2E332C` | Garis kartu & divider. |
| `borderStrong` | `#D5CDBD` | `#3D433B` | Outline field & tombol outlined. |
| `scrim` | `#66101410` | `#99000000` | Barrier dialog lebih pekat di mode gelap. |

**Brand & aksen**

| Token | Terang | Gelap (usulan) | Catatan |
|---|---|---|---|
| `primary` | `#0D5D42` | `#74CFA4` | Hijau daun terang; teks di atasnya = `#06281B`, bukan putih. |
| `primaryDark` (pressed) | `#0A4A35` | `#5FBB90` | |
| `primaryDeep` (permukaan brand) | `#063124` | `#0E3A2A` | Panel total/header khusus. |
| `primary200` | `#9AC7AE` | `#3E7C61` | Border kartu terpilih. |
| `primary100` | `#CCE3D8` | `#2A5C46` | Track progress, border tonal. |
| `primary50` (latar lembut) | `#E9F2ED` | `#123128` | Chip aktif, kapsul nav aktif. |
| `accent` | `#D97E27` | `#E9A25A` | Isi penanda; teks di atasnya tetap gelap. |
| `accentText` | `#8A4A08` | `#EDB279` | Teks/ikon aksen. |
| `accent100` | `#F6DDB9` | `#4A3316` | Border tonal aksen. |
| `accent50` | `#FCF0DF` | `#33240F` | Latar lembut aksen (badge "Hutang"). |

**Semantik (trio isi / soft / text)**

| Status | Terang (isi · soft · text) | Gelap (usulan) |
|---|---|---|
| success | `#14764C` · `#E6F3EC` · `#0B5233` | `#5FC98F` · `#12291D` · `#8FE0B4` |
| warning | `#8A5B08` · `#FBF0D8` · `#6E4806` | `#D9A441` · `#31260D` · `#F0C475` |
| danger | `#B3261E` · `#FBE9E7` · `#8C1D18` | `#E0645B` · `#3A1512` · `#F2B4AE` |
| info | `#175F8F` · `#E5EFF6` · `#124D74` | `#5AA7DA` · `#0F2836` · `#8FC7E8` |

Alias domain (`tunai` = success, `nonTunai` = info, `hutang` = accentText) tetap berlaku tanpa perubahan makna.

### 5.5 Dampak arsitektur & UI (bagian tersulit)

**Masalahnya bukan memilih warna — tapi bahwa warna saat ini tidak bergantung konteks.** `AppColors` adalah `abstract final class` berisi `static const Color`, dipakai langsung di 44 file. Nilai `const` tidak bisa berubah menurut tema.

Tiga opsi dipertimbangkan:

| Opsi | Isi | Putusan |
|---|---|---|
| A. Ganti isi `AppColors` secara global saat runtime | Ubah `static const` jadi `static` mutable, tulis ulang saat tema berganti | **Ditolak.** Tidak reaktif (widget tidak rebuild), merusak `const` di seluruh widget tree, membuat test bocor antar-kasus, dan menimbulkan bug kedip. |
| B. `AppColors.of(context)` mengembalikan objek palet | Palet diambil dari `Theme.of(context).extension<AppPalette>()` | **Dipilih.** Reaktif, satu sumber kebenaran, mudah diuji. |
| C. Pakai `ColorScheme` Material saja | Buang token khusus, andalkan `colorScheme` | **Ditolak.** `ColorScheme` tidak punya slot untuk trio semantik (success/warning + soft + text), `surfaceAlt`, atau alias domain — memaksanya masuk akan merusak design language. |

**Keputusan K-5.1 — `AppPalette` sebagai `ThemeExtension`:**

- Kelas `AppPalette extends ThemeExtension<AppPalette>` memuat **semua** token warna (netral, brand, aksen, semantik) sebagai field instance, dengan dua konstruktor `const AppPalette.light()` dan `const AppPalette.dark()`.
- Ditambahkan ke `ThemeData.extensions` di `AppTheme.light()` dan `AppTheme.dark()`.
- Akses lewat extension pada `BuildContext`: `context.palette.ink`, `context.palette.primary` — pendek supaya migrasi 351 pemakaian tidak menyakitkan.
- `AppTone` mendapat method sadar-tema: `tone.colorsOf(context)` menggantikan getter `tone.colors`. Getter lama dipertahankan sementara (mengembalikan palet terang) dan ditandai `@Deprecated`.
- `AppColors` **tetap ada** sebagai sumber nilai palet terang dan alias untuk kode lama, sehingga migrasi bisa bertahap dan tidak memaksa satu commit raksasa.
- Aturan baru: **kode UI baru dilarang memakai `AppColors.*` langsung.** Ditegakkan lewat review + skrip pemeriksa sederhana (grep gate) di `analysis_options`/CI opsional.

**Urutan migrasi yang disarankan** (setiap langkah tetap bisa dibangun & diuji):
1. `AppPalette` + `AppTheme.dark()` + `themeModeProvider` + kartu Pengaturan → aplikasi sudah bisa gelap, tapi banyak layar masih hardcoded terang.
2. `core/widgets/` (8 file: `AppCard`, `AppPill`, `AppDataRow`, `EmptyState`, `MainShell`, dll.) — ini menyelesaikan sebagian besar permukaan sekaligus.
3. Layar per fitur berurutan: `pos` → `products` → `transactions` → `reports` → `settings` → `inventory`.
4. Sapu bersih: tidak ada lagi `AppColors.` di `lib/features/`.

**Dampak UI lain:**
- `AppShadows` mendapat varian gelap (alpha lebih rendah); `AppDecorations` mengambil warna dari `context.palette`.
- Ikon tonal, chip, badge, dan `NavigationBar` mengambil warna dari palet; **tidak boleh** ada `Colors.white`/`Colors.black` telanjang di kode fitur.
- Field input, divider, dan `TextSelectionTheme` ikut versi gelap.
- Foto produk (bila ada) tidak diberi filter apa pun; hanya diberi border `border` agar tidak "melayang" di atas latar gelap.

### 5.6 Dampak skema database

**Tidak ada perubahan skema. `schemaVersion` tetap 1.**

**Keputusan K-5.2 — preferensi tema disimpan di `shared_preferences`, BUKAN di tabel `settings`.**

Alasan: tema adalah preferensi **perangkat & mata penggunanya**, bukan data toko. Menyimpannya di database berarti ikut terbawa `backup → restore`, sehingga memulihkan data di HP orang lain akan memaksakan tema HP asal — perilaku yang mengejutkan dan tidak diinginkan. Alasan kedua: `shared_preferences` bisa dimuat di `main()` sebelum `runApp()` tanpa membuka database, yang justru dibutuhkan agar frame pertama sudah bertema benar (AC-5.5).

| Penyimpanan | Key | Nilai | Default |
|---|---|---|---|
| `shared_preferences` | `theme_mode` | `light` \| `dark` \| `system` | `light` |

### 5.7 Acceptance criteria

| # | Kriteria (bisa diuji) |
|---|---|
| AC-5.1 | Pengaturan → Tampilan menawarkan tepat tiga pilihan (Terang/Gelap/Ikuti Sistem); memilih salah satunya mengubah seluruh aplikasi seketika tanpa restart. |
| AC-5.2 | Pilihan tema bertahan setelah aplikasi ditutup paksa dan dibuka kembali. |
| AC-5.3 | Mode "Ikuti Sistem": mengubah tema di pengaturan Android mengubah tema aplikasi tanpa perlu membuka ulang aplikasi. |
| AC-5.4 | Backup di perangkat bertema gelap → restore di perangkat lain: tema perangkat tujuan **tidak** berubah. |
| AC-5.5 | Membuka aplikasi dalam mode gelap tidak menampilkan kedipan latar terang pada frame pertama setelah splash. |
| AC-5.6 | Tidak ada layar yang menampilkan `Colors.white`/`Colors.black` telanjang: `grep -r "Colors.white\|Colors.black" lib/features lib/core/widgets` tidak menemukan hasil (kecuali yang sengaja di-*allowlist* dengan komentar alasan). |
| AC-5.7 | Struk yang di-share sebagai gambar tetap berlatar putih dengan tinta gelap ketika aplikasi dalam mode gelap (uji widget: capture `ReceiptWidget` di kedua tema, bandingkan warna piksel latar). |
| AC-5.8 | **Uji otomatis kontras**: untuk setiap pasangan (teks, latar) yang didefinisikan di `AppPalette` versi gelap maupun terang, rasio kontras ≥ 4.5:1 untuk teks normal dan ≥ 3:1 untuk teks ≥18px/ikon. Token yang sengaja di bawah ambang (mis. `inkTertiary`) terdaftar eksplisit sebagai pengecualian dalam test. |
| AC-5.9 | Status bar & ikon sistem terbaca di kedua tema (ikon terang di atas latar gelap dan sebaliknya). |
| AC-5.10 | Seluruh layar utama (Kasir, Produk, Riwayat, Laporan, Pengaturan, detail transaksi, sukses transaksi, form produk, PIN) tampil benar di mode gelap — diverifikasi lewat widget test yang mem-*pump* setiap layar dengan `AppTheme.dark()`. |
| AC-5.11 | Semua status/pill (lunas, hutang, ditahan, batal, stok menipis, non-tunai) tetap dapat dibedakan di mode gelap dan tetap membawa **label teks**, tidak hanya warna. |
| AC-5.12 | Tidak ada regresi di mode terang: seluruh test M0–M6 yang sudah ada tetap lulus tanpa perubahan ekspektasi warna. |

### 5.8 Keputusan & risiko teknis

- **K-5.1** `AppPalette` sebagai `ThemeExtension` (lihat §5.5).
- **K-5.2** `theme_mode` di `shared_preferences` (lihat §5.6).
- **K-5.3** Struk (widget & pratinjau cetak) **dipaksa tema terang** (§5.3.D).
- **K-5.4** Tidak ada mode "AMOLED hitam pekat" terpisah. Satu palet gelap saja; menambah varian berarti menggandakan biaya uji kontras tanpa nilai yang sepadan.
- **K-5.5** **Splash screen native tidak dibuat dua versi.** Splash memakai warna brand solid `#1B7A43` yang bekerja di kedua tema, dan `flutter_native_splash` sengaja **tidak** dikembalikan sebagai dev-dependency permanen (kegagalan build release di M6 — lihat plan.md). Aset splash hanya diregenerasi manual bila memang perlu.
- **K-5.6** Migrasi bertahap dengan `AppColors` dipertahankan sebagai alias palet terang, bukan penulisan ulang sekaligus.

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Layar terlewat saat migrasi → "pulau putih" di mode gelap | Terlihat rusak & tidak profesional | AC-5.6 (grep gate) + AC-5.10 (widget test per layar dalam tema gelap) + urutan migrasi yang mencakup `core/widgets` lebih dulu. |
| Kontras kurang di palet gelap | Angka uang salah baca — risiko uang | AC-5.8: rasio kontras dihitung otomatis oleh test, bukan dinilai dengan mata. |
| Perubahan `AppTone.colors` merusak kode lama | Kompilasi gagal massal | Getter lama dipertahankan (`@Deprecated`) mengembalikan palet terang selama masa migrasi. |
| Pekerjaan membengkak (351 pemakaian) | Tier 1 molor | Dipecah jadi 4 langkah yang masing-masing bisa dirilis; langkah 1 saja sudah memberi mode gelap yang berfungsi. |
| Perubahan tema besar-besaran menimbulkan regresi visual di mode terang | Merusak yang sudah bagus | AC-5.12: seluruh test lama wajib lulus tanpa diubah; palet terang memakai nilai `AppColors` yang persis sama. |

### 5.9 TIDAK termasuk

- Mode AMOLED/hitam pekat terpisah.
- Penjadwalan otomatis (gelap saat matahari terbenam, gelap pada jam tertentu).
- Pemilihan warna brand/aksen oleh pengguna (tema kustom).
- Tema per layar atau per pengguna (lihat §8 — multi-user tidak membawa preferensi tema per kasir).
- Splash screen versi gelap.
- Penyesuaian ukuran font / mode kontras tinggi terpisah (aksesibilitas lanjutan di luar cakupan v1.1).
- Mode gelap untuk file export atau struk cetak.

---

## 6. Fitur Tier 1 — Sistem Lisensi Offline (Aktivasi Wajib)

### 6.1 Latar & masalah pengguna

Lima fitur lain di dokumen ini menjawab kebutuhan **pengguna**. Bab ini menjawab kebutuhan **produk**: aplikasi ini akan **dijual** ke UMKM, bukan dibagikan gratis. Tanpa gerbang aktivasi, satu file APK yang beredar di grup WhatsApp langsung menjadi seratus pemakai tanpa satu rupiah pun kembali ke pengembang — dan pengembangan v1.2 ke atas berhenti dengan sendirinya.

Masalah yang harus diselesaikan sekaligus:

1. **Menggerbangi penjualan.** Aplikasi hanya bisa dipakai setelah pembeli memasukkan kode aktivasi yang diterbitkan penjual.
2. **Tanpa server.** Menambah backend berarti biaya bulanan, akun, dan ketergantungan jaringan — semuanya melanggar janji inti produk ([prd.md §1](prd.md)). Verifikasi harus **murni offline**.
3. **Tanpa menyandera data pengguna.** Lisensi habis tidak boleh menghapus atau mengunci data penjualan pengguna selamanya. Yang dikunci adalah **kemampuan berjualan**, bukan datanya.
4. **Bisa dijalankan satu orang.** Penjualnya adalah satu orang dengan laptop dan WhatsApp, bukan tim. Alur penerbitan kode harus bisa selesai dalam hitungan menit tanpa infrastruktur apa pun.

Tiga jenis lisensi yang dijual (keputusan pemilik produk, final):

| Jenis | Masa berlaku | Untuk |
|---|---|---|
| **Coba (trial)** | **3 hari** sejak kode diterbitkan (absolut) | Calon pembeli yang ingin mencoba dulu di warungnya sendiri |
| **Selamanya (lifetime)** | tanpa kedaluwarsa | Sekali beli, dipakai selamanya di perangkat itu |
| **Tahunan** | **365 hari** + masa tenggang 7 hari | Harga masuk lebih murah; diperpanjang dengan kode baru |

> **Ini adalah pengecualian pertama yang DISENGAJA terhadap prinsip "100% offline" [prd.md §1](prd.md)** — dan pengecualiannya lebih kecil daripada kelihatannya. Lihat §1.4: perangkat kasir **tetap tidak pernah butuh internet**, bahkan saat aktivasi. Yang berubah adalah adanya **gerbang aktivasi** sebelum aplikasi bisa dipakai, dan pertukaran kode dilakukan lewat **manusia** (WhatsApp dari HP mana pun), bukan lewat jaringan aplikasi.

### 6.2 User stories

Fitur ini punya **dua** pengguna: pembeli aplikasi (pemilik warung) dan penjual aplikasi (pengembang). Keduanya ditulis, karena alur penjual adalah bagian dari produk — bukan urusan internal.

**Pembeli (pemilik warung):**

1. Sebagai calon pembeli, saya bisa mencoba aplikasi **3 hari penuh** di warung saya sendiri sebelum memutuskan membeli.
2. Sebagai pembeli, saya bisa membaca **kode perangkat** saya di layar pertama dan mengirimkannya ke penjual lewat WhatsApp dengan satu tap — tanpa perlu paham istilah teknis apa pun.
3. Sebagai pembeli, saya bisa memasukkan kode aktivasi dengan cara termudah yang tersedia: **memindai QR**, **menempel** dari WhatsApp, atau **mengetik manual** kalau kodenya sampai di HP lain.
4. Sebagai pembeli, saya tahu **kapan lisensi saya berakhir** dan diingatkan jauh-jauh hari, bukan dikejutkan pada pagi hari saat antrian panjang.
5. Sebagai pembeli lisensi tahunan, saya bisa memperpanjang dengan memasukkan kode baru — **tanpa kehilangan satu transaksi pun**.
6. Sebagai pembeli yang masa cobanya habis, saya tahu bahwa **data saya masih utuh** dan akan langsung kembali begitu saya membeli.
7. Sebagai pembeli, saya bisa memakai aplikasi ini **tanpa pernah menyalakan internet di HP kasir**, termasuk saat aktivasi.

**Penjual (pengembang):**

8. Sebagai penjual, saya bisa menerbitkan kode aktivasi untuk satu kode perangkat dalam **satu perintah** di laptop saya, lalu mengirimkannya lewat WhatsApp.
9. Sebagai penjual, saya bisa menerbitkan trial, lifetime, dan tahunan dari alat yang sama, dan setiap penerbitan **tercatat otomatis** supaya saya tahu perangkat mana yang sudah pernah dapat trial.
10. Sebagai penjual, saya ingin kode yang saya terbitkan **hanya berlaku di perangkat yang memintanya**, supaya satu kode tidak beredar di grup WhatsApp.
11. Sebagai penjual, saya ingin kunci penerbit saya aman dan **tidak pernah ikut ter-commit** ke repositori.

### 6.3 Perilaku & alur detail

#### A. Alur aktivasi pertama (sisi pembeli)

```
Pasang APK → buka aplikasi
→ Layar Aktivasi (di luar shell navigasi; navigasi bawah TIDAK tampil)

  ┌────────────────────────────────────────┐
  │  Kasir Warung                          │
  │  Aplikasi ini perlu diaktifkan dulu.   │
  │                                        │
  │  Kode perangkat Anda                   │
  │      KW-4T7QP-9M2XK        (besar)     │
  │      [ Salin ]  [ Kirim ke Penjual ]   │
  │                                        │
  │  Kirim kode perangkat di atas ke       │
  │  penjual, lalu masukkan kode aktivasi  │
  │  yang dikirim balik.                   │
  │                                        │
  │  [ Pindai QR ] [ Tempel ] [ Ketik ]    │
  │  ──────────────────────────────────    │
  │  [        AKTIFKAN        ] (60dp)     │
  └────────────────────────────────────────┘

→ "Kirim ke Penjual" membuka lembar berbagi (share_plus yang sudah ada)
  dengan teks siap kirim:
  "Halo, saya mau aktivasi Kasir Warung. Kode perangkat saya:
   KW-4T7QP-9M2XK"
→ penjual membalas dengan kode aktivasi (teks + gambar QR)
→ Pindai QR / Tempel / Ketik → tap AKTIFKAN
→ verifikasi lokal (< 1 detik) → "Aktif — Lisensi Selamanya" → masuk aplikasi
```

Tiga jalur masuk kode, berurutan dari yang paling mudah:

| Jalur | Kapan dipakai | Catatan |
|---|---|---|
| **Pindai QR** | Kode sampai di HP lain / dikirim sebagai gambar | Me-*reuse* `mobile_scanner` yang **sudah** dipakai untuk barcode produk — tanpa dependency baru |
| **Tempel** | WhatsApp ada di HP kasir itu sendiri | Satu tap; jalur paling sering dalam praktik |
| **Ketik manual** | Jalur terakhir yang **selalu** bekerja | Kode dikelompokkan 5 karakter, huruf besar, alfabet tanpa karakter kembar (§6.3.D) |

Aplikasi **tidak pernah** menyentuh jaringan pada alur ini. Pengiriman kode perangkat dan penerimaan kode aktivasi terjadi lewat aplikasi lain milik pengguna (WhatsApp/SMS), atau lewat HP orang lain sama sekali.

#### B. Alur penjual (penerbitan kode)

Generator adalah **tool CLI Dart di dalam repo**, dijalankan di laptop penjual:

```
1. Sekali seumur produk — membuat pasangan kunci:
   dart run tool/license_generator.dart --buat-kunci
   → menulis kunci privat ke ~/.kasir-warung/license_ed25519.key   (DI LUAR REPO)
   → mencetak kunci publik (32 byte, base64) untuk ditempel ke
     lib/core/license/license_keys.dart

2. Setiap penjualan:
   dart run tool/license_generator.dart \
     --device KW-4T7QP-9M2XK \
     --jenis tahunan \
     --nama "Warung Bu Ani" --catatan "WA 0812xxxx, transfer 12 Agu"

   Tool melakukan berurutan:
   a. memeriksa karakter cek kode perangkat  → salah ketik ketahuan SEBELUM
      kode diterbitkan (tidak ada bolak-balik WhatsApp yang sia-sia)
   b. mencari kode perangkat itu di lisensi-terbit.csv → memperingatkan bila
      perangkat ini SUDAH PERNAH dapat trial (mitigasi risiko §6.7.3)
   c. menandatangani muatan dengan kunci privat
   d. menulis keluaran:
      • kode aktivasi teks (120 karakter, terkelompok 5)
      • lisensi-KW-4T7QP-9M2XK.png  (QR berisi kode yang sama)
      • satu baris di lisensi-terbit.csv:
        tanggal, kode perangkat, jenis, kedaluwarsa, nama, catatan

3. Penjual mengirim kode teks + gambar QR lewat WhatsApp.
```

Perintah pendukung:

| Perintah | Fungsi |
|---|---|
| `--buat-kunci` | Membuat pasangan kunci Ed25519 baru (menolak menimpa kunci yang sudah ada) |
| `--verifikasi <kode> --device <id>` | Menjalankan **jalur verifikasi yang sama persis** dengan aplikasi; dipakai penjual saat pembeli melapor "kode saya ditolak" |
| `--daftar [--jenis trial]` | Menampilkan isi `lisensi-terbit.csv` (siapa, kapan, jenis apa, kedaluwarsa kapan) |

`lisensi-terbit.csv` dan `*.key` masuk `.gitignore`. Tata kelola kunci: §6.7.2.

#### C. Kode perangkat (device ID)

- Sumber: **ANDROID_ID / SSAID** (`Settings.Secure.ANDROID_ID`). Pada Android 8.0+ nilainya unik per (aplikasi-penanda-tangan × pengguna × perangkat), **stabil melewati uninstall–reinstall selama APK ditandatangani kunci rilis yang sama**, dan hanya berubah saat *factory reset*. Ini persis sifat yang dibutuhkan: trial tidak bisa direset dengan memasang ulang, tapi pengguna jujur juga tidak kehilangan lisensinya saat memperbarui aplikasi.
- Yang ditampilkan **bukan** SSAID mentah, melainkan turunannya:
  `deviceId = crockford32( SHA-256("kasirwarung.device.v1|" + SSAID)[0..44 bit] )` → 9 karakter, ditambah **1 karakter cek** berbobot posisi (menangkap salah ketik satu karakter *dan* tertukarnya dua karakter bersebelahan).
- Format tampil: `KW-4T7QP-9M2XK` — awalan `KW-`, lalu 10 karakter dalam dua kelompok lima.
- Alasan tidak menampilkan SSAID mentah: (a) 16 karakter heksadesimal jauh lebih rawan salah ketik dan tidak punya karakter cek; (b) SSAID mentah adalah pengenal perangkat yang tidak perlu beredar di WhatsApp; (c) turunan 45 bit (≈ 3,5 × 10¹³ kemungkinan) sudah jauh lebih dari cukup untuk basis pelanggan UMKM.
- **Kasus khusus:** bila SSAID tidak terbaca atau bernilai cacat yang terkenal (`9774d56d682e549c` pada sebagian perangkat lama), aplikasi membangkitkan pengenal acak sekali dan menyimpannya di `shared_preferences`. Konsekuensinya jujur dan dicatat di UI bantuan: pada perangkat itu, memasang ulang aplikasi **akan** mengubah kode perangkat dan pembeli perlu kode baru dari penjual.

#### D. Kode aktivasi: muatan, tanda tangan, dan bentuknya

**Muatan yang ditandatangani (9 byte):**

| Byte | Isi | Keterangan |
|---|---|---|
| 0 | versi format | `0x01`. Versi yang lebih besar dari yang dikenal aplikasi → pesan "Perbarui aplikasi dulu", bukan "kode tidak sah" |
| 1 | jenis lisensi | `0x01` coba · `0x02` selamanya · `0x03` tahunan |
| 2–3 | tanggal terbit | uint16 BE, hari sejak 2020-01-01 (UTC) |
| 4–5 | tanggal kedaluwarsa | uint16 BE, hari sejak 2020-01-01; `0xFFFF` = tanpa kedaluwarsa |
| 6 | masa tenggang | uint8, jumlah hari (trial `0`, tahunan `7`) — **ikut ditandatangani** supaya penjual bisa memberi kelonggaran khusus tanpa mengubah aplikasi |
| 7–8 | petunjuk perangkat | 16 bit pertama SHA-256 kode perangkat; **hanya** untuk membedakan pesan "kode ini untuk perangkat lain" dari "kode tidak sah" |

**Pesan yang ditandatangani** (bukan yang dikirim):

```
msg = "KASIRWARUNG-LICENSE-v1" || 0x00 || deviceId(10 karakter ASCII) || muatan(9 byte)
sig = Ed25519-sign(kunciPrivatPenjual, msg)            // 64 byte
```

Kode perangkat **ikut ditandatangani tapi tidak ikut dikirim** — aplikasi menyusun ulang `msg` memakai kode perangkatnya sendiri. Akibatnya: kode yang diterbitkan untuk perangkat lain **tidak akan pernah lolos verifikasi**, tanpa perlu memboroskan karakter untuk mengangkut kode perangkat.

**Bentuk yang diketik/dipindai:**

```
token = muatan(9) || sig(64) || CRC-16(2)              = 75 byte
teks  = "KW1-" + Crockford-Base32(token)               = 120 karakter data
tampil= KW1-4T7QP-9M2XK-...                            dikelompokkan 5 karakter
```

- **Alfabet Crockford Base32** (0–9, A–Z tanpa `I`, `L`, `O`, `U`): tidak ada pasangan karakter yang mirip saat ditulis tangan atau dibaca di layar retak. Saat memasukkan kode, `I`/`l` diterima sebagai `1`, `O` sebagai `0`, huruf kecil dinaikkan otomatis, tanda hubung/spasi diabaikan. Awalan `KW1-` boleh ada atau tidak (penanda versi format, memudahkan format v2 kelak).
- **CRC-16 ada meskipun sudah ada tanda tangan.** Tanda tangan bisa menjawab "sah/tidak sah", tapi tidak bisa membedakan **salah ketik** dari **kode palsu**. CRC memungkinkan pesan yang benar: *"Kode belum lengkap atau ada yang salah ketik — periksa lagi kelompok ke-7"* alih-alih menuduh pengguna memakai kode bajakan. Ini menghilangkan seluruh kelas keluhan dukungan.
- **120 karakter memang panjang, dan itu harga yang disadari.** Tanda tangan Ed25519 berukuran tetap 64 byte; memotongnya membuat verifikasi mustahil, dan mengganti Ed25519 dengan HMAC/kunci simetris berarti menanam kunci penerbit di dalam APK — satu orang membongkarnya, jadilah *keygen* untuk semua perangkat. Karena itu panjang kode tidak dilawan dengan mengorbankan keamanan, melainkan dengan **UX yang membuat pengetikan jadi jalan terakhir**, bukan jalan utama (§6.3.A). Lihat K-6.3 dan tabel risiko.

#### E. Keadaan lisensi & perilaku saat berakhir

Aplikasi mengenal enam keadaan. Semuanya diturunkan dari token + tanggal acuan (§6.3.G), tidak ada yang disimpan sebagai "keadaan" yang bisa melenceng:

| Keadaan | Kapan | Perilaku aplikasi |
|---|---|---|
| `belumAktif` | belum pernah ada token sah | Layar Aktivasi mengunci seluruh aplikasi |
| `aktif` | lifetime, atau `hariIni < hariKedaluwarsa` | Normal sepenuhnya |
| `akanBerakhir` | sisa ≤ 7 hari (trial: sisa ≤ 1 hari) | Normal + banner peringatan di layar Kasir |
| `masaTenggang` | lewat kedaluwarsa, masih dalam tenggang (tahunan: 7 hari) | Normal + **banner merah menetap** berisi sisa hari & tombol "Perpanjang" |
| `kedaluwarsaTahunan` | tenggang habis | **Layar Kasir dikunci.** Riwayat, Laporan, Export Excel, Backup, dan Pengaturan **tetap terbuka** |
| `kedaluwarsaTrial` | masa coba habis (tanpa tenggang) | Layar penuh ajakan beli; **data tidak dihapus** dan tombol "Cadangkan Data" tetap tersedia |

Aturan yang mengikat perilaku di atas:

1. **Data tidak pernah dihapus, disembunyikan, atau diacak** oleh kedaluwarsa apa pun. Begitu kode baru dimasukkan, seluruh data — termasuk data yang dibuat selama masa coba — muncul kembali apa adanya (AC-6.12).
2. **Lisensi tahunan yang habis tidak menyandera data.** Yang dikunci hanya kemampuan membuat transaksi baru. Pengguna tetap bisa menagih hutang lama? Tidak — pelunasan hutang adalah penulisan data dan ikut terkunci; tapi ia tetap bisa **melihat** siapa yang berhutang berapa, meng-export-nya ke Excel, dan mem-backup seluruh datanya untuk dibawa ke mana pun. Prinsip "Data milik pengguna" ([prd.md §1](prd.md)) menang atas keinginan menekan pembeli.
3. **Trial habis mengunci penuh** (keputusan pemilik produk) — dengan satu kelonggaran yang sengaja ditambahkan: tombol **"Cadangkan Data"** pada layar kunci, sehingga pengguna yang memutuskan tidak jadi membeli tetap bisa membawa pergi datanya sendiri. Bila PIN aktif, tombol ini melewati gerbang PIN yang sudah ada. Ini tidak melemahkan gerbang penjualan sama sekali: data tiga hari tidak bernilai bagi pembajak, sementara "aplikasi menyandera catatan warung saya" adalah kerusakan reputasi yang jauh lebih mahal daripada satu lisensi.
4. **Transaksi yang sedang berjalan tidak pernah diputus di tengah** (§6.3.F).

#### F. Kapan lisensi diperiksa

- **Saat *cold start*, sebelum `runApp()`** — token dibaca dari `shared_preferences` dan diverifikasi, sehingga frame pertama sudah menampilkan layar yang benar (pola yang sama dengan pembacaan tema, K-5.2/AC-5.5). Tidak ada kedipan layar Kasir sebelum layar Aktivasi.
- **Saat aplikasi kembali ke depan** (`AppLifecycleState.resumed`) — menangkap kasus aplikasi menginap semalam melewati tanggal kedaluwarsa.
- **Setelah database terbuka** — pemeriksaan mundur-jam yang membutuhkan `sales.created_at` (§6.3.G) dijalankan setelah frame pertama; bila hasilnya menurunkan keadaan lisensi, `redirect` router bereaksi sendiri.
- **TIDAK pernah** di tengah alur pembayaran. Bila lisensi berakhir saat aplikasi sedang terbuka dan ada keranjang berjalan, transaksi itu **tetap boleh diselesaikan sampai tersimpan**; kunci baru berlaku setelahnya. Menghentikan kasir di depan pembeli yang sedang membayar adalah kerusakan yang tidak sebanding dengan satu hari lisensi.
- Gerbangnya adalah `redirect` **di lapisan `go_router`, di luar/sebelum `StatefulShellRoute`** — bukan sekadar menyembunyikan layar. Urutan gerbang bila §8 (multi-user) kelak aktif: **lisensi → masuk (login) → shell**.

#### G. Mitigasi mundur-jam (clock rollback)

Aplikasi tidak punya sumber waktu tepercaya. Mitigasinya adalah **jam yang tidak bisa mundur**, dibangun dari jam perangkat ditambah tiga saksi tersimpan:

```
waktuAcuan = max(
    jam perangkat sekarang,
    license_last_seen_at            (nilai tertinggi yang pernah dilihat, shared_preferences),
    created_at transaksi TERBARU di database,
    license_activated_at            (saat kode terakhir diaktifkan)
)
```

- `license_last_seen_at` diperbarui saat *start*, saat *resume*, dan setiap kali satu penjualan tersimpan.
- Seluruh evaluasi kedaluwarsa (§6.3.E) memakai **`waktuAcuan`**, bukan jam perangkat. Mundurkan jam sejauh apa pun, sisa masa berlaku tidak pernah bertambah.
- `created_at` transaksi terbaru adalah saksi yang **tidak ikut hilang** saat pengguna memulihkan backup di perangkat yang jamnya sudah dimundurkan — kasus yang paling mungkin terjadi dalam praktik.
- Bila `jam perangkat < waktuAcuan − 10 menit`, aplikasi menampilkan banner: *"Jam HP Anda tampaknya mundur. Betulkan tanggal & jam agar laporan dan lisensi tetap akurat."* Toleransi 10 menit mencegah koreksi NTP biasa memicu peringatan palsu.
- **Jam yang salah tidak pernah dipakai sebagai alasan mengunci aplikasi** selama `waktuAcuan` masih di dalam masa berlaku. Pengguna yang baterainya habis dan jamnya ter-reset ke 2016 adalah pengguna jujur, bukan pembajak.

#### H. Perpanjangan & pindah perangkat

- **Perpanjangan tahunan:** Pengaturan → kartu "Lisensi" → "Masukkan Kode Baru", atau langsung dari banner masa tenggang. Kode baru menimpa yang lama; masa berlaku baru dihitung dari **tanggal terbit kode baru** (bukan ditumpuk pada sisa lama) — sederhana, dan penjual bisa mengompensasi sisa hari saat menerbitkan bila mau.
- **Kode lama tetap boleh dimasukkan ulang.** Token bukan sekali pakai: setelah memasang ulang aplikasi di perangkat yang sama, pembeli cukup memasukkan kode yang sama. Trial pun begitu — dan justru itu yang membuat trial **tidak bisa direset** dengan memasang ulang: tanggal kedaluwarsanya absolut, tertanam di dalam kode.
- **Ganti perangkat / factory reset** menghasilkan kode perangkat baru, jadi butuh kode aktivasi baru. Aplikasi tidak punya mekanisme transfer otomatis; ini **kebijakan komersial penjual** (menerbitkan ulang secara cuma-cuma atau tidak), dan `lisensi-terbit.csv` memberi penjual bukti pembelian sebelumnya. Layar Aktivasi menyebut ini secara terbuka: *"Ganti HP? Kirim kode perangkat baru Anda ke penjual."*

### 6.4 Acceptance criteria

| # | Kriteria (bisa diuji) |
|---|---|
| AC-6.1 | Pemasangan baru → aplikasi **tidak bisa** dipakai sebelum aktivasi: seluruh rute (`/kasir`, `/produk`, `/riwayat`, `/laporan`, `/pengaturan`) diarahkan ke layar Aktivasi, termasuk saat dibuka lewat *deep link* langsung (penjagaan di `redirect` router, bukan hanya di UI). |
| AC-6.2 | Kode perangkat yang sama tampil di layar Aktivasi, di kartu Lisensi pada Pengaturan, dan pada teks "Kirim ke Penjual" — **persis sama**, dan tidak berubah setelah aplikasi ditutup paksa & dibuka lagi. |
| AC-6.3 | Uninstall lalu install ulang APK yang ditandatangani kunci rilis yang sama → kode perangkat **tidak berubah** (diuji di perangkat fisik). |
| AC-6.4 | Kode aktivasi sah untuk perangkat ini → aktivasi berhasil dan aplikasi terbuka; waktu verifikasi < 1 detik di HP kelas menengah. |
| AC-6.5 | Kode sah yang diterbitkan untuk **perangkat lain** → ditolak dengan pesan spesifik "Kode ini diterbitkan untuk perangkat lain", bukan pesan generik. |
| AC-6.6 | Kode yang **satu karakternya salah ketik** → ditolak oleh CRC dengan pesan "Kode salah ketik atau belum lengkap", dan bukan dengan pesan "kode tidak sah". Diuji atas seluruh 120 posisi karakter (uji tabel, satu karakter diubah per kasus). |
| AC-6.7 | Kode yang tanda tangannya dipalsukan (satu bit muatan diubah lalu CRC dihitung ulang) → **selalu** ditolak. |
| AC-6.8 | Vektor uji tetap (fixture) berisi ≥ 6 kode: trial/lifetime/tahunan × (sah, kedaluwarsa) diverifikasi oleh unit test **tanpa perangkat dan tanpa jaringan**, dengan pasangan kunci uji yang di-*commit* (kunci uji, bukan kunci produksi). |
| AC-6.9 | Huruf kecil, `I`/`l`→`1`, `O`→`0`, spasi & tanda hubung acak, serta awalan `KW1-` yang ada/tidak ada — semuanya menghasilkan hasil verifikasi yang sama. |
| AC-6.10 | Trial 3 hari: pada hari ke-1 dan ke-3 aplikasi terbuka normal; pada hari ke-4 aplikasi menampilkan layar "Masa coba berakhir" (diuji dengan menyuntikkan tanggal acuan, bukan menunggu). |
| AC-6.11 | **Trial tidak bisa direset:** uninstall → install ulang → memasukkan kode trial yang sama pada hari ke-4 tetap menghasilkan keadaan kedaluwarsa. |
| AC-6.12 | Trial kedaluwarsa lalu diaktifkan dengan kode lifetime → **seluruh data yang dibuat selama trial tetap ada** (jumlah produk, transaksi, dan pergerakan stok identik sebelum vs sesudah). |
| AC-6.13 | Lisensi tahunan lewat tanggal kedaluwarsa → 7 hari berikutnya aplikasi tetap berfungsi penuh dengan banner masa tenggang berisi **sisa hari yang benar**. |
| AC-6.14 | Setelah masa tenggang habis: layar Kasir terkunci, sementara Riwayat, Laporan, Export Excel, Backup, dan Pengaturan **tetap bisa dibuka dan tetap menghasilkan file yang benar**. |
| AC-6.15 | Layar "Masa coba berakhir" menyediakan "Cadangkan Data" yang menghasilkan file backup sah (bisa di-restore), dan melewati gerbang PIN bila PIN aktif. |
| AC-6.16 | Jam perangkat dimundurkan 1 tahun → sisa masa berlaku **tidak bertambah**, banner "jam mundur" tampil, dan lisensi yang sudah kedaluwarsa **tetap** kedaluwarsa. |
| AC-6.17 | Backup dibuat di perangkat A (berlisensi) lalu di-restore di perangkat B (belum aktif) → perangkat B **tetap** meminta aktivasi; tidak ada jejak lisensi di dalam file backup (diverifikasi dengan memeriksa isi tabel `settings` pada file backup). |
| AC-6.18 | Lisensi berakhir saat aplikasi terbuka dengan keranjang berisi → transaksi berjalan **tetap bisa diselesaikan & tersimpan**; kunci baru berlaku setelah transaksi tersimpan. |
| AC-6.19 | Kunci privat tidak pernah ada di repositori: `git grep` atas pola kunci & `.gitignore` diperiksa dalam checklist rilis; aplikasi hanya memuat **kunci publik**. |
| AC-6.20 | Verifikator aplikasi menerima **daftar** kunci publik tepercaya (siap rotasi): token yang ditandatangani kunci lama maupun kunci baru sama-sama lolos selama keduanya masih terdaftar. |
| AC-6.21 | Muatan dengan `versi` lebih besar dari yang dikenal → pesan "Kode ini butuh versi aplikasi yang lebih baru", bukan "kode tidak sah". |
| AC-6.22 | Ukuran APK release tetap < 40 MB dan cold start tetap < 3 detik setelah fitur ini masuk (verifikasi Ed25519 tidak menambah waktu buka yang terasa). |

### 6.5 Dampak skema database

**Tidak ada tabel baru, tidak ada kolom baru, `schemaVersion` tetap 1** — dan yang lebih penting: **tidak ada satu pun nilai lisensi yang disimpan di database.**

**Keputusan K-6.1 — status lisensi disimpan di `shared_preferences`, BUKAN di tabel `settings`.** Alasannya berlapis, dan yang pertama menentukan:

1. **File backup boleh berpindah tangan; lisensi tidak boleh ikut.** Tabel `settings` ikut terbawa `backup → restore`. Menaruh token lisensi di sana berarti satu file backup yang beredar di grup WhatsApp membawa serta lisensi berbayarnya. Token memang terikat perangkat sehingga tidak akan lolos verifikasi di HP lain — tapi merancang gerbang penjualan yang keselamatannya bergantung pada satu lapisan saja adalah kecerobohan yang tidak perlu.
2. **Konsisten dengan keputusan yang sudah diambil.** Preferensi tema memakai alasan yang sama persis (K-5.2): yang bersifat **perangkat**, bukan **data toko**, tidak masuk database. Lisensi adalah contoh paling murni dari kategori itu.
3. **Harus terbaca sebelum database dibuka.** Gerbang aktivasi berjalan sebelum `runApp()` (§6.3.F); `shared_preferences` bisa dibaca di sana tanpa membuka Drift.
4. **Restore tidak boleh mengubah status lisensi** — baik menaikkan (mendapat lisensi gratis) maupun menurunkan (kehilangan lisensi yang sudah dibayar karena memulihkan backup lama).

| Penyimpanan | Key | Nilai | Default |
|---|---|---|---|
| `shared_preferences` | `license_token` | teks kode aktivasi yang sudah dinormalkan | kosong |
| `shared_preferences` | `license_activated_at` | epoch millis saat kode terakhir diaktifkan | kosong |
| `shared_preferences` | `license_last_seen_at` | epoch millis tertinggi yang pernah dilihat (§6.3.G) | kosong |
| `shared_preferences` | `license_device_id_fallback` | pengenal acak, **hanya** bila SSAID tidak terbaca (§6.3.C) | kosong |

Jenis lisensi, tanggal terbit, kedaluwarsa, dan masa tenggang **sengaja tidak disimpan terpisah** — semuanya diturunkan ulang dengan memverifikasi `license_token` di setiap *cold start*. Tidak ada nilai turunan yang bisa diubah orang lain tanpa merusak tanda tangan, dan tidak ada dua sumber kebenaran yang bisa melenceng.

Satu-satunya sentuhan ke database adalah **pembacaan**: `SELECT MAX(created_at) FROM sales` untuk saksi mundur-jam (§6.3.G), memakai index `idx_sales_created_at` yang sudah ada.

### 6.6 Dampak UI

Semua mengikuti [ui-redesign-foundation.md](ui-redesign-foundation.md). Layar-layar bab ini lahir **setelah** mode gelap (§5) selesai, jadi seluruh warna diambil dari `context.palette` — dilarang `AppColors.*` langsung.

- **Layar Aktivasi** (rute `/aktivasi`, di luar shell): satu titik fokus. `AppIconBadge` kunci ukuran `xl`, judul `headlineMedium` "Aktifkan Kasir Warung", lalu **kartu kode perangkat** (`AppCard(elevated: true)`) berisi kode dengan `AppTextStyles.numeric` berukuran besar bertabular — mengikuti prinsip "angka lebih penting dari labelnya". Dua tombol sekunder setinggi `buttonHeight` 52 ("Salin", "Kirim ke Penjual"), lalu masukan kode, lalu **satu CTA** `buttonHeightLarge` 60 "AKTIFKAN". Konten dibatasi `maxContentWidth` agar rapi di tablet.
- **Masukan kode manual** meminjam pola `pin_keypad.dart`: kelompok karakter yang terlihat sebagai kotak-kotak, bukan satu `TextField` panjang. Bedanya, alfabetnya alfanumerik sehingga tetap memakai keyboard sistem (`textCapitalization: characters`, `autocorrect: false`, `enableSuggestions: false`) — keypad khusus 32 tombol akan terlalu kecil dan melanggar target sentuh 48dp. Karakter dinormalkan saat diketik (huruf besar otomatis, `O`→`0`), pemisah kelompok muncul sendiri, dan kelompok yang sudah terisi berubah warna tenang.
- **Umpan balik verifikasi** memakai pola yang sudah ada di `pin_entry_screen.dart`: tombol tidak diganti spinner (bikin layar melompat), melainkan dinonaktifkan sambil baris status berubah "Memeriksa kode…". Kode salah → `AppPill(tone: danger)` dengan pesan yang **spesifik** (§6.4 AC-6.5, AC-6.6, AC-6.21), plus getaran halus + `HapticFeedback.heavyImpact` seperti PIN salah.
- **Layar "Masa coba berakhir"** (`/lisensi-berakhir`): `EmptyState` bernada `AppTone.accent` — ikon, judul "Masa coba 3 hari sudah berakhir", kalimat pengarah **yang menenangkan** ("Semua data Anda masih tersimpan aman dan akan langsung kembali setelah aplikasi diaktifkan."), kode perangkat, lalu CTA "Masukkan Kode Aktivasi" dan tombol tersier "Cadangkan Data". Tidak ada nada menghukum, tidak ada hitungan mundur dramatis.
- **Layar Kasir terkunci** (lisensi tahunan setelah tenggang): pola `EmptyState` yang sama di dalam shell — **navigasi bawah tetap ada dan tetap berfungsi**, sehingga terlihat jelas bahwa Riwayat/Laporan/Pengaturan masih bisa dibuka. Ini pesan visual yang penting: yang terkunci adalah jualannya, bukan datanya.
- **Banner** memakai `AppBanner` yang sudah ada, di atas daftar produk pada layar Kasir:
  - `AppTone.warning` — "Lisensi berakhir 5 hari lagi" (`akanBerakhir`),
  - `AppTone.danger` — "Lisensi sudah berakhir. Sisa masa tenggang 3 hari." + tombol "Perpanjang" (`masaTenggang`),
  - `AppTone.info` — banner jam mundur (§6.3.G).
  Banner **tidak pernah** menutupi bar keranjang atau CTA "Bayar", dan bisa ditutup untuk sesi berjalan kecuali pada keadaan `masaTenggang`.
- **Kartu "Lisensi" di Pengaturan** memakai `SettingsCard` (pola sama dengan `pin_section.dart`), ditempatkan **paling bawah** — di bawah kartu Data — karena bukan pengaturan harian. Isinya: `AppPill` status (`success` "Aktif" · `warning` "Akan berakhir" · `danger` "Masa tenggang/Berakhir"), jenis lisensi, tanggal aktivasi, tanggal berakhir + sisa hari (lifetime menampilkan "Selamanya" tanpa tanggal), kode perangkat + tombol Salin, dan tombol "Masukkan Kode Baru".
- **Ikon:** `Icons.verified_outlined` untuk lisensi aktif, `Icons.lock_clock` untuk kedaluwarsa, `Icons.qr_code_scanner` untuk pindai QR, `Icons.content_paste` untuk tempel.
- **Splash → Aktivasi** tidak boleh berkedip: keadaan lisensi sudah diketahui sebelum `runApp()` (§6.3.F), sama seperti tema.

### 6.7 Riset package, tata kelola kunci, keputusan & risiko

#### 6.7.1 Kandidat package

Diverifikasi pada 12 Agustus 2026 terhadap `pubspec.yaml` proyek ini (resolusi diuji dengan `flutter pub add --dry-run`; isi arsip paket diperiksa langsung, bukan dinilai dari deskripsi pub.dev).

| Kebutuhan | Package | Versi | Hasil |
|---|---|---|---|
| **Tanda tangan Ed25519** | **`cryptography`** | **2.9.0** (2025-11-21) | ✅ **Dipilih.** Murni Dart (implementasi Ed25519 ada di `lib/src/dart/ed25519.dart`), Apache-2.0, 150/160 pub points, ±561k unduhan/30 hari. Resolusi bersih terhadap `pubspec.yaml` proyek (`Would change 1 dependency`). **Tidak punya modul Android sama sekali**, sehingga seluruh kelas kegagalan `namespace`/AGP yang menghantam M0 & M6 tidak berlaku. Paket yang sama dipakai aplikasi (verify) **dan** tool CLI (sign) — satu jalur kode, satu sumber bug. |
| | `ed25519_edwards` | 0.3.1 (2021-09-17) | ➖ **Cadangan.** Murni Dart, Apache-2.0, resolusi bersih (+1 dependensi transitif `adaptive_number`). Rilis terakhir 2021 — untuk paket murni Dart tanpa kode platform ini jauh lebih ringan risikonya daripada paket plugin, tapi tetap menjadi alasan menomorduakannya. |
| | `pointycastle` | 4.0.0 | ❌ **Tidak punya Ed25519** — diverifikasi dengan memeriksa isi arsip 4.0.0 (tidak ada berkas `ed25519`/`eddsa`). Memakainya berarti pindah ke ECDSA, menyimpang dari keputusan Ed25519 tanpa keuntungan. |
| | `cryptography_plus` | 3.0.0 | ➖ Fork komunitas dari `cryptography`; adopsi jauh lebih kecil (±30k vs ±561k unduhan/30 hari). Kandidat pengganti **hanya bila** `cryptography` benar-benar berhenti dipelihara. |
| **Kode perangkat (SSAID)** | **MethodChannel sendiri** | — | ✅ **Dipilih.** ±15 baris Kotlin di `MainActivity.kt` yang **sudah ada**: `Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)`. Nol dependensi platform baru — alasan yang sama persis dengan K-9.1 (tidak menambah package untuk sesuatu yang bisa ditulis sendiri dalam puluhan baris). |
| | `android_id` | 0.5.2+1 (2026-07-06) | ➖ **Cadangan.** 160/160 pub points, terpelihara. Dipakai bila MethodChannel sendiri ternyata merepotkan; wajib lewat commit gerbang dependency yang sama. |
| | `device_info_plus` | 13.2.0 | ❌ **Tidak menyediakan SSAID.** `androidId` dihapus sejak versi 4.0.0 (CHANGELOG-nya sendiri mengarahkan ke package `android_id`). `AndroidDeviceInfo.id` adalah `Build.ID` — **bukan** pengenal perangkat, tidak stabil, dan tidak unik. Jebakan yang mudah termakan; dicatat di sini supaya tidak dicoba dua kali. |
| **QR (khusus tool penjual)** | `qr` + `image` | 4.0.0 + 4.3.0 | ✅ **dev_dependencies saja**, keduanya murni Dart (resolusi diuji: `Would change 2 dependencies`). Tidak ikut ke dalam APK. Pelajaran M6 tetap berlaku: **hanya paket murni Dart yang boleh masuk `dev_dependencies`**, dan `flutter build apk --release` diuji ulang setelah menambahkannya. |
| **Pindai QR (di aplikasi)** | `mobile_scanner` | 7.4.0 | ✅ **Sudah ada** di proyek untuk barcode produk — jalur QR di layar Aktivasi me-*reuse*-nya, **tanpa dependency baru**. |

**Versi yang dikunci di `pubspec.yaml`:**

```yaml
dependencies:
  cryptography: ^2.9.0        # verifikasi Ed25519 (murni Dart, tanpa modul Android)

dev_dependencies:
  qr: ^4.0.0                  # hanya untuk tool/license_generator.dart
  image: ^4.3.0               # menulis QR sebagai PNG
```

#### 6.7.2 Tata kelola kunci penerbit

Kunci privat penerbit adalah **aset paling berharga proyek ini di luar kode sumbernya**. Aturannya tegas dan tidak boleh dilonggarkan:

| Aturan | Rinciannya |
|---|---|
| **Tidak pernah di-commit** | Kunci hidup di `~/.kasir-warung/license_ed25519.key` (di luar repo). `.gitignore` menutup `*.key`, `*.pem`, `lisensi-terbit.csv`. Checklist rilis memuat pemeriksaan `git grep` (AC-6.19). |
| **Cadangan minimal dua tempat luring** | Mis. USB terenkripsi di rumah + catatan tercetak/pengelola kata sandi. **Bukan** Google Drive akun kerja yang sama dengan laptop, dan bukan repositori privat. |
| **Kalau kunci HILANG** | Kode yang sudah beredar **tetap sah selamanya** (aplikasi hanya butuh kunci publik). Yang hilang adalah kemampuan **menerbitkan kode baru**. Pemulihan: buat pasangan kunci baru, tambahkan kunci publik baru ke **daftar** kunci tepercaya (AC-6.20), rilis pembaruan aplikasi. Pelanggan lama tidak terganggu; pelanggan baru harus memakai versi aplikasi ≥ rilis itu. |
| **Kalau kunci BOCOR** | Siapa pun bisa menerbitkan kode untuk perangkat mana pun (masih terikat per perangkat, jadi bukan "satu kode untuk semua" — tapi cukup untuk membuat *keygen*). Tanggapan: terbitkan kunci baru, **keluarkan kunci lama dari daftar tepercaya**, rilis pembaruan. Konsekuensinya diakui terus terang: seluruh pemasangan lama yang tidak pernah diperbarui tetap bisa dibobol. Karena itu aturan "tidak pernah di-commit" bukan formalitas. |
| **Rotasi sudah disiapkan sejak awal** | Verifikator menerima **daftar** kunci publik, bukan satu kunci. Rotasi tidak butuh perubahan format token maupun alur verifikasi (AC-6.20). |
| **Kunci uji terpisah** | Vektor uji (AC-6.8) memakai pasangan kunci **uji** yang boleh di-commit di `test/fixtures/`. Kunci uji **tidak pernah** masuk daftar tepercaya build release — diuji sebagai bagian dari AC-6.19. |

#### 6.7.3 Risiko

Bagian ini sengaja jujur. Sistem lisensi klien-saja punya batas yang tidak bisa ditutup dengan kepintaran apa pun, dan lebih baik batas itu tertulis di sini daripada ditemukan sebagai kejutan.

| Risiko | Dampak | Mitigasi |
|---|---|---|
| **Satu perangkat meminta trial berkali-kali** | Pemakaian gratis tanpa henti dengan trial berantai | Kedaluwarsa trial bersifat **absolut** (tertanam di kode), sehingga memasang ulang tidak meresetnya. Yang tersisa: pembeli meminta **kode trial baru** untuk perangkat yang sama. Satu-satunya penjaganya adalah **pencatatan penjual** — `lisensi-terbit.csv` terisi otomatis dan generator **memperingatkan** bila kode perangkat itu sudah pernah dapat trial (§6.3.B). Tanpa server, tidak ada mekanisme lain; ini diterima secara sadar. |
| **APK dibongkar (patching)** | Proteksi dilewati sepenuhnya | **Tidak ada mitigasi yang benar-benar menutupnya.** Tujuan fitur ini adalah **deterrence yang wajar untuk pasar UMKM**, bukan DRM. Pembeli target tidak membongkar APK; ia meminta kode ke penjual. R8 yang sudah aktif ([plan.md](plan.md) M6) menaikkan sedikit ongkos pembongkaran, dan verifikasi yang tersebar di beberapa titik (start, resume, gerbang router) membuat patching butuh lebih dari satu sentuhan — itu saja, dan itu memang cukup. |
| **Kode beredar di grup WhatsApp** | Satu kode dipakai banyak orang | Terikat perangkat lewat tanda tangan atas kode perangkat (§6.3.D): kode yang sama **tidak akan lolos** di perangkat lain. Ini justru kekuatan utama desain ini. |
| **Kode 120 karakter dianggap merepotkan** | Pembeli menyerah saat aktivasi | Tiga jalur masuk dengan pengetikan sebagai **jalan terakhir** (§6.3.A), alfabet tanpa karakter kembar, pengelompokan 5 karakter, dan CRC yang menunjukkan salah ketik sebelum menyalahkan pengguna. Metrik §11.1 mengunci ini. |
| **Kunci privat bocor atau hilang** | Keygen beredar / tidak bisa jualan | §6.7.2 — cadangan luring, `.gitignore`, daftar kunci tepercaya yang bisa dirotasi. |
| **Jam perangkat dimundurkan** | Trial/tahunan dipakai selamanya | Jam monoton dari tiga saksi (§6.3.G), termasuk `created_at` transaksi yang **ikut terbawa restore backup**. |
| **SSAID berubah tak terduga** (factory reset, ganti HP, perangkat cacat) | Pembeli jujur kehilangan lisensi yang sudah dibayar | Dinyatakan terus terang di layar Aktivasi & kartu Lisensi; `lisensi-terbit.csv` menjadi bukti pembelian sehingga penjual bisa menerbitkan ulang dalam hitungan menit. Kasus SSAID cacat ditangani dengan pengenal cadangan (§6.3.C). |
| **Lisensi sah ditolak aplikasi** (false negative) | Pembeli yang sudah membayar tidak bisa berjualan — kerusakan terparah dari fitur ini | Vektor uji tetap (AC-6.8), perintah `--verifikasi` yang menjalankan **jalur kode yang sama** dengan aplikasi untuk dukungan jarak jauh, dan metrik **0 kasus** di §11.1. Bila ragu, aplikasi **selalu memilih membiarkan pengguna bekerja** — mis. jam kacau tidak pernah mengunci selama masa berlaku belum lewat (§6.3.G). |
| **Gerbang lisensi mengunci di tengah transaksi** | Uang pembeli sudah di tangan, transaksi hilang | Dilarang keras — §6.3.F dan AC-6.18. |
| **Aktivasi dianggap "aplikasi jadi butuh internet"** | Melanggar janji inti produk & merusak kepercayaan | §1.4 dan §6.1: perangkat kasir tidak pernah menyentuh jaringan; pertukaran kode lewat manusia. Wajib ditulis apa adanya di materi jualan, bukan disembunyikan. |
| **Dependency `cryptography` gagal build release** | Seluruh Tier 1 tertahan (preseden M0 & M6) | Paket murni Dart tanpa modul Android → kelas kegagalan itu tidak berlaku. Aturan tetap dijalankan: dependency masuk **commit terpisah** yang divalidasi `flutter build apk --release` sebelum kode fitur ditulis. |

#### 6.7.4 Keputusan

- **K-6.1** Status lisensi disimpan di **`shared_preferences`**, tidak pernah di tabel `settings`/database, sehingga tidak pernah ikut backup/restore (§6.5). Konsisten dengan K-5.2.
- **K-6.2** **Ed25519**, kunci privat di tangan penjual, **daftar** kunci publik ditanam di aplikasi (siap rotasi). Skema simetris (HMAC dengan kunci bersama) **ditolak**: kuncinya harus ikut di dalam APK, dan satu pembongkaran menghasilkan keygen untuk semua perangkat.
- **K-6.3** Kode aktivasi **tidak dipendekkan dengan mengorbankan keamanan.** Tanda tangan tidak dipotong (memotong Ed25519 membuat verifikasi mustahil) dan kurva/skema non-standar tidak dipakai (implementasi kripto sendiri adalah risiko yang jauh lebih besar daripada kode panjang). Panjang 120 karakter dilawan dengan **UX**: QR → tempel → ketik.
- **K-6.4** Kode **terikat perangkat** lewat kode perangkat yang ikut ditandatangani tapi **tidak ikut dikirim** — verifier menyusun ulang pesannya sendiri.
- **K-6.5** Kode perangkat berasal dari **SSAID yang di-hash dan dipendekkan** (45 bit + 1 karakter cek), bukan SSAID mentah (§6.3.C).
- **K-6.6** Kode aktivasi **bukan sekali pakai**: memasukkan kode yang sama setelah pasang ulang selalu boleh. Justru inilah yang membuat trial tidak bisa direset (kedaluwarsanya absolut).
- **K-6.7** **CRC-16 tetap dipakai** walau sudah ada tanda tangan — semata-mata agar aplikasi bisa membedakan *salah ketik* dari *kode palsu* dan memberi pesan yang benar.
- **K-6.8** Seluruh evaluasi masa berlaku memakai **jam monoton** `waktuAcuan` (§6.3.G), bukan jam perangkat langsung; jam yang kacau **tidak pernah** dijadikan alasan mengunci selama masa berlaku belum lewat.
- **K-6.9** Gerbang lisensi berada di **`redirect` go_router sebelum shell**, bukan di UI. Urutan gerbang bila §8 aktif: lisensi → masuk → shell.
- **K-6.10** **Tidak pernah mengunci di tengah transaksi berjalan** (§6.3.F, AC-6.18).
- **K-6.11** **Data tidak pernah disandera.** Kedaluwarsa tahunan menyisakan Riwayat/Laporan/Export/Backup; layar trial berakhir tetap menyediakan "Cadangkan Data".
- **K-6.12** Generator adalah **tool CLI Dart di dalam repo** (`tool/license_generator.dart`) yang memakai **jalur verifikasi yang sama** dengan aplikasi (paket & kode bersama), sehingga tidak mungkin ada perbedaan tafsir antara yang diterbitkan dan yang diverifikasi.
- **K-6.13** Masa tenggang **7 hari untuk lisensi tahunan, 0 untuk trial**, dan nilainya **ikut ditandatangani** di dalam muatan sehingga bisa disesuaikan per pelanggan tanpa merilis aplikasi baru.
- **K-6.14** Perpanjangan dihitung dari **tanggal terbit kode baru**, bukan ditumpuk pada sisa lama (sederhana dan mudah dijelaskan; kompensasi sisa hari dilakukan penjual saat menerbitkan).
- **K-6.15** **Tidak ada transfer lisensi otomatis antar perangkat.** Ganti perangkat = kode baru; keputusan memberi atau tidak adalah kebijakan komersial penjual, dibantu `lisensi-terbit.csv`.

### 6.8 TIDAK termasuk

- Server/backend aktivasi, akun pembeli, dasbor lisensi daring, dan **telemetri apa pun** (berapa kali aplikasi dibuka, di mana, oleh siapa).
- Pembayaran di dalam aplikasi (IAP Play Store), pembelian lewat kartu/e-wallet, perpanjangan otomatis, atau langganan bulanan yang menagih sendiri.
- Trial otomatis tanpa kode ("pasang, langsung 3 hari gratis") — mustahil dijaga tanpa server dan langsung mengundang reset lewat pasang ulang.
- Transfer lisensi antar perangkat secara otomatis, atau satu lisensi untuk beberapa perangkat sekaligus.
- Lisensi per fitur (mis. "laporan hanya untuk paket mahal") — seluruh fitur ikut dalam satu lisensi.
- Proteksi anti-bongkar di luar R8 yang sudah aktif: tanpa deteksi root, tanpa pemeriksaan tanda tangan APK saat berjalan, tanpa obfuscation tambahan, tanpa "kill switch".
- Penonaktifan/pencabutan lisensi dari jarak jauh (butuh server; mustahil dan tidak diinginkan).
- Pemulihan lisensi lewat email/SMS/OTP.
- Dukungan iOS (menyusul bersama rilis iOS; SSAID adalah konsep Android, padanannya di iOS adalah `identifierForVendor` dengan sifat yang berbeda dan harus dirancang tersendiri).
- Harga, promo, kode voucher, dan skema diskon — itu urusan penjualan, bukan aplikasi.

> **Jalur evolusi (bukan cakupan sekarang).** Format muatan §6.3.D sengaja dirancang agar backend aktivasi otomatis (mis. Supabase/serverless) bisa **ditambahkan kelak tanpa mengubah format token maupun alur verifikasi offline**: server hanya menggantikan peran penjual sebagai penerbit (menandatangani muatan yang sama dengan kunci yang sama), dan aplikasi bisa menambah satu jalur pengambilan kode otomatis di layar Aktivasi — jalur manual tetap ada dan tetap wajib bekerja tanpa internet. Byte `versi` di muatan dan **daftar** kunci publik tepercaya adalah dua kait yang membuat evolusi itu tidak memaksa perubahan yang merusak. Sekali lagi: **ini bukan pekerjaan v1.1.**

---

## 7. Fitur Tier 2 — Manajemen Pelanggan Lengkap (Poin & Riwayat Belanja)

### 7.1 Latar & masalah pengguna

Di v1.0, pelanggan hanyalah **teks bebas** di kolom `sales.customer_name`, yang diisi ketika transaksi hutang. Konsekuensinya nyata dan menjengkelkan:

- **Nama kembar karena typo.** "Bu Ani", "bu ani", dan "Bu Ani " menjadi tiga penghutang berbeda di daftar hutang. Pemilik jadi tidak percaya angkanya.
- **Tidak ada riwayat.** Pertanyaan sederhana "Bu Ani biasanya belanja apa?" atau "bulan ini dia belanja berapa?" tidak bisa dijawab.
- **Tidak ada penghargaan pelanggan setia.** Warung bersaing dengan minimarket; program poin sederhana ("belanja Rp10.000 dapat 1 poin, 10 poin bisa ditukar Rp5.000") adalah alat yang murah dan sangat khas warung.
- **Pelanggan tunai tak terlacak sama sekali.** Nama hanya diminta pada transaksi hutang, padahal pelanggan setia justru sering membayar tunai.

### 7.2 User stories

1. Sebagai pemilik, saya bisa menyimpan daftar pelanggan langganan (nama, no. HP, catatan) supaya tidak mengetik ulang setiap kali.
2. Sebagai kasir, saat menagih saya bisa memilih pelanggan dari daftar dengan mengetik beberapa huruf — bukan mengetik ulang namanya.
3. Sebagai pemilik, saya bisa membuka satu pelanggan dan melihat **seluruh riwayat belanjanya**, total belanja, dan sisa hutangnya.
4. Sebagai pemilik, saya bisa menyalakan program poin dan menentukan aturannya sendiri (berapa rupiah per poin, berapa rupiah nilai satu poin).
5. Sebagai kasir, saat pelanggan punya cukup poin saya bisa menukarnya menjadi potongan harga langsung di layar pembayaran.
6. Sebagai pemilik, saya bisa **menggabungkan** dua nama pelanggan yang ternyata orang yang sama, tanpa kehilangan riwayat atau poin.
7. Sebagai pemilik lama, setelah memperbarui aplikasi, daftar hutang saya yang lama **tetap benar** dan otomatis rapi.

### 7.3 Perilaku & alur detail

#### A. Daftar & detail pelanggan

Layar **Pelanggan** (letaknya di §7.6) menampilkan daftar dengan pencarian: nama, sisa hutang (bila ada), saldo poin, dan tanggal transaksi terakhir. Detail pelanggan berisi tiga bagian:
- **Ringkasan** — total belanja sepanjang waktu, jumlah transaksi, sisa hutang, saldo poin.
- **Riwayat belanja** — daftar transaksi (paginasi, pola sama dengan riwayat transaksi M3), tap untuk membuka detail transaksi yang sudah ada.
- **Riwayat poin** — buku besar poin: kapan dapat, dari transaksi mana, kapan ditukar, saldo setelahnya.

Aksi: ubah, nonaktifkan (bukan hapus keras), gabungkan dengan pelanggan lain.

#### B. Memilih pelanggan saat transaksi

Kolom teks bebas "Nama pelanggan" pada sheet pembayaran diganti **pemilih pelanggan**:

```
Pembayaran → [ + Pilih Pelanggan ]  (opsional untuk tunai/non-tunai,
                                      WAJIB untuk hutang)
→ ketik "an" → daftar cocok: "Bu Ani (poin 12)", "Andi Warung Sebelah"
→ tidak ada yang cocok → "Buat pelanggan baru: 'Anisa'" (satu tap, nama saja;
   nomor HP bisa dilengkapi belakangan)
→ terpilih → chip pelanggan tampil di sheet, bisa dilepas
```

Aturan penting: alur kasir untuk pelanggan **tanpa nama tetap tidak berubah** — nol tap tambahan bila pelanggan tidak dipilih.

#### C. Poin

Pengaturan → kartu "Program Poin":

| Pengaturan | Default | Keterangan |
|---|---|---|
| Program poin aktif | **mati** | Bila mati, seluruh UI poin tersembunyi. |
| Rupiah per 1 poin | `10000` | Belanja Rp37.000 → 3 poin (pembulatan ke bawah). |
| Nilai tukar 1 poin | `500` | 10 poin = potongan Rp5.000. |
| Minimum poin untuk ditukar | `10` | |

Aturan perolehan & pembatalan:
- Poin diberikan saat transaksi **tersimpan**, untuk semua metode bayar termasuk hutang (menyederhanakan aturan; hutang yang tidak dibayar akhirnya di-void atau ditagih).
- Dasar perhitungan adalah **total setelah diskon**, dan **tidak termasuk** potongan hasil penukaran poin (poin tidak menghasilkan poin).
- **Void transaksi → poin ditarik kembali**, dan poin yang sempat ditukar pada transaksi itu dikembalikan ke saldo. Keduanya dicatat sebagai entri buku besar terpisah dalam transaksi DB yang sama dengan void.
- Saldo poin **tidak boleh negatif**; bila void membuat saldo minus (poin sudah terlanjur ditukar di transaksi lain), saldo dipatok 0 dan entri buku besar mencatat selisihnya dengan catatan jelas.
- Penukaran poin di kasir menghasilkan **diskon level transaksi** (kolom `sales.discount` yang sudah ada) plus entri buku besar `redeem`. Struk mencetak baris "Tukar poin".

#### D. Menggabungkan pelanggan

```
Pelanggan → pilih 2 atau lebih (long-press → mode pilih) → "Gabungkan"
→ pilih nama mana yang dipertahankan
→ pratinjau: "3 pelanggan digabung → 47 transaksi, 24 poin, hutang Rp150.000"
→ konfirmasi
→ satu transaksi DB: sales.customer_id dialihkan, entri poin dialihkan,
  saldo dijumlahkan, pelanggan sumber ditandai nonaktif & ditandai
  'digabung ke <id>'
```

#### E. Migrasi data lama (paling kritis)

Saat `schemaVersion` naik 1 → 2, migrasi wajib:
1. Membuat tabel `customers` dan `customer_point_entries`, serta kolom `sales.customer_id`.
2. Mengambil seluruh `DISTINCT TRIM(customer_name)` dari `sales` yang tidak kosong.
3. Mengelompokkan **case-insensitive** setelah trim (`"Bu Ani"`, `"bu ani"`, `"BU ANI "` → satu pelanggan). Ejaan yang dipakai adalah yang **paling sering muncul**; bila seri, yang paling awal.
4. Membuat satu baris `customers` per kelompok, `points = 0`.
5. Mengisi `sales.customer_id` untuk semua transaksi terkait.
6. `sales.customer_name` **tidak dihapus dan tidak diubah** — tetap menjadi snapshot historis (persis seperti `sale_items.product_name`), sehingga mengganti nama pelanggan tidak pernah mengubah struk lama.

Poin **tidak** diberikan surut untuk transaksi lama (keputusan K-7.4).

### 7.4 Acceptance criteria

| # | Kriteria (bisa diuji) |
|---|---|
| AC-7.1 | Database v1 berisi transaksi hutang dengan nama `"Bu Ani"`, `"bu ani"`, `"Bu Ani "` → setelah migrasi terbentuk **satu** pelanggan dengan tiga transaksi, dan daftar hutang menampilkan satu baris dengan total gabungan. |
| AC-7.2 | Backup v1.0 yang direstore di aplikasi v1.1 menjalankan migrasi tersebut otomatis dan menghasilkan total hutang yang **identik** dengan sebelum migrasi (uji: jumlahkan sebelum & sesudah). |
| AC-7.3 | `sales.customer_name` pada transaksi lama tidak berubah setelah migrasi maupun setelah pelanggan di-*rename*. |
| AC-7.4 | Transaksi hutang tanpa memilih pelanggan tetap ditolak dengan `NamaPelangganWajibException` (perilaku v1.0 dipertahankan). |
| AC-7.5 | Alur kasir tunai tanpa memilih pelanggan tidak bertambah satu tap pun dibanding v1.0. |
| AC-7.6 | Program poin mati (default) → tidak ada elemen poin yang muncul di layar mana pun, termasuk struk. |
| AC-7.7 | Program poin nyala, aturan Rp10.000/poin: belanja Rp37.000 → tepat 3 poin; belanja Rp9.999 → 0 poin. |
| AC-7.8 | Void transaksi berpoin → saldo pelanggan kembali seperti sebelum transaksi, dan buku besar poin punya entri pembatalan yang merujuk `sale_id` tersebut. |
| AC-7.9 | Penukaran poin menghasilkan diskon transaksi yang benar, mengurangi saldo poin tepat sejumlah yang ditukar, dan tercetak/tertulis di struk. |
| AC-7.10 | Poin tidak pernah diberikan atas nilai potongan hasil penukaran poin. |
| AC-7.11 | Saldo poin di tabel `customers` **selalu** sama dengan jumlah seluruh entri di `customer_point_entries` (uji invarian setelah rangkaian acak: jual, void, tukar, gabung). |
| AC-7.12 | Menggabungkan 3 pelanggan → seluruh transaksi menunjuk pelanggan hasil gabungan, saldo poin = jumlah ketiganya, tidak ada entri buku besar yang hilang. |
| AC-7.13 | Pelanggan dengan hutang belum lunas tidak bisa dinonaktifkan; pesan menjelaskan alasannya. |
| AC-7.14 | Pencarian pelanggan pada 2.000 pelanggan menghasilkan saran < 100 ms. |
| AC-7.15 | Detail pelanggan dengan 5.000 transaksi tetap terbuka mulus (paginasi, bukan memuat semuanya). |
| AC-7.16 | Export Excel mendapat sheet/berkas "Pelanggan & Poin" berisi nama, no. HP, total belanja, sisa hutang, saldo poin. |

### 7.5 Dampak skema database — `schemaVersion` 1 → 2

```sql
-- BARU
customers(
  id INTEGER PK AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NULL,
  note TEXT NULL,
  points INTEGER NOT NULL DEFAULT 0,     -- saldo tercache; kebenaran ada di ledger
  is_active INTEGER NOT NULL DEFAULT 1,
  merged_into_id INTEGER NULL REFERENCES customers(id),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)

-- BARU: buku besar poin (audit trail, pola sama dengan stock_movements)
customer_point_entries(
  id INTEGER PK AUTOINCREMENT,
  customer_id INTEGER NOT NULL REFERENCES customers(id),
  sale_id INTEGER NULL REFERENCES sales(id),
  type TEXT NOT NULL,           -- 'earn' | 'redeem' | 'void_return' | 'adjust' | 'merge'
  points INTEGER NOT NULL,      -- +dapat / −pakai
  balance_after INTEGER NOT NULL,
  note TEXT NULL,
  created_at INTEGER NOT NULL
)

-- PERUBAHAN pada tabel yang sudah ada
ALTER TABLE sales ADD COLUMN customer_id INTEGER NULL REFERENCES customers(id);
-- sales.customer_name TETAP ADA (snapshot historis, tidak boleh dihapus)

-- INDEX
CREATE UNIQUE INDEX idx_customers_name_nocase ON customers(name COLLATE NOCASE)
  WHERE is_active = 1;                        -- cegah duplikat baru
CREATE INDEX idx_sales_customer ON sales(customer_id, created_at);
CREATE INDEX idx_point_entries_customer ON customer_point_entries(customer_id, created_at);
```

Pengaturan tambahan di tabel `settings`: `points_enabled` (`0`/`1`, default `0`), `points_rupiah_per_point` (default `10000`), `points_value_per_point` (default `500`), `points_min_redeem` (default `10`).

**Kewajiban migrasi (`onUpgrade` 1 → 2):** langkah backfill di §7.3.E dijalankan di dalam satu transaksi. Uji migrasi wajib memakai *snapshot* database v1 nyata (pola uji migrasi Drift, lihat [architecture.md §8](architecture.md)).

**Kompatibilitas backup:** mulai v1.1 Tier 2, file backup ber-`user_version = 2` **tidak bisa** dibuka aplikasi v1.0. `BackupService.validateBackupFile` saat ini membaca `PRAGMA user_version` tapi **tidak membandingkannya** — ini harus diperbaiki: bila `user_version` file lebih besar daripada `schemaVersion` aplikasi, restore ditolak dengan pesan "File backup berasal dari versi aplikasi yang lebih baru. Perbarui aplikasi ini dulu." (dicatat sebagai AC-10.2).

### 7.6 Dampak UI

- **Letak layar Pelanggan.** Navigasi bawah **tetap 5 tab** (Kasir · Produk · Riwayat · Laporan · Pengaturan). Tab keenam akan memaksa target sentuh di bawah 48dp pada HP 5 inci — melanggar [prd.md §6](prd.md). Pelanggan diakses dari:
  1. **Tab Laporan** — kartu "Hutang Pelanggan" yang ada berkembang menjadi kartu "Pelanggan" dengan dua ringkasan (total hutang, jumlah pelanggan) dan tautan ke daftar penuh. Layar `debt_list_screen.dart` menjadi *filter* "Punya hutang" di dalam daftar pelanggan, bukan layar terpisah.
  2. **Sheet pembayaran** — pemilih pelanggan.
  3. **Detail transaksi** — nama pelanggan menjadi tautan ke profil pelanggan.
- **Pemilih pelanggan** memakai bottom sheet dengan field pencarian di atas (autofocus), hasil sebagai list ≥ 56dp per baris, dan baris pertama "Buat pelanggan baru: <ketikan>" saat tidak ada yang cocok persis.
- **Saldo poin** ditampilkan sebagai `AppPill` `AppTone.accent` (gula aren = penanda yang butuh perhatian, konsisten dengan hutang) dengan angka memakai `AppTextStyles.numeric`.
- **Kartu ringkasan pelanggan** memakai `AppCard(elevated: true)` dengan angka besar di atas label kecil.
- **Riwayat poin** memakai `AppDataRow` dengan tanda +/− berwarna `AppTone.success`/`AppTone.danger`.
- Semua warna diambil dari `context.palette` (§5) — layar ini ditulis **setelah** mode gelap selesai, jadi tidak boleh ada `AppColors.*` langsung.

### 7.7 Keputusan & risiko teknis

- **K-7.1** `sales.customer_name` dipertahankan sebagai snapshot selamanya, berdampingan dengan `customer_id`. Konsisten dengan pola snapshot `sale_items` di v1.0.
- **K-7.2** Poin memakai **buku besar (ledger)**, bukan sekadar kolom saldo. Saldo di `customers.points` adalah cache yang diperbarui dalam transaksi DB yang sama; kebenarannya bisa diaudit dan diperbaiki dari ledger.
- **K-7.3** Poin berbentuk **bilangan bulat**. Tidak ada poin pecahan — lebih mudah dijelaskan ke pembeli dan tidak memunculkan galat pembulatan.
- **K-7.4** **Tidak ada poin surut** untuk transaksi sebelum fitur menyala. Menghitung surut akan memberi saldo besar yang mengejutkan dan bisa langsung ditukar — risiko kerugian nyata bagi pemilik.
- **K-7.5** Poin diberikan saat transaksi tersimpan (termasuk hutang), bukan saat hutang lunas. Aturan sederhana lebih penting daripada aturan yang "adil sempurna", dan void sudah menutup celah penyalahgunaan.
- **K-7.6** Penukaran poin diwujudkan sebagai **diskon transaksi biasa**, sehingga seluruh laporan, laba kotor, dan struk yang sudah ada bekerja tanpa perubahan konsep.
- **K-7.7** Penggabungan pelanggan bersifat **satu arah dan tidak bisa dibatalkan**; pelanggan sumber disimpan (nonaktif + `merged_into_id`) agar jejaknya tetap ada.

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Migrasi backfill salah kelompok → hutang tampak berubah | Kepercayaan hancur (ini soal uang) | AC-7.1 & AC-7.2 dengan uji atas snapshot DB v1 nyata; migrasi dijalankan dalam satu transaksi; pengguna diminta backup sebelum update besar. |
| Saldo poin melenceng dari ledger | Sengketa dengan pembeli | AC-7.11 invarian saldo = jumlah ledger, diuji dengan rangkaian operasi acak; fungsi "hitung ulang saldo dari ledger" tersedia di Pengaturan (aksi pemeliharaan). |
| Nama pelanggan tetap duplikat setelah migrasi (mis. "Ani" vs "Bu Ani") | Daftar berantakan | Fitur gabung manual (§7.3.D) — sengaja manual, karena penggabungan otomatis berbasis kemiripan berisiko menyatukan dua orang berbeda. |
| Alur kasir jadi lebih lambat | Melanggar prinsip 3 langkah | Pemilih pelanggan opsional & tidak muncul kecuali ditekan; AC-7.5 mengunci ini. |
| Unique index nama membuat impor/entri gagal | Pengguna terhalang | Index unik hanya berlaku untuk pelanggan aktif; pesan error menyarankan memilih pelanggan yang sudah ada. |

### 7.8 TIDAK termasuk

- Tingkatan membership (silver/gold), kartu member fisik, atau barcode member.
- Promo ulang tahun, kupon, voucher, promo otomatis berbasis aturan.
- Blast SMS/WhatsApp/email ke pelanggan (butuh internet — dilarang [prd.md §3.2](prd.md)).
- Batas kredit (plafon hutang) per pelanggan dan penagihan otomatis.
- Poin yang kedaluwarsa (masa berlaku poin).
- Segmentasi/analitik pelanggan (RFM, pelanggan hilang, dsb.).
- Impor daftar pelanggan dari Excel (§4 hanya untuk produk).
- Sinkronisasi pelanggan antar perangkat selain lewat backup/restore.
- Foto pelanggan.

---

## 8. Fitur Tier 2 — Multi-user dengan PIN per Kasir

### 8.1 Latar & masalah pengguna

v1.0 punya **satu PIN global** (`pin_hash` + `pin_salt` di tabel `settings`) yang melindungi Laporan, Pengaturan, dan void. Cukup untuk pemilik yang menjaga sendiri, tapi tidak cukup begitu ada karyawan:

- **Tidak ada jejak siapa.** Kalau kas kurang atau ada transaksi janggal, tidak ada cara tahu siapa yang melayani.
- **PIN bocor sekali, bocor selamanya.** Satu PIN dipakai bersama; mengganti PIN berarti memberi tahu semua orang lagi.
- **Semua atau tidak sama sekali.** Pemilik ingin karyawan bisa berjualan tapi tidak melihat laba dan tidak bisa membatalkan transaksi — v1.0 tidak bisa memisahkan itu selain dengan menahan PIN dari karyawan (yang berarti karyawan juga tidak bisa mengakses hal-hal wajar).
- **Penyesuaian stok tanpa nama.** `stock_movements` mencatat apa dan kapan, tapi bukan siapa.

### 8.2 User stories

1. Sebagai pemilik, saya bisa menambah akun kasir dengan nama dan PIN sendiri-sendiri.
2. Sebagai pemilik, saya bisa melihat **siapa** yang melayani setiap transaksi di riwayat dan di struk.
3. Sebagai pemilik, saya ingin kasir **tidak bisa** melihat laba, mengubah harga, membatalkan transaksi, membuka Pengaturan, atau memulihkan backup.
4. Sebagai kasir, saya bisa masuk dengan memilih nama saya lalu mengetik PIN saya — tanpa mengingat PIN orang lain.
5. Sebagai pemilik, saya bisa mengganti giliran kasir dengan cepat ("Ganti Kasir") tanpa menutup aplikasi.
6. Sebagai pemilik, saya bisa mereset PIN kasir yang lupa.
7. Sebagai pemilik yang lupa PIN saya sendiri, saya punya jalan pemulihan yang tidak butuh internet.
8. Sebagai pemilik warung tanpa karyawan, saya bisa **tidak menyalakan fitur ini sama sekali** dan aplikasi tetap persis seperti sebelumnya.

### 8.3 Perilaku & alur detail

#### A. Menyalakan multi-user

```
Pengaturan → kartu "Pengguna & Akses" → "Aktifkan Multi-Pengguna"
→ (bila sudah ada PIN global) PIN itu OTOMATIS menjadi PIN akun
   "Pemilik"; pengguna diminta mengisi nama pemilik (default "Pemilik")
→ (bila belum ada PIN) buat PIN Pemilik sekarang (6 digit)
→ tampilkan KODE PEMULIHAN 8 karakter SEKALI SAJA
   "Catat kode ini. Tanpa kode ini, PIN Pemilik yang lupa hanya bisa
    dipulihkan dengan memasang ulang aplikasi (data hilang)."
   [Salin]  [Bagikan]  [Saya sudah mencatat] ← wajib dicentang
→ selesai; layar masuk akan muncul saat aplikasi dibuka
```

Mematikan multi-user hanya boleh dilakukan Pemilik: akun-akun kasir dinonaktifkan, PIN Pemilik kembali menjadi PIN global, dan `sales.user_id` yang sudah tercatat **tetap dipertahankan** (riwayat tidak boleh hilang).

#### B. Masuk & ganti kasir

```
Buka aplikasi (multi-user aktif)
→ Layar Masuk: daftar nama pengguna (kartu besar, ≥64dp)
→ tap nama → keypad PIN (reuse pin_keypad.dart) → masuk
→ sesi bertahan sampai "Ganti Kasir" ditekan atau kunci otomatis aktif
```

- **Pemilihan nama lebih dulu, baru PIN** — bukan PIN saja. Ini menghindari masalah dua pengguna berkebetulan memilih PIN sama, dan membuat pencatatan "siapa" tidak ambigu.
- **"Ganti Kasir"** tersedia di Pengaturan dan sebagai aksi di menu ⋮ layar Kasir (satu-satunya tambahan di layar kasir, karena berganti giliran adalah kebutuhan nyata di tengah jam sibuk).
- **Kunci otomatis** opsional: mati (default), 1, 5, atau 15 menit tanpa aktivitas. Saat terkunci, keranjang yang sedang berjalan **tidak dibuang** — hanya ditutupi layar PIN.
- Percobaan PIN salah: setelah 5 kali gagal, keypad terkunci 30 detik (naik berlipat sampai maksimal 5 menit). Tidak ada penghapusan data setelah sekian kali gagal.

#### C. Peran & izin (tetap, tidak bisa dikustomisasi)

| Kemampuan | Pemilik | Kasir |
|---|---|---|
| Layar Kasir, jual, hold, item bebas | ✅ | ✅ |
| Scan barcode, cari produk | ✅ | ✅ |
| Transaksi hutang & pelunasan | ✅ | ✅ |
| Riwayat transaksi | ✅ semua | ✅ **hanya hari ini** |
| Cetak / cetak ulang struk | ✅ | ✅ |
| Void transaksi | ✅ | ❌ |
| Lihat laba kotor & harga modal | ✅ | ❌ |
| Laporan & grafik | ✅ | ❌ |
| Tambah/ubah produk & harga | ✅ | ❌ |
| Penyesuaian stok | ✅ | ✅ (tercatat atas namanya) |
| Kelola kategori | ✅ | ❌ |
| Kelola pelanggan & poin | ✅ | ✅ pilih/buat, ❌ ubah aturan poin |
| Export Excel, backup, restore | ✅ | ❌ |
| Pengaturan (toko, printer, tema, pengguna) | ✅ | ❌ kecuali tema |
| Kelola pengguna & reset PIN | ✅ | ❌ |

Kasir yang menyentuh area terlarang mendapat pesan yang jelas ("Fitur ini hanya untuk Pemilik. Minta Pemilik untuk masuk.") beserta tombol "Masuk sebagai Pemilik" — bukan sekadar menu yang hilang tanpa penjelasan. Elemen yang menampilkan angka laba **disembunyikan sepenuhnya**, bukan diburamkan.

#### D. Jejak pengguna

- `sales.user_id` + `sales.user_name` (snapshot) diisi setiap penjualan.
- `stock_movements.user_id` diisi setiap penyesuaian stok.
- Void mencatat siapa yang membatalkan (`sales.voided_by_user_id`).
- Struk mencetak baris `Kasir: <nama>` (§3.3.D).
- Riwayat & Laporan mendapat filter "Kasir" (dan grafik §9 mendapat filter yang sama).

#### E. Pemulihan PIN

| Situasi | Jalan keluar |
|---|---|
| Kasir lupa PIN | Pemilik → Pengguna → pilih kasir → "Reset PIN" → buat PIN baru. |
| Pemilik lupa PIN, punya kode pemulihan | Layar Masuk → "Lupa PIN?" → masukkan kode pemulihan → buat PIN Pemilik baru. Kode lama hangus, kode baru diterbitkan. |
| Pemilik lupa PIN dan kehilangan kode | **Tidak ada jalan lain** — dinyatakan terus terang di UI saat penyiapan. Data tetap bisa diselamatkan bila pengguna punya file backup (restore di pemasangan baru mengembalikan data; PIN ikut terbawa, jadi pengguna harus punya kode pemulihannya). Konsekuensi dari janji offline tanpa akun: tidak ada pihak yang bisa mereset dari luar. |

### 8.4 Acceptance criteria

| # | Kriteria (bisa diuji) |
|---|---|
| AC-8.1 | Multi-user mati (default) → aplikasi berperilaku persis seperti v1.0, termasuk PIN global untuk Laporan/Pengaturan/void; tidak ada layar masuk. |
| AC-8.2 | Menyalakan multi-user pada aplikasi yang sudah punya PIN global → PIN itu berhasil dipakai masuk sebagai Pemilik (tidak perlu membuat PIN baru). |
| AC-8.3 | Kode pemulihan hanya ditampilkan sekali, tersimpan sebagai hash (bukan teks polos), dan berhasil dipakai mereset PIN Pemilik. |
| AC-8.4 | Kasir masuk → menu Laporan tidak dapat diakses; mencoba membuka rute laporan lewat deep link tetap ditolak (penjagaan di lapisan router, bukan hanya menyembunyikan tombol). |
| AC-8.5 | Kasir masuk → tidak ada satu pun angka laba/harga modal yang tampil di layar mana pun (uji widget: cari teks label laba di seluruh layar yang bisa diakses kasir). |
| AC-8.6 | Kasir mencoba void → ditolak dengan pesan jelas; transaksi tidak berubah. |
| AC-8.7 | Setiap penjualan menyimpan `user_id` & `user_name` yang benar; mengganti nama pengguna tidak mengubah nama pada transaksi lama. |
| AC-8.8 | Penyesuaian stok oleh kasir tercatat dengan `user_id` kasir tersebut. |
| AC-8.9 | Riwayat & Laporan bisa difilter per kasir dan angkanya cocok dengan penjumlahan manual. |
| AC-8.10 | 5 kali PIN salah → keypad terkunci 30 detik; hitungan berlanjut setelah aplikasi ditutup-buka (tidak bisa dilewati dengan restart). |
| AC-8.11 | "Ganti Kasir" saat keranjang berisi → memunculkan konfirmasi; keranjang tidak hilang diam-diam. |
| AC-8.12 | Kunci otomatis aktif → keranjang tetap utuh setelah membuka kunci. |
| AC-8.13 | Mematikan multi-user tidak menghapus `user_id` pada transaksi lama; filter kasir di riwayat masih menampilkan data historis. |
| AC-8.14 | PIN disimpan sebagai hash SHA-256 + salt **per pengguna** (reuse `PinHasher`); tidak ada PIN dalam bentuk teks polos di database maupun `shared_preferences`. |
| AC-8.15 | Dua pengguna dengan PIN yang sama persis tetap bisa masuk ke akunnya masing-masing (karena nama dipilih lebih dulu). |
| AC-8.16 | Backup v1.1 (schema 3) yang direstore membawa seluruh akun & perannya; aplikasi meminta masuk setelah restore. |

### 8.5 Dampak skema database — `schemaVersion` 2 → 3

```sql
-- BARU
users(
  id INTEGER PK AUTOINCREMENT,
  name TEXT NOT NULL,
  role TEXT NOT NULL,            -- 'owner' | 'cashier'
  pin_hash TEXT NOT NULL,
  pin_salt TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  last_login_at INTEGER NULL
)

-- PERUBAHAN pada tabel yang sudah ada
ALTER TABLE sales ADD COLUMN user_id INTEGER NULL REFERENCES users(id);
ALTER TABLE sales ADD COLUMN user_name TEXT NULL;              -- snapshot
ALTER TABLE sales ADD COLUMN voided_by_user_id INTEGER NULL REFERENCES users(id);
ALTER TABLE stock_movements ADD COLUMN user_id INTEGER NULL REFERENCES users(id);

-- INDEX
CREATE UNIQUE INDEX idx_users_name_nocase ON users(name COLLATE NOCASE) WHERE is_active = 1;
CREATE INDEX idx_sales_user ON sales(user_id, created_at);
```

Kunci `settings` tambahan: `multi_user_enabled` (`0`/`1`, default `0`), `auto_lock_minutes` (`0` = mati), `recovery_code_hash`, `recovery_code_salt`.

Kunci lama `pin_hash`/`pin_salt` **dipertahankan** untuk mode single-user; saat multi-user dinyalakan, nilainya disalin menjadi PIN akun Pemilik dan tetap dibiarkan agar mematikan multi-user bisa kembali mulus.

Sesi aktif (siapa yang sedang masuk) disimpan di `shared_preferences` (`active_user_id`) — bukan di database, karena itu keadaan perangkat, bukan data toko (alasan yang sama dengan K-5.2).

### 8.6 Dampak UI

- **Layar Masuk** (rute baru, di luar shell navigasi): kartu pengguna besar (≥64dp, avatar inisial berlatar `AppTone.primary`), lalu keypad PIN yang me-*reuse* `pin_keypad.dart` & `pin_entry_screen.dart`. Judul "Siapa yang bertugas?".
- **Kartu "Pengguna & Akses"** di Pengaturan memakai `SettingsCard`, pola sama dengan `pin_section.dart`.
- **Penanda pengguna aktif** di AppBar layar Kasir: chip kecil berisi inisial + nama pendek, tap → "Ganti Kasir". Ini satu-satunya elemen tambahan di layar kasir, dan tidak boleh lebih menonjol daripada CTA "Bayar".
- **Peran** ditampilkan sebagai `AppPill`: `AppTone.primary` "Pemilik", `AppTone.neutral` "Kasir".
- **Penolakan akses** memakai pola `EmptyState` (ikon gembok + judul + kalimat pengarah + tombol "Masuk sebagai Pemilik") — bukan dialog error telanjang.
- **Kode pemulihan** ditampilkan dengan tipografi besar bertabular (`AppTextStyles.numeric`), latar `AppTone.warning`, dan tombol Salin/Bagikan.
- Penjagaan izin dilakukan di **lapisan router** (`redirect` go_router) sekaligus di UI, agar rute tidak bisa diakses lewat jalur lain.

### 8.7 Keputusan & risiko teknis

- **K-8.1** Hanya **dua peran tetap** (Pemilik, Kasir) dengan izin yang tidak bisa dikustomisasi. Matriks izin bebas akan menjadi layar konfigurasi rumit untuk pengguna yang menurut [prd.md §2](prd.md) "gaptek ringan".
- **K-8.2** Masuk dengan **pilih nama → PIN**, bukan PIN saja (menghindari tabrakan PIN & ambiguitas pencatatan).
- **K-8.3** Reuse `PinHasher` (SHA-256 + salt) yang sudah ada; salt disimpan **per pengguna**, bukan satu salt global.
- **K-8.4** **Kode pemulihan offline** wajib ada. Tanpa itu, "lupa PIN" menjadi kehilangan data total — konsekuensi tak dapat diterima dari aplikasi tanpa akun online. Kode disimpan sebagai hash, ditampilkan sekali.
- **K-8.5** Multi-user **mati secara default**, dan seluruh perilaku v1.0 dipertahankan saat mati.
- **K-8.6** `sales.user_name` disimpan sebagai snapshot, sejalan dengan K-7.1 dan pola `sale_items.product_name`.
- **K-8.7** Tidak ada masuk dengan sidik jari/wajah di v1.1 (butuh dependency `local_auth` + penanganan fallback; ditunda, bukan ditolak selamanya).

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Pemilik terkunci dari datanya sendiri | Kehilangan data total, kemarahan wajar | K-8.4 kode pemulihan + peringatan tegas saat penyiapan + centang wajib "saya sudah mencatat" + dorongan backup. |
| Izin hanya disembunyikan di UI, bisa ditembus lewat rute | Karyawan melihat laba/menghapus transaksi | AC-8.4: penjagaan di `redirect` router, diuji khusus. |
| Kasir kesal karena terlalu banyak yang terkunci | Fitur dimatikan lagi | Kasir tetap punya akses penuh ke pekerjaan hariannya (jual, hutang, pelunasan, stok, cetak, riwayat hari ini). |
| Ganti kasir menghilangkan keranjang berjalan | Transaksi hilang di depan pembeli | AC-8.11 & AC-8.12: keranjang dipertahankan; konfirmasi eksplisit. |
| Migrasi 2→3 pada database besar | Update terasa menggantung | `ALTER TABLE ADD COLUMN` di SQLite bersifat O(1) (tidak menulis ulang tabel); pembuatan index dijalankan sekali dengan indikator progres bila > 1 detik. |

### 8.8 TIDAK termasuk

- Peran & izin kustom, atau peran ketiga (mis. "supervisor").
- Buka/tutup kas per shift, hitung fisik uang laci, selisih kas (rekonsiliasi shift).
- Komisi/target penjualan per kasir.
- Absensi / jam kerja karyawan.
- Masuk dengan sidik jari atau wajah.
- Akun online, pemulihan PIN lewat email/SMS, atau manajemen pengguna jarak jauh.
- Log audit menyeluruh untuk setiap aksi (yang dicatat hanya penjualan, void, dan pergerakan stok).
- Preferensi per pengguna (tema, tata letak) — tema tetap satu per perangkat (§5.9).

---

## 9. Fitur Tier 2 — Grafik Penjualan di Dashboard

### 9.1 Latar & masalah pengguna

Laporan v1.0 menjawab "**berapa**": omzet hari ini, jumlah transaksi, laba kotor, produk terlaris. Yang belum terjawab adalah "**bagaimana perkembangannya**" dan "**kapan**":

- "Minggu ini lebih ramai atau lebih sepi dari minggu lalu?" — harus membuka rentang dua kali dan membandingkan di kepala.
- "Jam berapa warung saya paling ramai?" — tidak bisa dijawab sama sekali, padahal ini menentukan kapan harus siaga dan kapan bisa belanja ulang.
- "Apakah orang mulai bayar QRIS?" — tersedia sebagai angka, tapi proporsinya sulit dirasakan.

Deret angka tidak menunjukkan tren; batang menunjukkannya dalam sekali lihat. Data untuk semua ini **sudah ada** di `sales` — yang kurang hanya agregasi dan penyajiannya.

### 9.2 User stories

1. Sebagai pemilik, saya bisa melihat grafik batang omzet harian untuk rentang yang saya pilih, agar tahu tren naik/turun.
2. Sebagai pemilik, saya bisa melihat perbandingan singkat dengan periode sebelumnya ("+12% dari 7 hari sebelumnya").
3. Sebagai pemilik, saya bisa melihat jam-jam paling ramai, agar bisa mengatur kesiapan dan waktu belanja.
4. Sebagai pemilik, saya bisa melihat proporsi metode pembayaran (tunai / non-tunai / hutang) dalam satu batang bertumpuk.
5. Sebagai pemilik, saya bisa mengalihkan grafik tren antara **Omzet** dan **Laba**, karena keduanya bisa bergerak berlawanan.
6. Sebagai pemilik, saya bisa menyentuh satu batang untuk melihat angka persisnya, bukan menebak dari tinggi batang.

### 9.3 Perilaku & alur detail

Grafik hidup di dalam **tab Laporan** yang sudah ada, di bawah kartu ringkasan, dan mengikuti pemilih rentang tanggal yang sudah ada (hari ini, kemarin, 7 hari, bulan ini, custom) — **tanpa pemilih rentang baru**.

#### A. Grafik 1 — Tren penjualan (utama)

- Grafik batang vertikal. Ukuran ember (bucket) otomatis mengikuti panjang rentang:

| Panjang rentang | Ember | Jumlah batang |
|---|---|---|
| 1 hari | per jam | 24 |
| 2–62 hari | per hari | 2–62 |
| > 62 hari | per bulan | ≤ ~24 |

- Peralih **Omzet / Laba** di atas grafik (`SegmentedButton`). Laba hanya tampil bila pengguna berhak melihatnya (§8).
- Di bawah judul: perbandingan dengan periode sebelumnya yang sama panjang — "Rp4.320.000 · +12% dari 7 hari sebelumnya", berwarna `AppTone.success`/`AppTone.danger`.
- Tap batang → tooltip/kartu kecil: tanggal, omzet, jumlah transaksi. Tap dua kali atau tombol "Lihat transaksi" → membuka Riwayat yang sudah difilter ke rentang itu.
- Transaksi `voided` **selalu dikecualikan**, konsisten dengan laporan v1.0.

#### B. Grafik 2 — Jam ramai

- Batang per jam 0–23, diagregasi atas seluruh rentang terpilih (bukan hanya satu hari).
- Batang tertinggi diberi warna `primary`, sisanya `primary100`/`primary200` — satu titik fokus per grafik.
- Jam tanpa transaksi tetap ditampilkan sebagai batang nol (agar bentuk hari terbaca utuh).
- Di bawahnya kalimat ringkas: "Paling ramai: 17.00–18.00 (Rp1.240.000 dari 38 transaksi)".

#### C. Grafik 3 — Komposisi metode bayar

- Satu **batang horizontal bertumpuk**: Tunai / Non-tunai / Hutang, dengan legenda berlabel teks + nominal + persentase.
- Warna memakai alias domain yang sudah ada: `tunai` (hijau), `nonTunai` (biru), `hutang` (aksen).

#### D. Grafik 4 — Produk terlaris (opsional, reuse data)

- Batang horizontal 5 teratas memakai data `getTopProducts` yang sudah ada — menggantikan/melengkapi daftar teks yang sekarang, tanpa query baru.

#### E. Keadaan khusus

- **Belum ada transaksi pada rentang** → `EmptyState` bergaya sistem ("Belum ada penjualan pada rentang ini / Pilih rentang lain atau mulai transaksi pertama hari ini"), bukan grafik kosong.
- **Hanya satu batang** → tetap ditampilkan, dengan sumbu Y menyesuaikan.
- **Nilai nol semua** → sumbu Y memakai skala minimal agar grafik tidak terlihat rusak.

### 9.4 Acceptance criteria

| # | Kriteria (bisa diuji) |
|---|---|
| AC-9.1 | Jumlah batang mengikuti aturan ember di §9.3.A untuk rentang 1 hari, 7 hari, 90 hari, dan 400 hari. |
| AC-9.2 | Jumlah seluruh batang pada grafik tren **sama persis** dengan angka omzet di kartu ringkasan untuk rentang yang sama (uji: bandingkan hasil dua query). |
| AC-9.3 | Transaksi `voided` tidak menyumbang tinggi batang mana pun. |
| AC-9.4 | Pengelompokan hari mengikuti **zona waktu perangkat**: transaksi pukul 23.30 WIB masuk ke hari itu, bukan hari berikutnya (uji dengan data pada batas tengah malam untuk WIB/WITA/WIT). |
| AC-9.5 | Grafik tren dengan 100.000 transaksi di database: query + render selesai < 300 ms (agregasi di SQL, bukan di Dart). |
| AC-9.6 | Peralih Omzet/Laba mengubah data grafik tanpa memuat ulang layar. |
| AC-9.7 | Perbandingan periode sebelumnya benar untuk rentang 7 hari (dibandingkan dengan 7 hari tepat sebelumnya) dan menampilkan tanda +/− yang benar. |
| AC-9.8 | Tap batang menampilkan angka persis batang tersebut; area sentuh setiap batang ≥ 48dp lebarnya (bila batang lebih sempit, area sentuhnya diperlebar tanpa mengubah gambar). |
| AC-9.9 | Grafik terbaca di mode gelap: seluruh warna diambil dari `context.palette`, tidak ada hex tetap (uji widget di kedua tema). |
| AC-9.10 | Setiap deret pada komposisi metode bayar punya **label teks**, tidak dibedakan hanya oleh warna. |
| AC-9.11 | Rentang tanpa transaksi menampilkan `EmptyState`, bukan grafik kosong atau angka `NaN`. |
| AC-9.12 | Grafik tampil benar pada HP 5 inci (batang tidak berdesakan; label sumbu X dijarangkan otomatis bila tidak muat) dan pada tablet landscape. |
| AC-9.13 | Ukuran APK tidak bertambah lebih dari 1 MB akibat fitur ini. |
| AC-9.14 | (Bila §8 aktif) filter "Kasir" memengaruhi seluruh grafik secara konsisten dengan kartu ringkasan. |

### 9.5 Dampak skema database

**Tidak ada tabel atau kolom baru.** Yang dibutuhkan hanya query agregasi baru dan satu index.

Method baru pada `ReportRepository` (seluruhnya agregasi SQL — wajib, sesuai aturan yang sudah ditegakkan di kontrak repository M4):

```dart
enum SeriesBucket { hour, day, month }

Future<List<SalesPoint>> getSalesSeries({
  required DateTime start,
  required DateTime end,
  required SeriesBucket bucket,
  int? userId,                      // §8; null = semua kasir
});

Future<List<HourlyPoint>> getHourlyDistribution({
  required DateTime start,
  required DateTime end,
  int? userId,
});
```

Catatan SQL penting: `sales.created_at` disimpan sebagai **epoch millis UTC** (keputusan M0), sehingga pengelompokan harus mengonversi ke waktu lokal secara eksplisit:

```sql
strftime('%Y-%m-%d', created_at / 1000, 'unixepoch', 'localtime')
```

Tanpa `'localtime'`, batas hari akan meleset dari jam perangkat (AC-9.4). Indonesia tidak menerapkan DST, sehingga konversi ini aman sepanjang tahun.

Index tambahan (dibuat pada migrasi, `CREATE INDEX IF NOT EXISTS` agar idempoten):

```sql
CREATE INDEX IF NOT EXISTS idx_sales_status_created ON sales(status, created_at);
```

Index ini menggantikan pemakaian terpisah `idx_sales_status` + `idx_sales_created_at` pada query grafik yang selalu memfilter status **dan** rentang tanggal sekaligus.

### 9.6 Dampak UI

- Grafik ditempatkan di tab **Laporan** yang sudah ada, di bawah `summary_card.dart`, sebagai `AppCard(elevated: true)` per grafik dengan `SectionHeader` di atasnya.
- **Judul kartu kecil, angka besar** — konsisten dengan prinsip "angka lebih penting dari labelnya": nilai total periode tampil dengan `AppTextStyles.moneyLarge` di atas grafik, grafiknya sendiri adalah pendukung.
- Batang memakai `radiusXs` di ujung atas, jarak antar batang `spaceXs`, tinggi area grafik tetap (mis. 160dp) agar tata letak tidak melompat saat data berubah.
- Sumbu Y hanya menampilkan **maksimum dan nol** (dua label) untuk mengurangi kekacauan; nilai persis diperoleh lewat tap.
- Label sumbu X memakai `bodySmall`/`inkSecondary`, dijarangkan otomatis (setiap 2/3/7 batang) bila tidak muat.
- Animasi masuk `AppDurations.fast` (200 ms) dengan `Curves.easeOutCubic`; tidak ada animasi > 500 ms.
- Seluruh warna dari `context.palette` (§5). Warna metode bayar memakai alias domain `tunai`/`nonTunai`/`hutang`.

### 9.7 Keputusan & risiko teknis

- **K-9.1 — Tidak menambah dependency grafik (mis. `fl_chart`).** Grafik yang dibutuhkan hanya **batang** (vertikal, horizontal, bertumpuk); semuanya bisa dibangun dengan `Flex`/`CustomPainter` dalam widget bersama `core/widgets/app_bar_chart.dart` (~200–300 baris). Alasannya konkret dan spesifik untuk proyek ini:
  1. Proyek ini sudah dua kali tersandung dependency pihak ketiga (bentrok `win32` pada `file_picker`/`share_plus` di M0; kegagalan build release karena `namespace` pada `flutter_native_splash` di M6). Setiap dependency baru adalah risiko build nyata, bukan teoretis.
  2. Anggaran APK < 40 MB dan cold start < 3 detik.
  3. Pustaka grafik umum membawa gaya visualnya sendiri yang harus dilawan agar cocok dengan "Kertas & Daun" — pekerjaan penyesuaiannya sebanding dengan menulis batang sendiri.
  4. Widget sendiri otomatis sadar tema (§5) dan sadar target sentuh 48dp.

  **Rencana cadangan:** bila kebutuhan berkembang ke grafik garis dengan interpolasi, zoom/pan, atau sumbu ganda, `fl_chart` menjadi kandidat pertama untuk dievaluasi ulang — dengan syarat lolos uji `flutter build apk --release` di commit terpisah sebelum dipakai.
- **K-9.2 — Tidak ada pie/donut chart.** Proporsi disajikan sebagai batang bertumpuk. Mata manusia buruk membandingkan sudut, dan potongan kecil (mis. non-tunai 4%) menjadi tak terbaca beserta labelnya di layar 5 inci.
- **K-9.3 — Grafik selalu mengikuti pemilih rentang yang sudah ada**, tidak punya pemilih sendiri. Dua pemilih rentang di satu layar adalah sumber kebingungan.
- **K-9.4 — Maksimum ~90 batang** dalam satu grafik. Di atas itu, ember dinaikkan (hari → bulan). Batang selebar 2px tidak menyampaikan apa pun dan tidak bisa disentuh.
- **K-9.5 — Semua agregasi di SQL**, mengikuti aturan yang sudah ditegakkan kontrak `ReportRepository` sejak M4.

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Salah zona waktu pada pengelompokan hari | Angka grafik beda dengan kartu ringkasan → kepercayaan hilang | AC-9.2 & AC-9.4 dengan uji khusus batas tengah malam untuk WIB/WITA/WIT. |
| Query lambat pada 100k transaksi | Tab Laporan terasa menggantung | Index `(status, created_at)`, agregasi SQL, uji beban dengan data dummy besar (pola yang sudah dipakai M4). |
| Grafik buatan sendiri jelek/tidak akurat | Malu di depan pengguna | Cakupan sengaja dibatasi pada batang; uji widget yang memeriksa tinggi batang proporsional terhadap nilai; ulasan visual di HP kecil & tablet. |
| Grafik penuh sesak di HP 5 inci | Tidak terbaca | AC-9.12: penjarangan label otomatis, tinggi area tetap, maksimum 90 batang. |
| Laba bocor ke kasir lewat grafik | Melanggar §8 | Peralih "Laba" hanya dirender untuk Pemilik; diuji di AC-8.5. |

### 9.8 TIDAK termasuk

- Grafik pie/donut.
- Grafik garis dengan kurva halus, zoom, pan, atau *crosshair*.
- Prakiraan/proyeksi penjualan, deteksi anomali, atau saran otomatis.
- Membandingkan dua rentang kustom berdampingan (yang ada hanya perbandingan dengan periode sebelumnya yang sama panjang).
- Export grafik sebagai gambar atau menyisipkan grafik ke file Excel.
- Grafik pergerakan stok, grafik pelanggan, atau grafik poin.
- Widget/grafik di layar Kasir (layar kasir tetap bersih — prinsip "cepat > cantik").
- Dashboard yang bisa disusun sendiri oleh pengguna (drag & drop kartu).

---

## 10. Ringkasan Dampak Database & Rencana Migrasi

| Tahap | Fitur | `schemaVersion` | Perubahan |
|---|---|---|---|
| Sekarang (v1.0) | — | **1** | 7 tabel: categories, products, sales, sale_items, stock_movements, held_carts, settings |
| Tier 1 | §3 Printer, §4 Import, §5 Mode gelap, §6 Lisensi | **1** (tetap) | Tidak ada. Hanya key baru di `settings` & `shared_preferences`. **§6 sama sekali tidak menulis ke database** — statusnya hanya di `shared_preferences` supaya tidak pernah ikut backup/restore (K-6.1). |
| Tier 2a | §7 Pelanggan | 1 → **2** | +`customers`, +`customer_point_entries`, +`sales.customer_id`, 3 index, **backfill dari `sales.customer_name`** |
| Tier 2b | §8 Multi-user | 2 → **3** | +`users`, +`sales.user_id`/`user_name`/`voided_by_user_id`, +`stock_movements.user_id`, 2 index |
| Tier 2c | §9 Grafik | 3 (tetap) | +index `idx_sales_status_created` (idempoten) |

### Aturan migrasi yang mengikat

| # | Aturan |
|---|---|
| AC-10.1 | Setiap kenaikan `schemaVersion` wajib punya uji migrasi memakai *snapshot* database versi sebelumnya (bukan hanya `createAll()` dari nol), dengan data nyata secukupnya. |
| AC-10.2 | `BackupService.validateBackupFile` wajib **membandingkan** `PRAGMA user_version` file backup dengan `schemaVersion` aplikasi. Bila file lebih baru → tolak dengan pesan "File backup berasal dari versi aplikasi yang lebih baru. Perbarui aplikasi ini terlebih dahulu." Saat ini nilai itu hanya dibaca tanpa dibandingkan — celah yang harus ditutup **sebelum** migrasi pertama dirilis. |
| AC-10.3 | Backup v1.0 (schema 1) wajib tetap bisa direstore di aplikasi v1.1 mana pun dan termigrasi otomatis tanpa kehilangan satu baris pun. |
| AC-10.4 | Migrasi tidak boleh destruktif: tidak ada `DROP COLUMN`, tidak ada penulisan ulang tabel, tidak ada penghapusan data historis. |
| AC-10.5 | Seluruh langkah migrasi berjalan dalam satu transaksi; kegagalan mengembalikan database ke keadaan semula dan menampilkan pesan Bahasa Indonesia yang jelas. |
| AC-10.6 | Sebelum merilis versi yang menaikkan `schemaVersion`, aplikasi menampilkan pengingat backup bila backup terakhir > 7 hari (memanfaatkan `last_backup_at` yang sudah ada). |

---

## 11. Metrik Keberhasilan

### 11.1 Tier 1

| Metrik | Target |
|---|---|
| Keberhasilan cetak percobaan pertama | ≥ 90% pada 3 model printer thermal 58mm berbeda yang diuji |
| Waktu tap "Cetak" → kertas mulai keluar | ≤ 5 detik (printer bonded) |
| Kegagalan cetak yang menyebabkan transaksi hilang/rusak | **0 kasus** |
| Impor 500 produk dari file valid | ≤ 20 detik, 0 baris salah tafsir |
| Impor yang menghasilkan data setengah masuk | **0 kasus** (atomik) |
| Baris bermasalah yang tidak dilaporkan ke pengguna | **0** |
| Pengisian katalog awal warung 300 produk | dari > 3 jam (manual) menjadi ≤ 15 menit |
| Layar dengan teks kontras < 4.5:1 di mode gelap | **0** (dibuktikan uji otomatis, bukan penilaian mata) |
| Layar yang masih "putih" saat mode gelap | **0** |
| Struk yang di-share tetap berlatar putih | 100% |
| **Aktivasi lisensi sejak kode diterima sampai aplikasi terbuka** | ≤ **30 detik** lewat pindai QR atau tempel; ≤ **2 menit** bila kode diketik manual |
| **Lisensi sah yang ditolak aplikasi** (false negative) | **0 kasus** |
| Kode salah ketik yang **diterima** aplikasi (false positive) | **0 kasus** |
| Trial yang ter-reset dengan uninstall–reinstall | **0 kasus** |
| Data pengguna yang hilang/terkunci permanen akibat lisensi berakhir | **0 baris** — export & backup selalu bisa diakses |
| Transaksi yang gagal tersimpan karena gerbang lisensi menutup di tengah alur | **0 kasus** |
| Waktu verifikasi kode di HP kelas menengah | < 1 detik |
| Pertambahan ukuran APK akibat sistem lisensi | < 1 MB |
| Kunci privat penerbit yang ter-commit ke repositori | **0** (diperiksa di checklist rilis) |
| Ukuran APK release | tetap < 40 MB |
| Cold start | tetap < 3 detik |
| Regresi pada alur v1.0 | **0** (seluruh test M0–M6 lulus tanpa diubah) |

### 11.2 Tier 2

| Metrik | Target |
|---|---|
| Nama pelanggan duplikat akibat typo setelah migrasi | berkurang ≥ 90% pada data uji nyata |
| Selisih total hutang sebelum vs sesudah migrasi | **Rp0** |
| Selisih saldo poin vs jumlah buku besar poin | **0 poin**, pada seluruh skenario uji |
| Tap tambahan pada alur kasir tanpa memilih pelanggan | **0** |
| Kebocoran angka laba ke akun Kasir | **0** (diuji per peran, termasuk lewat rute langsung) |
| Transaksi tanpa `user_id` saat multi-user aktif | **0** |
| Pemilik yang terkunci permanen tanpa jalan pemulihan | **0** (kode pemulihan wajib dicatat saat penyiapan) |
| Waktu query + render grafik @ 100.000 transaksi | < 300 ms |
| Selisih total grafik vs kartu ringkasan | **Rp0** |
| Dependency baru untuk grafik | **0 package** |
| Pertambahan ukuran APK akibat grafik | < 1 MB |

---

## 12. Non-Fitur yang Tetap Berlaku

### 12.1 Diwarisi dari [prd.md §3.2](prd.md) — tetap DILARANG

- ❌ Sinkronisasi cloud / multi-perangkat realtime
- ❌ Login / akun online
- ❌ Integrasi pembayaran online (QRIS dinamis, e-wallet API)
- ❌ Multi-toko / multi-cabang
- ❌ Pajak kompleks (PPN dsb) — cukup diskon sederhana
- ❌ Manajemen supplier & purchase order lengkap

Ditegaskan ulang karena fitur v1.1 menggodanya:
- Multi-user (§8) **bukan** akun online dan **bukan** multi-toko — semua pengguna berbagi satu database di satu perangkat.
- Poin pelanggan (§7) **bukan** program loyalitas cloud; tidak ada pengiriman notifikasi ke pelanggan.
- Cetak thermal (§3) **bukan** integrasi pembayaran; QR yang dicetak hanyalah gambar statis milik toko.
- **Aktivasi lisensi (§6) bukan login dan bukan akun online.** Tidak ada identitas, tidak ada kata sandi, tidak ada server yang dihubungi, tidak ada data yang dikirim. Yang ada hanyalah satu kode ter-tanda-tangan yang diverifikasi di dalam perangkat. Larangan "login/akun online" tetap berlaku penuh, dan §6.8 menegaskan batasnya.

### 12.2 Non-fitur baru yang ditetapkan dokumen ini

- ❌ Printer WiFi/LAN/USB, cash drawer, printer label
- ❌ Impor CSV / Google Sheets / sumber online mana pun
- ❌ Impor transaksi, pelanggan, atau pengaturan (hanya produk)
- ❌ Penghapusan produk lewat impor & "batalkan impor" (undo)
- ❌ Mode AMOLED hitam pekat, tema kustom, penjadwalan tema otomatis
- ❌ Tingkatan membership, kupon, promo otomatis, poin kedaluwarsa
- ❌ Blast SMS/WhatsApp/email ke pelanggan
- ❌ Plafon hutang per pelanggan
- ❌ Peran & izin kustom, rekonsiliasi shift/laci kas, absensi karyawan
- ❌ Masuk dengan sidik jari/wajah
- ❌ Pie/donut chart, prakiraan penjualan, dashboard yang bisa disusun sendiri
- ❌ Export grafik sebagai gambar
- ❌ Dependency baru untuk grafik
- ❌ Server/backend aktivasi, akun pembeli, dasbor lisensi daring, telemetri pemakaian
- ❌ Pembayaran dalam aplikasi (IAP), langganan yang menagih sendiri, perpanjangan otomatis
- ❌ Trial otomatis tanpa kode, transfer lisensi antar perangkat otomatis, satu lisensi untuk banyak perangkat
- ❌ Lisensi per fitur (paket murah/mahal dengan fitur berbeda)
- ❌ Proteksi anti-bongkar di luar R8: tanpa deteksi root, tanpa pemeriksaan tanda tangan APK saat berjalan, tanpa pencabutan lisensi jarak jauh

---

## 13. Asumsi & Batasan (v1.1)

Semua asumsi [prd.md §8](prd.md) tetap berlaku. Tambahan:

1. **Satu perangkat = satu toko = satu database** tetap berlaku, termasuk setelah multi-user. Multi-user memisahkan **orang**, bukan data.
2. **Printer** adalah perangkat keras milik pengguna; aplikasi tidak menjamin kompatibilitas dengan setiap merek yang beredar. Dukungan resmi terbatas pada printer ESC/POS Bluetooth 58mm.
3. **Poin adalah kesepakatan antara pemilik dan pembelinya**; aplikasi hanya mencatat. Tidak ada nilai uang yang dijamin dan tidak ada kewajiban hukum yang ditanggung aplikasi.
4. **Tidak ada pihak yang bisa memulihkan PIN dari luar.** Ini konsekuensi langsung dari janji "tanpa akun, tanpa server" dan harus dikomunikasikan terus terang di UI.
5. **Waktu tetap mengikuti jam perangkat.** Mengubah jam perangkat mundur bisa membuat urutan grafik dan nomor invoice tampak aneh; tidak ada validasi server (dan tidak akan pernah ada). Khusus untuk masa berlaku lisensi, jam perangkat **tidak dipercaya sendirian** — dipakai nilai tertinggi yang pernah dilihat (§6.3.G) — tapi mekanisme itu hanya mencegah jam **mundur**, bukan jam yang salah sejak awal.
6. **Zona waktu** yang dipakai pengelompokan laporan & grafik adalah zona waktu perangkat saat query dijalankan. Memindahkan perangkat antar zona waktu Indonesia dapat menggeser batas hari pada data lama.
7. **iOS** tetap menyusul; seluruh fitur v1.1 dispesifikasikan untuk Android lebih dulu. Fitur printer kemungkinan besar butuh penyesuaian tersendiri di iOS (BLE saja, tanpa Bluetooth Klasik), dan sistem lisensi butuh sumber kode perangkat tersendiri (`identifierForVendor`, yang sifatnya **tidak** sama dengan SSAID).
8. **Foto produk** masih di luar cakupan (ditunda sejak M1) dan tidak dihidupkan oleh dokumen ini.
9. **Lisensi terikat pada satu perangkat fisik** lewat SSAID. Factory reset, ganti HP, atau perangkat dengan SSAID cacat menghasilkan kode perangkat baru dan **membutuhkan kode aktivasi baru dari penjual**. Aplikasi tidak punya mekanisme transfer; pemberian kode pengganti adalah **kebijakan komersial penjual**, dibantu catatan penerbitan `lisensi-terbit.csv` (§6.3.B).
10. **Sistem lisensi ini adalah deterrence yang wajar, bukan DRM.** Proteksi sisi klien pada Android bisa dibongkar pembajak yang gigih lewat *patching* APK; tidak ada klaim sebaliknya di mana pun. Sasarannya adalah pasar UMKM yang membeli karena aplikasinya berguna dan penjualnya bisa dihubungi — bukan memenangkan perlombaan melawan pembongkar (§6.7.3).
11. **Kunci privat penerbit adalah aset paling berharga proyek ini di luar kode sumber.** Kehilangannya berarti tidak bisa menerbitkan kode baru (kode lama tetap sah); kebocorannya berarti *keygen* dan memaksa rotasi kunci + rilis baru. Tata kelolanya wajib mengikuti §6.7.2 tanpa pengecualian.
12. **Satu perangkat hanya bisa memakai satu lisensi aktif.** Memasukkan kode baru selalu menimpa yang lama (dipakai untuk perpanjangan dan peningkatan dari trial ke berbayar).
