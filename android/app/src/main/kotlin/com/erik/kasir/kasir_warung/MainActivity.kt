package com.erik.kasir.kasir_warung

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Satu-satunya kode platform milik aplikasi ini, dua channel yang berdiri
 * sendiri-sendiri:
 *
 * 1. [CHANNEL_DEVICE] — membaca SSAID (`Settings.Secure.ANDROID_ID`) sebagai
 *    sumber kode perangkat lisensi (PRD v1.1 §6.3.C, K-6.5).
 * 2. [CHANNEL_SYSTEM] — pintasan ke layar Pengaturan Bluetooth Android untuk
 *    memasangkan printer thermal (PRD v1.1 §3.3.A, AC-3.16).
 *
 * Keduanya sengaja ditulis sendiri (masing-masing ±15 baris) alih-alih
 * menambah package: tidak ada dependency platform baru, tidak ada modul
 * Gradle tambahan, dan tidak ada kelas kegagalan `namespace`/AGP yang pernah
 * menghentikan M0 & M6.
 *
 * Sifat SSAID yang membuatnya tepat untuk fitur lisensi: pada Android 8.0+ ia
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
        const val CHANNEL_DEVICE = "kasirwarung/device"
        const val METHOD_SSAID = "ssaid"

        const val CHANNEL_SYSTEM = "kasir_warung/system"
        const val METHOD_OPEN_BLUETOOTH_SETTINGS = "openBluetoothSettings"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, CHANNEL_DEVICE).setMethodCallHandler { call, result ->
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

        MethodChannel(messenger, CHANNEL_SYSTEM).setMethodCallHandler { call, result ->
            if (call.method == METHOD_OPEN_BLUETOOTH_SETTINGS) {
                result.success(openBluetoothSettings())
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * Membuka layar Bluetooth bawaan Android. Mengembalikan `true` bila
     * layarnya benar-benar terbuka.
     *
     * Kegagalan TIDAK dilaporkan sebagai error channel: pintasan ini cuma
     * mempercepat panduan tiga langkah yang sudah tercetak di layar, jadi
     * ROM yang tidak punya layar ini (atau membatasinya) cukup dijawab
     * `false` — sisi Dart membiarkan pengguna melanjutkan manual, tanpa
     * dialog error teknis.
     */
    private fun openBluetoothSettings(): Boolean {
        return try {
            startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
            true
        } catch (_: ActivityNotFoundException) {
            // Sebagian ROM tidak mengekspor layar Bluetooth secara langsung —
            // coba layar Pengaturan utama sebagai jalan tengah.
            try {
                startActivity(Intent(Settings.ACTION_SETTINGS))
                true
            } catch (_: ActivityNotFoundException) {
                false
            }
        } catch (_: SecurityException) {
            false
        }
    }
}
