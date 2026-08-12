# Fondasi Desain UI — Kasir Warung

**Design language: "Kertas & Daun"**
Versi 1.1 · 12 Agustus 2026 · Status: **AKTIF — sumber kebenaran desain**

> Dokumen ini WAJIB dibaca oleh semua agent yang menyentuh UI (layar POS,
> Produk, Riwayat, Laporan, Pengaturan). Kalau ada pertanyaan desain, jawabannya
> ada di sini. Kalau tidak ada di sini, ikuti prinsip di §1 dan konsisten dengan
> layar lain — jangan mengarang sistem baru.

---

## 1. Filosofi & Arah Desain

### Masalah yang diperbaiki
Versi sebelumnya adalah Material 3 default: seed color hijau yang di-generate
otomatis, AppBar blok hijau, kartu abu-abu, tipografi Roboto bawaan. Hasilnya
fungsional tapi tanpa identitas — bisa jadi aplikasi apa saja.

### Arah baru
Warung Indonesia itu **hangat, personal, dan cepat**. Tapi ini juga alat kerja
yang memegang uang — harus terasa **akurat dan bisa dipercaya**. Design
language "Kertas & Daun" menjahit keduanya:

| Unsur | Referensi dunia nyata | Wujud di UI |
|---|---|---|
| **Kertas** | Kertas struk, buku catatan warung, karung beras | Kanvas krem hangat `#F5F2EA`, kartu putih hangat, garis tipis alih-alih shadow tebal |
| **Daun** | Daun pisang, pandan — juga warna "uang" & "lunas" | Hijau tua pekat `#0D5D42` untuk semua aksi & identitas |
| **Gula aren** | Gula merah, kunyit | Amber `#D97E27` untuk penanda yang butuh perhatian (hutang, ditahan) |

### Lima prinsip (urutan prioritas kalau bertabrakan)

1. **Angka lebih penting dari labelnya.** Di aplikasi kasir yang dibaca adalah
   nominal. Nilai selalu lebih besar & lebih tebal daripada label. JANGAN
   pernah membuat "Omzet" lebih menonjol daripada "Rp1.250.000".
2. **Cepat > cantik.** Kasir sedang dikejar antrian. Target sentuh besar
   (≥48dp, CTA 52–60dp), aksi utama di zona jempol (sepertiga bawah layar),
   informasi terbuka langsung — bukan disembunyikan di balik tap tambahan.
3. **Tenang, dengan satu titik fokus.** 60% kanvas netral, 30% tinta/struktur,
   10% warna brand. Satu layar = satu aksi utama yang jelas menonjol.
4. **Kedalaman dari cahaya lembut, bukan dari garis tebal.** Shadow selalu
   halus & bernada cokelat hangat (bukan abu/hitam), radius besar dan konsisten.
5. **Layar kosong & error tetap mengarahkan.** Tidak ada "Tidak ada data".
   Selalu: ikon + judul + kalimat pengarah + tombol aksi.

### Momen puncak (peak-end rule)
Momen puncak aplikasi ini adalah **transaksi selesai**: total & kembalian
tampil sebesar mungkin (`AppMoneySize.hero`), tanda centang hijau, dan langkah
berikutnya (struk / transaksi baru) langsung tersedia. Layar itu boleh — dan
harus — lebih ekspresif daripada layar lain. Layar lain jangan mencuri
perhatian dari momen ini.

---

## 2. Palet Warna

File: `lib/core/constants/app_colors.dart`

### 2.1 Brand — Hijau Daun

| Token | Hex | Dipakai kapan |
|---|---|---|
| `AppColors.primary` | `#0D5D42` | Tombol utama, ikon aktif, nominal penting, indikator terpilih. Kontras 7,9:1 di atas putih → aman untuk teks. |
| `AppColors.primaryDark` | `#0A4A35` | State pressed/hover tombol utama. |
| `AppColors.primaryDeep` | `#063124` | Permukaan gelap brand (panel total, header khusus). |
| `AppColors.primary200` | `#9AC7AE` | Border kartu terpilih, teks aksi di atas latar gelap. |
| `AppColors.primary100` | `#CCE3D8` | Track progress, border tonal. |
| `AppColors.primary50` | `#E9F2ED` | Latar lembut: chip aktif, ikon tonal, kapsul nav aktif. Alias lama: `primaryLight`. |

