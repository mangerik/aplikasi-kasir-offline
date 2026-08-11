# Aturan tambahan R8/ProGuard untuk build release (plan.md Milestone 6 poin 6).
#
# Flutter engine, plugin embedding, dan kode Dart (dikompilasi AOT ke
# libapp.so) TIDAK terpengaruh R8 sama sekali — aturan di sini hanya untuk
# sisi Java/Kotlin (native plugin glue) dari dependency yang dipakai proyek
# ini (lihat pubspec.yaml): sqlite3 (FFI ke native SQLite), mobile_scanner
# (ML Kit barcode), file_picker, share_plus.

# sqlite3 (package Dart `sqlite3`, dipakai BackupService.validateBackupFile)
# memuat native lib via JNI/dlopen — jaga class yang direferensikan reflektif.
-keep class io.tekartik.sqflite.** { *; }
-dontwarn org.sqlite.**

# ML Kit barcode scanning (dipakai mobile_scanner) — banyak class internal
# diakses lewat reflection oleh Play Services ML Kit.
-keep class com.google.mlkit.vision.barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# Umum: jangan hapus anotasi Keep dari AndroidX/dependency pihak ketiga yang
# sudah menandai sendiri bagian yang wajib dipertahankan.
-keep @androidx.annotation.Keep class * { *; }
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <methods>;
}
