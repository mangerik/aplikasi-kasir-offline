package com.erik.kasir.kasir_warung

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Satu-satunya kode platform milik aplikasi ini: membaca SSAID
 * (`Settings.Secure.ANDROID_ID`) sebagai sumber kode perangkat lisensi
 * (PRD v1.1 §6.3.C, K-6.5).
 *
 * Sengaja ditulis sendiri (±15 baris) alih-alih menambah package
 * `android_id`: tidak ada dependency platform baru, tidak ada modul Gradle
 * tambahan, dan tidak ada kelas kegagalan `namespace`/AGP yang pernah
 * menghentikan M0 & M6.
 *
 * Sifat SSAID yang membuatnya tepat untuk fitur ini: pada Android 8.0+ ia
 * unik per (kunci penanda tangan APK × pengguna × perangkat), **bertahan
 * melewati uninstall–reinstall** selama APK ditandatangani kunci rilis yang
 * sama, dan hanya berubah saat factory reset. Trial jadi tidak bisa direset
 * dengan memasang ulang, sementara pengguna jujur tidak kehilangan
 * lisensinya saat memperbarui aplikasi.
 *
 * Nilai mentahnya TIDAK pernah ditampilkan maupun dikirim ke mana pun —
 * sisi Dart langsung meng-hash-nya (`DeviceCode.fromSeed`).
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "kasirwarung/device"
        const val METHOD_SSAID = "ssaid"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == METHOD_SSAID) {
                    // Bisa null pada sebagian perangkat/pengguna kerja; sisi
                    // Dart yang memutuskan memakai pengenal cadangan.
                    result.success(
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