### 2.2 Aksen — Gula Aren

| Token | Hex | Dipakai kapan |
|---|---|---|
| `AppColors.accent` | `#D97E27` | Isi/fill penanda (badge jumlah, highlight). **Kontras 3,0:1 di atas putih — DILARANG jadi warna teks di atas latar terang.** Teks DI ATAS warna ini harus `AppColors.ink`, bukan putih. |
| `AppColors.accentText` | `#8A4A08` | Versi teks/ikon aksen di atas latar terang (kontras 6,8:1). |
| `AppColors.accent100` | `#F6DDB9` | Border tonal aksen. |
| `AppColors.accent50` | `#FCF0DF` | Latar lembut aksen (badge "Hutang", banner hangat). |

> Alias lama `AppColors.secondary` = `accent`. Kode lama tetap jalan, tapi
> tulis `accent`/`accentText` untuk kode baru.

**Pakai aksen dengan hemat: maksimal satu elemen aksen menonjol per layar.**
Kalau semuanya oranye, tidak ada yang penting.

### 2.3 Netral — Kertas & Tinta

| Token | Hex | Dipakai kapan |
|---|---|---|
| `AppColors.background` | `#F5F2EA` | Kanvas Scaffold & AppBar. Sudah jadi default tema. |
| `AppColors.surface` | `#FFFDFA` | Kartu, sheet, dialog, dock nav, field input. |
| `AppColors.surfaceAlt` | `#FAF7F0` | Sub-panel di dalam kartu, baris zebra, field non-aktif. |
| `AppColors.surfaceDark` | `#1F2723` | SnackBar, tooltip, panel gelap. |
| `AppColors.ink` | `#191D1A` | Teks utama & angka. Alias lama: `textPrimary`. |
| `AppColors.inkSecondary` | `#5A625C` | Label, keterangan, ikon netral. Alias lama: `textSecondary`. |
| `AppColors.inkTertiary` | `#8A928B` | **Hanya** hint/placeholder & teks ≥18px. Kontras ~3:1 — jangan untuk teks kecil yang penting. |
| `AppColors.onDark` | `#F6F8F5` | Teks/ikon di atas `primary` atau `surfaceDark`. |
| `AppColors.border` | `#E6E0D4` | Garis kartu & divider (default). |
| `AppColors.borderStrong` | `#D5CDBD` | Outline field input & tombol outlined. |

### 2.4 Semantik — trio per status

Setiap status punya tiga warna: **isi/ikon**, **latar lembut**, **teks**.

| Status | isi | soft (latar) | text (teks) | Dipakai untuk |
|---|---|---|---|---|
| success | `#14764C` | `#E6F3EC` | `#0B5233` | Lunas, stok aman, laba positif, tunai |
| warning | `#8A5B08` | `#FBF0D8` | `#6E4806` | Stok menipis, transaksi ditahan |
| danger | `#B3261E` | `#FBE9E7` | `#8C1D18` | Batal/void, stok habis, aksi merusak |
| info | `#175F8F` | `#E5EFF6` | `#124D74` | Info netral, pembayaran non-tunai (QRIS/transfer) |

**Alias domain (pakai ini supaya konsisten lintas layar):**
`AppColors.tunai` (hijau) · `AppColors.nonTunai` (biru) · `AppColors.hutang` (amber).

### 2.5 `AppTone` — cara memilih warna yang benar

Jangan memilih hex sendiri di layar. Pilih **nada**, sistem yang memberi
warnanya:

```dart
enum AppTone { neutral, primary, accent, success, warning, danger, info }

final c = AppTone.success.colors;   // c.fg (teks/ikon), c.bg (latar), c.border
```

Pemetaan status domain → nada (WAJIB seragam di semua layar):

