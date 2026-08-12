import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/features/settings/widgets/printer_device_sheet.dart';

/// Kontrak `MethodChannel('kasir_warung/system')` — pintasan "Buka
/// Pengaturan Bluetooth Android" (AC-3.16).
///
/// Sampai M11 tombol ini **tidak melakukan apa-apa**: sisi Dart memanggil
/// channel yang belum punya penerima di `MainActivity.kt` (lihat
/// laporan-m8.md §5). Test ini memaku nama channel dan nama metodenya
/// supaya salah satu sisi tidak bisa lagi berganti nama diam-diam dan
/// membuat tombolnya kembali jadi no-op — kegagalannya memang tidak pernah
/// terlihat di layar, jadi hanya test yang bisa menjaganya.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final binding = TestDefaultBinaryMessengerBinding.instance;
  final channel = PrinterDeviceSheet.systemChannel;

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('nama channel persis sama dengan yang didengarkan MainActivity.kt', () {
    expect(channel.name, 'kasir_warung/system');
  });

  test('memanggil metode openBluetoothSettings dan meneruskan hasil true', () async {
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });

    final opened = await PrinterDeviceSheet.openAndroidBluetoothSettings();

    expect(opened, isTrue);
    expect(calls.map((c) => c.method), ['openBluetoothSettings']);
    expect(calls.single.arguments, isNull);
  });

  test('handler menjawab false (ROM tanpa layar Bluetooth) → false, tanpa lempar', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async => false);

    await expectLater(PrinterDeviceSheet.openAndroidBluetoothSettings(), completion(isFalse));
  });

  test('handler belum terpasang (notImplemented) → false, bukan crash', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async => null);

    await expectLater(PrinterDeviceSheet.openAndroidBluetoothSettings(), completion(isFalse));
  });

  test('handler melempar PlatformException → ditelan jadi false', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'ERROR', message: 'gagal membuka');
    });

    await expectLater(PrinterDeviceSheet.openAndroidBluetoothSettings(), completion(isFalse));
  });
}
