import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci penanda tangan RILIS (PRD v1.1 §6.7.2). Kredensialnya hidup di
// `android/key.properties` yang TIDAK ikut repo — keystore & passwordnya
// aset penjual, bukan aset kode.
//
// PENTING: kode perangkat lisensi (SSAID) terikat kunci penanda tangan.
// Mengganti keystore = seluruh kode aktivasi yang sudah beredar tidak
// cocok lagi. Satu keystore dipakai selamanya, termasuk untuk setiap
// pembaruan versi.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.erik.kasir.kasir_warung"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.erik.kasir.kasir_warung"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Tanpa `android/key.properties`, build JATUH ke kunci debug —
            // cukup untuk `flutter run --release` di mesin dev, TAPI kode
            // perangkatnya berbeda dari APK rilis sungguhan. APK yang
            // dibagikan ke pembeli WAJIB dibangun dengan keystore rilis;
            // penjaganya adalah baris peringatan di bawah.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "PERINGATAN: android/key.properties tidak ditemukan — " +
                        "release ditandatangani KUNCI DEBUG. Jangan bagikan " +
                        "APK ini ke pembeli: kode perangkat lisensinya akan " +
                        "berubah saat pindah ke APK bertanda kunci rilis.",
                )
                signingConfigs.getByName("debug")
            }
            // R8/shrink aktif (plan.md Milestone 6 poin 6) — perkecil ukuran APK
            // (target < 40 MB per PRD §6). Keep rules tambahan di proguard-rules.pro
            // untuk library yang pakai reflection (sqlite3 FFI, dsb).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