| Keadaan | Nada |
|---|---|
| Lunas / selesai / stok aman | `AppTone.success` |
| Hutang / bon / transaksi ditahan | `AppTone.accent` |
| Stok menipis | `AppTone.warning` |
| Dibatalkan (void) / stok habis | `AppTone.danger` |
| Non-tunai (QRIS/transfer) | `AppTone.info` |
| Tanpa penekanan (kategori, jumlah item) | `AppTone.neutral` |

### 2.6 Shadow & overlay
`AppColors.shadowBase` = `#3B2E1F` (cokelat hangat). **Tidak pernah pakai
hitam/abu murni untuk shadow** — di atas kanvas krem hasilnya terlihat kotor.

---

## 3. Tipografi

File: `lib/core/constants/app_typography.dart` · Font: **Plus Jakarta Sans**
(bundled di `assets/fonts/`, bobot 400/500/600/700/800).

**Kenapa font ini:** dirancang di Indonesia (Tokotype, awalnya untuk identitas
kota Jakarta) — relevan secara budaya, geometris-humanis (modern tapi ramah),
dan angkanya lebar & jelas untuk dibaca cepat.

**Kenapa di-bundle, bukan `google_fonts`:** package `google_fonts` mengunduh
font dari internet saat runtime pertama. PRD §1 mewajibkan aplikasi 100%
offline. **DILARANG menambah dependency `google_fonts`.**

### 3.1 Skala (sudah jadi `Theme.of(context).textTheme`)

| Peran | Ukuran / line-height | Bobot | Dipakai untuk |
|---|---|---|---|
| `displayLarge` | 40 / 1.10 | 800 | Kembalian di layar sukses |
| `displayMedium` | 34 / 1.12 | 800 | Angka hero sekunder |
| `displaySmall` | 28 / 1.15 | 800 | Total belanja |
| `headlineLarge` | 26 / 1.20 | 800 | Judul layar hero |
| `headlineMedium` | 22 / 1.25 | 700 | Judul besar dalam konten |
| `headlineSmall` | 20 / 1.30 | 700 | Judul dialog, judul EmptyState |
| `titleLarge` | 20 / 1.30 | 800 | **Judul AppBar** (otomatis) |
| `titleMedium` | 16 / 1.35 | 700 | Judul kartu, nama produk di list |
| `titleSmall` | 14 / 1.40 | 700 | Judul tab, sub-judul |
| `bodyLarge` | 16 / 1.50 | 400 | Teks isi utama, isi field |
| `bodyMedium` | 14 / 1.50 | 400 | Teks isi sekunder |
| `bodySmall` | 12 / 1.45 | 500 | Keterangan, timestamp (warna `inkSecondary`) |
| `labelLarge` | 15 / 1.20 | 700 | Teks tombol (otomatis) |
| `labelMedium` | 12 / 1.20 | 700 | Chip, badge |
| `labelSmall` | 11 / 1.20 | 700 · ls 0.6 | Label mungil |

### 3.2 Gaya khusus (`AppTextStyles`)

| Gaya | Untuk |
|---|---|
| `AppTextStyles.eyebrow` | Label kapital kecil di atas judul section ("RINGKASAN HARI INI") |
| `AppTextStyles.money` (16/700) | Nominal di list & kartu |
| `AppTextStyles.moneyLarge` (28/800) | Total belanja, omzet |
| `AppTextStyles.moneyHero` (40/800) | Total & kembalian di layar sukses |
| `AppTextStyles.numeric` (15/700) | Qty, stok, jumlah transaksi |

Semua gaya uang/angka memakai **tabular figures** supaya digit sejajar antar
baris dan tidak "goyang" saat berubah. Pakai `AppMoneyText` (§5) daripada
`Text` biasa untuk nominal.

### 3.3 Disiplin
- Maksimal **4 ukuran** dan **2 bobot** dalam satu layar.
- Hierarki dari ukuran + bobot + **warna**, bukan dari mem-bold semuanya.
- Teks sekunder: turunkan warnanya ke `inkSecondary`, jangan turunkan opacity.

