/// Vektor uji **tetap** untuk verifikator lisensi (PRD v1.1 AC-6.8).
///
/// Seluruh kode di bawah ditandatangani kunci **uji**
/// (`license_test_keys.dart`) dan di-commit apa adanya. Sengaja konstanta,
/// bukan dibangkitkan ulang tiap kali test berjalan: kalau format muatan,
/// urutan byte, tabel CRC, atau alfabet Base32 pernah berubah tanpa
/// disengaja, test yang membangkitkan sendiri kodenya akan tetap hijau —
/// hanya vektor beku yang bisa menangkap perubahan format yang merusak
/// kompatibilitas dengan kode yang SUDAH beredar di tangan pembeli.
///
/// Seluruhnya berjalan tanpa perangkat & tanpa jaringan.
library;

/// Kode perangkat yang dipakai vektor di bawah — turunan benih tetap, sama
/// dengan default `deviceCodeProvider` pada widget test.
const String kVectorDeviceSeed = 'kasirwarung.test.device';
const String kVectorDeviceRaw = 'X3G2C4BNT0';

/// Perangkat lain (untuk AC-6.5).
const String kVectorOtherDeviceSeed = 'perangkat-lain-uji';
const String kVectorOtherDeviceRaw = '4XFVRZS78Y';

/// Coba (trial) 3 hari, terbit 2026-08-10 → kedaluwarsa 2026-08-13.
const String kVectorTrialValid =
    '040GJV89E00BH64BJ5914H9FXD9DHJ1NBZS9JTWH39KZTVZX5ZGWYWKPG4G7CSEMFJ1JJBYHVQHCMMPJ2SRY886QC8DSJDSY70R1VGGGRDGPG63QQ9QGFPDQ';

/// Coba, terbit 2026-01-01 → sudah lewat kedaluwarsa (2026-01-04).
const String kVectorTrialExpired =
    '040GH408JC0BH65PSADHPMB6JCX55Z69N7B10GY2XNQNNF7F8QY32RTRZ5V0JY45MEXMGDWER368D0THN0BWM9NJJ3QS1R94JNXV8GDZEP3Q054HRP10Z9V9';

/// Selamanya, terbit 2026-08-10.
const String kVectorLifetime =
    '0410JVFZZW0BH60JH1QA0BM1GRWCSQCJ05H7ZZKZ974D0JV13EABTRC11T6D74FEMV7CX82FVRJM3FTTPVAKAXA9HBD20T4N8KPNME8CQSG8J7ZJQN9GRRDH';

/// Selamanya, terbit 2020-01-01 — bukti bahwa "selamanya" memang tidak
/// pernah kedaluwarsa berapa pun umurnya.
const String kVectorLifetimeOld =
    '0410007ZZW0BH63NZMWKCABBMBB7ZNY8V4NMWPTCRVZZXCJ3XCTEZE2Q01JNA6C11VQ3E4M5XN3T943AKY7CM66BK6S0J328S0B3ECGVEP2MG78RJQBGEGB6';

/// Tahunan, terbit 2026-08-01 → kedaluwarsa 2027-08-01, tenggang 7 hari.
const String kVectorYearlyValid =
    '041GJS0AT43VH62DNSK3FGN86HKKQP366RJTKT6ZM289DYZFQ2CV8XSJDCFV4602GVCJSZZAGS3AM4RCCHBSQXRAXYYWM9M74XR4V2CA6CNP2BVFFY30HXZC';

/// Tahunan, terbit 2024-01-01 → kedaluwarsa 2024-12-31, tenggang 7 hari.
const String kVectorYearlyExpired =
    '041GBD87483VH65GC4TKNSGY6AH04VJCXFEYAPVK37JHMG1B354K5EPBS5RV39X298HPQ2NZKEVX6VTKEA6ZAC47G2GB7Z3T9P46X8RXEN38CD3GBZW0SW4T';

/// Kode SAH, tapi diterbitkan untuk [kVectorOtherDeviceRaw] (AC-6.5).
const String kVectorOtherDevice =
    '0410JVFZZW040693YZNDG3R21JRDX277J4QQ8F28YWHEZBHW7BV7RWPYHHEJE4B765GXEW6H5VV6WPVDKFE162BS7615N9TZ2BB9RF3D0RVEJG0T0SDGJM28';

/// Ditandatangani kunci yang TIDAK ada di daftar tepercaya.
const String kVectorForeignKey =
    '0410JVFZZW0BH63RZANJD9W8EHA8GFE7ZGRND91H41TDWDPY25DX2MJ81PHH6D3ZX245F1EN8MTXN6GYSDY96Z7FRRCTG1KQXCCAWRYEXTZDY6PR2HP044JE';

/// Muatan versi 2 (lebih baru dari yang dikenal aplikasi) — AC-6.21.
const String kVectorFutureVersion =
    '0810JVFZZW0BH64NQV6RB90MNZGRWZ5FAQEY032XT5T5XWBJ4CTNHK9X3BK37QTCPPZCWYBVF7YHMQ6KA5BEPF545DC7RNS3RSGGGF6X92JZQ07X9F50VQM0';
