# Laporan — Backup Otomatis Lokal & Riwayat di Perangkat

Tanggal: 2026-08-13 · Lanjutan revisi pasca-v1.2.0 (lihat
[laporan-revisi-void-lisensi.md](laporan-revisi-void-lisensi.md))

Permintaan user: data harus terpotret otomatis supaya kalau ada yang
terhapus tinggal direstore, dan sistem tahu file backup apa saja yang ada
di perangkat.

## Perilaku

- **Harian**: sekali per hari kalender, setelah frame pertama aplikasi
  dibuka (`app.dart` postFrameCallback → `runDailyIfNeeded`). Penanda
  harinya di `settings.last_auto_backup_at` — SENGAJA terpisah dari
  `last_backup_at` milik pengingat backup, karena pengingat menagih
  salinan yang dibagikan KELUAR perangkat, bukan potret internal.
- **Saat lisensi habis**: listener di `app.dart` menangkap perpindahan
  keadaan dari masih-berlaku (`canSell`) ke `kedaluwarsaTrial`/
  `kedaluwarsaTahunan` dan langsung memotret — dari revalidate mana pun
  (cold start, resumed, setelah penjualan).
- **Rotasi**: hanya file berawalan `kasir_backup_otomatis_` yang dirotasi;
  **7 terbaru** disimpan (keputusan user). Backup manual tidak pernah
  dihapus sistem.
- **Riwayat**: panel "Riwayat di Perangkat" di Pengaturan → Backup &
  Restore menampilkan seluruh file `backups/` (tanggal, ukuran, pill
  Otomatis/Manual) dengan aksi pulihkan yang memakai jalur restore lama
  persis (validasi + konfirmasi ganda + sign-out sesi).
- **Tidak pernah melempar**: kegagalan backup otomatis/daftar riwayat
  tertelan senyap — jaring pengaman tidak boleh mengganggu kasir.

## Batas yang dijelaskan ke pengguna (teks di panel)

File riwayat hidup di penyimpanan internal aplikasi: ikut hilang bila
aplikasi di-uninstall, dan sengaja tidak ikut Auto Backup Google
(`allowBackup=false`, alasan lisensi). Salinan benar-benar aman tetap
lewat "Backup Sekarang" → simpan di luar HP.

## Berkas

| Berkas | Perubahan |
|---|---|
| `lib/data/services/backup_service.dart` | `BackupFileInfo`, `createAutoBackup` (+anti-timpa nama, rotasi), `listBackups` |
| `lib/features/settings/providers/auto_backup_providers.dart` | **baru** — `AutoBackupService`, `backupHistoryProvider` |
| `lib/app.dart` | pemicu harian + listener transisi lisensi |
| `lib/features/settings/widgets/backup_restore_section.dart` | panel riwayat + `_restore(presetPath:)` |

Test: 846/846 (8 baru — 4 `backup_service_test.dart`, 4
`auto_backup_test.dart`). Catatan uji fisik tambahan: lihat kemunculan
file otomatis di HP sungguhan setelah ganti tanggal & saat trial habis.