---

## 4. Token Spacing, Radius, Elevasi, Motion

File: `lib/core/constants/app_sizes.dart` & `app_shadows.dart`

### 4.1 Spacing (grid 4pt)

| Token | Nilai | Dipakai untuk |
|---|---|---|
| `spaceXs` | 4 | Label ke nilainya, ikon ke teks kecil |
| `spaceSm` | 8 | Antar elemen dalam satu baris |
| `spaceMs` | 12 | Antar item list padat, padding banner |
| `spaceMd` | 16 | **Padding layar** & padding kartu default |
| `spaceMl` | 20 | Padding kartu lega (kartu hero/ringkasan) |
| `spaceLg` | 24 | Antar grup dalam satu section |
| `spaceXl` | 32 | Antar section |
| `space2xl` | 48 | Jeda besar (empty state) |
| `space3xl` | 64 | Ruang napas hero |
| `screenPadding` | 16 | Padding horizontal SEMUA layar |
| `bottomSafePadding` | 96 | Padding bawah scroll view agar konten terakhir tidak tertutup dock nav / bar keranjang |

**Aturan relasi:** kalau jarak antar elemen sekerabat 8, jarak ke grup
berikutnya minimal 2× (16–24). Jangan pernah menulis angka mentah
(`SizedBox(height: 13)`).

### 4.2 Radius

| Token | Nilai | Untuk |
|---|---|---|
| `radiusXs` | 6 | Badge mungil, checkbox |
| `radiusSm` | 10 | Chip kecil, thumbnail, tombol ikon |
| `radiusMd` | 14 | Tombol, field input |
| `radiusLg` | 18 | **Kartu**, tile produk, banner, FAB |
| `radiusXl` | 24 | Dialog, dock nav, kartu hero |
| `radius2xl` | 28 | Bottom sheet (sudut atas) |
| `radiusPill` | 999 | Pill status, chip filter |

Aturan: makin besar elemennya, makin besar radiusnya. Radius elemen di dalam
kartu harus lebih kecil dari radius kartunya.

### 4.3 Elevasi (`AppShadows`)

| Token | Untuk |
|---|---|
| `level0` | Datar — kartu di dalam list panjang (andalkan garis `border`) |
| `level1` | Kartu ringkasan / kartu yang bisa ditekan |
| `level2` | Elemen mengambang: dock nav, bar keranjang, kartu hero |
| `level3` | Dialog, bottom sheet, menu |
| `primaryGlow` | **Hanya** di bawah CTA utama (tombol Bayar) |

Semua shadow dua lapis (ambient rapat + key light lebar) dengan warna cokelat
hangat. **Jangan pakai `elevation:` Material secara langsung** — tema sudah
menyetel elevation 0 di mana-mana dan kedalaman diatur lewat `AppShadows`.

### 4.4 Target sentuh
`minTouchTarget` 48 · `buttonHeight` 52 (default tombol) · `buttonHeightLarge`
60 (CTA bar bawah: Bayar/Simpan) · ikon `iconSm` 18 / `iconMd` 22 / `iconLg` 28
/ `iconXl` 40.

### 4.5 Motion (`AppDurations`)
`instant` 120ms (feedback tekan) · `fast` 200ms (transisi standar) ·
`medium` 320ms (sheet/dialog) · `slow` 500ms (perayaan checkout).
Kurva default: `Curves.easeOutCubic`. Jangan ada animasi > 500ms.

---

## 5. Komponen Bersama

Semua ada di `lib/core/widgets/`, cukup satu import:

```dart
import '../../../core/widgets/app_widgets.dart';
```

Barrel ini sudah mengekspor `AppColors`, `AppTone`, `AppSizes`, `AppShadows`,
`AppTextStyles`, `AppDecorations`, dan seluruh widget di bawah — **tidak perlu
import `app_colors.dart`/`app_sizes.dart` terpisah lagi.**

### 5.1 `AppCard` — permukaan dasar

Ganti SEMUA `Card` dan `Container` + `BoxDecoration` manual dengan ini.

```dart
// Kartu biasa di dalam list (datar + garis tipis):
AppCard(
  onTap: () => _bukaDetail(),
  child: Row(children: [...]),
)

// Kartu ringkasan yang menonjol:
AppCard(
  elevated: true,
  padding: const EdgeInsets.all(AppSizes.spaceMl),
  child: Column(...),
)

// Kartu dalam keadaan terpilih (border & latar hijau):
AppCard(selected: isSelected, onTap: ..., child: ...)

// Sub-panel di dalam kartu:
AppCard(color: AppColors.surfaceAlt, radius: AppSizes.radiusMd, child: ...)
```

Parameter: `padding` (default 16), `margin`, `onTap`, `onLongPress`, `color`,
`borderColor`, `radius`, `elevated`, `selected`, `width`.

### 5.2 `SectionHeader` — judul section

```dart
SectionHeader(
  title: 'Produk Terlaris',
  subtitle: '7 hari terakhir',
  actionLabel: 'Lihat semua',
  onAction: () => ...,
)

SectionHeader(eyebrow: 'RINGKASAN', title: 'Hari Ini')

SectionHeader(title: 'Keranjang', trailing: AppPill(label: '3 item'))
```

### 5.3 `EmptyState` — layar/daftar kosong

```dart
EmptyState(
  icon: Icons.inventory_2_outlined,
  title: 'Belum ada produk',
  message: 'Tambahkan barang jualanmu supaya bisa langsung dipakai di layar kasir.',
  actionLabel: 'Tambah Produk',
  onAction: () => ...,
)

// Versi ringkas di dalam kartu/section:
EmptyState(icon: ..., title: ..., compact: true)
```

### 5.4 `AppPill` — label status

```dart
const AppPill(label: 'Lunas', tone: AppTone.success);
const AppPill(label: 'Hutang', tone: AppTone.accent, icon: Icons.schedule);
const AppPill(label: 'BATAL', tone: AppTone.danger, filled: true);  // penekanan maksimal
const AppPill(label: 'Minuman', dense: true);                        // netral, di list padat
```

**Teks panjang (sejak v1.1):** label selalu **satu baris dan dipotong dengan
elipsis** — pill tidak akan lagi meluber saat diisi data dinamis (nama
pelanggan, nomor struk). Tampilan untuk teks pendek tidak berubah: pill tetap
menciut ke lebar isinya.

- Di `Wrap`, `ListTile.trailing`, `Column`, `Flexible`/`Expanded` → pill
  menyusut sendiri mengikuti ruang yang tersedia. Tidak perlu apa-apa.
- Sebagai **anak langsung `Row`**, lebar yang diterima pill tak terbatas
  sehingga Row tidak bisa memberitahu sisa ruangnya. Untuk label dinamis di
  posisi itu, bungkus `Flexible(child: AppPill(...))` **atau** isi `maxWidth`:

```dart
Row(children: [
  Flexible(child: AppPill(label: sale.customerName, tone: AppTone.accent)),
  ...
]);

// atau plafon eksplisit (bukan lebar tetap — teks pendek tetap menciut):
AppPill(label: sale.customerName, tone: AppTone.accent, maxWidth: 140);
```

### 5.5 `AppIconBadge` — ikon dalam kotak lembut

```dart
const AppIconBadge(icon: Icons.payments_outlined, tone: AppTone.success);
const AppIconBadge(icon: Icons.inventory_2_outlined, size: AppIconBadgeSize.lg);
```
Ukuran: `sm` 32 · `md` 40 (default) · `lg` 52 · `xl` 72.
Pakai sebagai `leading` list item & ikon kartu ringkasan — jauh lebih hidup
daripada ikon telanjang.

### 5.6 `AppKeyValueRow` — baris "label — nilai"

```dart
AppKeyValueRow(label: 'Subtotal', value: CurrencyFormatter.format(sub)),
AppKeyValueRow(label: 'Diskon', value: '-Rp2.000', valueColor: AppColors.dangerText),
AppKeyValueRow(label: 'Total', value: CurrencyFormatter.format(total), emphasized: true),
```

### 5.7 `AppMoneyText` — nominal rupiah

```dart
AppMoneyText(CurrencyFormatter.format(p.price));                        // md
AppMoneyText(CurrencyFormatter.format(total), size: AppMoneySize.lg);
AppMoneyText(CurrencyFormatter.format(kembalian), size: AppMoneySize.hero);
AppMoneyText(hargaAsli, size: AppMoneySize.sm, strikethrough: true);    // harga sebelum diskon
```

### 5.8 `AppLoadingView` & `AppErrorView` — state async

```dart
asyncValue.when(
  data: (d) => _isi(d),
  loading: () => const AppLoadingView(),
  error: (e, _) => AppErrorView(
    message: AppErrorMessage.from(e),
    onRetry: () => ref.invalidate(provider),
  ),
);
```

### 5.9 `AppBanner` — pesan kontekstual menetap

```dart
AppBanner(
  tone: AppTone.warning,
  icon: Icons.warning_amber_rounded,
  message: '5 produk stoknya menipis.',
  actionLabel: 'Lihat',
  onAction: () => ...,
)
```
Untuk pesan sekilas pakai `SnackBar` (sudah bertema gelap mengambang).

### 5.10 `AppDecorations` — kalau benar-benar butuh `BoxDecoration`

```dart
AppDecorations.card()                       // permukaan kartu standar
AppDecorations.floating()                   // elemen mengambang (bar bawah)
AppDecorations.tonal(AppTone.warning)       // latar lembut bernada
```

---

## 6. Navigasi Utama

`lib/core/widgets/main_shell.dart` — **dock mengambang**, bukan `NavigationBar`
Material: kartu putih hangat radius 24 dengan shadow `level2`, kapsul hijau
`primary50` yang membesar halus (200ms) di tab aktif, ikon berganti
outlined→filled dengan transisi scale+fade, haptic `selectionClick` saat
pindah tab.

Label tab: **Kasir · Produk · Riwayat · Laporan · Setelan**
("Pengaturan" dipendekkan jadi "Setelan" agar muat tanpa terpotong di HP kecil).
Badge stok menipis tetap di tab Produk; gate PIN untuk Laporan & Setelan tidak
berubah.

**Konsekuensi untuk layar:** dock memakan ~78dp di bawah. Setiap scroll view
di layar tab WAJIB menambah `AppSizes.bottomSafePadding` (96) di bawah, atau
konten terakhir akan tertutup.

---

## 7. ATURAN WAJIB UNTUK AGENT LAYAR

### 7.1 DO — lakukan ini

1. **DO** import lewat barrel: `import '../../../core/widgets/app_widgets.dart';`
2. **DO** pakai `AppCard`, `SectionHeader`, `EmptyState`, `AppPill`,
   `AppIconBadge`, `AppKeyValueRow`, `AppMoneyText`, `AppLoadingView`,
   `AppErrorView`, `AppBanner` untuk pola yang sudah ada widget-nya.
3. **DO** pakai token: `AppSizes.space*`, `AppSizes.radius*`, `AppColors.*`,
   `AppTone`, `AppShadows.*`, `AppDurations.*`.
4. **DO** ambil gaya teks dari `Theme.of(context).textTheme.*` atau
   `AppTextStyles.*`.
5. **DO** bungkus SEMUA nominal rupiah dengan `AppMoneyText` (atau
   `AppTextStyles.money*`) supaya digitnya sejajar.
6. **DO** buat nilai lebih menonjol daripada labelnya.
7. **DO** taruh aksi utama di sepertiga bawah layar, tinggi
   `AppSizes.buttonHeightLarge`, lebar penuh, di dalam bar mengambang
   (`AppDecorations.floating()`).
8. **DO** tambahkan `padding: EdgeInsets.only(bottom: AppSizes.bottomSafePadding)`
   pada scroll view di layar tab.
9. **DO** pakai `AppTone` sesuai pemetaan §2.5 — status yang sama harus
   berwarna sama di layar manapun.
10. **DO** rancang keempat state: data, kosong, loading, error. Layar kosong
    wajib punya kalimat pengarah + tombol aksi.
11. **DO** pakai teks bahasa Indonesia yang ramah & manusiawi ("Belum ada
    transaksi hari ini", bukan "No data").
12. **DO** jaga target sentuh ≥48dp, terutama tombol +/− qty di keranjang.
13. **DO** pakai ikon `_outlined` untuk keadaan pasif dan versi filled untuk
    aktif/terpilih — konsisten dengan dock nav.
14. **DO** jalankan `flutter analyze` (harus 0 issue) sebelum selesai.

### 7.2 DON'T — jangan pernah

1. **DON'T** menulis hex warna langsung (`Color(0xFF...)`) di folder
   `lib/features/`. Semua warna dari `AppColors`/`AppTone`.
2. **DON'T** memakai `Colors.grey`, `Colors.blue`, `Colors.red`, dst. Palet
   Material bawaan merusak identitas — pakai `AppColors`.
3. **DON'T** menulis angka spacing/radius mentah (`SizedBox(height: 13)`,
   `BorderRadius.circular(7)`). Selalu token.
4. **DON'T** memakai `Card`, atau `Container` + `BoxDecoration` manual untuk
   permukaan. Pakai `AppCard`.
5. **DON'T** meng-override tema komponen secara lokal (warna AppBar sendiri,
   `ElevatedButton.styleFrom` dengan warna sendiri, dsb). Kalau merasa perlu,
   berarti ada yang kurang di fondasi — laporkan, jangan tambal di layar.
6. **DON'T** memakai `elevation:` Material atau `BoxShadow` buatan sendiri.
   Pakai `AppShadows`.
7. **DON'T** memakai `AppColors.accent` sebagai warna teks di atas latar
   terang (kontras 3,0:1). Untuk teks pakai `AppColors.accentText`.
8. **DON'T** memakai `AppColors.inkTertiary` untuk teks kecil yang penting —
   hanya hint/placeholder.
9. **DON'T** memakai `withOpacity`/opacity untuk hierarki teks. Ganti warnanya
   ke `inkSecondary`.
10. **DON'T** memakai lebih dari 4 ukuran huruf atau 3 bobot dalam satu layar.
11. **DON'T** memakai gradient, glassmorphism, atau blur. Bukan bahasa visual
    aplikasi ini.
12. **DON'T** menambah dependency font/ikon baru — khususnya `google_fonts`
    (melanggar prinsip offline PRD §1).
13. **DON'T** menampilkan "Tidak ada data" telanjang, atau melempar pesan
    `Exception: ...` mentah ke UI (pakai `AppErrorMessage.from(e)`).
14. **DON'T** mengubah logika bisnis, provider, repository, atau skema data.
    Pekerjaan agent layar murni visual & struktur widget.
15. **DON'T** menyembunyikan aksi utama di balik menu tiga titik atau di luar
    zona jempol.
16. **DON'T** mengedit file di `lib/core/constants/` atau `lib/core/widgets/`
    tanpa alasan kuat — itu milik bersama. Kalau butuh komponen baru yang
    dipakai >1 layar, tambahkan ke `lib/core/widgets/`, ekspor di
    `app_widgets.dart`, dan catat di dokumen ini.

### 7.3 Resep cepat per pola

| Kebutuhan | Pakai |
|---|---|
| Baris item di list (produk, transaksi) | `AppCard` + `AppIconBadge` (leading) + `titleMedium` (nama) + `bodySmall` (keterangan) + `AppMoneyText` (kanan) + `AppPill` (status) |
| Kartu angka ringkasan | `AppCard(elevated: true)` + `AppTextStyles.eyebrow` (label) + `AppMoneyText(size: lg)` (nilai) |
| Ringkasan total keranjang/struk | Deretan `AppKeyValueRow`, baris terakhir `emphasized: true` |
| Filter kategori/preset tanggal | `ChoiceChip` (sudah bertema pill) dalam list horizontal, tinggi ≥40 |
| Bar aksi bawah | `Container(decoration: AppDecorations.floating())` + `FilledButton` setinggi `buttonHeightLarge` |
| Sheet input (bayar, diskon) | `showModalBottomSheet` (tema sudah mengurus radius, drag handle, warna) |
| Konfirmasi hapus/void | `AlertDialog` + tombol utama `FilledButton` warna `AppColors.danger` (satu-satunya override warna tombol yang diizinkan) |

---

## 8. Berkas yang Menyusun Fondasi

| File | Isi |
|---|---|
| `lib/core/constants/app_colors.dart` | Palet + `AppTone` + resolver trio warna |
| `lib/core/constants/app_typography.dart` | Font family, skala teks, `AppTextStyles` |
| `lib/core/constants/app_sizes.dart` | Spacing, radius, target sentuh, ikon, `AppDurations` |
| `lib/core/constants/app_shadows.dart` | Token elevasi (shadow hangat 2 lapis) |
| `lib/core/constants/app_theme.dart` | Tema Material 3 lengkap + `AppDecorations` |
| `lib/core/widgets/app_widgets.dart` | **Barrel export** — satu-satunya import yang dibutuhkan layar |
| `lib/core/widgets/app_card.dart` | `AppCard` |
| `lib/core/widgets/app_pill.dart` | `AppPill`, `AppIconBadge` |
| `lib/core/widgets/section_header.dart` | `SectionHeader` |
| `lib/core/widgets/empty_state.dart` | `EmptyState` |
| `lib/core/widgets/app_state_views.dart` | `AppLoadingView`, `AppErrorView`, `AppBanner` |
| `lib/core/widgets/app_data_row.dart` | `AppKeyValueRow`, `AppMoneyText` |
| `lib/core/widgets/main_shell.dart` | Dock navigasi kustom |
| `assets/fonts/PlusJakartaSans-*.ttf` | Font bundled (5 bobot) |

Komponen Material yang sudah bertema penuh di `app_theme.dart` (tidak perlu
disetel ulang di layar): AppBar, Card, Elevated/Filled/Outlined/Text/Icon/
Segmented Button, FAB, InputDecoration, TextSelection, Chip, Dialog,
BottomSheet, PopupMenu, Menu, Tooltip, NavigationBar, BottomNavigationBar,
TabBar, ListTile, Divider, ExpansionTile, SnackBar, ProgressIndicator, Badge,
Switch, Checkbox, Radio, Slider, DatePicker.

---

## 9. Catatan Verifikasi

- `flutter analyze` → **No issues found!** (0 error, 0 warning).
- `flutter test` → **215 test lolos** (0 gagal).
- v1.1: `AppPill` diperbaiki agar aman untuk teks dinamis panjang (elipsis
  satu baris + menyusut mengikuti ruang). Regresi dikunci oleh 7 test di
  `test/core/widgets/app_pill_test.dart` (ruang sempit, Wrap, Row unbounded,
  `maxWidth`, varian `dense`).
- Widget test navigasi disesuaikan ke dock baru: `MainShell.dockKey`
  (`Key('mainNavDock')`) jadi pegangan stabil untuk menemukan navigasi, dan
  index tab dibaca dari `StatefulNavigationShell.currentIndex`, bukan lagi
  `NavigationBar.selectedIndex`. Label tab "Pengaturan" → "Setelan".
- Font terverifikasi masuk bundle (`FontManifest.json` memuat 5 bobot
  Plus Jakarta Sans).
- Smoke test render seluruh komponen fondasi: lolos tanpa overflow/exception.
- Perbaikan di luar scope desain yang terpaksa dilakukan agar proyek bisa
  di-compile: `lib/features/settings/widgets/backup_restore_section.dart` —
  `FilePicker.platform.pickFiles(...)` → `FilePicker.pickFiles(...)`
  (API `file_picker` 12.x menghapus `.platform`; error ini sudah ada sebelum
  redesign dan membuat SELURUH widget test gagal compile).
